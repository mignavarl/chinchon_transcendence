extends Node

# =============================================================================
# database.gd
#
# Autoload para hablar con la base de datos desde cualquier parte del juego.
# El juego corre en el navegador, asi que no se conecta a Postgres
# directamente: manda la SQL por HTTP al gateway (/db/query) y este la
# ejecuta y devuelve las filas.
#
# Uso:
#   Database.query("SELECT * FROM demo WHERE id = $1", [1], func(res):
#       if res.ok:
#           print(res.rows)
#       else:
#           push_error(res.error)
#   )
#
# Los valores van SIEMPRE en el array de params ($1, $2, ...), nunca pegados
# a mano dentro del string de la SQL.
# =============================================================================


# Ejecuta la consulta y llama a callback(result: Dictionary).
# result = { ok = true, rows = [...], rowCount = n }  si va bien
# result = { ok = false, error = "..." }              si falla
func query(sql: String, params: Array, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	# En el editor el certificado es autofirmado, asi que hay que saltarse
	# la validacion. En web de esto ya se encarga el navegador.
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())

	http.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			var text := body.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data == null or not (data is Dictionary):
				callback.call({ "ok": false, "error": "respuesta invalida (codigo %d)" % code })
			else:
				callback.call(data)
	)

	var url := _api_base() + "/db/query"
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify({ "sql": sql, "params": params })

	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		callback.call({ "ok": false, "error": "no se pudo enviar la peticion: %s" % err })


# Mismo origen que la pagina, igual que hace lobby.gd con el WebSocket.
# Asi no hay hosts escritos a mano y nginx puede hacer de proxy.
func _api_base() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true))
	return "https://localhost:9443"  # fallback para ejecutar desde el editor


# =============================================================================
# ATAJOS POR TABLA
#
# Todos reciben un callback y le pasan el MISMO diccionario que query():
#   { ok = true, rows = [...], rowCount = n }   o   { ok = false, error = "..." }
#
# Los que devuelven "una sola cosa" igualmente traen la fila dentro de rows,
# asi que se lee con res.rows[0] despues de comprobar res.ok.
# =============================================================================


# ── Usuarios ────────────────────────────────────────────────────────────────

# Crea un usuario. Si el username ya existe no crea nada y rows llega vacio,
# asi que rowCount == 0 es "ese nombre esta cogido".
# El hash de la password se calcula FUERA de aqui: en esta tabla no entra
# nunca una password en claro.
func create_user(username: String, name: String, email, password_hash, callback: Callable) -> void:
	query("""
		INSERT INTO users (username, name, email, password_hash)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (username) DO NOTHING
		RETURNING id, username, name, coins, deck_selected
	""", [username, name, email, password_hash], callback)


func get_user(user_id: int, callback: Callable) -> void:
	query("""
		SELECT id, username, name, email, avatar_url, coins, deck_selected,
		       wins, losses, created_at, last_seen
		  FROM users WHERE id = $1
	""", [user_id], callback)


func get_user_by_username(username: String, callback: Callable) -> void:
	query("""
		SELECT id, username, name, email, avatar_url, coins, deck_selected,
		       wins, losses, created_at, last_seen
		  FROM users WHERE username = $1
	""", [username], callback)


# Devuelve tambien el password_hash, para comparar al hacer login.
func get_credentials(username: String, callback: Callable) -> void:
	query("SELECT id, username, password_hash FROM users WHERE username = $1",
		[username], callback)


func update_profile(user_id: int, name: String, avatar_url, callback: Callable) -> void:
	query("""
		UPDATE users SET name = $2, avatar_url = $3
		 WHERE id = $1 RETURNING id, name, avatar_url
	""", [user_id, name, avatar_url], callback)


func touch_last_seen(user_id: int, callback: Callable) -> void:
	query("UPDATE users SET last_seen = now() WHERE id = $1", [user_id], callback)


