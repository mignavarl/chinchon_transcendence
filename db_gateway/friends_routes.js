// Rutas REST de la lista de amigos.
//
// La tabla friends guarda filas dirigidas: (A, B) es "A tiene a B en su
// lista". Ver el comentario de db/init.sql para el por que.
//
// Metodos:
//   GET    /db/profile/me/friends            lista, con online/offline
//   POST   /db/profile/me/friends            anade por username
//   DELETE /db/profile/me/friends/:id        quita a uno
//   HEAD   /db/profile/me/friends/:id        200 lo tengo / 404 no

import { requireUser } from "./auth.js";

// Lo que pide la pantalla de perfil: "maximo 10 amigos". Cuando se llega al
// tope, profile.tscn ya tiene el Label $friends/max_friends para avisar.
const MAX_FRIENDS = 10;

// Se considera conectado si ha dado senales de vida hace menos de esto.
// Database.touch_last_seen() es lo que actualiza la columna.
//
// Va en segundos y como parametro de la consulta (make_interval), no pegado al
// string: asi en este fichero no hay ni un valor interpolado dentro de la SQL.
const ONLINE_WINDOW_SECONDS = 120;

// La lista, ya ordenada como se pinta: primero los conectados, y dentro de
// cada grupo por nombre.
//
// is_online sale de users.last_seen, no de una tabla de sesiones: si el
// navegador se cierra de golpe no queda nadie "conectado" para siempre.
const SQL_LIST = `
	SELECT u.id, u.username, u.name,
	       coalesce(u.avatar_url, $2) AS avatar_url,
	       u.wins, u.losses, u.last_seen, f.added_at,
	       (u.last_seen IS NOT NULL
	        AND u.last_seen > now() - make_interval(secs => $3)) AS is_online,
	       EXISTS (SELECT 1 FROM friends r
	                WHERE r.user_id = u.id AND r.friend_id = $1) AS is_mutual
	  FROM friends f
	  JOIN users u ON u.id = f.friend_id
	 WHERE f.user_id = $1
	 ORDER BY is_online DESC, lower(u.name), u.id
`;

