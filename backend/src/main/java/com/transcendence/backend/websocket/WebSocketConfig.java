package com.transcendence.backend.websocket;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.support.DefaultHandshakeHandler;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final GameWebSocketHandler gameWebSocketHandler;
    private final JwtHandshakeInterceptor jwtHandshakeInterceptor;

    public WebSocketConfig(GameWebSocketHandler gameWebSocketHandler,
                           JwtHandshakeInterceptor jwtHandshakeInterceptor) {
        this.gameWebSocketHandler = gameWebSocketHandler;
        this.jwtHandshakeInterceptor = jwtHandshakeInterceptor;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // El cliente ofrece dos subprotocolos: "chinchon.v1" y el token. El
        // navegador exige que el servidor conteste eligiendo uno de los que
        // ofreció, y aquí solo se admite "chinchon.v1": el token nunca vuelve.
        DefaultHandshakeHandler handshakeHandler = new DefaultHandshakeHandler();
        handshakeHandler.setSupportedProtocols(JwtHandshakeInterceptor.PROTOCOL);

        // Endpoint disponible en: wss://tu-host/ws/game (siempre a través de nginx)
        registry.addHandler(gameWebSocketHandler, "/ws/game")
                .setHandshakeHandler(handshakeHandler)
                .addInterceptors(jwtHandshakeInterceptor)
                .setAllowedOrigins("*"); // En producción, restringe a tu dominio/IP
    }
}
