// ============================================================
// AuthService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic for user authentication.
//
//          Iteration 1 (current): uses a hardcoded dev stub.
//          Iteration 2: replaces stub with real DB query against
//          ledger_owner table + BCrypt password verification.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.security.JwtUtil;

// HttpStatus: provides HTTP status constants (e.g. UNAUTHORIZED = 401).
import org.springframework.http.HttpStatus;

// @Service: marks this as a Spring service bean (business logic layer).
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class AuthService {

    // JwtUtil handles token generation after successful authentication.
    private final JwtUtil jwtUtil;

    /**
     * Constructor injection of JwtUtil.
     *
     * @param jwtUtil The JWT utility bean for generating signed tokens.
     */
    public AuthService(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    /**
     * Authenticates a user by email and password.
     *
     * CURRENT STATE (Iteration 1 — Dev Stub):
     *   Hardcoded credentials for local development only.
     *   Returns a valid JWT without querying the database.
     *
     * NEXT ITERATION (Iteration 2):
     *   1. Query ledger_owner WHERE email = :email AND deleted_at IS NULL
     *   2. Verify request password against ledger_owner.password_hash using BCrypt
     *   3. Throw ApiException(UNAUTHORIZED) if no match
     *   4. Return real ownerID from the database row
     *
     * @param  email    The user's email address.
     * @param  password The plain-text password from the request.
     * @return          A TokenResponse with JWT and ownerID on success.
     * @throws ApiException HTTP 401 if credentials do not match.
     */
    public TokenResponse login(String email, String password) {

        // --- DEV STUB: replace this block in Iteration 2 ---
        if (!"dev@test.com".equals(email) || !"password".equals(password)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }
        // Fixed UUID for dev testing — will be the real DB UUID in Iteration 2.
        UUID ownerID = UUID.fromString("00000000-0000-0000-0000-000000000001");
        // --- END DEV STUB ---

        // Generate a signed JWT containing ownerID as the subject claim.
        String token = jwtUtil.generateToken(ownerID);

        // Return the token and ownerID to the controller for serialization.
        return new TokenResponse(token, ownerID);
    }
}