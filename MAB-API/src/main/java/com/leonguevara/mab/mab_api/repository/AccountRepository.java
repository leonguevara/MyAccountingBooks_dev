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
// ============================================================
// Last edited: 2026-03-05
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.response.AccountResponse;

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
    // Parameter rowNum is never used, so I'm replacing it with an underscore
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
                    rs.getString("at_code")
            );

    /**
     * Returns all active, non-deleted accounts for a given ledger,
     * ordered by account code for natural COA display order.
     * <p>
     * Query design:
     *   - LEFT JOIN account_type: placeholder accounts have NULL
     *     account_type_id — LEFT JOIN ensures they still appear.
     *   - WHERE a.ledger_id = :ledgerId: scopes to this ledger.
     *   - RLS on account table: PostgreSQL automatically filters to
     *     accounts whose ledger belongs to the current owner.
     *     If ledgerId belongs to a different owner, zero rows return.
     *   - ORDER BY COALESCE(a.code, a.name): accounts with codes sort
     *     by code; accounts without codes sort by name as fallback.
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
                        at.code   AS at_code
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
     * @return          true if the ledger exists and belongs to an owner.
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
}