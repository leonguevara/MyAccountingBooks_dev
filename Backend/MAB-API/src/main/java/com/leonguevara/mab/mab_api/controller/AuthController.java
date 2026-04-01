// ============================================================
// AuthController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: Handles authentication requests.
//          It currently implements POST /auth/login.
//          Public route — no JWT required.
// ============================================================
// Last edited: 2026-03-31
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.LoginRequest;
import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.service.AuthService;
import com.leonguevara.mab.mab_api.dto.request.RegisterRequest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;

// @RestController: marks this as a REST API controller.
import org.springframework.web.bind.annotation.RestController;

// @RequestMapping: sets the base path for all routes in this controller.
import org.springframework.web.bind.annotation.RequestMapping;

// @PostMapping: maps HTTP POST to a handler method.
import org.springframework.web.bind.annotation.PostMapping;

// @RequestBody: deserializes the incoming JSON body into a Java object.
import org.springframework.web.bind.annotation.RequestBody;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

// @Valid: triggers Bean Validation on the @RequestBody object.
//   Validation errors return HTTP 400 automatically.
import jakarta.validation.Valid;

/**
 * REST controller for public authentication endpoints.
 *
 * <p>Handles owner account creation and credential-based login under the
 * {@code /auth} base path. Both routes are explicitly whitelisted in
 * {@link com.leonguevara.mab.mab_api.config.SecurityConfig} and require no JWT.
 *
 * <p>Available routes:
 * <table border="1" summary="Auth routes">
 *   <tr><th>Method</th><th>Path</th><th>Description</th></tr>
 *   <tr><td>POST</td><td>{@code /auth/login}</td><td>Authenticate and obtain a JWT</td></tr>
 *   <tr><td>POST</td><td>{@code /auth/register}</td><td>Create a new owner account and obtain a JWT</td></tr>
 * </table>
 *
 * @see AuthService
 * @see com.leonguevara.mab.mab_api.config.SecurityConfig
 */
@RestController
@RequestMapping("/auth")
@Tag(name = "Auth", description = "Authentication — obtain JWT token")
public class AuthController {

    private final AuthService authService;

    /**
     * Constructs the controller with the required authentication service.
     *
     * @param authService The service handling credential validation and JWT issuance.
     */
    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * Authenticates an existing owner and returns a signed JWT.
     *
     * <p><strong>Route:</strong> {@code POST /auth/login} (public — no JWT required)
     *
     * <p>Delegates to {@link AuthService#login(String, String)}, which looks up the owner
     * by email, verifies the bcrypt password hash, and issues a token valid for 24 hours.
     *
     * @param request The login payload containing {@code email} and {@code password}.
     * @return A {@link TokenResponse} containing the signed JWT.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if the email
     *         is not found or the password does not match.
     */
    @PostMapping("/login")
    @Operation(summary = "Login",
            description = "Authenticates with email and password. Returns a JWT token valid for 24 hours.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Login successful — use the token in all subsequent requests",
                    content = @Content(schema = @Schema(implementation = TokenResponse.class))),
            @ApiResponse(responseCode = "401", description = "Invalid credentials", content = @Content)
    })
    @SecurityRequirements
    public TokenResponse login(@RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }

    /**
     * Creates a new owner account and returns a signed JWT.
     *
     * <p><strong>Route:</strong> {@code POST /auth/register} (public — no JWT required)
     *
     * <p>Delegates to {@link AuthService#register(String, String, String)}, which
     * inserts a new row into {@code ledger_owner} with a bcrypt-hashed password and
     * immediately issues a JWT — no email verification step is required.
     *
     * <p>Bean Validation ({@code @Valid}) is applied to the request body before the
     * handler is invoked; constraint violations are returned as HTTP 400 automatically.
     *
     * @param request The registration payload containing {@code email}, {@code password},
     *                and {@code displayName}.
     * @return HTTP 201 with a {@link TokenResponse} containing the signed JWT.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 400 if the request
     *         body fails Bean Validation (e.g. invalid email format, password too short).
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 409 if the email
     *         address is already registered.
     */
    @PostMapping("/register")
    @Operation(summary = "Register",
            description = """
               Creates a new account with email and password.
               Returns a JWT immediately — no email verification required.
               Returns HTTP 409 if the email is already registered.
               """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Account created — JWT returned",
                    content = @Content(schema = @Schema(implementation = TokenResponse.class))),
            @ApiResponse(responseCode = "400", description = "Validation error (invalid email, short password)",
                    content = @Content),
            @ApiResponse(responseCode = "409", description = "Email already registered",
                    content = @Content)
    })
    @SecurityRequirements   // public endpoint — no JWT required
    public ResponseEntity<TokenResponse> register(
            @Valid @RequestBody RegisterRequest request) {
        TokenResponse response = authService.register(
                request.email(),
                request.password(),
                request.displayName()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
