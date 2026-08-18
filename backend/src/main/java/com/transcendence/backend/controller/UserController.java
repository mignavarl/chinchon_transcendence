package com.transcendence.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller responsible for exposing user-related endpoints.
 */
@RestController
@RequestMapping("/api/user")
public class UserController {

    /**
     * Returns information about the currently authenticated user.
     *
     * @param auth the authentication object injected by Spring Security
     * @return a response containing the authenticated username
     */
    @GetMapping("/me")
    public ResponseEntity<UserInfoResponse> getAuthenticatedUser(Authentication auth) {
        String username = extractUsername(auth);
        return ResponseEntity.ok(new UserInfoResponse(username));
    }

    // -------------------------------------------------------------------------
    // Helper Methods
    // -------------------------------------------------------------------------

    /**
     * Extracts the username from the Authentication object.
     *
     * @param auth the authentication object
     * @return the authenticated username
     */
    private String extractUsername(Authentication auth) {
        return auth.getName();
    }

    // -------------------------------------------------------------------------
    // Response DTOs
    // -------------------------------------------------------------------------

    /**
     * DTO representing the authenticated user's information.
     */
    public record UserInfoResponse(String username) {}
}
