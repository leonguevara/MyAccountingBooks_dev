// ============================================================
// LoginRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of a POST /auth/login request.
//
//          Declared as a Java record: immutable, concise,
//          auto-generates constructor, accessors, equals, hashCode.
//
//          Validation annotations (@NotBlank, @Email) are
//          enforced by Spring's @Valid before the controller
//          method body executes.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

// @NotBlank: rejects null, empty string, and whitespace-only values.
import jakarta.validation.constraints.NotBlank;

// @Email: verifies the string matches a valid email address format.
import jakarta.validation.constraints.Email;

/**
 * Incoming request body for the login endpoint.
 *
 * Expected JSON:
 * {
 *   "email":    "user@example.com",
 *   "password": "secret"
 * }
 *
 * @param email    The ledger_owner's email address. Must be non-blank and valid format.
 * @param password The plain-text password to verify against the bcrypt hash in the DB.
 */
public record LoginRequest(

        @NotBlank(message = "Email is required")
        @Email(message = "Must be a valid email address")
        String email,

        @NotBlank(message = "Password is required")
        String password
) {}