// ============================================================
// AccountRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for account (COA) operations.
//
//          Key design decisions:
//
//          1. JOIN with account_type: the query joins an account
//             to account_type to return accountTypeCode in one
//             query — no second round-trip needed.
//
//          2. Flat list ordered by code: the DB returns all
//             accounts for a ledger as a flat list sorted by
//             code ASC. Clients use parentId to reconstruct
//             the tree. This is the correct approach for
//             multi-platform clients.
//
//          3. Ledger ownership validation: before querying
//             accounts, we verify the requested ledger belongs
//             to the authenticated owner. RLS handles this
//             automatically — if the ledger doesn't belong to
//             the owner, the query returns zero rows.
//             We treat zero rows as "not found" and return
//             an appropriate error in the service layer.
//
//          4. TenantContext: all queries go through
//             TenantContext.withOwner() so SET LOCAL
//             app.current_owner_id activates RLS.
//
//          5. account_role: returned alongside each account so
//             clients can apply operational-role logic (Banks,
//             Cash, Memo) without a separate lookup call.
// ============================================================
// Last edited: 2026-03-28
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.dto.request.CreateAccountRequest;
import com.leonguevara.mab.mab_api.dto.request.PatchAccountRequest;
import com.leonguevara.mab.mab_api.dto.response.AccountTypeResponse;

// NamedParameterJdbcTemplate: executes SQL with named parameters.
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

// MapSqlParameterSource: builds the named parameter map for queries.
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

// RowMapper: maps one ResultSet row to one AccountResponse record.
import org.springframework.jdbc.core.RowMapper;

// TransactionTemplate: used by TenantContext for BEGIN/COMMIT wrapping.
import org.springframework.transaction.support.TransactionTemplate;

