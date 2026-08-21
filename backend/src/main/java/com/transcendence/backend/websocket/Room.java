package com.transcendence.backend.websocket;

import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Representa una sala de juego identificada por un código corto (ej. "AB3K").
 * Gestiona las sesiones conectadas a ella y el envío de mensajes solo
 * entre los miembros de esta sala.
 */
public class Room {

    public static final int MAX_PLAYERS = 4;

    /**
     * Un jugador dentro de la sala.
     *
     * username y userId son los del login del cliente y viajan hasta la mesa:
     * son los que el anfitrión acaba escribiendo en match_players cuando
     * guarda la partida. Un invitado sin cuenta manda userId = null, y
     * entonces su asiento se apunta sin usuario detrás.
     */
    public record Member(WebSocketSession session, int playerId, String username, Integer userId) {

        /** Nombre que se enseña en la mesa. Un invitado no manda ninguno. */
        public String displayName() {
            return (username == null || username.isBlank()) ? "Jugador " + playerId : username;
        }
    }

    private final String code;

    // sessionId -> jugador. ConcurrentHashMap NO garantiza orden, así que
    // todo listado que salga hacia los clientes se ordena por playerId: los
    // asientos tienen que quedar iguales en todas las máquinas.
    private final Map<String, Member> members = new ConcurrentHashMap<>();

    // El primero que entra. Solo él puede arrancar la partida y es quien la
    // guarda en la base de datos.
    private volatile Integer hostId;

    // Una vez empezada no se admite a nadie más: llegaría sin mazo ni manos.
    private volatile boolean started;

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

    public boolean isStarted() {
        return started;
    }

    public void markStarted() {
        this.started = true;
    }

    public synchronized void addMember(WebSocketSession session, int playerId, String username, Integer userId) {
        members.put(session.getId(), new Member(session, playerId, username, userId));
        if (hostId == null) {
            hostId = playerId;
        }
    }

    public void removeMember(WebSocketSession session) {
        members.remove(session.getId());
    }

    public Member getMember(WebSocketSession session) {
        return members.get(session.getId());
    }

    public Integer getPlayerId(WebSocketSession session) {
        Member member = members.get(session.getId());
        return member == null ? null : member.playerId();
    }

    public boolean isHost(WebSocketSession session) {
        Integer playerId = getPlayerId(session);
        return playerId != null && playerId.equals(hostId);
    }

    /** Los miembros ordenados por playerId: el orden de los asientos. */
    public List<Member> getMembers() {
        List<Member> ordered = new ArrayList<>(members.values());
        ordered.sort(Comparator.comparingInt(Member::playerId));
        return ordered;
    }

    public int size() {
        return members.size();
    }

    /**
     * Envía un mensaje a todos los miembros de la sala excepto (opcionalmente) al emisor.
     */
    public void broadcast(String payload, WebSocketSession exclude) {
        members.values().forEach(m -> {
            WebSocketSession s = m.session();
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
