package com.transcendence.backend.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.transcendence.backend.model.User;
import com.transcendence.backend.service.AuthService;
import com.transcendence.backend.service.JwtService;

import lombok.RequiredArgsConstructor;

/**
 * REST controller responsible for handling user authentication requests.
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final JwtService jwtService;

    /**
     * Registers a new user using a signup request payload.
     *
     * @param request the signup request containing username and password
     * @return a response containing the created username
     */
    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody SignupRequest request) {
        authService.signup(request.username(), request.password());
        return ResponseEntity.ok(Map.of("message", "User registered successfully"));
    }

    /**
     * Authenticates a user and returns a JWT token.
     *
     * @param request the login request containing username and password
     * @return a response containing a signed JWT token
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        User user = authService.login(request.username(), request.password());
        String token = jwtService.generateToken(user.getUsername());
        return ResponseEntity.ok(Map.of("token", token));
    }

    // -------------------------------------------------------------------------
    // Request & Response DTOs
    // -------------------------------------------------------------------------

    /**
     * DTO representing a signup request.
     */
    public record SignupRequest(String username, String password) {}

    /**
     * DTO representing a signup response.
     */
    public record SignupResponse(String username) {}

    /**
     * DTO representing a login request.
     */
    public record LoginRequest(String username, String password) {}

    /**
     * DTO representing a login response containing a JWT token.
     */
    public record LoginResponse(String token) {}
}
