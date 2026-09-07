// Rutas REST del perfil.
//
// A diferencia de /db/query, que recibe SQL desde el navegador, aqui la SQL
// esta escrita en este fichero y lo unico que llega de fuera son los valores,
// siempre por $1, $2... Ademas todas las rutas /me piden token.
//
// Las consultas grandes (stats e historial) son las mismas que ya estaban en
// game_godot/src/network/database.gd: get_user_stats() y get_match_history().
// Si hay que tocarlas, tocarlas en los dos sitios o dejar solo este.
//
// Metodos:
//   GET    /db/profile/me                  ficha + estadisticas
//   PATCH  /db/profile/me                  cambia solo los campos que llegan
//   POST   /db/profile/me/username         renombrar (comprueba que este libre)
//   PUT    /db/profile/me/avatar           pone un avatar del catalogo
//   DELETE /db/profile/me/avatar           lo deja por defecto
//   GET    /db/profile/me/history?limit=   ultimas partidas
//   GET    /db/profile/avatars             catalogo (publico)
//   HEAD   /db/profile/username/:name      200 cogido / 404 libre

import { requireUser } from "./auth.js";
import { AVATARS, AVATAR_BY_ID, DEFAULT_AVATAR_URL } from "./avatars.js";

const USERNAME_RE = /^[A-Za-z0-9_-]{3,20}$/;
const NAME_MAX = 32;

const HISTORY_LIMIT_DEFAULT = 10;
const HISTORY_LIMIT_MAX = 50;

// Copiada de Database.get_user_stats(). Devuelve SIEMPRE una fila: si el
// usuario no ha jugado nada, los contadores van a 0.
//
// Los ::int y ::float8 no son decorado: count() y sum() devuelven bigint, y
// round(avg(...)) devuelve numeric, y node-postgres manda los dos como STRING
// en el JSON (para no perder precision en JS). Sin el cast, al cliente le
// llegaria "3" en vez de 3 y en GDScript habria que hacer int() a cada campo.
// Es el mismo truco que ya usaba Database.get_unread_count() con count(*)::int.
const SQL_STATS = `
	WITH historial AS (
	    SELECT m.id, m.is_online, m.deck_id, m.ended_at,
	           mp.score, mp.is_winner
	      FROM match_players mp
	      JOIN matches m ON m.id = mp.match_id
	     WHERE mp.user_id = $1 AND m.ended_at IS NOT NULL
	),
	totales AS (
	    SELECT count(*)::int                              AS games_played,
	           count(*) FILTER (WHERE is_winner)::int     AS games_won,
	           count(*) FILTER (WHERE NOT is_winner)::int AS games_lost,
	           count(*) FILTER (WHERE is_online)::int     AS online_games,
	           count(*) FILTER (WHERE NOT is_online)::int AS offline_games,
	           min(score)                                 AS best_score,
	           max(score)                                 AS worst_score,
	           round(avg(score), 1)::float8               AS avg_score,
	           coalesce(sum(score), 0)::int               AS total_points,
	           min(ended_at)                              AS first_played,
	           max(ended_at)                              AS last_played
	      FROM historial
	),
	numeradas AS (
	    SELECT is_winner,
	           row_number() OVER (ORDER BY ended_at DESC, id DESC) AS pos,
	           row_number() OVER (PARTITION BY is_winner
	                              ORDER BY ended_at DESC, id DESC) AS pos_tipo
	      FROM historial
	),
	racha_actual AS (
	    SELECT count(*)::int      AS current_streak,
	           bool_or(is_winner) AS streak_is_win
	      FROM numeradas
	     WHERE pos = pos_tipo
	),
	tramos AS (
	    SELECT is_winner,
	           row_number() OVER (ORDER BY ended_at, id)
	             - row_number() OVER (PARTITION BY is_winner
	                                  ORDER BY ended_at, id) AS tramo
	      FROM historial
	),
	mejor_racha AS (
	    SELECT coalesce(max(largo), 0)::int AS longest_win_streak
	      FROM (SELECT count(*) AS largo
	              FROM tramos WHERE is_winner GROUP BY tramo) t
	),
	baraja AS (
	    SELECT deck_id AS favourite_deck
	      FROM historial
	     WHERE deck_id IS NOT NULL
	     GROUP BY deck_id
	     ORDER BY count(*) DESC, deck_id
	     LIMIT 1
	)
	SELECT u.id AS user_id, u.username, u.name,
	       coalesce(u.avatar_url, $2) AS avatar_url,
	       u.avatar_url IS NULL       AS avatar_is_default,
	       u.coins, u.deck_selected, u.created_at, u.last_seen,
	       u.wins, u.losses,
	       t.games_played, t.games_won, t.games_lost,
	       t.online_games, t.offline_games,
	       CASE WHEN t.games_played = 0 THEN 0
	            ELSE round(100.0 * t.games_won / t.games_played, 1)
	       END::float8 AS win_rate,
	       t.best_score, t.worst_score, t.avg_score, t.total_points,
	       t.first_played, t.last_played,
	       coalesce(r.current_streak, 0)    AS current_streak,
	       coalesce(r.streak_is_win, false) AS streak_is_win,
	       ml.longest_win_streak,
	       b.favourite_deck,
	       (SELECT count(*)::int FROM user_decks ud WHERE ud.user_id = u.id)
	           AS decks_owned
	  FROM users u
	  LEFT JOIN totales      t  ON true
	  LEFT JOIN racha_actual r  ON true
	  LEFT JOIN mejor_racha  ml ON true
	  LEFT JOIN baraja       b  ON true
	 WHERE u.id = $1
`;

