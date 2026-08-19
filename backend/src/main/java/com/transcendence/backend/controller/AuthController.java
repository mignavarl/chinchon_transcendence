package com.transcendence.backend.controller;

import java.util.Map;

import org.springframework.http.HttpStatus;
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
        if (isBlank(request.username()) || isBlank(request.password())) {
            return error(HttpStatus.BAD_REQUEST, "Username and password are required");
        }

        try {
            authService.signup(request.username(), request.password());
        } catch (IllegalArgumentException e) {
            // El unico motivo por el que signup() lanza es que el nombre ya exista.
            return error(HttpStatus.CONFLICT, e.getMessage());
        }

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
        if (isBlank(request.username()) || isBlank(request.password())) {
            return error(HttpStatus.BAD_REQUEST, "Username and password are required");
        }

        User user;
        try {
            user = authService.login(request.username(), request.password());
        } catch (IllegalArgumentException e) {
            // Credenciales malas. Sin este catch Spring devolvia un 500 y el
            // cliente no podia distinguir "password mal" de "backend caido".
            return error(HttpStatus.UNAUTHORIZED, e.getMessage());
        }

        String token = jwtService.generateToken(user.getUsername());
        return ResponseEntity.ok(Map.of("token", token));
    }

    // -------------------------------------------------------------------------
    // Helper Methods
    // -------------------------------------------------------------------------

    /**
     * Checks whether a request field is missing or contains only whitespace.
     *
     * @param value the field value to check
     * @return true if the value is null or blank
     */
    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    /**
     * Builds an error response with the shape the client expects: a JSON
     * object with a single "error" field.
     *
     * @param status the HTTP status to return
     * @param message the message shown to the user
     * @return the error response
     */
    private ResponseEntity<Map<String, String>> error(HttpStatus status, String message) {
        return ResponseEntity.status(status).body(Map.of("error", message));
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
