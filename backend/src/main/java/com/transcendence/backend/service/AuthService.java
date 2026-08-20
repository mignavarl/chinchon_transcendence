package com.transcendence.backend.service;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import com.transcendence.backend.model.User;
import com.transcendence.backend.repository.UserRepository;

import lombok.RequiredArgsConstructor;

/**
 * Service responsible for user authentication and registration.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    /**
     * Registers a new user in the system.
     *
     * @param username the desired username
     * @param rawPassword the plain-text password
     * @return the created User entity
     */
    public User signup(String username, String rawPassword) {
        validateUsernameAvailability(username);

        String encodedPassword = encodePassword(rawPassword);
        User newUser = buildUser(username, encodedPassword);

        return saveUser(newUser);
    }

    /**
     * Authenticates a user by validating username and password.
     *
     * @param username the username provided
     * @param rawPassword the plain-text password provided
     * @return the authenticated User entity
     */
    public User login(String username, String rawPassword) {
        User user = findUserOrThrow(username);
        validatePassword(rawPassword, user.getPassword());
        return user;
    }

    // -------------------------------------------------------------------------
    // Helper Methods
    // -------------------------------------------------------------------------

    /**
     * Checks if the username is already taken.
     *
     * @param username the username to validate
     */
    private void validateUsernameAvailability(String username) {
        if (userRepository.findByUsername(username).isPresent()) {
            throw new IllegalArgumentException("Username already exists");
        }
    }

    /**
     * Encodes a plain-text password using BCrypt.
     *
     * @param rawPassword the plain-text password
     * @return the encoded password
     */
    private String encodePassword(String rawPassword) {
        return passwordEncoder.encode(rawPassword);
    }

    /**
     * Builds a new User entity.
     *
     * El nombre visible arranca igual que el username porque en init.sql
     * la columna "name" es NOT NULL y no tiene DEFAULT. El usuario puede
     * cambiarlo despues desde el perfil.
     *
     * @param username the username
     * @param encodedPassword the encoded password
     * @return a new User instance
     */
    private User buildUser(String username, String encodedPassword) {
        return User.builder()
                .username(username)
                .name(username)
                .password(encodedPassword)
                .build();
    }

    /**
     * Saves a user entity to the database.
     *
     * @param user the user to save
     * @return the saved User entity
     */
    private User saveUser(User user) {
        return userRepository.save(user);
    }

    /**
     * Retrieves a user by username or throws an exception.
     *
     * @param username the username to search
     * @return the found User entity
     */
    private User findUserOrThrow(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Invalid username or password"));
    }

    /**
     * Validates that the provided password matches the stored encoded password.
     *
     * @param rawPassword the plain-text password provided
     * @param encodedPassword the stored encoded password
     */
    private void validatePassword(String rawPassword, String encodedPassword) {
        if (!passwordEncoder.matches(rawPassword, encodedPassword)) {
            throw new IllegalArgumentException("Invalid username or password");
        }
    }
}