// Copiada de Database.get_match_history(). "rivales" es un array JSON que
// monta Postgres con los demas asientos de la partida.
const SQL_HISTORY = `
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
`;

// Recorta el limit a un rango sano. Nunca se pega al string de la SQL: va
// como parametro, pero si llega basura mejor un numero que un NaN.
function parseLimit(raw) {
	const n = Number.parseInt(raw ?? "", 10);
	if (!Number.isFinite(n) || n <= 0) {
		return HISTORY_LIMIT_DEFAULT;
	}
	return Math.min(n, HISTORY_LIMIT_MAX);
}

export default async function profileRoutes(app, options) {
	const { pool } = options;
	const authed = { preHandler: requireUser(pool) };

	const fail = (reply, code, error) => reply.code(code).send({ ok: false, error });

	// ── Catalogo de avatares (publico) ──────────────────────────────────────
	//
	// Sin token: son rutas de texturas que ya vienen dentro del juego, no hay
	// nada privado que ensenar.
	app.get("/db/profile/avatars", async () => ({
		ok: true,
		rows: AVATARS,
		rowCount: AVATARS.length,
		default_avatar_url: DEFAULT_AVATAR_URL,
	}));

	// ── Esta cogido el nombre? ──────────────────────────────────────────────
	//
	// GET y HEAD comparten handler: en el HEAD, Fastify manda las cabeceras y
	// tira el cuerpo, asi que el cliente solo mira el codigo (200 cogido,
	// 404 libre) y no tiene que parsear nada.
	app.route({
		method: ["GET", "HEAD"],
		url: "/db/profile/username/:name",
		handler: async (req, reply) => {
			const name = req.params.name ?? "";

			if (!USERNAME_RE.test(name)) {
				// No es que este libre: es que no vale como nombre.
				return fail(reply, 400, "el nombre debe tener 3-20 caracteres (letras, numeros, - o _)");
			}

			const { rows } = await pool.query(
				"SELECT 1 FROM users WHERE lower(username) = lower($1)",
				[name],
			);

			if (rows.length > 0) {
				return reply.code(200).send({ ok: true, taken: true });
			}
			return reply.code(404).send({ ok: true, taken: false });
		},
	});

	// ── Ficha del usuario que llama ─────────────────────────────────────────
	app.get("/db/profile/me", authed, async (req, reply) => {
		const { rows, rowCount } = await pool.query(SQL_STATS, [req.userId, DEFAULT_AVATAR_URL]);

		if (rowCount === 0) {
			// requireUser ya comprobo que la fila existe, asi que llegar aqui
			// significa que se borro entre las dos consultas.
			return fail(reply, 404, "no se encontro el perfil");
		}

		return { ok: true, rows, rowCount };
	});

	// ── Historial de partidas ───────────────────────────────────────────────
	app.get("/db/profile/me/history", authed, async (req) => {
		const limit = parseLimit(req.query.limit);
		const { rows, rowCount } = await pool.query(SQL_HISTORY, [req.userId, limit]);
		return { ok: true, rows, rowCount, limit };
	});

	// ── Cambio parcial: solo lo que venga en el cuerpo ──────────────────────
	//
	// La gracia del PATCH es esta: mandar {"name": "x"} NO puede dejar el
	// avatar en blanco. Por eso el SET se monta con las claves que llegan y
	// las que no llegan no se mencionan.
	app.patch("/db/profile/me", authed, async (req, reply) => {
		const body = req.body ?? {};
		const sets = [];
		const params = [req.userId];

		if ("name" in body) {
			const name = typeof body.name === "string" ? body.name.trim() : "";
			if (name.length === 0) {
				return fail(reply, 400, "el nombre no puede estar vacio");
			}
			if (name.length > NAME_MAX) {
				return fail(reply, 400, `el nombre no puede pasar de ${NAME_MAX} caracteres`);
			}
			params.push(name);
			sets.push(`name = $${params.length}`);
		}

		if ("avatar" in body) {
			// null explicito = volver al de por defecto.
			if (body.avatar === null) {
				sets.push("avatar_url = NULL");
			} else {
				const avatar = AVATAR_BY_ID.get(body.avatar);
				if (avatar === undefined) {
					return fail(reply, 400, "ese avatar no esta en el catalogo");
				}
				params.push(avatar.url);
				sets.push(`avatar_url = $${params.length}`);
			}
		}

		if (sets.length === 0) {
			return fail(reply, 400, "no hay nada que cambiar: se esperaba 'name' y/o 'avatar'");
		}

		// El SET se monta con los nombres de columna de arriba (fijos, escritos
		// aqui), nunca con nada que venga del cuerpo: lo de fuera va siempre por
		// $n. El avatar por defecto tambien va como parametro, no pegado al
		// string, para que en este fichero no haya ni un valor interpolado.
		params.push(DEFAULT_AVATAR_URL);
		const { rows, rowCount } = await pool.query(
			`UPDATE users SET ${sets.join(", ")}
			  WHERE id = $1
			 RETURNING id, username, name,
			           coalesce(avatar_url, $${params.length}) AS avatar_url,
			           avatar_url IS NULL AS avatar_is_default`,
			params,
		);

		return { ok: true, rows, rowCount };
	});

	// ── Renombrar ───────────────────────────────────────────────────────────
	//
	// Va aparte del PATCH porque no es "un campo mas": el username es con lo
	// que se hace login y lo que lleva dentro el token, asi que al cambiarlo
	// el token en curso se queda apuntando a un nombre que ya no existe.
	//
	// Es POST y no PUT porque tiene una comprobacion propia (que este libre) y
	// puede fallar con 409 aunque el cuerpo sea identico al de antes.
	app.post("/db/profile/me/username", authed, async (req, reply) => {
		const wanted = typeof req.body?.username === "string" ? req.body.username.trim() : "";

		if (!USERNAME_RE.test(wanted)) {
			return fail(reply, 400, "el nombre debe tener 3-20 caracteres (letras, numeros, - o _)");
		}
		// Pedir el nombre que ya tienes no es un error, pero tampoco hay que
		// hacer nada: se contesta que si y se avisa de que no cambio, para que
		// la pantalla no mande a nadie a volver a iniciar sesion por gusto.
		// Cambiar solo mayusculas (miguel -> Miguel) SI pasa de aqui: el
		// "id <> $1" del NOT EXISTS evita que choque contigo mismo.
		if (wanted === req.username) {
			return {
				ok: true,
				rows: [{ id: req.userId, username: req.username }],
				rowCount: 0,
				unchanged: true,
			};
		}

		// El WHERE NOT EXISTS hace de comprobacion y de reserva en la misma
		// sentencia: si otro lo pilla a la vez, aqui rowCount se queda en 0.
		// El UNIQUE de la columna es la ultima red por si acaso.
		let result;
		try {
			result = await pool.query(
				`UPDATE users SET username = $2
				  WHERE id = $1
				    AND NOT EXISTS (
				        SELECT 1 FROM users
				         WHERE lower(username) = lower($2) AND id <> $1
				    )
				 RETURNING id, username, name`,
				[req.userId, wanted],
			);
		} catch (err) {
			if (err.code === "23505") {
				return fail(reply, 409, "ese nombre de usuario ya esta cogido");
			}
			throw err;
		}

		if (result.rowCount === 0) {
			return fail(reply, 409, "ese nombre de usuario ya esta cogido");
		}

		// El token viejo lleva el username anterior en "sub", asi que a partir
		// de ahora no vale: requireUser no encontraria la fila.
		return {
			ok: true,
			rows: result.rows,
			rowCount: result.rowCount,
			reauth_required: true,
		};
	});

	// ── Avatar: reemplazo entero ────────────────────────────────────────────
	//
	// PUT y no PATCH porque el avatar es un solo valor: lo que se manda pasa a
	// ser el estado completo del recurso, y repetir la misma llamada deja lo
	// mismo (idempotente).
	app.put("/db/profile/me/avatar", authed, async (req, reply) => {
		const id = req.body?.avatar;
		const avatar = AVATAR_BY_ID.get(id);

		if (avatar === undefined) {
			return fail(reply, 400, "ese avatar no esta en el catalogo");
		}

		const { rows, rowCount } = await pool.query(
			`UPDATE users SET avatar_url = $2
			  WHERE id = $1
			 RETURNING id, username, avatar_url, false AS avatar_is_default`,
			[req.userId, avatar.url],
		);

		return { ok: true, rows, rowCount };
	});

	// ── Avatar: volver al de por defecto ────────────────────────────────────
	//
	// Deja la columna a NULL en vez de escribir la ruta del avatar por
	// defecto: asi "no ha elegido ninguno" y "eligio justo el primero" siguen
	// siendo distinguibles, y si algun dia cambia el de por defecto, cambia
	// para todos los que no eligieron.
	app.delete("/db/profile/me/avatar", authed, async (req, reply) => {
		await pool.query("UPDATE users SET avatar_url = NULL WHERE id = $1", [req.userId]);
		// 204: borrado hecho, no hay cuerpo que devolver.
		return reply.code(204).send();
	});
}
