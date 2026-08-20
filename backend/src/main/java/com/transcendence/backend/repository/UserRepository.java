package com.transcendence.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.transcendence.backend.model.User;

/**
 * Repository interface for accessing and managing User entities.
 * Extends JpaRepository to provide CRUD operations and query methods.
 */
public interface UserRepository extends JpaRepository<User, Integer> {

    /**
     * Retrieves a user by their username.
     *
     * @param username the username to search for
     * @return an Optional containing the user if found, or empty otherwise
     */
    Optional<User> findByUsername(String username);
}
