// ============================================================
// AuthController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: Handles authentication requests.
//          It currently implements POST /auth/login.
//          Public route — no JWT required.
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.LoginRequest;
import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.service.AuthService;

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

// @Valid: triggers Bean Validation on the @RequestBody object.
//   Validation errors return HTTP 400 automatically.
// import jakarta.validation.Valid;

@RestController
@RequestMapping("/auth")
@Tag(name = "Auth", description = "Authentication — obtain JWT token")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

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
}
