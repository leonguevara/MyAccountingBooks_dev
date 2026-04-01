// ============================================================
// AuthService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic for user authentication and registration.
//
//          login() flow:
//            1. Query ledger_owner by email (active, not deleted)
//            2. Verify the submitted password against the BCrypt
//               hash stored in ledger_owner.password_hash
//            3. Update ledger_owner.last_login_at on success
//            4. Return a signed JWT containing the owner's UUID
//
//          register() flow:
//            1. Check email is not already taken (HTTP 409 if so)
//            2. BCrypt-hash the plain-text password
//            3. Insert ledger_owner row   ─┐ wrapped in
//            4. Insert auth_identity row  ─┘ TransactionTemplate
//            5. Return a signed JWT — user is immediately authenticated
//
//          IMPORTANT: ledger_owner is NOT tenant-scoped by RLS.
//          We query it directly without TenantContext / SET LOCAL.
//          However, register() wraps both INSERTs in a TransactionTemplate
//          so that RETURNING id is reliable and both rows are atomic.
// ============================================================
// Last edited: 2026-04-01
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.security.JwtUtil;
import com.leonguevara.mab.mab_api.dto.request.RegisterRequest;

// NamedParameterJdbcTemplate: executes SQL with named parameters.
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

// MapSqlParameterSource: builds a named parameter map for SQL queries.
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

// PasswordEncoder: Spring Security interface for BCrypt verification.
//   Injected from the @Bean defined in SecurityConfig.
import org.springframework.security.crypto.password.PasswordEncoder;

// HttpStatus: provides HTTP status constants (e.g. UNAUTHORIZED = 401).
import org.springframework.http.HttpStatus;

// @Service: marks this as a Spring service bean (business logic layer).
import org.springframework.stereotype.Service;

// EmptyResultDataAccessException: thrown by queryForObject() when
//   the SQL returns zero rows. We catch it to return a 401 instead.
import org.springframework.dao.EmptyResultDataAccessException;

import org.springframework.transaction.support.TransactionTemplate;

import java.util.Map;
import java.util.UUID;

/**
 * Business logic for owner authentication and registration.
 *
 * <p>Provides two public operations:
 * <ul>
 *   <li>{@link #login(String, String)} — verifies credentials and issues a JWT.</li>
 *   <li>{@link #register(String, String, String)} — creates a new owner account and
 *       issues a JWT immediately, with no email-verification step.</li>
 * </ul>
 *
 * <p><strong>RLS note:</strong> {@code ledger_owner} and {@code auth_identity} are
 * <em>not</em> tenant-scoped by Row-Level Security. Both methods query and write these
 * tables directly without wrapping in {@link com.leonguevara.mab.mab_api.config.TenantContext}.
 * {@code register()} still uses {@link TransactionTemplate} to make the two INSERTs
 * atomic and to ensure the {@code RETURNING id} clause is reliably captured by JDBC.
 *
 * @see com.leonguevara.mab.mab_api.controller.AuthController
 * @see JwtUtil
 * @see com.leonguevara.mab.mab_api.config.SecurityConfig
 */
@Service
public class AuthService {

    /** JDBC template used to execute all SQL against the PostgreSQL database. */
    private final NamedParameterJdbcTemplate jdbc;

    /** BCrypt password encoder, injected from {@code SecurityConfig.passwordEncoder()}. */
    private final PasswordEncoder passwordEncoder;

    /** Generates signed JWTs after successful authentication or registration. */
    private final JwtUtil jwtUtil;

    /**
     * Wraps the two INSERTs in {@link #register} inside a single {@code BEGIN/COMMIT}
     * so that {@code RETURNING id} is reliably captured and partial state is impossible.
     */
    private final TransactionTemplate tx;

    /**
     * Constructs the service with all required dependencies.
     *
     * @param jdbc            JDBC template for database queries.
     * @param passwordEncoder BCrypt password encoder (from {@code SecurityConfig}).
     * @param jwtUtil         JWT token generator.
     * @param tx              Transaction template for atomic multi-step writes.
     */
    public AuthService(NamedParameterJdbcTemplate jdbc,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil,
                       TransactionTemplate tx) {
        this.jdbc            = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil         = jwtUtil;
        this.tx              = tx;
    }

