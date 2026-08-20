package com.transcendence.backend.service;

import java.security.Key;
import java.util.Base64;
import java.util.Date;

import org.springframework.stereotype.Service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;

/**
 * Service responsible for generating and validating JWT tokens.
 */
@Service
public class JwtService {

	private static final String SECRET_KEY = "change-in-production-change-in-production";
    private static final long EXPIRATION_TIME_MS = 24 * 60 * 60 * 1000; // 24 hours

	private Key getSigningKey() {
		byte[] keyBytes = Base64.getEncoder().encode(SECRET_KEY.getBytes());
		return Keys.hmacShaKeyFor(keyBytes);
	}

    /**
     * Generates a signed JWT token containing the username.
     *
     * @param username the username to embed in the token
     * @return a signed JWT token
     */
    public String generateToken(String username) {
        Date expirationDate = createExpirationDate();
        return buildToken(username, expirationDate);
    }

    /**
     * Validates a JWT token and returns its claims.
     *
     * @param token the JWT token to validate
     * @return Claims if valid, otherwise null
     */
    public Claims validateToken(String token) {
        if (token == null || token.isBlank()) {
            return null;
        }

        try {
            return parseToken(token);
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }
    }

    // -------------------------------------------------------------------------
    // Helper Methods
    // -------------------------------------------------------------------------

    /**
     * Creates the expiration date for the JWT token.
     *
     * @return expiration date 24 hours from now
     */
    private Date createExpirationDate() {
        return new Date(System.currentTimeMillis() + EXPIRATION_TIME_MS);
    }

    /**
     * Builds a JWT token with the given username and expiration date.
     *
     * @param username the subject of the token
     * @param expirationDate the expiration date
     * @return a signed JWT token
     */
    private String buildToken(String username, Date expirationDate) {
        return Jwts.builder()
                .setSubject(username)
                .setExpiration(expirationDate)
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    /**
     * Parses and validates the JWT token using the secret key.
     *
     * @param token the JWT token to parse
     * @return the extracted Claims
     */
    private Claims parseToken(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
				.build()
                .parseClaimsJws(token)
                .getBody();
    }
}