# amount puede ser negativo para gastar en el gachapon. El GREATEST evita
# dejar las monedas en negativo si se piden mas de las que hay.
func add_coins(user_id: int, amount: int, callback: Callable) -> void:
	query("""
		UPDATE users SET coins = GREATEST(0, coins + $2)
		 WHERE id = $1 RETURNING coins
	""", [user_id, amount], callback)


# ── Barajas ─────────────────────────────────────────────────────────────────

# Catalogo entero, equivalente a rarity__database.gd pero desde la base de datos.
func get_all_decks(callback: Callable) -> void:
	query("SELECT id, name, rarity FROM decks ORDER BY id", [], callback)


# Las barajas que tiene el usuario. Sustituye a los diccionarios
# dic_common / dic_uncommon / dic_rare / dic_legen de first.gd.
func get_user_decks(user_id: int, callback: Callable) -> void:
	query("""
		SELECT d.id, d.name, d.rarity, ud.obtained_at
		  FROM user_decks ud
		  JOIN decks d ON d.id = ud.deck_id
		 WHERE ud.user_id = $1
		 ORDER BY ud.obtained_at
	""", [user_id], callback)


# Las que le faltan: de aqui sale el sorteo del gachapon, es el equivalente
# a get_keys_unowned() de bazar.gd pero sin cargar todo el catalogo.
func get_unowned_decks(user_id: int, rarity: String, callback: Callable) -> void:
	query("""
		SELECT d.id, d.name, d.rarity
		  FROM decks d
		 WHERE d.rarity = $2
		   AND NOT EXISTS (
		       SELECT 1 FROM user_decks ud
		        WHERE ud.user_id = $1 AND ud.deck_id = d.id
		   )
	""", [user_id, rarity], callback)


# Da una baraja al usuario. Si ya la tenia no pasa nada y rowCount llega a 0.
func grant_deck(user_id: int, deck_id: String, callback: Callable) -> void:
	query("""
		INSERT INTO user_decks (user_id, deck_id) VALUES ($1, $2)
		ON CONFLICT (user_id, deck_id) DO NOTHING
		RETURNING deck_id
	""", [user_id, deck_id], callback)


# Solo deja elegir una baraja que el usuario tenga: el AND del EXISTS hace que
# la fila no se actualice si no la tiene, y rowCount se queda en 0.
func set_deck_selected(user_id: int, deck_id: String, callback: Callable) -> void:
	query("""
		UPDATE users SET deck_selected = $2
		 WHERE id = $1
		   AND EXISTS (SELECT 1 FROM user_decks
		                WHERE user_id = $1 AND deck_id = $2)
		RETURNING deck_selected
	""", [user_id, deck_id], callback)


# ── Partidas ────────────────────────────────────────────────────────────────

# Guarda una partida terminada con todos sus asientos.
#
# players es un Array de diccionarios, uno por asiento:
#   { seat = 1, user_id = 3, name = "Miguel", kind = "human", score = 34,
#     is_winner = true }
# user_id va a null si el asiento es una IA o un invitado sin cuenta.
# kind tiene que ser "human", "ai" o "network" (los de PlayerData.Type).
#
# Va todo en UNA sentencia con un CTE a proposito: si se hiciera en dos
# consultas y fallara la segunda, quedaria una partida sin jugadores.
func save_match(is_online: bool, max_rounds: int, deck_id, players: Array, callback: Callable) -> void:
	if players.is_empty():
		callback.call({ "ok": false, "error": "save_match sin jugadores" })
		return

	var params: Array = [is_online, max_rounds, deck_id]
	var tuples: PackedStringArray = []

	for p in players:
		# $1..$3 son los de la partida, los asientos empiezan en $4.
		var n := params.size()
		tuples.append("($%d::smallint, $%d::integer, $%d::text, $%d::text, $%d::integer, $%d::boolean)"
			% [n + 1, n + 2, n + 3, n + 4, n + 5, n + 6])
		params.append_array([
			p.get("seat"),
			p.get("user_id"),
			p.get("name"),
			p.get("kind", "human"),
			p.get("score"),
			p.get("is_winner", false),
		])

	var sql := """
		WITH nueva AS (
		    INSERT INTO matches (is_online, max_rounds, deck_id, ended_at)
		    VALUES ($1, $2, $3, now())
		    RETURNING id
		)
		INSERT INTO match_players (match_id, seat, user_id, name, kind, score, is_winner)
		SELECT nueva.id, v.seat, v.user_id, v.name, v.kind, v.score, v.is_winner
		  FROM nueva, (VALUES %s) AS v(seat, user_id, name, kind, score, is_winner)
		RETURNING match_id, seat, name, score, is_winner
	""" % ", ".join(tuples)

	query(sql, params, callback)