    // ── Login ─────────────────────────────────────────────────────────────────

    /**
     * Authenticates an existing owner by email and password and returns a signed JWT.
     *
     * <p>Workflow:
     * <ol>
     *   <li>Query {@code ledger_owner} by email (only active, non-deleted rows).</li>
     *   <li>Verify the submitted password against the stored BCrypt hash via
     *       {@link PasswordEncoder#matches}.</li>
     *   <li>Update {@code ledger_owner.last_login_at} and {@code updated_at}.</li>
     *   <li>Issue and return a JWT containing the owner UUID as its subject.</li>
     * </ol>
     *
     * <p><strong>Security:</strong> Both "email not found" and "wrong password" cases
     * return the identical {@code "Invalid credentials"} message to prevent user
     * enumeration attacks — an attacker cannot distinguish one failure from the other.
     *
     * @param  email    The owner's email address.
     * @param  password The plain-text password to verify against the stored hash.
     * @return          A {@link TokenResponse} containing the signed JWT and owner UUID.
     * @throws ApiException HTTP 401 if the email is not found or the password does not match.
     */
    public TokenResponse login(String email, String password) {

        // ── Step 1: Look up the owner by email ───────────────────────────
        // We query id and password_hash only — the minimum needed for auth.
        // deleted_at IS NULL: excludes soft-deleted owners.
        // is_active = true: excludes disabled accounts.
        String sql = """
                SELECT id, password_hash
                  FROM public.ledger_owner
                 WHERE email       = :email
                   AND is_active   = true
                   AND deleted_at  IS NULL
                """;

        // Build the parameter map for the named parameter :email.
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("email", email);

        UUID   ownerID;
        String storedHash;

        try {
            // queryForObject: expects exactly one row.
            // Throws EmptyResultDataAccessException if no row is found.
            Map<String, Object> row = jdbc.queryForMap(sql, params);

            // Extract the UUID and stored BCrypt hash from the result row.
            ownerID    = (UUID)   row.get("id");
            storedHash = (String) row.get("password_hash");

        } catch (EmptyResultDataAccessException e) {
            // No owner found with this email — return generic 401.
            // Do NOT reveal that the email doesn't exist.
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }

        // ── Step 2: Verify the password against the BCrypt hash ──────────
        // passwordEncoder.matches() computes BCrypt on the submitted password
        // and compares it to the stored hash. Never compare hashes directly.
        if (storedHash == null || !passwordEncoder.matches(password, storedHash)) {
            // Wrong password — same generic error to prevent enumeration.
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }

        // ── Step 3: Update last_login_at timestamp ───────────────────────
        // Records when the owner last authenticated successfully.
        // This is a direct update — no tenant scoping needed on ledger_owner.
        String updateSql = """
                UPDATE public.ledger_owner
                   SET last_login_at = now(),
                       updated_at    = now()
                 WHERE id = :id
                """;
        jdbc.update(updateSql, new MapSqlParameterSource("id", ownerID));

        // ── Step 4: Generate and return the JWT ──────────────────────────
        String token = jwtUtil.generateToken(ownerID);
        return new TokenResponse(token, ownerID);
    }

    // ── Register ──────────────────────────────────────────────────────────────

