package com.transcendence.backend.websocket;

import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Representa una sala de juego identificada por un código corto (ej. "AB3K").
 * Gestiona las sesiones conectadas a ella y el envío de mensajes solo
 * entre los miembros de esta sala.
 */
public class Room {

    public static final int MAX_PLAYERS = 4;

    private final String code;

    // sessionId -> WebSocketSession (solo las sesiones que pertenecen a esta sala)
    private final Map<String, WebSocketSession> members = new ConcurrentHashMap<>();

    // sessionId -> id de jugador dentro de la sala (el que ya usas en el protocolo actual)
    private final Map<String, Integer> playerIds = new ConcurrentHashMap<>();

    public Room(String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public synchronized boolean isFull() {
        return members.size() >= MAX_PLAYERS;
    }

    public boolean isEmpty() {
        return members.isEmpty();
    }

    public synchronized void addMember(WebSocketSession session, int playerId) {
        members.put(session.getId(), session);
        playerIds.put(session.getId(), playerId);
    }

    public void removeMember(WebSocketSession session) {
        members.remove(session.getId());
        playerIds.remove(session.getId());
    }

    public Integer getPlayerId(WebSocketSession session) {
        return playerIds.get(session.getId());
    }

    public synchronized java.util.List<Integer> getPlayerIds() {
        return new java.util.ArrayList<>(playerIds.values());
    }

    public int size() {
        return members.size();
    }

    /**
     * Envía un mensaje a todos los miembros de la sala excepto (opcionalmente) al emisor.
     */
    public void broadcast(String payload, WebSocketSession exclude) {
        members.values().forEach(s -> {
            try {
                if ((exclude == null || !s.getId().equals(exclude.getId())) && s.isOpen()) {
                    s.sendMessage(new TextMessage(payload));
                }
            } catch (IOException e) {
                System.out.println("Error enviando mensaje en sala " + code + ": " + e.getMessage());
            }
        });
    }
}