# Suma la partida al contador de victorias o derrotas del usuario.
func add_result(user_id: int, won: bool, callback: Callable) -> void:
	query("""
		UPDATE users
		   SET wins   = wins   + CASE WHEN $2 THEN 1 ELSE 0 END,
		       losses = losses + CASE WHEN $2 THEN 0 ELSE 1 END
		 WHERE id = $1 RETURNING wins, losses
	""", [user_id, won], callback)


# Historial: una fila por partida jugada, con el puesto del usuario y los
# demas asientos en "rivales" (un array JSON ya montado por Postgres).
func get_match_history(user_id: int, limit: int, callback: Callable) -> void:
	query("""
		SELECT m.id, m.is_online, m.deck_id, m.started_at, m.ended_at,
		       mp.seat, mp.score, mp.is_winner,
		       (SELECT json_agg(json_build_object(
		                   'seat', o.seat, 'name', o.name,
		                   'score', o.score, 'is_winner', o.is_winner)
		                ORDER BY o.seat)
		          FROM match_players o
		         WHERE o.match_id = m.id AND o.seat <> mp.seat) AS rivales
		  FROM match_players mp
		  JOIN matches m ON m.id = mp.match_id
		 WHERE mp.user_id = $1 AND m.ended_at IS NOT NULL
		 ORDER BY m.ended_at DESC
		 LIMIT $2
	""", [user_id, limit], callback)


# Todos los asientos de una partida concreta.
func get_match(match_id: int, callback: Callable) -> void:
	query("""
		SELECT seat, user_id, name, kind, score, is_winner
		  FROM match_players WHERE match_id = $1 ORDER BY seat
	""", [match_id], callback)


# En el Chinchon gana el que MENOS puntua, asi que la media va de menor a mayor.
func get_leaderboard(limit: int, callback: Callable) -> void:
	query("""
		SELECT u.id, u.username, u.name, u.wins, u.losses,
		       count(mp.*)      AS partidas,
		       round(avg(mp.score), 1) AS media_puntos
		  FROM users u
		  JOIN match_players mp ON mp.user_id = u.id
		 GROUP BY u.id
		 ORDER BY u.wins DESC, media_puntos ASC
		 LIMIT $1
	""", [limit], callback)


# ── Mensajes privados ───────────────────────────────────────────────────────

func send_message(sender_id: int, recipient_id: int, body: String, callback: Callable) -> void:
	query("""
		INSERT INTO messages (sender_id, recipient_id, body)
		VALUES ($1, $2, $3)
		RETURNING id, sent_at
	""", [sender_id, recipient_id, body], callback)


# La conversacion son los mensajes en los dos sentidos.
# El desempate por id importa: dos mensajes de la misma transaccion comparten
# sent_at, y sin el salen en orden arbitrario.
func get_conversation(user_id: int, other_id: int, limit: int, callback: Callable) -> void:
	query("""
		SELECT id, sender_id, recipient_id, body, sent_at, read_at
		  FROM messages
		 WHERE (sender_id = $1 AND recipient_id = $2)
		    OR (sender_id = $2 AND recipient_id = $1)
		 ORDER BY sent_at DESC, id DESC
		 LIMIT $3
	""", [user_id, other_id, limit], callback)