export default async function friendsRoutes(app, options) {
	const { pool, defaultAvatarUrl } = options;
	const authed = { preHandler: requireUser(pool) };

	const fail = (reply, code, error, extra = {}) =>
		reply.code(code).send({ ok: false, error, ...extra });

	// El :id de las rutas viene de la URL, asi que hay que comprobar que es un
	// entero antes de usarlo como parametro.
	const parseId = (raw) => {
		const n = Number.parseInt(raw ?? "", 10);
		return Number.isSafeInteger(n) && n > 0 ? n : null;
	};

	// ── La lista ────────────────────────────────────────────────────────────
	app.get("/db/profile/me/friends", authed, async (req) => {
		const { rows, rowCount } = await pool.query(SQL_LIST, [
			req.userId,
			defaultAvatarUrl,
			ONLINE_WINDOW_SECONDS,
		]);
		return {
			ok: true,
			rows,
			rowCount,
			max_friends: MAX_FRIENDS,
			// Para que la pantalla no tenga que saber el tope: si esto es
			// true, toca ensenar $friends/max_friends.
			is_full: rowCount >= MAX_FRIENDS,
		};
	});

	// ── Anadir por nombre de usuario ────────────────────────────────────────
	//
	// Se anade por username y no por id porque es lo que se escribe en
	// $friends/VBoxContainer/line_friend: quien lo usa no sabe ningun id.
	app.post("/db/profile/me/friends", authed, async (req, reply) => {
		const wanted = typeof req.body?.username === "string" ? req.body.username.trim() : "";

		if (wanted.length === 0) {
			return fail(reply, 400, "hace falta el nombre del amigo");
		}
		if (wanted.toLowerCase() === req.username.toLowerCase()) {
			return fail(reply, 400, "no te puedes anadir a ti mismo");
		}

		// Se cuenta ANTES de insertar. No es una carrera perfecta (dos
		// peticiones a la vez podrian colarse en el 10), pero el tope es de
		// pantalla, no una regla de integridad: nadie se rompe por tener 11.
		const { rows: countRows } = await pool.query(
			"SELECT count(*)::int AS total FROM friends WHERE user_id = $1",
			[req.userId],
		);
		if (countRows[0].total >= MAX_FRIENDS) {
			return fail(reply, 409, `no se pueden tener mas de ${MAX_FRIENDS} amigos`, {
				is_full: true,
				max_friends: MAX_FRIENDS,
			});
		}

		// El INSERT ... SELECT resuelve el username y comprueba que existe en
		// la misma sentencia: si no hay nadie con ese nombre, no inserta y
		// rowCount se queda en 0. El lower() es para que "Miguel" y "miguel"
		// encuentren al mismo, igual que en el resto de rutas.
		const { rows, rowCount } = await pool.query(
			`INSERT INTO friends (user_id, friend_id)
			 SELECT $1, u.id
			   FROM users u
			  WHERE lower(u.username) = lower($2)
			    AND u.id <> $1
			 ON CONFLICT (user_id, friend_id) DO NOTHING
			 RETURNING friend_id`,
			[req.userId, wanted],
		);

		if (rowCount === 0) {
			// Puede ser que no exista, o que ya lo tuviera. Se distingue con
			// una consulta aparte para poder dar el mensaje correcto.
			const { rows: who } = await pool.query(
				"SELECT id FROM users WHERE lower(username) = lower($1)",
				[wanted],
			);
			if (who.length === 0) {
				return fail(reply, 404, `no hay ningun usuario que se llame '${wanted}'`);
			}
			return fail(reply, 409, `ya tienes a '${wanted}' en tu lista`);
		}

		// Se devuelve la ficha entera del recien anadido para que la pantalla
		// pueda pintar la fila sin volver a pedir la lista completa.
		const { rows: added } = await pool.query(
			`SELECT u.id, u.username, u.name,
			        coalesce(u.avatar_url, $2) AS avatar_url,
			        u.last_seen,
			        (u.last_seen IS NOT NULL
			         AND u.last_seen > now() - make_interval(secs => $4)) AS is_online,
			        EXISTS (SELECT 1 FROM friends r
			                 WHERE r.user_id = u.id AND r.friend_id = $3) AS is_mutual
			   FROM users u WHERE u.id = $1`,
			[rows[0].friend_id, defaultAvatarUrl, req.userId, ONLINE_WINDOW_SECONDS],
		);

		return reply.code(201).send({ ok: true, rows: added, rowCount: 1 });
	});

	// ── Lo tengo anadido? ───────────────────────────────────────────────────
	//
	// GET y HEAD en la misma ruta: en HEAD, Fastify tira el cuerpo y el
	// cliente se queda solo con el codigo.
	app.route({
		method: ["GET", "HEAD"],
		url: "/db/profile/me/friends/:id",
		preHandler: requireUser(pool),
		handler: async (req, reply) => {
			const id = parseId(req.params.id);
			if (id === null) {
				return fail(reply, 400, "el id del amigo tiene que ser un numero");
			}

			const { rows } = await pool.query(
				"SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2",
				[req.userId, id],
			);

			if (rows.length === 0) {
				return reply.code(404).send({ ok: true, is_friend: false });
			}
			return reply.code(200).send({ ok: true, is_friend: true });
		},
	});

	// ── Quitar ──────────────────────────────────────────────────────────────
	//
	// Solo borra la fila de quien llama: si el otro te tiene anadido, eso es
	// suyo y no se toca.
	app.delete("/db/profile/me/friends/:id", authed, async (req, reply) => {
		const id = parseId(req.params.id);
		if (id === null) {
			return fail(reply, 400, "el id del amigo tiene que ser un numero");
		}

		const { rowCount } = await pool.query(
			"DELETE FROM friends WHERE user_id = $1 AND friend_id = $2",
			[req.userId, id],
		);

		if (rowCount === 0) {
			return fail(reply, 404, "ese usuario no esta en tu lista");
		}

		// 204: borrado hecho, no hay cuerpo que devolver.
		return reply.code(204).send();
	});
}
