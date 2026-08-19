package com.transcendence.backend.filter;

import java.io.IOException;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.transcendence.backend.service.JwtService;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

/**
 * JWT filter responsible for validating incoming requests.
 * It extracts the JWT token, validates it, and sets the authenticated user
 * in the SecurityContext.
 */
@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    /**
     * Main filter method executed for every incoming request.
     * Delegates work to smaller helper methods to follow clean code principles.
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null) {
            Claims claims = validateToken(token);
            if (claims != null) {
                authenticateUser(request, claims);
            }
        }

        filterChain.doFilter(request, response);
    }

    // -------------------------------------------------------------------------
    // Helper Methods
    // -------------------------------------------------------------------------

    /**
     * Extracts the JWT token from the Authorization header.
     *
     * @param request the incoming HTTP request
     * @return the JWT token or null if the header is missing or invalid
     */
    private String extractToken(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return null;
        }

        return authHeader.substring(7);
    }

    /**
     * Validates the JWT token using JwtService.
     *
     * @param token the JWT token extracted from the request
     * @return Claims if the token is valid, otherwise null
     */
    private Claims validateToken(String token) {
        return jwtService.validateToken(token);
    }

    /**
     * Creates an Authentication object and stores it in the SecurityContext.
     *
     * @param request the incoming HTTP request
     * @param claims the validated JWT claims
     */
    private void authenticateUser(HttpServletRequest request, Claims claims) {
        String username = claims.getSubject();

        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(username, null, null);

        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}