func mark_conversation_read(user_id: int, other_id: int, callback: Callable) -> void:
	query("""
		UPDATE messages SET read_at = now()
		 WHERE recipient_id = $1 AND sender_id = $2 AND read_at IS NULL
	""", [user_id, other_id], callback)


func get_unread_count(user_id: int, callback: Callable) -> void:
	query("""
		SELECT count(*)::int AS unread
		  FROM messages WHERE recipient_id = $1 AND read_at IS NULL
	""", [user_id], callback)


# ── Chats de grupo ──────────────────────────────────────────────────────────

# Crea el grupo y mete dentro al que lo crea, en la misma sentencia.
func create_group(name: String, owner_id: int, callback: Callable) -> void:
	query("""
		WITH nuevo AS (
		    INSERT INTO group_chats (name, owner_id) VALUES ($1, $2)
		    RETURNING id, name
		), dueno AS (
		    INSERT INTO group_members (chat_id, user_id, role)
		    SELECT id, $2, 'owner' FROM nuevo
		)
		SELECT id, name FROM nuevo
	""", [name, owner_id], callback)


func add_group_member(chat_id: int, user_id: int, callback: Callable) -> void:
	query("""
		INSERT INTO group_members (chat_id, user_id) VALUES ($1, $2)
		ON CONFLICT (chat_id, user_id) DO NOTHING
		RETURNING user_id
	""", [chat_id, user_id], callback)


func remove_group_member(chat_id: int, user_id: int, callback: Callable) -> void:
	query("DELETE FROM group_members WHERE chat_id = $1 AND user_id = $2",
		[chat_id, user_id], callback)


func get_group_members(chat_id: int, callback: Callable) -> void:
	query("""
		SELECT u.id, u.username, u.name, u.avatar_url, gm.role, gm.joined_at
		  FROM group_members gm
		  JOIN users u ON u.id = gm.user_id
		 WHERE gm.chat_id = $1
		 ORDER BY gm.joined_at
	""", [chat_id], callback)


# Los grupos del usuario con el ultimo mensaje de cada uno, para pintar la
# lista de chats. Mismo desempate por id que en get_conversation().
func get_user_groups(user_id: int, callback: Callable) -> void:
	query("""
		SELECT g.id, g.name, g.owner_id, gm.role,
		       (SELECT body FROM group_messages x
		         WHERE x.chat_id = g.id
		         ORDER BY x.sent_at DESC, x.id DESC LIMIT 1) AS ultimo_mensaje
		  FROM group_members gm
		  JOIN group_chats g ON g.id = gm.chat_id
		 WHERE gm.user_id = $1
		 ORDER BY g.name
	""", [user_id], callback)


# Solo deja escribir a quien esta en el grupo: si no es miembro, el SELECT no
# devuelve filas, no se inserta nada y rowCount se queda en 0.
func send_group_message(chat_id: int, sender_id: int, body: String, callback: Callable) -> void:
	query("""
		INSERT INTO group_messages (chat_id, sender_id, body)
		SELECT $1, $2, $3
		 WHERE EXISTS (SELECT 1 FROM group_members
		                WHERE chat_id = $1 AND user_id = $2)
		RETURNING id, sent_at
	""", [chat_id, sender_id, body], callback)


func get_group_messages(chat_id: int, limit: int, callback: Callable) -> void:
	query("""
		SELECT gm.id, gm.sender_id, u.username, u.name, gm.body, gm.sent_at
		  FROM group_messages gm
		  LEFT JOIN users u ON u.id = gm.sender_id
		 WHERE gm.chat_id = $1
		 ORDER BY gm.sent_at DESC, gm.id DESC
		 LIMIT $2
	""", [chat_id, limit], callback)