// @Repository: Spring data-access bean + SQL exception translation.
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * Data access layer for Chart of Accounts (COA) operations.
 * <p>
 * All tenant-scoped queries are executed inside
 * {@link com.leonguevara.mab.mab_api.config.TenantContext#withOwner TenantContext.withOwner()},
 * which issues {@code SET LOCAL app.current_owner_id} to activate PostgreSQL Row-Level
 * Security before any SQL runs. Omitting this wrapper would cause all RLS-protected
 * queries to return zero rows.
 * <p>
 * The exception is {@link #findAllAccountTypes()}, which reads the system-wide
 * {@code account_type} catalog that is shared across all tenants and is not RLS-protected.
 *
 * @see com.leonguevara.mab.mab_api.config.TenantContext
 * @see com.leonguevara.mab.mab_api.service.AccountService
 */
@Repository
public class AccountRepository {

    // JDBC template for executing named-parameter SQL.
    private final NamedParameterJdbcTemplate jdbc;

    // Transaction template for TenantContext scoping.
    private final TransactionTemplate tx;

    /**
     * Constructor injection of JDBC and transaction dependencies.
     *
     * @param jdbc JDBC template bean (from DataSourceConfig).
     * @param tx   Transaction template bean (from DataSourceConfig).
     */
    public AccountRepository(NamedParameterJdbcTemplate jdbc,
                             TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    // ── RowMapper ────────────────────────────────────────────────────────────
    // Maps a single result row to an AccountResponse record.
    // The LEFT JOIN on account_type means accountTypeCode may be null
    // for placeholder accounts — rs.getString() returns null safely.
    private static final RowMapper<AccountResponse> ACCOUNT_MAPPER = (rs, _) ->
            new AccountResponse(
                    // id: UUID primary key of this account.
                    rs.getObject("id",        UUID.class),
                    // name: display-name of the account.
                    rs.getString("name"),
                    // code: account code (e.g. "1010"). Nullable in the schema.
                    rs.getString("code"),
                    // parent_id: UUID of the parent-account. Null for the root account.
                    rs.getObject("parent_id", UUID.class),
                    // is_placeholder: grouping node — cannot receive transactions.
                    rs.getBoolean("is_placeholder"),
                    // is_hidden: UI visibility flag.
                    rs.getBoolean("is_hidden"),
                    // kind: accounting nature smallint (1=asset, 2=liability, etc.)
                    rs.getInt("kind"),
                    // at_code: account_type.code from the LEFT JOIN.
                    // Null if the account has no account_type assigned.
                    rs.getString("at_code"),
                    // account_role: operational role smallint (0=Unspecified, 101=banks,
                    // 210=Accounts payable). Clients use this for special display/validation rules.
                    rs.getInt("account_role")
            );

    /**
     * Returns all active, non-deleted accounts for a given ledger,
     * ordered by account code for natural COA display order.
     * <p>
     * Query design:
     * <ul>
     *   <li><b>LEFT JOIN account_type</b>: placeholder accounts have {@code NULL}
     *       {@code account_type_id} — LEFT JOIN ensures they still appear.</li>
     *   <li><b>WHERE a.ledger_id = :ledgerId</b>: scopes results to this ledger.</li>
     *   <li><b>RLS on account table</b>: PostgreSQL automatically filters to accounts
     *       whose ledger belongs to the current owner. If {@code ledgerId} belongs to a
     *       different owner, zero rows are returned.</li>
     *   <li><b>ORDER BY COALESCE(a.code, a.name)</b>: accounts with codes sort by code;
     *       accounts without codes sort by name as fallback.</li>
     * </ul>
     *
     * @param  ownerID   The authenticated owner's UUID (from JWT).
     * @param  ledgerID  The ledger whose accounts to retrieve.
     * @return           Flat list of AccountResponse objects.
     *                   Empty list if the ledger has no accounts or
     *                   does not belong to this owner.
     */
    @SuppressWarnings("null")
    public List<AccountResponse> findAllByLedger(UUID ownerID, UUID ledgerID) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            String sql = """
                    SELECT
                        a.id,
                        a.name,
                        a.code,
                        a.parent_id,
                        a.is_placeholder,
                        a.is_hidden,
                        a.kind,
                        at.code   AS at_code,
                        a.account_role
                    FROM  public.account      a
                    -- LEFT JOIN: placeholder accounts have no account_type_id.
                    -- Using LEFT JOIN ensures they are included in results.
                    LEFT JOIN public.account_type at
                           ON at.id = a.account_type_id
                          AND at.deleted_at IS NULL
                    WHERE a.ledger_id  = :ledgerId
                      AND a.is_active  = true
                      AND a.deleted_at IS NULL
                    ORDER BY COALESCE(a.code, a.name) ASC
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("ledgerId", ledgerID);

            // query(): maps every result row through ACCOUNT_MAPPER.
            return template.query(sql, params, ACCOUNT_MAPPER);
        });
    }

    /**
     * Checks whether a ledger with the given ID exists and belongs
     * to the authenticated owner (via RLS).
     * <p>
     * Used by AccountService before querying accounts, so it can
     * return a meaningful 404 instead of a silent empty list when
     * the ledger ID is invalid or belongs to another owner.
     *
     * @param  ownerID  The authenticated owner's UUID.
     * @param  ledgerID The ledger ID to check.
     * @return          true if the ledger exists and belongs to the authenticated owner.
     */
    public boolean ledgerExists(UUID ownerID, UUID ledgerID) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            String sql = """
                    SELECT COUNT(*)
                      FROM public.ledger
                     WHERE id         = :ledgerId
                       AND is_active  = true
                       AND deleted_at IS NULL
                    """;

            // RLS ensures this returns 0 if the ledger belongs to
            // a different owner, even if the UUID exists in the DB.
            Integer count = template.queryForObject(
                    sql,
                    new MapSqlParameterSource("ledgerId", ledgerID),
                    Integer.class);

            return count != null && count > 0;
        });
    }

    // ── Create account ────────────────────────────────────────────────────────────

    /**
     * Creates a new account in the specified ledger.
     * <p>
     * This method performs the following operations within a single database transaction:
     * <ol>
     *   <li>Resolves {@code accountTypeCode} to {@code account_type.id} (if provided)</li>
     *   <li>Retrieves parent account's {@code kind}, {@code commodity_scu}, and {@code commodity_id}</li>
     *   <li>Inserts the new account row with inherited properties from parent</li>
     *   <li>Auto-promotes the parent to a placeholder (if not already one) — a parent with
     *       at least one child cannot receive transactions directly under double-entry rules</li>
     *   <li>Fetches and returns the newly created account via {@link #fetchAccount}</li>
     * </ol>
     * <p>
     * <strong>Important:</strong> This method does NOT call the {@code mab_create_account()}
     * stored function. Instead, it performs a direct INSERT. This means:
     * <ul>
     *   <li>Database-level validations (circular hierarchy checks, etc.) are NOT enforced</li>
     *   <li>The {@code kind}, {@code commodity_scu}, and {@code commodity_id} are inherited
     *       directly from the parent account</li>
     *   <li>RLS (Row-Level Security) is active via {@code TenantContext.withOwner()}, ensuring
     *       the parent and ledger belong to the authenticated owner</li>
     * </ul>
     * <p>
     * <strong>Placeholder accounts:</strong> If {@code accountTypeCode} is null or blank,
     * the account is created without an {@code account_type_id} (suitable for placeholder nodes).
     *
     * @param ownerID  The authenticated owner's UUID (from JWT). Used to activate RLS.
     * @param request  The account creation request containing ledger, name, parent, type, etc.
     * @return         The newly created account as an {@link AccountResponse}.
     * @throws org.springframework.dao.EmptyResultDataAccessException if {@code accountTypeCode}
     *         does not exist in the {@code account_type} table.
     * @throws org.springframework.dao.EmptyResultDataAccessException if {@code parentId}
     *         does not exist or does not belong to the authenticated owner.
     */
    public AccountResponse create(UUID ownerID, CreateAccountRequest request) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // Resolve account_type_id from code
            String resolveTypeSql = """
            SELECT id FROM public.account_type
             WHERE code = :code AND deleted_at IS NULL
            LIMIT 1
            """;

            UUID accountTypeId = null;
            if (request.accountTypeCode() != null && !request.accountTypeCode().isBlank()) {
                accountTypeId = template.queryForObject(
                        resolveTypeSql,
                        new MapSqlParameterSource("code", request.accountTypeCode()),
                        UUID.class
                );
            }

            // Derive kind and commodity_scu from parent account
            String parentSql = """
            SELECT kind, commodity_scu, commodity_id
              FROM public.account
             WHERE id = :parentId AND deleted_at IS NULL
            """;

            var parentRow = template.queryForMap(parentSql,
                    new MapSqlParameterSource("parentId", request.parentId()));

            short kind         = ((Number) parentRow.get("kind")).shortValue();
            int   commodityScu = ((Number) parentRow.get("commodity_scu")).intValue();
            UUID  commodityId  = (UUID) parentRow.get("commodity_id");

            String insertSql = """
            INSERT INTO public.account (
                ledger_id, name, code, parent_id,
                account_type_id, account_role,
                is_placeholder, is_hidden,
                kind, commodity_scu, commodity_id,
                is_active, non_std_scu,
                created_at, updated_at, revision
            ) VALUES (
                :ledgerId, :name, :code, :parentId,
                :accountTypeId, :accountRole,
                :isPlaceholder, :isHidden,
                :kind, :commodityScu, :commodityId,
                true, 0,
                now(), now(), 0
            )
            RETURNING id
            """;

            UUID newId = template.queryForObject(
                    insertSql,
                    new MapSqlParameterSource()
                            .addValue("ledgerId",       request.ledgerId())
                            .addValue("name",           request.name())
                            .addValue("code",           request.code())
                            .addValue("parentId",       request.parentId())
                            .addValue("accountTypeId",  accountTypeId)
                            .addValue("accountRole",    request.accountRole())
                            .addValue("isPlaceholder",  request.isPlaceholder())
                            .addValue("isHidden",       request.isHidden())
                            .addValue("kind",           kind)
                            .addValue("commodityScu",   commodityScu)
                            .addValue("commodityId",    commodityId),
                    UUID.class
            );

            // ── Auto-promote parent to placeholder ───────────────────────────
            // If the parent account was not already a placeholder, mark it as one.
            // A parent with at least one child cannot receive transactions directly
            // under double-entry accounting rules.
            // This UPDATE is a no-op when the parent is already a placeholder.
            String promoteParentSql = """
                    UPDATE public.account
                       SET is_placeholder = true,
                           updated_at     = now(),
                           revision       = revision + 1
                     WHERE id             = :parentId
                       AND is_placeholder = false
                       AND deleted_at     IS NULL
                    """;
            template.update(promoteParentSql,
                    new MapSqlParameterSource("parentId", request.parentId()));
            // ─────────────────────────────────────────────────────────────────

            return fetchAccount(template, newId);
        });
    }

    // ── Patch account ────────────────────────────────────────────────────────

    /**
     * Partially updates an existing account with sparse field updates.
     * <p>
     * Implements JSON Merge Patch semantics (RFC 7396): only non-null fields in the
     * {@link PatchAccountRequest} are applied to the database. Fields set to {@code null}
     * retain their existing values.
     * <p>
     * This method performs the following operations within a single database transaction:
     * <ol>
     *   <li>Builds a dynamic UPDATE statement with only the provided (non-null) fields</li>
     *   <li>Resolves {@code accountTypeCode} to {@code account_type.id} (if provided)</li>
     *   <li>Executes the UPDATE with automatic {@code updated_at} and {@code revision} increment</li>
     *   <li>Fetches and returns the updated account via {@link #fetchAccount}</li>
     * </ol>
     * <p>
     * <strong>Important:</strong> This method does NOT call {@code mab_update_account()}
     * stored function. Instead, it performs a direct UPDATE. This means:
     * <ul>
     *   <li>Database-level validations are NOT enforced (e.g., circular hierarchy prevention)</li>
     *   <li>Placeholder conversion (non-placeholder → placeholder) is NOT validated against
     *       existing transactions</li>
     *   <li>RLS (Row-Level Security) is active via {@code TenantContext.withOwner()}, ensuring
     *       only accounts belonging to the authenticated owner can be updated</li>
     * </ul>
     * <p>
     * If no fields are provided (all null), the method still fetches and returns the
     * current account state without modifying the database.
     *
     * @param ownerID    The authenticated owner's UUID (from JWT). Used to activate RLS.
     * @param accountId  The UUID of the account to update.
     * @param request    The patch request with nullable fields (only non-null fields are applied).
     * @return           The updated account as an {@link AccountResponse}.
     * @throws org.springframework.dao.EmptyResultDataAccessException if {@code accountTypeCode}
     *         does not exist in the {@code account_type} table.
     * @throws org.springframework.dao.EmptyResultDataAccessException if the account does not exist
     *         or does not belong to the authenticated owner.
     */
    public AccountResponse patch(UUID ownerID, UUID accountId,
                                 PatchAccountRequest request) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            var params  = new MapSqlParameterSource("accountId", accountId);
            var setClauses = new java.util.ArrayList<String>();

            if (request.name() != null) {
                setClauses.add("name = :name");
                params.addValue("name", request.name());
            }
            if (request.code() != null) {
                setClauses.add("code = :code");
                params.addValue("code", request.code());
            }
            if (request.parentId() != null) {
                setClauses.add("parent_id = :parentId");
                params.addValue("parentId", request.parentId());
            }
            if (request.accountTypeCode() != null) {
                String resolveTypeSql = """
                SELECT id FROM public.account_type
                 WHERE code = :code AND deleted_at IS NULL LIMIT 1
                """;
                UUID typeId = template.queryForObject(resolveTypeSql,
                        new MapSqlParameterSource("code", request.accountTypeCode()),
                        UUID.class);
                setClauses.add("account_type_id = :accountTypeId");
                params.addValue("accountTypeId", typeId);
            }
            if (request.accountRole() != null) {
                setClauses.add("account_role = :accountRole");
                params.addValue("accountRole", request.accountRole());
            }
            if (request.isPlaceholder() != null) {
                setClauses.add("is_placeholder = :isPlaceholder");
                params.addValue("isPlaceholder", request.isPlaceholder());
            }
            if (request.isHidden() != null) {
                setClauses.add("is_hidden = :isHidden");
                params.addValue("isHidden", request.isHidden());
            }

            if (!setClauses.isEmpty()) {
                setClauses.add("updated_at = now()");
                setClauses.add("revision = revision + 1");
                String sql = "UPDATE public.account SET "
                        + String.join(", ", setClauses)
                        + " WHERE id = :accountId AND deleted_at IS NULL";
                template.update(sql, params);
            }

            return fetchAccount(template, accountId);
        });
    }

    // ── Fetch account types catalog ──────────────────────────────────────────

    /**
     * Retrieves all active account types from the system-wide catalog.
     * <p>
     * Account types define the functional classification of accounts (BANK, CASH,
     * RECEIVABLE, PAYABLE, EQUITY, etc.) and are NOT tenant-scoped. They are seeded
     * during schema bootstrap via {@code 002_Populating_account_type.pgsql}.
     * <p>
     * This method does NOT use {@code TenantContext} because account types are
     * shared across all owners and are not subject to Row-Level Security (RLS).
     * <p>
     * Results are ordered by {@code sort_order ASC}, providing a natural display
     * order for UI dropdowns and forms.
     *
     * @return A list of all active {@link AccountTypeResponse} objects, ordered by
     *         {@code sort_order}. Never returns null; returns an empty list if no
     *         account types exist (which should never happen in a properly seeded database).
     */
    public List<AccountTypeResponse> findAllAccountTypes() {
        String sql = """
        SELECT id, code, name, kind, normal_balance, sort_order
          FROM public.account_type
         WHERE deleted_at IS NULL AND is_active = true
         ORDER BY sort_order ASC
        """;

        return jdbc.query(sql, (rs, _) -> new AccountTypeResponse(
                rs.getObject("id",   UUID.class),
                rs.getString("code"),
                rs.getString("name"),
                rs.getInt("kind"),
                rs.getInt("normal_balance"),
                rs.getInt("sort_order")
        ));
    }

    // ── Private fetch helper ─────────────────────────────────────────────────

    /**
     * Private helper method to fetch a single account by ID.
     * <p>
     * Used internally by {@link #create} and {@link #patch} to retrieve the account
     * state after insert/update operations. Performs a LEFT JOIN with {@code account_type}
     * to include the {@code account_type_code} in the response.
     * <p>
     * This method assumes it is called within an active {@code TenantContext.withOwner()}
     * scope, so RLS is active and only accounts belonging to the authenticated owner
     * will be returned.
     *
     * @param template  The JDBC template instance (from TenantContext).
     * @param accountId The UUID of the account to fetch.
     * @return          The account as an {@link AccountResponse}.
     * @throws org.springframework.dao.EmptyResultDataAccessException if the account does not
     *         exist or does not belong to the authenticated owner (due to RLS).
     */
    private AccountResponse fetchAccount(
            NamedParameterJdbcTemplate template, UUID accountId) {
        String sql = """
        SELECT a.id, a.name, a.code, a.parent_id,
               a.is_placeholder, a.is_hidden, a.kind,
               at.code AS at_code, a.account_role
          FROM public.account a
          LEFT JOIN public.account_type at ON at.id = a.account_type_id
         WHERE a.id = :id AND a.deleted_at IS NULL
        """;
        return template.queryForObject(sql,
                new MapSqlParameterSource("id", accountId),
                ACCOUNT_MAPPER);
    }
}