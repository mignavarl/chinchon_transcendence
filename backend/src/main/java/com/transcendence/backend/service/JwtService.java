package com.transcendence.backend.service;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Base64;
import java.util.Date;

import org.springframework.beans.factory.annotation.Value;
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

	private static final String DEFAULT_SECRET_KEY = "change-in-production-change-in-production";
    private static final long EXPIRATION_TIME_MS = 24 * 60 * 60 * 1000; // 24 hours

	// El secreto sale de JWT_SECRET (docker-compose lo saca del .env). El
	// db_gateway verifica los mismos tokens, asi que los dos servicios TIENEN
	// que leer el mismo valor: si no cuadra, todo responde 401.
	//
	// Si la variable no esta se usa el valor de siempre, para que a quien no
	// haya actualizado su .env le siga funcionando.
	@Value("${JWT_SECRET:" + DEFAULT_SECRET_KEY + "}")
	private String secretKey;

	// OJO: esto base64-CODIFICA el secreto y usa esos bytes ASCII como clave
	// HMAC; no lo descodifica. Queda asi a proposito. El gateway repite el
	// mismo paso (db_gateway/auth.js), y cambiarlo en un lado solo hace que
	// las firmas no cuadren. Ademas, cambiarlo invalida todos los tokens ya
	// repartidos, asi que habria que hacerlo en los dos sitios a la vez.
	private Key getSigningKey() {
		byte[] keyBytes = Base64.getEncoder().encode(secretKey.getBytes(StandardCharsets.UTF_8));
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
