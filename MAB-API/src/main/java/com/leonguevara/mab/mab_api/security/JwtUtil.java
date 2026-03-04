// ============================================================
// JwtUtil.java
// Package: com.leonguevara.mab.mab_api.security
//
// Purpose: Handles all JWT operations:
//            - Token generation (sign)
//            - Token validation (verify signature + expiry)
//            - Owner UUID extraction from a valid token
//
//          Uses the JJWT library (io.jsonwebtoken).
//          The signing key and expiration duration are injected
//          from application.properties via @Value.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.security;

// Keys: utility class from JJWT that creates a cryptographic
//       signing key from a plain-text secret string.
import io.jsonwebtoken.security.Keys;

// Jwts: main entry point of the JJWT library.
//       Used to build (sign) and parse (verify) tokens.
import io.jsonwebtoken.Jwts;

// JwtException: base exception for all JWT parsing/validation errors
//               (expired, malformed, wrong signature, etc.)
import io.jsonwebtoken.JwtException;

// SecretKey: Java standard interface for symmetric cryptographic keys.
//            HMAC-SHA256 is a symmetric algorithm — same key signs and verifies.
import javax.crypto.SecretKey;

// StandardCharsets: provides the UTF_8 charset constant used when
//                   converting the secret string to bytes.
import java.nio.charset.StandardCharsets;

// Date: used to set token issuedAt and expiration timestamps.
import java.util.Date;

// UUID: the type of ledger_owner.id in the database.
import java.util.UUID;

// @Component: registers this class as a Spring-managed singleton bean,
//             available for injection into other components.
import org.springframework.stereotype.Component;

// @Value: injects a value from application.properties into a field or
//         constructor parameter at startup time.
import org.springframework.beans.factory.annotation.Value;

@Component
public class JwtUtil {

    // The cryptographic key used to sign and verify tokens.
    // Derived from the jwt.secret property at construction time.
    private final SecretKey key;

    // How long (in milliseconds) a token remains valid after issuance.
    // Injected from jwt.expiration-ms in application.properties.
    private final long expirationMs;

    /**
     * Constructor — called once by Spring at startup.
     *
     * @param secret       Plain-text secret from application.properties.
     *                     Must be at least 32 characters for HMAC-SHA256.
     * @param expirationMs Token lifetime in milliseconds (e.g. 86400000 = 24h).
     */
    public JwtUtil(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiration-ms}") long expirationMs) {

        // Convert the plain-text secret into a proper HMAC-SHA256 key.
        // Keys.hmacShaKeyFor() enforces minimum key length requirements.
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    /**
     * Generates a signed JWT token for an authenticated ledger_owner.
     *
     * Token structure:
     *   Header:  { "alg": "HS256" }
     *   Payload: { "sub": "<ownerID>", "iat": <now>, "exp": <now + expirationMs> }
     *   Signature: HMAC-SHA256(header + payload, key)
     *
     * @param ownerID The UUID of the authenticated ledger_owner.
     * @return A compact, URL-safe JWT string (xxxxx.yyyyy.zzzzz format).
     */
    public String generateToken(UUID ownerID) {
        Date now        = new Date();
        Date expiration = new Date(now.getTime() + expirationMs);

        return Jwts.builder()
                // subject: stores the ownerID as a string in the token payload.
                // This is what we extract on subsequent requests to identify the user.
                .subject(ownerID.toString())
                // issuedAt: timestamp of token creation — for auditing.
                .issuedAt(now)
                // expiration: after this date/time, the token is rejected.
                .expiration(expiration)
                // signWith: signs the token using HMAC-SHA256 with our key.
                .signWith(key)
                // compact: serializes into the final xxxxx.yyyyy.zzzzz string.
                .compact();
    }

    /**
     * Extracts the ledger_owner UUID from a valid JWT token.
     *
     * Internally verifies the signature and expiration before
     * returning the subject. Throws JwtException if invalid.
     *
     * @param token The raw JWT string from the Authorization header.
     * @return The UUID of the authenticated ledger_owner.
     * @throws JwtException if the token is expired, malformed, or has a bad signature.
     */
    public UUID extractOwnerID(String token) {
        String subject = Jwts.parser()
                // verifyWith: sets the key used to verify the token's signature.
                .verifyWith(key)
                .build()
                // parseSignedClaims: verifies signature + expiration, then returns claims.
                .parseSignedClaims(token)
                // getPayload(): returns the claims map from the token body.
                .getPayload()
                // getSubject(): retrieves the "sub" claim we stored as ownerID.
                .getSubject();

        // Convert the string subject back to a UUID object.
        return UUID.fromString(subject);
    }

    /**
     * Validates a JWT token without throwing exceptions to the caller.
     *
     * Used by JwtAuthFilter to decide whether to authenticate
     * the request or reject it silently.
     *
     * @param token The raw JWT string.
     * @return true if the token is valid and not expired; false otherwise.
     */
    public boolean isValid(String token) {
        try {
            extractOwnerID(token); // throws if invalid
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            // JwtException covers: expired, malformed, bad signature.
            // IllegalArgumentException covers: null or empty token string.
            return false;
        }
    }
}