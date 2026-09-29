package com.transcendence.backend.websocket;

import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

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
     * username y userId salen del token con el que se abrió el WebSocket
     * (JwtHandshakeInterceptor), no de lo que diga el cliente. Viajan hasta la
     * mesa y son los que se escriben en match_players al guardar la partida.
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

    // Quién jugaba cuando empezó la partida, en orden de asiento. Se guarda
    // aparte porque el que se va a mitad sale de "members", pero su asiento
    // tiene que seguir apareciendo en la partida guardada.
    private volatile List<Member> roster = List.of();

    // La partida solo se guarda una vez aunque llegue "match_result" dos veces.
    private final AtomicBoolean saved = new AtomicBoolean(false);

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

    public synchronized void markStarted() {
        this.roster = List.copyOf(getMembers());
        this.started = true;
    }

    /** Los jugadores con los que empezó la partida, en orden de asiento. */
    public List<Member> getRoster() {
        return roster;
    }

    /** true solo la primera vez: quien lo consigue es quien guarda. */
    public boolean claimSave() {
        return saved.compareAndSet(false, true);
    }

    /** Devuelve el permiso si el guardado falló, para poder reintentarlo. */
    public void releaseSave() {
        saved.set(false);
    }

    public boolean isSaved() {
        return saved.get();
    }

    /**
     * Mete al jugador si cabe y la partida no ha empezado. Va sincronizado
     * con markStarted() para que nadie se cuele entre la comprobación y el
     * alta (dos que entran a la vez en una sala con un hueco, o uno que entra
     * justo cuando el anfitrión pulsa empezar).
     *
     * @return false si la sala estaba llena o ya empezada
     */
    public synchronized boolean addMember(WebSocketSession session, int playerId, String username, Integer userId) {
        if (started || members.size() >= MAX_PLAYERS) {
            return false;
        }
        members.put(session.getId(), new Member(session, playerId, username, userId));
        if (hostId == null) {
            hostId = playerId;
        }
        return true;
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

    public Integer getHostId() {
        return hostId;
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
                    // sendMessage no admite dos envíos a la vez en la misma
                    // sesión, y aquí pueden llegar desde hilos distintos.
                    synchronized (s) {
                        s.sendMessage(new TextMessage(payload));
                    }
                }
            } catch (IOException e) {
                System.out.println("Error enviando mensaje en sala " + code + ": " + e.getMessage());
            }
        });
    }
}
