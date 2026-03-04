// ============================================================
// AuthController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: Handles authentication requests.
//          Currently implements POST /auth/login.
//          Public route — no JWT required.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.LoginRequest;
import com.leonguevara.mab.mab_api.dto.response.TokenResponse;
import com.leonguevara.mab.mab_api.service.AuthService;
import com.leonguevara.mab.mab_api.exception.ApiException;

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
import jakarta.validation.Valid;

@RestController
@RequestMapping("/auth")
public class AuthController {

    // AuthService contains the business logic for authentication.
    private final AuthService authService;

    /**
     * Constructor injection of AuthService.
     *
     * @param authService The authentication service bean.
     */
    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * POST /auth/login
     *
     * Accepts email + password, verifies credentials against
     * ledger_owner.password_hash in the database, and returns
     * a signed JWT on success.
     *
     * @param  request The login credentials (validated by @Valid).
     * @return         A TokenResponse containing the JWT and ownerID.
     * @throws ApiException HTTP 401 if credentials are invalid.
     */
    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }
}