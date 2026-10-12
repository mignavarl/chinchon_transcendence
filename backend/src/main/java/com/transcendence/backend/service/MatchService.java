package com.transcendence.backend.service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import lombok.RequiredArgsConstructor;

/**
 * Guarda en la base de datos las partidas online.
 *
 * Antes las escribía el anfitrión desde el navegador mandando SQL en crudo al
 * db_gateway, con los user_id que él quisiera. Ahora las escribe el servidor
 * del WebSocket, que es el único que sabe con certeza quién estaba en la sala:
 * los user_id salen de los tokens con los que se conectó cada uno.
 *
 * Las puntuaciones sí las sigue diciendo el anfitrión: el juego se simula en
 * los clientes y el servidor solo reenvía, así que no tiene otra forma de
 * saberlas.
 */
@Service
@RequiredArgsConstructor
public class MatchService {

    private final JdbcTemplate jdbc;

    /**
     * Un asiento tal y como se guarda. userId es null si no hay cuenta detrás
     * (o si la misma cuenta ya ocupa otro asiento de esta partida).
     */
    public record Seat(Integer userId, String name, int score, boolean winner) {}

    /**
     * Escribe la partida, sus asientos y la victoria/derrota de cada usuario,
     * todo en la misma transacción: o se guarda todo o nada.
     *
     * @param maxPoints límite de puntos con el que se jugó
     * @param deckId    baraja usada; si no existe en el catálogo se guarda null
     * @param seats     asientos en orden (el primero es el asiento 1)
     * @return el id de la partida nueva
     */
    @Transactional
    public int saveOnlineMatch(int maxPoints, String deckId, List<Seat> seats) {
        String deck = null;
        if (deckId != null) {
            Integer found = jdbc.queryForObject(
                    "SELECT count(*)::int FROM decks WHERE id = ?", Integer.class, deckId);
            if (found != null && found > 0) {
                deck = deckId;
            }
        }

        Integer matchId = jdbc.queryForObject(
                "INSERT INTO matches (is_online, max_points, deck_id, ended_at) "
                        + "VALUES (true, ?, ?, now()) RETURNING id",
                Integer.class, maxPoints, deck);
        if (matchId == null) {
            throw new IllegalStateException("el INSERT de la partida no devolvió id");
        }

        // match_players tiene UNIQUE (match_id, user_id): la misma cuenta en
        // dos pestañas tumbaría el INSERT entero. El segundo asiento se apunta
        // sin usuario en vez de perder la partida.
        Set<Integer> seen = new HashSet<>();
        for (int i = 0; i < seats.size(); i++) {
            Seat s = seats.get(i);
            Integer userId = (s.userId() != null && seen.add(s.userId())) ? s.userId() : null;

            jdbc.update(
                    "INSERT INTO match_players (match_id, seat, user_id, name, kind, score, is_winner) "
                            + "VALUES (?, ?, ?, ?, 'human', ?, ?)",
                    matchId, i + 1, userId, s.name(), s.score(), s.winner());

            if (userId != null) {
                jdbc.update(
                        "UPDATE users SET wins = wins + ?, losses = losses + ?, coins = coins + ? WHERE id = ?",
                        s.winner() ? 1 : 0, s.winner() ? 0 : 1, s.winner() ? 1 : 0, userId);
            }
        }

        return matchId;
    }
}
