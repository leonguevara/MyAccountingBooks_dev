// ============================================================
// JwtAuthFilter.java
// Package: com.leonguevara.mab.mab_api.security
//
// Purpose: Intercepts every incoming HTTP request and checks
//          for a valid JWT in the Authorization header.
//
//          If a valid token is found:
//            1. The ownerID is extracted from the token.
//            2. A UserPrincipal is created and wrapped in a
//               Spring Authentication object.
//            3. The Authentication is stored in the
//               SecurityContextHolder for the duration of
//               the request.
//
//          If no token or an invalid token is found:
//            - The request continues unauthenticated.
//            - Spring Security will reject it at the route
//              level if the endpoint requires authentication.
//
//          Extends OncePerRequestFilter: guarantees this filter
//          runs exactly once per HTTP request, never twice.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.security;

// OncePerRequestFilter: Spring base class that ensures the filter
//                       executes exactly once per request.
import org.springframework.web.filter.OncePerRequestFilter;

// UsernamePasswordAuthenticationToken: Spring Security's generic
//   Authentication implementation. We reuse it here to carry
//   our UserPrincipal — no username/password involved, just the ownerID.
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

// SecurityContextHolder: thread-local storage for the current
//   request's authentication. Setting auth here makes it available
//   to controllers via @AuthenticationPrincipal or SecurityContextHolder.
import org.springframework.security.core.context.SecurityContextHolder;

// HttpServletRequest / HttpServletResponse: standard Java EE types
//   representing the incoming HTTP request and outgoing response.
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

// FilterChain: allows this filter to pass the request along to
//              the next filter (or the controller) in the chain.
import jakarta.servlet.FilterChain;

// ServletException / IOException: checked exceptions required by
//   the doFilterInternal() contract.
import jakarta.servlet.ServletException;
import java.io.IOException;

// List.of(): creates an immutable empty list used as the
//            "granted authorities" (roles/permissions) argument.
//            We handle authorization at the DB level via RLS,
//            so no Spring roles are needed here.
import java.util.List;

// UUID: the type of ledger_owner.id.
import java.util.UUID;

// @Component: registers this filter as a Spring bean so it can
//             be injected into SecurityConfig.
import org.springframework.stereotype.Component;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    // JwtUtil handles all token verification and extraction logic.
    private final JwtUtil jwtUtil;

    /**
     * Constructor injection of JwtUtil.
     * Spring automatically injects the JwtUtil bean created in security/.
     *
     * @param jwtUtil The JWT utility bean.
     */
    public JwtAuthFilter(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    /**
     * Core filter logic — executed once per HTTP request.
     *
     * Flow:
     *   1. Read the "Authorization" header from the request.
     *   2. Check it starts with "Bearer " (standard JWT convention).
     *   3. Extract the token string (everything after "Bearer ").
     *   4. Validate the token with JwtUtil.
     *   5. If valid: extract ownerID, create Authentication, store in context.
     *   6. Always call chain.doFilter() to continue processing the request.
     *
     * @param request  The incoming HTTP request.
     * @param response The outgoing HTTP response.
     * @param chain    The remaining filter chain.
     */
    @Override
    protected void doFilterInternal(
            HttpServletRequest  request,
            HttpServletResponse response,
            FilterChain         chain)
            throws ServletException, IOException {

        // Read the Authorization header value (may be null if absent).
        String header = request.getHeader("Authorization");

        // Only process the header if it follows the "Bearer <token>" format.
        if (header != null && header.startsWith("Bearer ")) {

            // Strip the "Bearer " prefix (7 characters) to get the raw token.
            String token = header.substring(7);

            // Validate signature and expiry using JwtUtil.
            if (jwtUtil.isValid(token)) {

                // Extract the ownerID UUID from the token's subject claim.
                UUID ownerID = jwtUtil.extractOwnerID(token);

                // Wrap the ownerID in a UserPrincipal value object.
                UserPrincipal principal = new UserPrincipal(ownerID);

                // Create a Spring Authentication object:
                //   arg1: principal  — our UserPrincipal (who is authenticated)
                //   arg2: null       — credentials (not needed post-authentication)
                //   arg3: List.of()  — authorities/roles (handled by PostgreSQL RLS)
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(
                                principal, null, List.of());

                // Store the Authentication in the SecurityContext for this request.
                // This makes it available to @AuthenticationPrincipal in controllers.
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        }

        // Always continue the filter chain, whether authenticated or not.
        // Unauthenticated requests to protected routes will be rejected
        // by Spring Security at the route authorization level.
        chain.doFilter(request, response);
    }
}