// Rutas REST del juego: la ficha corta del usuario, sus barajas, el gachapon
// y guardar una partida offline.
//
// Sustituyen a lo que antes hacia el juego mandando SQL en crudo a /db/query.
// Aqui la SQL esta escrita en el servidor, de fuera solo llegan valores por
// $1, $2..., y todas piden token: el usuario sale del token, nunca del cuerpo.
//
// Metodos:
//   GET    /db/me                 id, nombre, avatar, monedas, baraja...
//   GET    /db/me/decks           barajas que tiene (la inicial siempre)
//   POST   /db/me/gacha           gasta 1 moneda y da una baraja que no tenga
//   POST   /db/matches            guarda una partida offline del que llama
//
// Las partidas ONLINE no pasan por aqui: las guarda el backend de Spring al
// recibir "match_result" por el WebSocket, porque es el unico que sabe quien
// estaba de verdad en la sala.

import { randomInt } from "node:crypto";

import { requireUser } from "./auth.js";

// Probabilidad de cada rareza en el gachapon, la misma que tenia bazar.gd
// (50 / 25 / 18 / 7). Si una rareza ya esta completa se reparte su parte
// entre las demas, que es lo que hacia el cliente al volver a tirar.
const GACHA_WEIGHTS = [
	["common", 50],
	["uncommon", 25],
	["rare", 18],
	["legendary", 7],
];

// Lo que admite match_players: seat 1..4 y kind human/ai/network.
const MIN_SEATS = 2;
const MAX_SEATS = 4;
const NAME_MAX = 32;
const POINTS_MAX = 10000;

const SQL_ME = `
	SELECT id, username, name,
	       coalesce(avatar_url, $2) AS avatar_url,
	       avatar_url IS NULL       AS avatar_is_default,
	       coins, deck_selected, wins, losses
	  FROM users
	 WHERE id = $1
`;

// La baraja inicial (rarity 'first') la tiene todo el mundo aunque no haya
// fila en user_decks, igual que first.gd la metia siempre en my_decks.
const SQL_DECKS = `
	SELECT d.id, d.name, d.rarity, ud.obtained_at
	  FROM decks d
	  LEFT JOIN user_decks ud ON ud.deck_id = d.id AND ud.user_id = $1
	 WHERE d.rarity = 'first' OR ud.user_id IS NOT NULL
	 ORDER BY ud.obtained_at NULLS FIRST, d.id
`;

// Elige rareza con los pesos de arriba, solo entre las que aun tienen algo
// que dar. available es un Set de rarezas.
function pickRarity(available) {
	const pool = GACHA_WEIGHTS.filter(([rarity]) => available.has(rarity));
	const total = pool.reduce((sum, [, w]) => sum + w, 0);
	let roll = randomInt(total);
	for (const [rarity, w] of pool) {
		if (roll < w) {
			return rarity;
		}
		roll -= w;
	}
	return pool[pool.length - 1][0];
}

const isInt = (v, min, max) => Number.isSafeInteger(v) && v >= min && v <= max;

// Comprueba el cuerpo de POST /db/matches. Devuelve el mensaje de error, o
// null si vale.
function validateMatch(body) {
	if (body === null || typeof body !== "object") {
		return "falta el cuerpo";
	}
	if (!isInt(body.max_points, 1, POINTS_MAX)) {
		return "'max_points' tiene que ser un entero positivo";
	}
	if (body.deck_id !== undefined && body.deck_id !== null && typeof body.deck_id !== "string") {
		return "'deck_id' tiene que ser un texto";
	}

	const players = body.players;
	if (!Array.isArray(players) || players.length < MIN_SEATS || players.length > MAX_SEATS) {
		return `'players' tiene que traer de ${MIN_SEATS} a ${MAX_SEATS} asientos`;
	}

	let mine = 0;
	let winners = 0;
	for (const p of players) {
		if (p === null || typeof p !== "object") {
			return "cada asiento tiene que ser un objeto";
		}
		if (typeof p.name !== "string" || p.name.trim().length === 0 || p.name.length > NAME_MAX) {
			return `cada asiento necesita un 'name' de 1 a ${NAME_MAX} caracteres`;
		}
		// Offline solo hay un humano (el que llama) y bots. "network" no tiene
		// sentido aqui: esas partidas las guarda el backend.
		if (p.kind !== "human" && p.kind !== "ai") {
			return "'kind' tiene que ser 'human' o 'ai'";
		}
		if (!isInt(p.score, -POINTS_MAX, POINTS_MAX)) {
			return "'score' tiene que ser un entero";
		}
		if (typeof p.is_winner !== "boolean") {
			return "'is_winner' tiene que ser true o false";
		}
		if (p.is_me === true) {
			if (p.kind !== "human") {
				return "el asiento propio tiene que ser 'human'";
			}
			mine += 1;
		}
		if (p.is_winner) {
			winners += 1;
		}
	}

	if (mine !== 1) {
		return "tiene que haber exactamente un asiento con 'is_me'";
	}
	if (winners === 0) {
		return "tiene que haber al menos un ganador";
	}
	return null;
}

