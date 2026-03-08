// ============================================================
// TokenResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON response body returned after a successful login.
//          The client stores the token and sends it on every
//          subsequent request as:
//            Authorization: Bearer <token>
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body for POST /auth/login.
 *
 * Returned JSON:
 * {
 *   "token":   "eyJhbGciOiJIUzI1NiJ9...",
 *   "ownerID": "550e8400-e29b-41d4-a716-446655440000"
 * }
 *
 * @param token   The signed JWT. Must be sent in the Authorization header.
 * @param ownerID The UUID of the authenticated ledger_owner. Useful for
 *                the client to store and display owner-specific UI.
 */
public record TokenResponse(String token, UUID ownerID) {}