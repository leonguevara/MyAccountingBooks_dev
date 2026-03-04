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
// Last edited: 2026-03-04
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
import org.springframework.security.config.http.SessionCreationPolicy;

// SecurityFilterChain: the resulting bean that Spring Security uses
//   to process incoming requests through our configured rules.
import org.springframework.security.web.SecurityFilterChain;

// UsernamePasswordAuthenticationFilter: Spring's built-in form-login filter.
//   We insert our JwtAuthFilter BEFORE this one so JWT authentication
//   runs first on every request.
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

// BCryptPasswordEncoder: industry-standard password hashing algorithm.
//   Used by AuthService to verify passwords stored as bcrypt hashes
//   in the ledger_owner.password_hash column.
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

// PasswordEncoder: the interface that BCryptPasswordEncoder implements.
//   Injecting via interface keeps the code flexible.
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class SecurityConfig {

    // The JWT filter to insert into the Spring Security filter chain.
    private final JwtAuthFilter jwtAuthFilter;

    /**
     * Constructor injection of JwtAuthFilter.
     *
     * @param jwtAuthFilter The custom JWT validation filter bean.
     */
    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    /**
     * Defines and builds the HTTP security filter chain.
     *
     * This is the central security configuration for the entire API.
     *
     * @param  http The HttpSecurity builder provided by Spring.
     * @return      The configured SecurityFilterChain bean.
     * @throws Exception if the security configuration fails to build.
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                // Disable CSRF: not needed for stateless REST APIs.
                // CSRF attacks require browser-managed cookies; our API uses
                // Authorization headers instead.
                .csrf(csrf -> csrf.disable())

                // Disable HTTP sessions: every request must carry its own JWT.
                // Spring will never create a HttpSession or set a JSESSIONID cookie.
                .sessionManagement(sm -> sm
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // Define route-level authorization rules.
                .authorizeHttpRequests(auth -> auth
                        // Public routes: login and health check require no token.
                        .requestMatchers("/auth/**", "/health").permitAll()
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
     * Provides a BCryptPasswordEncoder bean for password hashing/verification.
     *
     * BCrypt automatically handles salting and is the industry standard
     * for storing user passwords. Used by AuthService to verify the
     * password_hash column in the ledger_owner table.
     *
     * @return A BCryptPasswordEncoder with default strength (10 rounds).
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}