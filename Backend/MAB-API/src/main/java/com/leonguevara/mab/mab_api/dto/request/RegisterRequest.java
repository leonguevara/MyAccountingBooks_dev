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
 * Request body for POST /auth/register.
 *
 * Example JSON:
 * {
 *   "email":       "leon@example.com",
 *   "password":    "secret123",
 *   "displayName": "León Felipe"
 * }
 *
 * @param email       Valid email address. Must be unique across all owners.
 * @param password    Plain-text password. BCrypt-hashed before storage.
 *                    Minimum 8 characters.
 * @param displayName Human-readable name shown in the UI. Optional —
 *                    defaults to "No Name" if blank.
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