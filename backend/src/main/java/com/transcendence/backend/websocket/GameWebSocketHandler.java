package com.transcendence.backend.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper mapper = new ObjectMapper();
    private final RoomManager roomManager;

    // sessionId -> Room a la que pertenece (una sesión solo puede estar en una sala a la vez)
    private final Map<String, Room> sessionRoom = new ConcurrentHashMap<>();

    private final AtomicInteger nextPlayerId = new AtomicInteger(1);

    public GameWebSocketHandler(RoomManager roomManager) {
        this.roomManager = roomManager;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        System.out.println("Nueva conexión: " + session.getId());
        // Aún no pertenece a ninguna sala: espera a "create_room" o "join_room"
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        JsonNode node = mapper.readTree(message.getPayload());
        String type = node.path("type").asText();

        switch (type) {
            case "create_room" -> handleCreateRoom(session);
            case "join_room" -> handleJoinRoom(session, node.path("code").asText());
            case "start_game" -> handleBroadcastToAll(session, node);
            case "deck_sync" -> handleBroadcastToAll(session, node);
            case "game_action" -> handleGameAction(session, node);
			case "player_eliminated" -> handleBroadcastToAll(session, node);
			case "next_round" -> handleBroadcastToAll(session, node);
            default -> System.out.println("Tipo de mensaje desconocido: " + type);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        Room room = sessionRoom.remove(session.getId());
        if (room != null) {
            Integer playerId = room.getPlayerId(session);
            room.removeMember(session);

            ObjectNode left = mapper.createObjectNode();
            left.put("type", "player_left");
            left.put("id", playerId);
            room.broadcast(left.toString(), null);

            roomManager.removeIfEmpty(room);
            System.out.printf("Jugador %d salió de sala %s%n", playerId, room.getCode());
        }
    }

    // -------------------------------------------------------------------------
    // Handlers de cada tipo de mensaje
    // -------------------------------------------------------------------------

    private void handleCreateRoom(WebSocketSession session) throws Exception {
        Room room = roomManager.createRoom();
        joinExistingRoom(session, room);

        System.out.println("Sala creada: " + room.getCode());
    }

    private void handleJoinRoom(WebSocketSession session, String code) throws Exception {
        Room room = roomManager.getRoom(code);

        if (room == null) {
            sendError(session, "ROOM_NOT_FOUND", "La sala '" + code + "' no existe");
            return;
        }
        if (room.isFull()) {
            sendError(session, "ROOM_FULL", "La sala '" + code + "' ya está llena");
            return;
        }

        joinExistingRoom(session, room);
    }

    /**
     * Lógica común para meter una sesión en una sala (tanto al crearla como al unirse):
     * asigna id de jugador, registra la sesión, y notifica a todos.
     */
    private void joinExistingRoom(WebSocketSession session, Room room) throws Exception {
        // IMPORTANTE: obtener los ids que YA estaban en la sala antes de añadir al nuevo,
        // para poder informárselos en su propio mensaje "welcome".
        java.util.List<Integer> existingPlayerIds = room.getPlayerIds();

        int playerId = nextPlayerId.getAndIncrement();

        room.addMember(session, playerId);
        sessionRoom.put(session.getId(), room);

        // Confirmar al propio jugador: su id, el código de sala, y quién ya estaba
        ObjectNode welcome = mapper.createObjectNode();
        welcome.put("type", "welcome");
        welcome.put("id", playerId);
        welcome.put("room_code", room.getCode());
        var existingArray = welcome.putArray("existing_players");
        existingPlayerIds.forEach(existingArray::add);
        session.sendMessage(new TextMessage(welcome.toString()));

        // Avisar a los demás miembros de la sala
        ObjectNode joined = mapper.createObjectNode();
        joined.put("type", "player_joined");
        joined.put("id", playerId);
        room.broadcast(joined.toString(), session);

        System.out.printf("Jugador %d entró en sala %s (%d/%d)%n",
                playerId, room.getCode(), room.size(), Room.MAX_PLAYERS);
    }

    /**
     * Reenvía el mensaje tal cual a TODOS los miembros de la sala, incluido quien lo mandó.
     * Usado para mensajes de coordinación donde el propio emisor también necesita
     * confirmar/recibir el mensaje (start_game, deck_sync), a diferencia de
     * game_action donde el emisor ya conoce su propia acción.
     */
    private void handleBroadcastToAll(WebSocketSession session, JsonNode node) throws Exception {
        Room room = sessionRoom.get(session.getId());
        if (room == null) {
            sendError(session, "NOT_IN_ROOM", "No perteneces a ninguna sala todavía");
            return;
        }

        room.broadcast(node.toString(), null); // null = sin excluir a nadie
    }

    private void handleGameAction(WebSocketSession session, JsonNode node) throws Exception {
        Room room = sessionRoom.get(session.getId());
        if (room == null) {
            sendError(session, "NOT_IN_ROOM", "No perteneces a ninguna sala todavía");
            return;
        }

        Integer playerId = room.getPlayerId(session);

        ObjectNode out = node.deepCopy();
        out.put("from", playerId);

        room.broadcast(out.toString(), session);
    }

    private void sendError(WebSocketSession session, String code, String message) throws Exception {
        ObjectNode error = mapper.createObjectNode();
        error.put("type", "error");
        error.put("code", code);
        error.put("message", message);
        session.sendMessage(new TextMessage(error.toString()));
    }
}