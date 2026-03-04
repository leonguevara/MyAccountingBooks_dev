// ============================================================
// GlobalExceptionHandler.java
// Package: com.leonguevara.mab.mab_api.exception
//
// Purpose: Centralized error handler for all exceptions thrown
//          anywhere in the application.
//
//          Without this class, Spring Boot returns its default
//          "white label error page" or a raw stack trace.
//          With this class, all errors return a consistent,
//          structured JSON body:
//            {
//              "status":  404,
//              "error":   "NOT_FOUND",
//              "message": "Ledger not found"
//            }
//
//          @RestControllerAdvice: intercepts exceptions from
//          ALL @RestController classes and routes them here.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.exception;

// @RestControllerAdvice: combines @ControllerAdvice + @ResponseBody.
//   Intercepts exceptions from all controllers and serializes
//   the return value as JSON automatically.
import org.springframework.web.bind.annotation.RestControllerAdvice;

// @ExceptionHandler: maps a specific exception type to a handler method.
import org.springframework.web.bind.annotation.ExceptionHandler;

// ResponseEntity: wraps a response body + HTTP status code together.
import org.springframework.http.ResponseEntity;

// HttpStatus: enum of standard HTTP status codes.
import org.springframework.http.HttpStatus;

// Map: used to build a simple key-value JSON response body.
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Handles all ApiException instances thrown by service classes.
     *
     * Returns a structured JSON response with the status code
     * and message that was set when the exception was created.
     *
     * @param ex The ApiException that was thrown.
     * @return   A ResponseEntity with a JSON body and the correct HTTP status.
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApiException(ApiException ex) {
        return ResponseEntity
                .status(ex.getStatus())
                .body(Map.of(
                        // HTTP numeric status code (e.g. 401)
                        "status",  ex.getStatus().value(),
                        // HTTP status name (e.g. "UNAUTHORIZED")
                        "error",   ex.getStatus().name(),
                        // Developer/user-readable error description
                        "message", ex.getMessage()
                ));
    }

    /**
     * Catch-all handler for any unexpected exception not explicitly handled above.
     *
     * Prevents raw stack traces from leaking to clients.
     * Logs as a 500 Internal Server Error.
     *
     * @param ex Any unhandled exception.
     * @return   A generic 500 JSON response.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception ex) {
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of(
                        "status",  500,
                        "error",   "INTERNAL_SERVER_ERROR",
                        // In production, replace ex.getMessage() with a generic
                        // message and log the real error server-side only.
                        "message", ex.getMessage()
                ));
    }
}