    /**
     * Creates a new owner account with local (email/password) credentials and returns
     * a signed JWT — the owner is immediately authenticated after registration.
     *
     * <p>Workflow:
     * <ol>
     *   <li>Verify the email is not already taken in {@code ledger_owner}
     *       (throws HTTP 409 if a non-deleted row with that email exists).</li>
     *   <li>BCrypt-hash the plain-text password; resolve {@code displayName}
     *       to {@code "No Name"} if blank or {@code null}.</li>
     *   <li>Inside a {@link TransactionTemplate} (single {@code BEGIN/COMMIT}):
     *     <ol type="a">
     *       <li>INSERT into {@code ledger_owner} and capture the generated UUID via
     *           {@code RETURNING id}.</li>
     *       <li>INSERT into {@code auth_identity} with {@code provider = 'local'}.</li>
     *     </ol>
     *   </li>
     *   <li>Issue and return a JWT containing the new owner UUID as its subject.</li>
     * </ol>
     *
     * <p><strong>Why {@link TransactionTemplate}?</strong> Without an explicit transaction,
     * auto-commit mode can cause {@code NamedParameterJdbcTemplate} to mishandle the
     * {@code RETURNING id} clause in some JDBC driver configurations. Wrapping both
     * INSERTs also guarantees atomicity — a failure after step 3a rolls back the
     * {@code ledger_owner} row so no orphaned records are left behind.
     *
     * @param  email       Desired email address (trimmed and lower-cased before INSERT).
     * @param  password    Plain-text password; BCrypt-hashed before storage.
     * @param  displayName Optional human-readable name; defaults to {@code "No Name"} if blank.
     * @return             A {@link TokenResponse} containing the signed JWT and new owner UUID.
     * @throws ApiException HTTP 409 if a non-deleted {@code ledger_owner} row with that
     *                      email already exists.
     * @throws ApiException HTTP 500 if the INSERT succeeds but {@code RETURNING id} yields
     *                      {@code null} (should never occur under normal conditions).
     * @see com.leonguevara.mab.mab_api.dto.request.RegisterRequest
     */
    public TokenResponse register(String email, String password, String displayName) {

        // ── Step 1: Check for existing email ─────────────────────────────
        // Direct query — ledger_owner is not RLS-scoped, no TenantContext needed.
        String checkSql = """
            SELECT COUNT(*) 
              FROM public.ledger_owner
             WHERE email = :email
               AND deleted_at IS NULL
            """;
        Integer count = jdbc.queryForObject(
                checkSql,
                new MapSqlParameterSource("email", email),
                Integer.class
        );
        if (count != null && count > 0) {
            throw new ApiException(HttpStatus.CONFLICT,
                    "An account with this email already exists.");
        }

        // ── Step 2: Hash the password ─────────────────────────────────────
        String hash = passwordEncoder.encode(password);
        String name = (displayName != null && !displayName.isBlank())
                ? displayName.trim()
                : "No Name";

        // ── Steps 3 + 4: Insert owner and identity atomically ────────────
        // Wrapped in TransactionTemplate (BEGIN / COMMIT) so that:
        //   a) RETURNING id on the INSERT is reliably captured by JDBC.
        //   b) Both rows are committed together — partial state is impossible.
        UUID ownerID = tx.execute(status -> {

            final String normalizedEmail = email.trim().toLowerCase();
            // Insert ledger_owner and capture the generated UUID.
            String insertOwner = """
                    INSERT INTO public.ledger_owner
                           (email, password_hash, display_name, is_active)
                    VALUES (:email, :hash, :name, true)
                    RETURNING id
                    """;
            UUID newOwnerID = jdbc.queryForObject(
                    insertOwner,
                    new MapSqlParameterSource()
                            .addValue("email", normalizedEmail)
                            .addValue("hash",  hash)
                            .addValue("name",  name),
                    UUID.class
            );

            if (newOwnerID == null) {
                // Should never happen — RETURNING id always provides a value
                // when the INSERT succeeds. Treat as an internal error.
                status.setRollbackOnly();
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                        "Registration failed: owner UUID was null after insert.");
            }

            // Insert auth_identity for the 'local' (email/password) provider.
            String insertIdentity = """
                    INSERT INTO public.auth_identity
                           (ledger_owner_id, provider, provider_user_id,
                            provider_email,  email_verified)
                    VALUES (:ownerID, 'local', :email, :email, false)
                    """;
            jdbc.update(
                    insertIdentity,
                    new MapSqlParameterSource()
                            .addValue("ownerID", newOwnerID)
                            .addValue("email",   normalizedEmail)
            );

            return newOwnerID;
        });

        // ── Step 5: Issue JWT ─────────────────────────────────────────────
        // ownerID is the UUID of the newly created ledger_owner row.
        // The JWT subject is this UUID — GET /ledgers will correctly return
        // an empty list because no ledgers belong to this owner yet.
        String token = jwtUtil.generateToken(ownerID);
        return new TokenResponse(token, ownerID);
    }
}