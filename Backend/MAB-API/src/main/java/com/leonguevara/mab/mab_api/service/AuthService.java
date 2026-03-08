// ============================================================
// AuthService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic for user authentication.
//
//          Iteration 1: uses a hardcoded dev stub.
//          Iteration 2 (current): replaces the hardcoded dev stub with a
//          real database query against the ledger_owner table.
//
//          Authentication flow:
//            1. Query ledger_owner by email (active, not deleted)
//            2. Verify the submitted password against the BCrypt
//               hash stored in ledger_owner.password_hash
//            3. Update ledger_owner.last_login_at on success
//            4. Return a signed JWT containing the owner's UUID
//
//          IMPORTANT: The ledger_owner table is NOT tenant-scoped
//          by RLS — it is a public identity table. We query it
//          directly without SET LOCAL app.current_owner_id.
//          TenantContext is NOT used here.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.security.JwtUtil;

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

import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {

    // Executes SQL queries against the PostgreSQL database.
    private final NamedParameterJdbcTemplate jdbc;

    // Verifies plain-text passwords against BCrypt hashes.
    private final PasswordEncoder passwordEncoder;

    // JwtUtil handles token generation after successful authentication.
    private final JwtUtil jwtUtil;

    /**
     * Constructor injection of all dependencies.
     *
     * @param jdbc            JDBC template for database queries.
     * @param passwordEncoder BCrypt password verifier (from SecurityConfig).
     * @param jwtUtil         JWT token generator.
     */
    public AuthService(NamedParameterJdbcTemplate jdbc,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil) {
        this.jdbc            = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil         = jwtUtil;
    }


    /**
     * Authenticates a user by email and password.
     * <p>
     * Queries ledger_owner by email, verifies the BCrypt hash,
     * updates last_login_at, and returns a signed JWT.
     * <p>
     * Security note: we deliberately return the same generic error
     * message whether the email is not found OR the password is wrong.
     * This prevents user enumeration attacks (an attacker cannot
     * distinguish "email doesn't exist" from "wrong password").
     *
     * @param  email    The user's email address from the login request.
     * @param  password The plain-text password from the login request.
     * @return          A TokenResponse containing the JWT and ownerID.
     * @throws ApiException HTTP 401 if credentials are invalid.
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
}