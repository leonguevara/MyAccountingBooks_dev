// ============================================================
// HealthController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: Provides a public /health endpoint.
//          Used by load balancers, Docker health checks, and
//          monitoring systems to verify the API is running.
//          Requires no authentication.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

// @RestController: combines @Controller + @ResponseBody.
//   Every method return value is serialized as JSON automatically.
import org.springframework.web.bind.annotation.RestController;

// @GetMapping: maps HTTP GET requests to a handler method.
import org.springframework.web.bind.annotation.GetMapping;

// Map: used to build a simple key-value JSON response.
import java.util.Map;

@RestController
public class HealthController {

    /**
     * Health check endpoint.
     *
     * Returns HTTP 200 with a simple JSON body confirming the service is up.
     * No authentication required (configured as public in SecurityConfig).
     *
     * @return JSON: { "status": "ok", "service": "mab-api" }
     */
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of(
                "status",  "ok",
                "service", "mab-api"
        );
    }
}