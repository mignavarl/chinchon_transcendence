package com.transcendence.backend.websocket;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Gestiona el ciclo de vida de las salas: creación con código único,
 * búsqueda por código, y limpieza cuando quedan vacías o acaba la partida.
 */
@Component
public class RoomManager {

    private static final String CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin 0/O/1/I para evitar confusión
    private static final int CODE_LENGTH = 4;

    private final SecureRandom random = new SecureRandom();
    private final ConcurrentHashMap<String, Room> rooms = new ConcurrentHashMap<>();

    /**
     * Crea una sala nueva con un código único y la registra.
     */
    public Room createRoom() {
        while (true) {
            Room room = new Room(generateCode());
            // putIfAbsent y no containsKey + put: dos salas creadas a la vez
            // no pueden quedarse con el mismo código.
            if (rooms.putIfAbsent(room.getCode(), room) == null) {
                return room;
            }
        }
    }

    public Room getRoom(String code) {
        return rooms.get(code);
    }

    public boolean roomExists(String code) {
        return rooms.containsKey(code);
    }

    /**
     * Elimina la sala si ya no tiene miembros (llamar tras cada desconexión).
     */
    public void removeIfEmpty(Room room) {
        if (room != null && room.isEmpty()) {
            rooms.remove(room.getCode(), room);
        }
    }

    /**
     * Elimina la sala aunque quede gente dentro: al acabar la partida el
     * código deja de valer y nadie puede volver a entrar en ella.
     */
    public void removeRoom(Room room) {
        if (room != null) {
            rooms.remove(room.getCode(), room);
        }
    }

    private String generateCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(CODE_CHARS.charAt(random.nextInt(CODE_CHARS.length())));
        }
        return sb.toString();
    }
}
