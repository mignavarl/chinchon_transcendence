package com.transcendence.backend.websocket;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import com.transcendence.backend.model.User;
import com.transcendence.backend.repository.UserRepository;
import com.transcendence.backend.service.JwtService;

import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;

/**
 * Pide login para abrir el WebSocket del juego.
 *
 * El navegador no deja poner cabeceras (Authorization) al abrir un WebSocket,
 * así que el token viaja en la lista de subprotocolos: el cliente ofrece
 * ["chinchon.v1", "bearer.<token>"]. El servidor elige "chinchon.v1" (ver
 * WebSocketConfig) y el token no sale nunca en la URL, que es lo que acaba en
 * los logs de nginx.
 *
 * Si el token falta o no vale, la conexión se rechaza con 401 antes de abrirse.
 * Si vale, el username y el id del usuario quedan en los atributos de la
 * sesión: a partir de ahí la identidad de cada jugador sale de aquí, no de lo
 * que el cliente diga en sus mensajes.
 */
@Component
@RequiredArgsConstructor
public class JwtHandshakeInterceptor implements HandshakeInterceptor {

    public static final String PROTOCOL = "chinchon.v1";
    public static final String TOKEN_PREFIX = "bearer.";

    public static final String ATTR_USERNAME = "username";
    public static final String ATTR_USER_ID = "userId";

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                   WebSocketHandler wsHandler, Map<String, Object> attributes) {
        String token = extractToken(request);
        Claims claims = jwtService.validateToken(token);
        if (claims == null || claims.getSubject() == null) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        // El token solo lleva el username; el id se busca aquí. Si la cuenta se
        // borró o se renombró, el token ya no apunta a nadie.
        User user = userRepository.findByUsername(claims.getSubject()).orElse(null);
        if (user == null) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        attributes.put(ATTR_USERNAME, user.getUsername());
        attributes.put(ATTR_USER_ID, user.getId());
        return true;
    }

    @Override
    public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                               WebSocketHandler wsHandler, Exception exception) {
        // Nada que hacer después.
    }

    /** Busca "bearer.<token>" entre los subprotocolos que ofrece el cliente. */
    private String extractToken(ServerHttpRequest request) {
        List<String> offered = request.getHeaders().getValuesAsList("Sec-WebSocket-Protocol");
        for (String protocol : offered) {
            String p = protocol.trim();
            if (p.startsWith(TOKEN_PREFIX) && p.length() > TOKEN_PREFIX.length()) {
                return p.substring(TOKEN_PREFIX.length());
            }
        }
        return null;
    }
}
