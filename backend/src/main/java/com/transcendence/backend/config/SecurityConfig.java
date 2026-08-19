package com.transcendence.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import com.transcendence.backend.filter.JwtFilter;

import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

/**
 * Security configuration class responsible for defining how Spring Security
 * protects the application. It registers the JWT filter, disables CSRF for APIs,
 * and configures which routes require authentication.
 *
 * - /api/auth/** is publicly accessible (signup/login)
 * - /health is publicly accessible
 * - All other routes require a valid JWT token
 */
@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    /**
     * JWT filter that validates tokens on each request and sets the
     * authenticated user in the security context.
     */
    private final JwtFilter jwtFilter;

    /**
     * Defines the main security filter chain for the application.
     * Configures route permissions and registers the JWT filter.
     *
     * @param http the HttpSecurity object used to configure security
     * @return the configured SecurityFilterChain
     * @throws Exception if configuration fails
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
 		
		// ------------------------------------------------------------
        // Disable CSRF for stateless REST APIs
        // ------------------------------------------------------------
        http.csrf(csrf -> csrf.disable());

        // ------------------------------------------------------------
        // Stateless session management (no JSESSIONID, no server sessions)
        // ------------------------------------------------------------
        http.sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
        );

        // ------------------------------------------------------------
        // Custom authentication entry point (return 401 instead of 403)
        // ------------------------------------------------------------
        http.exceptionHandling(exception ->
                exception.authenticationEntryPoint((request, response, authException) -> {
                    response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized");
                })
        );

        // ------------------------------------------------------------
        // Route authorization rules
        // ------------------------------------------------------------
        http.authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()   // Signup/Login allowed
                .requestMatchers("/api/health").permitAll()    // Health check allowed
        		.requestMatchers("/ws/game").permitAll()       // WebSocket handshake allowed
                .anyRequest().authenticated()                  // Everything else requires JWT
        );


        // ------------------------------------------------------------
        // Register JWT filter before Spring Security's authentication filter
        // ------------------------------------------------------------
        http.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * Exposes the AuthenticationManager bean used by Spring Security.
     *
     * @param authenticationConfiguration the authentication configuration
     * @return the AuthenticationManager instance
     * @throws Exception if initialization fails
     */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration authenticationConfiguration) throws Exception {
        return authenticationConfiguration.getAuthenticationManager();
    }
}
