// ============================================================
// ApiException.java
// Package: com.leonguevara.mab.mab_api.exception
//
// Purpose: A custom runtime exception used throughout the
//          service layer to signal business-logic errors
//          (e.g. invalid credentials, ledger not found,
//          insufficient permissions).
//
//          Carries an HTTP status code so that
//          GlobalExceptionHandler can return the correct
//          HTTP response without extra logic.
// ============================================================

package com.leonguevara.mab.mab_api.exception;

// HttpStatus: Spring's enum of HTTP status codes (400, 401, 404, 500, etc.)
import org.springframework.http.HttpStatus;

/**
 * Application-level exception for predictable error conditions.
 *
 * Throw this from any service method when a request cannot be
 * fulfilled for a known reason (wrong credentials, missing resource, etc.)
 *
 * GlobalExceptionHandler catches this and returns a structured
 * JSON error response to the client.
 */
public class ApiException extends RuntimeException {

    // The HTTP status code to return to the client when this is thrown.
    private final HttpStatus status;

    /**
     * Creates a new ApiException with a status code and message.
     *
     * @param status  The HTTP status to return (e.g. HttpStatus.UNAUTHORIZED).
     * @param message A human-readable description of the error.
     */
    public ApiException(HttpStatus status, String message) {
        // Pass message to RuntimeException so it appears in logs.
        super(message);
        this.status = status;
    }

    /**
     * Returns the HTTP status code associated with this exception.
     *
     * @return The HttpStatus value (e.g. HttpStatus.NOT_FOUND).
     */
    public HttpStatus getStatus() {
        return status;
    }
}