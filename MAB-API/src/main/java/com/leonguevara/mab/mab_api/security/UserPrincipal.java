// ============================================================
// UserPrincipal.java
// Package: com.leonguevara.mab.mab_api.security
//
// Purpose: Represents the authenticated user within a single
//          HTTP request lifecycle.
//          After the JWT is validated, the ownerID extracted
//          from the token is wrapped in this record and stored
//          in the Spring SecurityContext.
//          Controllers retrieve it to scope database queries
//          to the correct ledger_owner.
// ============================================================

package com.leonguevara.mab.mab_api.security;

// UUID is the identifier type used for ledger_owner.id
// in the PostgreSQL schema.
import java.util.UUID;

/**
 * Immutable value object holding the authenticated owner's UUID.
 *
 * Declared as a Java record — the compiler auto-generates:
 *   - A constructor: UserPrincipal(UUID ownerID)
 *   - Accessor:      ownerID()
 *   - equals(), hashCode(), toString()
 *
 * @param ownerID The UUID of the authenticated ledger_owner row
 *                in the database. Extracted from the JWT subject claim.
 */
public record UserPrincipal(UUID ownerID) {}