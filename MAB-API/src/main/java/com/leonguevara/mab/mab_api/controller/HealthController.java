// ============================================================
// HealthController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: Provides a public /health endpoint.
//          Used by load balancers, Docker health checks, and
//          monitoring systems to verify the API is running.
//          Requires no authentication.
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;

// @RestController: combines @Controller + @ResponseBody.
//   Every method return value is serialized as JSON automatically.
import org.springframework.web.bind.annotation.RestController;

// @GetMapping: maps HTTP GET requests to a handler method.
import org.springframework.web.bind.annotation.GetMapping;

// Map: used to build a simple key-value JSON response.
import java.util.Map;

@RestController
@Tag(name = "Health", description = "Service liveness probe")
public class HealthController {

    @GetMapping("/health")
    @Operation(summary = "Health check",
            description = "Returns OK if the service is running. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Service is healthy")
    @SecurityRequirements   // overrides global bearerAuth — no token needed
    public Map<String, String> health() {
        return Map.of("status", "ok", "service", "mab-api");
    }
}
