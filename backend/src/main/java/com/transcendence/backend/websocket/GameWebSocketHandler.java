package com.transcendence.backend.websocket;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.transcendence.backend.service.MatchService;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {

    // Los mismos límites que acepta el db_gateway para las partidas offline.
    private static final int POINTS_MAX = 10000;

    private final ObjectMapper mapper = new ObjectMapper();
    private final RoomManager roomManager;
    private final MatchService matchService;

    // sessionId -> Room a la que pertenece (una sesión solo puede estar en una sala a la vez)
    private final Map<String, Room> sessionRoom = new ConcurrentHashMap<>();

    private final AtomicInteger nextPlayerId = new AtomicInteger(1);

    public GameWebSocketHandler(RoomManager roomManager, MatchService matchService) {
        this.roomManager = roomManager;
        this.matchService = matchService;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        System.out.printf("Nueva conexión: %s (%s)%n", session.getId(), username(session));
        // Aún no pertenece a ninguna sala: espera a "create_room" o "join_room"
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        // Un mensaje que no es JSON no puede tumbar la conexión: se contesta
        // con un error y se sigue.
        JsonNode node;
        try {
            node = mapper.readTree(message.getPayload());
        } catch (JsonProcessingException e) {
            sendError(session, "BAD_MESSAGE", "El mensaje no es JSON válido");
            return;
        }
        if (node == null || !node.isObject()) {
            sendError(session, "BAD_MESSAGE", "El mensaje tiene que ser un objeto JSON");
            return;
        }

        String type = node.path("type").asText();

        switch (type) {
            case "create_room" -> handleCreateRoom(session);
            case "join_room" -> handleJoinRoom(session, node);
            case "start_game" -> handleStartGame(session);
            case "player_left" -> handleClose(session, node, CloseStatus.GOING_AWAY);
            case "deck_sync" -> handleBroadcastToAll(session, node);
            case "game_action" -> handleGameAction(session, node);
            case "player_eliminated" -> handleBroadcastToAll(session, node);
            case "next_round" -> handleBroadcastToAll(session, node);
            case "match_result" -> handleMatchResult(session, node);
            case "match_ended" -> handleMatchEnded(session, node);
            // "match_saved" ya no se reenvía: lo manda solo el servidor, al
            // guardar. Si lo reenviara, cualquiera podría anunciar una partida
            // guardada que no existe.
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

    private void handleClose(WebSocketSession s, JsonNode n, CloseStatus status) throws Exception {
        handleBroadcastToAll(s, n);
        afterConnectionClosed(s, status);
    }

    private void handleCreateRoom(WebSocketSession session) throws Exception {
        if (sessionRoom.containsKey(session.getId())) {
            sendError(session, "ALREADY_IN_ROOM", "Ya estás en una sala");
            return;
        }
        Room room = roomManager.createRoom();
        if (!joinExistingRoom(session, room)) {
            roomManager.removeIfEmpty(room);
            return;
        }

        System.out.println("Sala creada: " + room.getCode());
    }

    private void handleJoinRoom(WebSocketSession session, JsonNode node) throws Exception {
        if (sessionRoom.containsKey(session.getId())) {
            sendError(session, "ALREADY_IN_ROOM", "Ya estás en una sala");
            return;
        }

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

        joinExistingRoom(session, room);
    }

    /**
     * Lógica común para meter una sesión en una sala (tanto al crearla como al unirse):
     * asigna id de jugador, registra la sesión, y notifica a todos.
     *
     * La identidad (username / user_id) sale del token con el que se abrió la
     * conexión (JwtHandshakeInterceptor). Si el mensaje trae "username" o
     * "user_id" se ignoran: si no, cualquiera podría sentarse a la mesa con el
     * nombre de otro y que la partida se le apuntara a él.
     *
     * @return false si no se pudo entrar (se le manda el error al cliente)
     */
    private boolean joinExistingRoom(WebSocketSession session, Room room) throws Exception {
        // IMPORTANTE: obtener los que YA estaban en la sala antes de añadir al nuevo,
        // para poder informárselos en su propio mensaje "welcome".
        var existing = room.getMembers();

        int playerId = nextPlayerId.getAndIncrement();
        if (!room.addMember(session, playerId, username(session), userId(session))) {
            // Se llenó o empezó entre la comprobación de handleJoinRoom y aquí.
            sendError(session, "ROOM_UNAVAILABLE", "La sala '" + room.getCode() + "' ya no admite jugadores");
            return false;
        }
        sessionRoom.put(session.getId(), room);

        Room.Member me = room.getMember(session);

        // Confirmar al propio jugador: su id, el código de sala, y quién ya estaba
        ObjectNode welcome = mapper.createObjectNode();
        welcome.put("type", "welcome");
        welcome.put("id", playerId);
        welcome.put("room_code", room.getCode());
        welcome.put("is_host", room.isHost(session));
        welcome.put("username", me.displayName());
        putUserId(welcome, me.userId());
        ArrayNode existingArray = welcome.putArray("existing_players");
        existing.forEach(m -> existingArray.add(describe(m)));
        send(session, welcome.toString());

        // Avisar a los demás miembros de la sala
        ObjectNode joined = describe(me);
        joined.put("type", "player_joined");
        room.broadcast(joined.toString(), session);

        System.out.printf("Jugador %d (%s) entró en sala %s (%d/%d)%n",
                playerId, me.displayName(), room.getCode(), room.size(), Room.MAX_PLAYERS);
        return true;
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
        if (room.isStarted()) {
            sendError(session, "ROOM_STARTED", "La partida ya ha empezado");
            return;
        }

        room.markStarted();

        ObjectNode start = mapper.createObjectNode();
        start.put("type", "start_game");
        ArrayNode players = start.putArray("players");
        room.getRoster().forEach(m -> players.add(describe(m)));

        // A todos, el anfitrión incluido: es el mensaje recibido lo que hace
        // que cada cliente cargue la mesa, también en la máquina que lo manda.
        room.broadcast(start.toString(), null);

        System.out.printf("Sala %s empieza con %d jugadores%n", room.getCode(), room.size());
    }

    /**
     * Reenvía el mensaje tal cual a TODOS los miembros de la sala, incluido quien lo mandó.
     * Usado para mensajes de coordinación donde el propio emisor también necesita
     * confirmar/recibir el mensaje (deck_sync, next_round), a diferencia
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

    /**
     * El anfitrión cuenta cómo acabó la partida y el servidor la guarda.
     *
     * Mensaje: { "type": "match_result", "max_points": 100, "deck_id": "pixel",
     *            "seats": [ { "id": 3, "score": 42, "is_winner": false }, ... ] }
     *
     * "id" es el id de jugador de la sala, no el de la base de datos: quién es
     * cada uno (user_id y nombre) lo pone el servidor a partir de los tokens.
     * Tiene que venir exactamente un asiento por cada jugador que empezó la
     * partida, incluidos los que se fueron a mitad.
     *
     * Si va bien, todos reciben { "type": "match_saved", "match_id": N }.
     */
    private void handleMatchResult(WebSocketSession session, JsonNode node) throws Exception {
        Room room = sessionRoom.get(session.getId());
        if (room == null) {
            sendError(session, "NOT_IN_ROOM", "No perteneces a ninguna sala todavía");
            return;
        }
        if (!room.isHost(session)) {
            sendError(session, "NOT_HOST", "Solo el anfitrión puede guardar la partida");
            return;
        }
        if (!room.isStarted()) {
            sendError(session, "NOT_STARTED", "La partida no ha empezado");
            return;
        }

        String invalid = validateResult(node, room.getRoster());
        if (invalid != null) {
            sendError(session, "BAD_RESULT", invalid);
            return;
        }

        if (!room.claimSave()) {
            sendError(session, "ALREADY_SAVED", "La partida ya está guardada");
            return;
        }

        Map<Integer, JsonNode> byId = new HashMap<>();
        node.path("seats").forEach(s -> byId.put(s.path("id").asInt(), s));

        List<MatchService.Seat> seats = new ArrayList<>();
        for (Room.Member m : room.getRoster()) {
            JsonNode s = byId.get(m.playerId());
            seats.add(new MatchService.Seat(
                    m.userId(), m.displayName(), s.path("score").asInt(), s.path("is_winner").asBoolean()));
        }

        JsonNode deckNode = node.path("deck_id");
        String deckId = deckNode.isTextual() ? deckNode.asText() : null;

        int matchId;
        try {
            matchId = matchService.saveOnlineMatch(node.path("max_points").asInt(), deckId, seats);
        } catch (RuntimeException e) {
            room.releaseSave();
            System.out.println("Error guardando la partida de la sala " + room.getCode() + ": " + e.getMessage());
            sendError(session, "SAVE_FAILED", "No se pudo guardar la partida");
            return;
        }

        ObjectNode saved = mapper.createObjectNode();
        saved.put("type", "match_saved");
        saved.put("match_id", matchId);
        room.broadcast(saved.toString(), null);

        System.out.printf("Sala %s: partida %d guardada%n", room.getCode(), matchId);
    }

    /**
     * Comprueba el "match_result". Devuelve el motivo del rechazo, o null si vale.
     */
    private String validateResult(JsonNode node, List<Room.Member> roster) {
        JsonNode maxPoints = node.path("max_points");
        if (!maxPoints.isIntegralNumber() || maxPoints.asInt() < 1 || maxPoints.asInt() > POINTS_MAX) {
            return "'max_points' tiene que ser un entero positivo";
        }
        JsonNode deck = node.path("deck_id");
        if (!deck.isMissingNode() && !deck.isNull() && !deck.isTextual()) {
            return "'deck_id' tiene que ser un texto";
        }

        JsonNode seats = node.path("seats");
        if (!seats.isArray() || seats.size() != roster.size()) {
            return "'seats' tiene que traer un asiento por cada jugador de la partida";
        }

        Set<Integer> expected = new HashSet<>();
        roster.forEach(m -> expected.add(m.playerId()));

        int winners = 0;
        for (JsonNode s : seats) {
            JsonNode id = s.path("id");
            JsonNode score = s.path("score");
            JsonNode winner = s.path("is_winner");
            if (!id.isIntegralNumber() || !expected.remove(id.asInt())) {
                return "'seats' tiene un jugador que no está en la partida o repetido";
            }
            if (!score.isIntegralNumber() || Math.abs(score.asLong()) > POINTS_MAX) {
                return "'score' tiene que ser un entero";
            }
            if (!winner.isBoolean()) {
                return "'is_winner' tiene que ser true o false";
            }
            if (winner.asBoolean()) {
                winners++;
            }
        }
        if (winners == 0) {
            return "tiene que haber al menos un ganador";
        }
        return null;
    }

    /**
     * Fin de la partida: se avisa a todos (vuelven al bar) y se cierra la sala.
     * El código deja de valer y nadie queda apuntado a ella.
     *
     * Lo puede mandar el anfitrión en cualquier momento, y el resto solo cuando
     * la partida ya está guardada: si no, un cliente trucado podría echar a
     * todos de la mesa a mitad de partida.
     */
    private void handleMatchEnded(WebSocketSession session, JsonNode node) throws Exception {
        Room room = sessionRoom.get(session.getId());
        if (room == null) {
            sendError(session, "NOT_IN_ROOM", "No perteneces a ninguna sala todavía");
            return;
        }
        if (!room.isHost(session) && !room.isSaved()) {
            sendError(session, "NOT_FINISHED", "La partida todavía no ha terminado");
            return;
        }

        ObjectNode ended = mapper.createObjectNode();
        ended.put("type", "match_ended");
        room.broadcast(ended.toString(), null);

        for (Room.Member m : room.getMembers()) {
            sessionRoom.remove(m.session().getId(), room);
            room.removeMember(m.session());
        }
        roomManager.removeRoom(room);

        System.out.printf("Sala %s cerrada%n", room.getCode());
    }

    // -------------------------------------------------------------------------
    // Utilidades
    // -------------------------------------------------------------------------

    /** La ficha de un jugador tal y como viaja por la red. */
    private ObjectNode describe(Room.Member member) {
        ObjectNode player = mapper.createObjectNode();
        player.put("id", member.playerId());
        player.put("username", member.displayName());
        putUserId(player, member.userId());
        return player;
    }

    private void putUserId(ObjectNode node, Integer userId) {
        if (userId == null) {
            node.putNull("user_id");
        } else {
            node.put("user_id", userId);
        }
    }

    private String username(WebSocketSession session) {
        Object v = session.getAttributes().get(JwtHandshakeInterceptor.ATTR_USERNAME);
        return v instanceof String s ? s : null;
    }

    private Integer userId(WebSocketSession session) {
        Object v = session.getAttributes().get(JwtHandshakeInterceptor.ATTR_USER_ID);
        return v instanceof Integer i ? i : null;
    }

    private void sendError(WebSocketSession session, String code, String message) throws Exception {
        ObjectNode error = mapper.createObjectNode();
        error.put("type", "error");
        error.put("code", code);
        error.put("message", message);
        send(session, error.toString());
    }

    /** sendMessage no admite dos envíos a la vez en la misma sesión (ver Room.broadcast). */
    private void send(WebSocketSession session, String payload) throws IOException {
        synchronized (session) {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(payload));
            }
        }
    }
}