export default async function gameRoutes(app, options) {
	const { pool, defaultAvatarUrl } = options;
	const authed = { preHandler: requireUser(pool) };

	const fail = (reply, code, error, extra = {}) =>
		reply.code(code).send({ ok: false, error, ...extra });

	// ── Ficha corta ─────────────────────────────────────────────────────────
	//
	// Lo que hace falta al entrar y en los menus. La ficha completa con
	// estadisticas es /db/profile/me, que es mucho mas cara.
	app.get("/db/me", authed, async (req, reply) => {
		const { rows, rowCount } = await pool.query(SQL_ME, [req.userId, defaultAvatarUrl]);
		if (rowCount === 0) {
			return fail(reply, 404, "no se encontro el usuario");
		}
		return { ok: true, rows, rowCount };
	});

	// ── Barajas que tiene ───────────────────────────────────────────────────
	app.get("/db/me/decks", authed, async (req) => {
		const { rows, rowCount } = await pool.query(SQL_DECKS, [req.userId]);
		return { ok: true, rows, rowCount };
	});

	// ── Gachapon ────────────────────────────────────────────────────────────
	//
	// El sorteo se hace aqui y no en el cliente: si lo hiciera el cliente,
	// cualquiera podria pedir la baraja que quisiera o no pagar la moneda.
	//
	// Todo va en una transaccion con la fila del usuario bloqueada (FOR
	// UPDATE): dos tiradas a la vez con una sola moneda no pueden dar dos
	// barajas. La segunda espera a la primera y ya ve 0 monedas.
	app.post("/db/me/gacha", authed, async (req, reply) => {
		const client = await pool.connect();
		try {
			await client.query("BEGIN");

			const { rows: userRows } = await client.query(
				"SELECT coins FROM users WHERE id = $1 FOR UPDATE",
				[req.userId],
			);
			if (userRows.length === 0) {
				await client.query("ROLLBACK");
				return fail(reply, 404, "no se encontro el usuario");
			}
			if (userRows[0].coins < 1) {
				await client.query("ROLLBACK");
				return fail(reply, 409, "no te quedan monedas", { reason: "no_coins" });
			}

			const { rows: unowned } = await client.query(
				`SELECT d.id, d.name, d.rarity
				   FROM decks d
				  WHERE d.rarity <> 'first'
				    AND NOT EXISTS (SELECT 1 FROM user_decks ud
				                     WHERE ud.user_id = $1 AND ud.deck_id = d.id)`,
				[req.userId],
			);
			if (unowned.length === 0) {
				await client.query("ROLLBACK");
				return fail(reply, 409, "ya tienes todas las barajas", { reason: "all_owned" });
			}

			const rarity = pickRarity(new Set(unowned.map((d) => d.rarity)));
			const candidates = unowned.filter((d) => d.rarity === rarity);
			const deck = candidates[randomInt(candidates.length)];

			await client.query(
				"INSERT INTO user_decks (user_id, deck_id) VALUES ($1, $2)",
				[req.userId, deck.id],
			);
			const { rows: after } = await client.query(
				"UPDATE users SET coins = coins - 1 WHERE id = $1 RETURNING coins",
				[req.userId],
			);

			await client.query("COMMIT");
			return {
				ok: true,
				rows: [{ deck_id: deck.id, name: deck.name, rarity: deck.rarity, coins: after[0].coins }],
				rowCount: 1,
			};
		} catch (err) {
			await client.query("ROLLBACK").catch(() => {});
			throw err;
		} finally {
			client.release();
		}
	});

	// ── Guardar una partida offline ─────────────────────────────────────────
	//
	// El unico asiento con usuario es el que llama (is_me), y su id sale del
	// token: el cliente no puede apuntar partidas a nombre de otros. Los demas
	// asientos son bots y se guardan sin usuario.
	//
	// Partida, asientos y victoria/derrota van en la misma transaccion: o se
	// guarda todo o nada.
	app.post("/db/matches", authed, async (req, reply) => {
		const body = req.body ?? null;
		const invalid = validateMatch(body);
		if (invalid !== null) {
			return fail(reply, 400, invalid);
		}

		// Una baraja que no esta en el catalogo se guarda como null en vez de
		// rechazar la partida entera: es solo un dato del historial, y perder
		// la partida por eso seria peor. Igual que hace el backend online.
		let deckId = body.deck_id ?? null;
		if (deckId !== null) {
			const { rowCount } = await pool.query("SELECT 1 FROM decks WHERE id = $1", [deckId]);
			if (rowCount === 0) {
				deckId = null;
			}
		}

		const client = await pool.connect();
		try {
			await client.query("BEGIN");

			const { rows: matchRows } = await client.query(
				`INSERT INTO matches (is_online, max_points, deck_id, ended_at)
				 VALUES (false, $1, $2, now())
				 RETURNING id`,
				[body.max_points, deckId],
			);
			const matchId = matchRows[0].id;

			let won = false;
			for (const [i, p] of body.players.entries()) {
				const mine = p.is_me === true;
				if (mine) {
					won = p.is_winner;
				}
				await client.query(
					`INSERT INTO match_players (match_id, seat, user_id, name, kind, score, is_winner)
					 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
					[matchId, i + 1, mine ? req.userId : null, p.name.trim(), p.kind, p.score, p.is_winner],
				);
			}

			await client.query(
				`UPDATE users
				    SET wins   = wins   + CASE WHEN $2 THEN 1 ELSE 0 END,
				        losses = losses + CASE WHEN $2 THEN 0 ELSE 1 END,
				        coins  = coins  + CASE WHEN $2 THEN 1 ELSE 0 END
				  WHERE id = $1`,
				[req.userId, won],
			);

			await client.query("COMMIT");
			return reply.code(201).send({ ok: true, rows: [{ match_id: matchId }], rowCount: 1 });
		} catch (err) {
			await client.query("ROLLBACK").catch(() => {});
			throw err;
		} finally {
			client.release();
		}
	});
}
