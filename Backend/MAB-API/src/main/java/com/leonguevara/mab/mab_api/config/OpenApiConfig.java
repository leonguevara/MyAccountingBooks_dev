// ============================================================
// OpenApiConfig.java
// Package: com.leonguevara.mab.mab_api.config
//
// Purpose: Configures the OpenAPI 3.0 specification metadata,
//          security scheme, and global JWT bearer auth.
//
//          After adding this config:
//            - Swagger UI at:  http://localhost:8080/swagger-ui.html
//            - OpenAPI JSON:   http://localhost:8080/v3/api-docs
//
//          Security:
//            A "bearerAuth" security scheme is defined globally.
//            All endpoints inherit it automatically.
//            The /auth/login and /health endpoints are marked
//            as NOT requiring auth via @SecurityRequirements({})
//            in their controllers.
//
//          Tags map 1:1 to controllers and group endpoints
//          logically in the Swagger UI sidebar.
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.config;

import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

// Defines the "bearerAuth" JWT scheme referenced by @SecurityRequirement
// annotations on individual operations and applied globally below.
@SecurityScheme(
        name       = "bearerAuth",
        type       = SecuritySchemeType.HTTP,
        scheme     = "bearer",
        bearerFormat = "JWT",
        description = "Paste the JWT token returned by POST /auth/login. " +
                "Format: Bearer <token> (the 'Bearer ' prefix is added automatically)."
)
@Configuration
public class OpenApiConfig {

    /**
     * Builds the OpenAPI root object with project metadata,
     * server definitions, and global JWT security requirement.
     * <p>
     * The global SecurityRequirement applies bearerAuth to ALL endpoints.
     * Individual endpoints that do NOT require auth (login, health)
     * override this with @SecurityRequirements({}) in their controller.
     *
     * @return Configured OpenAPI bean consumed by springdoc.
     */
    @Bean
    public OpenAPI mabOpenAPI() {
        return new OpenAPI()
                // ── API metadata ─────────────────────────────────────────────
                .info(new Info()
                        .title("MyAccountingBooks API")
                        .description("""
                                Double-entry accounting engine REST API.
                                
                                ## Authentication
                                1. Call **POST /auth/login** with your email and password.
                                2. Copy the `token` from the response.
                                3. Click **Authorize** (top right), paste the token, click **Authorize**.
                                4. All subsequent requests will include the Bearer token automatically.
                                
                                ## Rational Arithmetic
                                Monetary values use `valueNum / valueDenom` — never floating point.
                                Example: MXN $500.00 = `valueNum: 50000`, `valueDenom: 100`.
                                Use `GET /commodities/{id}` to retrieve the correct `fraction`
                                (which equals `valueDenom`) for any currency.
                                
                                ## RLS Tenant Isolation
                                All ledger, account, and transaction data is scoped to the
                                authenticated owner via PostgreSQL Row-Level Security.
                                You cannot access another owner's data even with a valid token.
                                """)
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("León Felipe Guevara Chávez")
                                .email("leon@myaccountingbooks.app"))
                        .license(new License()
                                .name("Proprietary")
                                .url("https://myaccountingbooks.app")))

                // ── Server definitions ───────────────────────────────────────
                // Add staging/production URLs here when deploying.
                .servers(List.of(
                        new Server()
                                .url("http://localhost:8080")
                                .description("Local development server")
                ))

                // ── Global security: all endpoints require bearerAuth ────────
                // Endpoints that don't need auth override this with
                // @SecurityRequirements({}) on their handler methods.
                .addSecurityItem(new SecurityRequirement()
                        .addList("bearerAuth"));
    }
}