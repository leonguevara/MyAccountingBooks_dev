// ============================================================
// SecurityConfig.java
// Package: com.leonguevara.mab.mab_api.config
//
// Purpose: Defines the Spring Security filter chain for the API.
//
//          Key decisions made here:
//            - CSRF disabled: REST APIs use stateless tokens,
//              not browser cookies — CSRF protection is irrelevant.
//            - Sessions disabled: every request is authenticated
//              independently via JWT. No server-side session state.
//            - Public routes: /auth/** and /health require no token.
//            - All other routes require a valid JWT.
//            - JwtAuthFilter is registered BEFORE Spring's default
//              username/password filter.
// ============================================================
// Last edited: 2026-03-31
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.config;

// JwtAuthFilter: our custom filter that validates JWT on each request.
import com.leonguevara.mab.mab_api.security.JwtAuthFilter;

// @Configuration: marks this class as a source of Spring bean definitions.
import org.springframework.context.annotation.Configuration;

// @Bean: marks a method as producing a Spring-managed bean.
import org.springframework.context.annotation.Bean;

// HttpSecurity: the main builder for configuring Spring Security behavior.
import org.springframework.security.config.annotation.web.builders.HttpSecurity;

// SessionCreationPolicy.STATELESS: tells Spring Security never to create
//   or use an HTTP session — required for stateless JWT-based APIs.
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;

// SecurityFilterChain: the resulting bean that Spring Security uses
//   to process incoming requests through our configured rules.
import org.springframework.security.web.SecurityFilterChain;

// UsernamePasswordAuthenticationFilter: Spring's built-in form-login filter.
//   We insert our JwtAuthFilter BEFORE this one, so JWT authentication
//   runs first on every request.
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

// BCryptPasswordEncoder: industry-standard password hashing algorithm.
//   Used by AuthService to verify passwords stored as bcrypt hashes
//   in the ledger_owner.password_hash column.
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

// PasswordEncoder: the interface that BCryptPasswordEncoder implements.
//   Injecting via interface keeps the code flexible.
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Spring Security configuration for the MAB REST API.
 *
 * <p>Produces two beans consumed by the Spring Security auto-configuration:
 * <ul>
 *   <li>{@link #filterChain(HttpSecurity)} — the HTTP security filter chain.</li>
 *   <li>{@link #passwordEncoder()} — the {@link PasswordEncoder} used by
 *       {@code AuthService} for password hashing and verification.</li>
 * </ul>
 *
 * <p><strong>Key design decisions:</strong>
 * <ul>
 *   <li><em>CSRF disabled</em> — REST APIs authenticate via {@code Authorization} headers,
 *       not browser-managed cookies; CSRF protection is therefore unnecessary.</li>
 *   <li><em>Sessions disabled</em> ({@link SessionCreationPolicy#STATELESS}) — every
 *       request carries its own JWT; no {@code HttpSession} or {@code JSESSIONID} cookie
 *       is ever created.</li>
 *   <li><em>{@link JwtAuthFilter} before {@code UsernamePasswordAuthenticationFilter}</em>
 *       — JWT validation runs first on every request, short-circuiting Spring's form-login
 *       path entirely.</li>
 * </ul>
 *
 * @see JwtAuthFilter
 * @see TenantContext
 */
@Configuration
public class SecurityConfig {

    /** The JWT filter inserted into the Spring Security filter chain. */
    private final JwtAuthFilter jwtAuthFilter;

    /**
     * Constructs the configuration with the required JWT filter.
     *
     * @param jwtAuthFilter The custom JWT validation filter bean.
     */
    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    /**
     * Builds and returns the HTTP security filter chain.
     *
     * <p>Authorization rules applied in order:
     * <ul>
     *   <li>{@code permitAll} — the routes below require no token:
     *     <table border="1" summary="Public routes">
     *       <tr><th>Path</th><th>Purpose</th></tr>
     *       <tr><td>{@code /health}</td><td>Liveness / readiness probe</td></tr>
     *       <tr><td>{@code /auth/login}</td><td>Obtain a JWT</td></tr>
     *       <tr><td>{@code /auth/register}</td><td>Create a new owner account</td></tr>
     *       <tr><td>{@code /swagger-ui.html}, {@code /swagger-ui/**}</td><td>Swagger UI</td></tr>
     *       <tr><td>{@code /v3/api-docs}, {@code /v3/api-docs/**}</td><td>OpenAPI spec</td></tr>
     *     </table>
     *   </li>
     *   <li>{@code authenticated} — every other route requires a valid JWT supplied
     *       in the {@code Authorization: Bearer <token>} header.</li>
     * </ul>
     *
     * @param  http The {@link HttpSecurity} builder provided by Spring.
     * @return      The configured {@link SecurityFilterChain} bean.
     * @throws Exception if the security configuration fails to build.
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                // Disable CSRF: not needed for stateless REST APIs.
                // CSRF attacks require browser-managed cookies; our API uses
                // Authorization headers instead.
                .csrf(AbstractHttpConfigurer::disable)
                // .csrf(csrf -> csrf.disable())

                // Disable HTTP sessions: every request must carry its own JWT.
                // Spring will never create a HttpSession or set a JSESSIONID cookie.
                .sessionManagement(sm -> sm
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // Define route-level authorization rules.
                .authorizeHttpRequests(auth -> auth
                        // Public routes: login and health check require no token.
                        .requestMatchers(
                                "/health",
                                "/auth/login",
                                "/auth/register",
                                // ── Swagger UI / OpenAPI ──────────────────────────────
                                "/swagger-ui.html",
                                "/swagger-ui/**",
                                "/v3/api-docs",
                                "/v3/api-docs/**"
                        ).permitAll()
                        // All other routes require a valid JWT to be present.
                        .anyRequest().authenticated())

                // Register our JwtAuthFilter to run before Spring's default
                // username/password filter in the filter chain.
                .addFilterBefore(jwtAuthFilter,
                        UsernamePasswordAuthenticationFilter.class)

                // Build and return the configured filter chain.
                .build();
    }

    /**
     * Provides a {@link BCryptPasswordEncoder} bean for password hashing and verification.
     *
     * <p>BCrypt automatically generates and embeds a salt, making it resistant to
     * rainbow-table attacks. {@code AuthService} injects this bean to verify plaintext
     * passwords against the {@code bcrypt} hashes stored in the
     * {@code ledger_owner.password_hash} column.
     *
     * @return A {@link BCryptPasswordEncoder} with default cost factor (10 rounds).
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}