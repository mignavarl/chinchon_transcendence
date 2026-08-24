package com.transcendence.backend.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
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
            case "create_room" -> handleCreateRoom(session, node);
            case "join_room" -> handleJoinRoom(session, node);
            case "start_game" -> handleStartGame(session);
            case "deck_sync" -> handleBroadcastToAll(session, node);
            case "game_action" -> handleGameAction(session, node);
            case "player_eliminated" -> handleBroadcastToAll(session, node);
            case "next_round" -> handleBroadcastToAll(session, node);
            case "match_ended" -> handleBroadcastToAll(session, node);
            case "match_saved" -> handleBroadcastToAll(session, node);
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

    private void handleCreateRoom(WebSocketSession session, JsonNode node) throws Exception {
        Room room = roomManager.createRoom();
        joinExistingRoom(session, room, node);

        System.out.println("Sala creada: " + room.getCode());
    }

    private void handleJoinRoom(WebSocketSession session, JsonNode node) throws Exception {
        String code = node.path("code").asText();
        Room room = roomManager.getRoom(code);

        if (room == null) {
            sendError(session, "ROOM_NOT_FOUND", "La sala '" + code + "' no existe");
            return;
        }
        if (room.isFull()) {
            sendError(session, "ROOM_FULL", "La sala '" + code + "' ya está llena");
            return;
        }
        // Entrar a mitad de partida dejaría al recién llegado sin mazo ni manos,
        // y el resto ya no está escuchando "player_joined".
        if (room.isStarted()) {
            sendError(session, "ROOM_STARTED", "La partida ya ha empezado");
            return;
        }

        joinExistingRoom(session, room, node);
    }

    /**
     * Lógica común para meter una sesión en una sala (tanto al crearla como al unirse):
     * asigna id de jugador, registra la sesión, y notifica a todos.
     *
     * La identidad (username / user_id) llega en el propio mensaje del cliente y
     * se queda guardada en la sala: es lo que se reparte a los demás para que
     * todos vean nombres reales en la mesa, y lo que el anfitrión usa al guardar.
     */
    private void joinExistingRoom(WebSocketSession session, Room room, JsonNode node) throws Exception {
        // IMPORTANTE: obtener los que YA estaban en la sala antes de añadir al nuevo,
        // para poder informárselos en su propio mensaje "welcome".
        var existing = room.getMembers();

        int playerId = nextPlayerId.getAndIncrement();
        String username = node.path("username").asText("");
        Integer userId = node.path("user_id").isIntegralNumber() ? node.path("user_id").asInt() : null;
        // El juego manda -1 cuando se entra sin cuenta; eso no es un usuario.
        if (userId != null && userId <= 0) {
            userId = null;
        }

        room.addMember(session, playerId, username, userId);
        sessionRoom.put(session.getId(), room);

        Room.Member me = room.getMember(session);

        // Confirmar al propio jugador: su id, el código de sala, y quién ya estaba
        ObjectNode welcome = mapper.createObjectNode();
        welcome.put("type", "welcome");
        welcome.put("id", playerId);
        welcome.put("room_code", room.getCode());
        welcome.put("is_host", room.isHost(session));
        ArrayNode existingArray = welcome.putArray("existing_players");
        existing.forEach(m -> existingArray.add(describe(m)));
        session.sendMessage(new TextMessage(welcome.toString()));

        // Avisar a los demás miembros de la sala
        ObjectNode joined = describe(me);
        joined.put("type", "player_joined");
        room.broadcast(joined.toString(), session);

        System.out.printf("Jugador %d (%s) entró en sala %s (%d/%d)%n",
                playerId, me.displayName(), room.getCode(), room.size(), Room.MAX_PLAYERS);
    }

    /**
     * Arranca la partida. Solo el anfitrión puede, y la plantilla la monta el
     * servidor a partir de quién hay en la sala: si viniera del cliente, un
     * cliente trucado podría repartir asientos o colar identidades ajenas.
     */
    private void handleStartGame(WebSocketSession session) throws Exception {
        Room room = sessionRoom.get(session.getId());
        if (room == null) {
            sendError(session, "NOT_IN_ROOM", "No perteneces a ninguna sala todavía");
            return;
        }
        if (!room.isHost(session)) {
            sendError(session, "NOT_HOST", "Solo el anfitrión puede empezar la partida");
            return;
        }

        room.markStarted();

        ObjectNode start = mapper.createObjectNode();
        start.put("type", "start_game");
        ArrayNode players = start.putArray("players");
        room.getMembers().forEach(m -> players.add(describe(m)));

        // A todos, el anfitrión incluido: es el mensaje recibido lo que hace
        // que cada cliente cargue la mesa, también en la máquina que lo manda.
        room.broadcast(start.toString(), null);

        System.out.printf("Sala %s empieza con %d jugadores%n", room.getCode(), room.size());
    }

    /**
     * Reenvía el mensaje tal cual a TODOS los miembros de la sala, incluido quien lo mandó.
     * Usado para mensajes de coordinación donde el propio emisor también necesita
     * confirmar/recibir el mensaje (deck_sync, next_round, match_saved), a diferencia
     * de game_action donde el emisor ya conoce su propia acción.
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

    /** La ficha de un jugador tal y como viaja por la red. */
    private ObjectNode describe(Room.Member member) {
        ObjectNode player = mapper.createObjectNode();
        player.put("id", member.playerId());
        player.put("username", member.displayName());
        if (member.userId() == null) {
            player.putNull("user_id");
        } else {
            player.put("user_id", member.userId());
        }
        return player;
    }

    private void sendError(WebSocketSession session, String code, String message) throws Exception {
        ObjectNode error = mapper.createObjectNode();
        error.put("type", "error");
        error.put("code", code);
        error.put("message", message);
        session.sendMessage(new TextMessage(error.toString()));
    }
}
