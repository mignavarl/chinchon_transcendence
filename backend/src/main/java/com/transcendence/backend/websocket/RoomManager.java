package com.transcendence.backend.websocket;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Gestiona el ciclo de vida de las salas: creación con código único,
 * búsqueda por código, y limpieza cuando quedan vacías.
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
        String code;
        do {
            code = generateCode();
        } while (rooms.containsKey(code));

        Room room = new Room(code);
        rooms.put(code, room);
        return room;
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
            rooms.remove(room.getCode());
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