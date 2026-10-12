// Rutas REST del ranking.
//
// La clasificacion sale de users.wins / users.losses, que ya mantienen al dia
// las dos formas de guardar partida: POST /db/matches (offline, game_routes.js)
// y MatchService del backend (online). No se recalcula desde match_players
// para no recorrer todo el historial cada vez que alguien abre el perfil.
//
// Metodos:
//   GET    /db/ranking?scope=&limit=      top N + la posicion de quien llama
//
//   scope=global   (por defecto) todos los usuarios con alguna partida
//   scope=friends  solo los de tu lista de amigos y tu
//
// Respuesta:
//   rows          el top, ya ordenado
//   me            tu fila aunque estes fuera del top, o null si aun no has
//                 jugado ninguna partida (sin partidas no se entra al ranking)
//   total_ranked  cuantos hay clasificados, para pintar "puesto 7 de 42"

import { requireUser } from "./auth.js";

const RANKING_LIMIT_DEFAULT = 10;
const RANKING_LIMIT_MAX = 100;

const SCOPES = new Set(["global", "friends"]);

// Orden: mas victorias primero y, a igualdad, menos derrotas (el mismo numero
// de victorias en menos partidas vale mas). Se usa rank() y no row_number()
// para que dos empatados de verdad compartan puesto: 1, 2, 2, 4...
//
// pos es solo para cortar el top en N filas exactas aunque haya empates, y
// el lower(name), user_id del final es para que ese corte sea estable.
//
// $4 decide si se filtra por amigos. Va como parametro y no montando la SQL
// con un if, para que la consulta sea siempre la misma y no haya nada
// pegado al string. Los ::int son por lo mismo que en profile_routes.js:
// rank() y count() devuelven bigint y llegarian como string al cliente.
const SQL_RANKING = `
	WITH clasif AS (
	    SELECT u.id AS user_id, u.username, u.name,
	           coalesce(u.avatar_url, $1) AS avatar_url,
	           u.wins, u.losses,
	           (u.wins + u.losses)::int AS games_played,
	           round(100.0 * u.wins / (u.wins + u.losses), 1)::float8 AS win_rate,
	           rank() OVER (ORDER BY u.wins DESC, u.losses ASC)::int AS position,
	           row_number() OVER (ORDER BY u.wins DESC, u.losses ASC,
	                                       lower(u.name), u.id)::int AS pos,
	           count(*) OVER ()::int AS total_ranked
	      FROM users u
	     WHERE u.wins + u.losses > 0
	       AND (NOT $4::boolean
	            OR u.id = $2
	            OR EXISTS (SELECT 1 FROM friends f
	                        WHERE f.user_id = $2 AND f.friend_id = u.id))
	)
	SELECT user_id, username, name, avatar_url,
	       wins, losses, games_played, win_rate,
	       position, pos, total_ranked,
	       user_id = $2 AS is_me
	  FROM clasif
	 WHERE pos <= $3 OR user_id = $2
	 ORDER BY pos
`;

// Igual que parseLimit de profile_routes.js: si llega basura, el de por
// defecto; si se pasa, el maximo.
function parseLimit(raw) {
	const n = Number.parseInt(raw ?? "", 10);
	if (!Number.isFinite(n) || n <= 0) {
		return RANKING_LIMIT_DEFAULT;
	}
	return Math.min(n, RANKING_LIMIT_MAX);
}

export default async function rankingRoutes(app, options) {
	const { pool, defaultAvatarUrl } = options;
	const authed = { preHandler: requireUser(pool) };

	const fail = (reply, code, error) => reply.code(code).send({ ok: false, error });

	// ── Clasificacion ───────────────────────────────────────────────────────
	//
	// Una sola consulta trae el top y tu fila: si estas dentro del top vienes
	// en rows con is_me = true; si no, la consulta te devuelve igualmente y
	// aqui se separa para mandarte solo en "me".
	app.get("/db/ranking", authed, async (req, reply) => {
		const scope = req.query.scope ?? "global";
		if (!SCOPES.has(scope)) {
			return fail(reply, 400, "'scope' tiene que ser 'global' o 'friends'");
		}
		const limit = parseLimit(req.query.limit);

		const { rows: all } = await pool.query(SQL_RANKING, [
			defaultAvatarUrl,
			req.userId,
			limit,
			scope === "friends",
		]);

		const me = all.find((r) => r.is_me) ?? null;
		const rows = all.filter((r) => r.pos <= limit);
		for (const r of all) {
			delete r.pos;
		}

		return {
			ok: true,
			rows,
			rowCount: rows.length,
			me,
			total_ranked: all[0]?.total_ranked ?? 0,
			scope,
			limit,
		};
	});
}
