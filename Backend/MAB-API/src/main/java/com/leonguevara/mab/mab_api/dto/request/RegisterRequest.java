// ============================================================
// RegisterRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /auth/register.
//          Validated before reaching AuthService.
// ============================================================
// Last edited: 2026-03-31
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Request body for {@code POST /auth/register}.
 *
 * <p>Deserialized from JSON by {@code AuthController.register} and validated by
 * Bean Validation ({@code @Valid}) before the handler body executes. Constraint
 * violations are returned as HTTP 400 automatically by Spring.
 *
 * <p>Example request body:
 * <pre>{@code
 * {
 *   "email":       "leon@example.com",
 *   "password":    "secret123",
 *   "displayName": "León Felipe"
 * }
 * }</pre>
 *
 * @param email       Valid RFC-5322 email address. Must be unique across all
 *                    {@code ledger_owner} rows; a duplicate triggers HTTP 409.
 *                    Validated by {@code @NotBlank} and {@code @Email}.
 * @param password    Plain-text password supplied by the user. Passed to
 *                    {@code BCryptPasswordEncoder} before storage — never persisted
 *                    in plain text. Minimum 8 characters ({@code @Size(min = 8)}).
 * @param displayName Human-readable name shown in the UI. Optional — {@code null}
 *                    or blank values are accepted; {@code AuthService} substitutes
 *                    {@code "No Name"} when this field is blank.
 * @see com.leonguevara.mab.mab_api.controller.AuthController#register
 * @see com.leonguevara.mab.mab_api.service.AuthService
 */
public record RegisterRequest(

        @NotBlank(message = "Email is required")
        @Email(message = "Email must be a valid address")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, message = "Password must be at least 8 characters")
        String password,

        String displayName
) {}