// Pruebas de punta a punta contra el stack levantado con `make`.
//
//   cd tests && npm install
//   node tests/e2e.mjs <seccion>      (o "all" para todas)
//
// Secciones: rawsql me decks gacha matches avatar wsauth wsidentity wsmatch
//            wsclose ports
//
// Todo va por nginx (https://localhost:9443), como iria el navegador. Para
// comprobar lo que queda escrito se mira la base de datos directamente con
// `docker exec <postgres> psql`. Cada ejecucion crea usuarios nuevos, asi que
// se puede repetir sin limpiar nada.
//
// Si todo va bien imprime "E2E <seccion> PASSED" y sale con 0. Al primer
// fallo imprime el motivo y sale con 1.

import { execFileSync } from "node:child_process";
import { createHmac, randomBytes } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

import WebSocket from "ws";

// Certificado autofirmado: en estas pruebas no se valida.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
process.removeAllListeners("warning");

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE = process.env.E2E_BASE ?? "https://localhost:9443";
const WS_URL = BASE.replace(/^http/, "ws") + "/ws/game";
const PG_CONTAINER = process.env.E2E_PG_CONTAINER ?? "transcendence_postgres";
const JWT_SECRET = process.env.JWT_SECRET ?? "change-in-production-change-in-production";

const env = Object.fromEntries(
	readFileSync(path.join(ROOT, ".env"), "utf8")
		.split("\n")
		.filter((l) => /^[A-Z_]+=/.test(l))
		.map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1).trim()]),
);

// ── utilidades ──────────────────────────────────────────────────────────────

class Failure extends Error {}

function check(cond, message) {
	if (!cond) {
		throw new Failure(message);
	}
}

function eq(actual, expected, message) {
	const a = JSON.stringify(actual);
	const e = JSON.stringify(expected);
	check(a === e, `${message}: esperaba ${e}, llego ${a}`);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Lanza SQL contra Postgres y devuelve las filas como arrays de strings.
// Solo la usa la prueba: el juego ya no puede hacer esto.
function psql(sql) {
	const out = execFileSync("docker", [
		"exec", "-i", PG_CONTAINER,
		"psql", "-U", env.POSTGRES_USER, "-d", env.POSTGRES_DB,
		"-v", "ON_ERROR_STOP=1", "-tA", "-F", "\t", "-c", sql,
	], { encoding: "utf8" });
	return out.split("\n").filter((l) => l.length > 0).map((l) => l.split("\t"));
}

const lit = (s) => `'${String(s).replaceAll("'", "''")}'`;

async function api(method, route, { token, body, raw, contentType } = {}) {
	const headers = {};
	if (token) {
		headers.Authorization = `Bearer ${token}`;
	}
	let payload;
	if (raw !== undefined) {
		payload = raw;
		headers["Content-Type"] = contentType;
	} else if (body !== undefined) {
		payload = JSON.stringify(body);
		headers["Content-Type"] = "application/json";
	}
	const res = await fetch(BASE + route, { method, headers, body: payload });
	const buf = Buffer.from(await res.arrayBuffer());
	let json = null;
	try {
		json = JSON.parse(buf.toString("utf8"));
	} catch {
		// no es JSON
	}
	return { status: res.status, json, buf, headers: res.headers };
}

let counter = 0;
function freshName() {
	counter += 1;
	return `e2e${Date.now().toString(36)}${randomBytes(2).toString("hex")}${counter}`.slice(0, 20);
}

// Crea una cuenta por /api/auth (Spring) y devuelve { username, token, id }.
async function newUser() {
	const username = freshName();
	const password = "pw-" + randomBytes(6).toString("hex");
	const s = await api("POST", "/api/auth/signup", { body: { username, password } });
	eq(s.status, 200, `signup de ${username}`);
	const l = await api("POST", "/api/auth/login", { body: { username, password } });
	eq(l.status, 200, `login de ${username}`);
	const token = l.json?.token;
	check(typeof token === "string" && token.length > 0, "el login no devolvio token");
	const [[id]] = psql(`SELECT id FROM users WHERE username = ${lit(username)}`);
	return { username, token, id: Number(id) };
}

// Un JWT con el formato de Spring pero firmado con otra clave.
function forgedToken(sub, secret = "otra-clave-que-no-es-la-buena-para-nada") {
	const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
	const head = b64({ alg: "HS256" });
	const body = b64({ sub, exp: Math.floor(Date.now() / 1000) + 3600 });
	const key = Buffer.from(Buffer.from(secret).toString("base64"));
	const sig = createHmac("sha256", key).update(`${head}.${body}`).digest("base64url");
	return `${head}.${body}.${sig}`;
}

// Un PNG de 1x1 valido.
const PNG_1x1 = Buffer.from(
	"89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da63f8cfc0f01f0005000201a3b1d5bd0000000049454e44ae426082",
	"hex",
);

// ── WebSocket ───────────────────────────────────────────────────────────────

// Abre una conexion. Resuelve con { ws, inbox, protocol } o rechaza con el
// codigo HTTP si el servidor no la acepta.
function wsOpen(protocols) {
	return new Promise((resolve, reject) => {
		const ws = new WebSocket(WS_URL, protocols, { rejectUnauthorized: false });
		const inbox = [];
		ws.on("message", (data) => inbox.push(JSON.parse(data.toString())));
		ws.once("open", () => resolve({ ws, inbox, protocol: ws.protocol }));
		ws.once("unexpected-response", (_req, res) => reject(Object.assign(new Error("refused"), { status: res.statusCode })));
		ws.once("error", (err) => reject(err));
	});
}

const wsAs = (user) => wsOpen(["chinchon.v1", `bearer.${user.token}`]);

const wsSend = (c, msg) => c.ws.send(JSON.stringify(msg));

// Espera al primer mensaje del buzon que cumpla pred y lo saca del buzon.
async function wsWait(c, pred, what, ms = 4000) {
	const until = Date.now() + ms;
	while (Date.now() < until) {
		const i = c.inbox.findIndex(pred);
		if (i >= 0) {
			return c.inbox.splice(i, 1)[0];
		}
		await sleep(20);
	}
	throw new Failure(`no llego ${what} (buzon: ${JSON.stringify(c.inbox)})`);
}

const ofType = (t) => (m) => m.type === t;

// Dos usuarios en una sala, con la partida empezada.
async function startedRoom() {
	const a = await newUser();
	const b = await newUser();
	const ca = await wsAs(a);
	const cb = await wsAs(b);
	wsSend(ca, { type: "create_room" });
	const welcomeA = await wsWait(ca, ofType("welcome"), "welcome de A");
	wsSend(cb, { type: "join_room", code: welcomeA.room_code });
	const welcomeB = await wsWait(cb, ofType("welcome"), "welcome de B");
	wsSend(ca, { type: "start_game" });
	await wsWait(ca, ofType("start_game"), "start_game en A");
	await wsWait(cb, ofType("start_game"), "start_game en B");
	return { a, b, ca, cb, code: welcomeA.room_code, idA: welcomeA.id, idB: welcomeB.id };
}

const closeAll = (...cs) => cs.forEach((c) => c?.ws.close());

// ── secciones ───────────────────────────────────────────────────────────────

const sections = {
	async rawsql() {
		const health = await api("GET", "/db/health");
		eq(health.json, { ok: true }, "el gateway responde por nginx");

		const r = await api("POST", "/db/query", { body: { sql: "SELECT 1 AS x", params: [] } });
		eq(r.status, 404, "POST /db/query");
		check(/Route POST:\/db\/query not found/.test(r.json?.message ?? ""),
			`el 404 no viene del gateway: ${r.buf.toString().slice(0, 200)}`);

		// Ningun script del juego llama a la ruta vieja ni a Database.query().
		const pattern = /"\/db\/query"|Database\.query\(/;
		check(pattern.test('Database.query("SELECT 1", [], cb)') && pattern.test('var url := base + "/db/query"'),
			"control positivo: el patron no detecta una llamada");
		const hits = [];
		const walk = (dir) => {
			for (const name of readdirSync(dir)) {
				if (name.startsWith(".")) continue;
				const full = path.join(dir, name);
				if (statSync(full).isDirectory()) {
					walk(full);
				} else if (name.endsWith(".gd")) {
					readFileSync(full, "utf8").split("\n").forEach((line, i) => {
						if (!line.trimStart().startsWith("#") && pattern.test(line)) {
							hits.push(`${path.relative(ROOT, full)}:${i + 1}`);
						}
					});
				}
			}
		};
		walk(path.join(ROOT, "game_godot"));
		eq(hits, [], "llamadas a la ruta de SQL en crudo en el juego");
	},

	async me() {
		const u = await newUser();

		eq((await api("GET", "/db/me")).status, 401, "sin token");
		eq((await api("GET", "/db/me", { token: forgedToken(u.username) })).status, 401, "token firmado con otra clave");
		const none = `${Buffer.from('{"alg":"none"}').toString("base64url")}.${Buffer.from(JSON.stringify({ sub: u.username })).toString("base64url")}.`;
		eq((await api("GET", "/db/me", { token: none })).status, 401, "token alg=none");

		psql(`UPDATE users SET last_seen = NULL WHERE id = ${u.id}`);
		const r = await api("GET", "/db/me", { token: u.token });
		eq(r.status, 200, "GET /db/me con token");
		const row = r.json.rows[0];
		eq([row.id, row.username], [u.id, u.username], "la fila es la del token");
		for (const k of ["coins", "deck_selected", "wins", "losses", "avatar_url"]) {
			check(k in row, `falta ${k} en /db/me`);
		}
		const [[seen]] = psql(`SELECT last_seen IS NOT NULL FROM users WHERE id = ${u.id}`);
		eq(seen, "t", "last_seen se actualiza con cada peticion con token");
	},

	async decks() {
		const u = await newUser();
		const other = await newUser();

		eq((await api("GET", "/db/me/decks")).status, 401, "sin token");

		let r = await api("GET", "/db/me/decks", { token: u.token });
		eq(r.json.rows.map((d) => d.id), ["española"], "usuario nuevo: solo la inicial");

		psql(`INSERT INTO user_decks (user_id, deck_id) VALUES (${u.id}, 'pixel')`);
		psql(`INSERT INTO user_decks (user_id, deck_id) VALUES (${other.id}, 'cutre')`);
		r = await api("GET", "/db/me/decks", { token: u.token });
		eq(r.json.rows.map((d) => d.id).sort(), ["española", "pixel"], "inicial + las suyas, no las de otro");
		check(r.json.rows.every((d) => typeof d.rarity === "string" && typeof d.name === "string"), "cada baraja trae name y rarity");
	},

	async gacha() {
		const ownedCount = (id) => Number(psql(`SELECT count(*) FROM user_decks WHERE user_id = ${id}`)[0][0]);
		const coinsOf = (id) => Number(psql(`SELECT coins FROM users WHERE id = ${id}`)[0][0]);

		eq((await api("POST", "/db/me/gacha", { body: {} })).status, 401, "sin token");

		// Sin monedas: 409 y no se toca nada.
		const poor = await newUser();
		let r = await api("POST", "/db/me/gacha", { token: poor.token, body: {} });
		eq([r.status, r.json?.reason], [409, "no_coins"], "sin monedas");
		eq([coinsOf(poor.id), ownedCount(poor.id)], [0, 0], "sin monedas no cambia nada");

		// Con monedas: cobra 1 y da una baraja que no tenia.
		const rich = await newUser();
		psql(`UPDATE users SET coins = 3 WHERE id = ${rich.id}`);
		r = await api("POST", "/db/me/gacha", { token: rich.token, body: {} });
		eq(r.status, 200, "tirada con monedas");
		const got = r.json.rows[0];
		eq(got.coins, 2, "monedas que devuelve la tirada");
		eq(coinsOf(rich.id), 2, "monedas en la base de datos");
		check(got.rarity !== "first", "el gachapon no da la baraja inicial");
		eq(psql(`SELECT deck_id FROM user_decks WHERE user_id = ${rich.id}`).flat(), [got.deck_id], "la baraja queda apuntada");

		// La siguiente nunca repite.
		r = await api("POST", "/db/me/gacha", { token: rich.token, body: {} });
		eq(r.status, 200, "segunda tirada");
		check(r.json.rows[0].deck_id !== got.deck_id, "la segunda tirada repitio baraja");

		// Con todas: 409 y no cobra.
		const full = await newUser();
		psql(`INSERT INTO user_decks (user_id, deck_id) SELECT ${full.id}, id FROM decks WHERE rarity <> 'first'`);
		psql(`UPDATE users SET coins = 5 WHERE id = ${full.id}`);
		r = await api("POST", "/db/me/gacha", { token: full.token, body: {} });
		eq([r.status, r.json?.reason], [409, "all_owned"], "con todas las barajas");
		eq(coinsOf(full.id), 5, "con todas no se cobra");

		// Dos tiradas a la vez con una moneda: solo una da baraja.
		const race = await newUser();
		psql(`UPDATE users SET coins = 1 WHERE id = ${race.id}`);
		const both = await Promise.all([1, 2].map(() => api("POST", "/db/me/gacha", { token: race.token, body: {} })));
		eq(both.map((x) => x.status).sort(), [200, 409], "dos tiradas simultaneas con 1 moneda");
		eq([coinsOf(race.id), ownedCount(race.id)], [0, 1], "tras la carrera: 0 monedas y 1 baraja");
	},

	async matches() {
		const u = await newUser();
		const other = await newUser();
		const seat = (over) => ({ name: "Paco", kind: "ai", score: 80, is_winner: false, ...over });
		const good = {
			max_points: 100,
			deck_id: "española",
			players: [
				seat({ name: "Tú", kind: "human", score: 12, is_winner: true, is_me: true }),
				// Intento de colar a otro usuario: el servidor tiene que ignorarlo.
				seat({ user_id: other.id, is_me: false }),
			],
		};

		eq((await api("POST", "/db/matches", { body: good })).status, 401, "sin token");

		const bad = [
			["sin is_me", { ...good, players: good.players.map((p) => ({ ...p, is_me: false })) }],
			["dos is_me", { ...good, players: good.players.map((p) => ({ ...p, kind: "human", is_me: true })) }],
			["5 asientos", { ...good, players: [...good.players, seat(), seat(), seat()] }],
			["1 asiento", { ...good, players: [good.players[0]] }],
			["kind network", { ...good, players: [good.players[0], seat({ kind: "network" })] }],
			["sin ganador", { ...good, players: good.players.map((p) => ({ ...p, is_winner: false })) }],
			["score texto", { ...good, players: [good.players[0], seat({ score: "80" })] }],
			["max_points 0", { ...good, max_points: 0 }],
		];
		for (const [what, body] of bad) {
			const r = await api("POST", "/db/matches", { token: u.token, body });
			eq(r.status, 400, `cuerpo invalido (${what})`);
		}
		eq(Number(psql(`SELECT count(*) FROM match_players WHERE user_id = ${u.id}`)[0][0]), 0, "los invalidos no guardan nada");

		const [[w0, l0]] = psql(`SELECT wins, losses FROM users WHERE id = ${u.id}`);
		const r = await api("POST", "/db/matches", { token: u.token, body: good });
		eq(r.status, 201, "partida valida");
		const matchId = r.json.rows[0].match_id;

		eq(psql(`SELECT is_online, max_points, deck_id, ended_at IS NOT NULL FROM matches WHERE id = ${matchId}`),
			[["f", "100", "española", "t"]], "fila de matches");
		eq(psql(`SELECT seat, coalesce(user_id::text, 'null'), name, kind, score, is_winner FROM match_players WHERE match_id = ${matchId} ORDER BY seat`),
			[["1", String(u.id), "Tú", "human", "12", "t"], ["2", "null", "Paco", "ai", "80", "f"]],
			"asientos: solo el del token lleva usuario");
		eq(psql(`SELECT wins, losses FROM users WHERE id = ${u.id}`), [[String(Number(w0) + 1), l0]], "victoria sumada");
		eq(Number(psql(`SELECT count(*) FROM match_players WHERE user_id = ${other.id}`)[0][0]), 0, "al otro no se le apunta nada");

		const h = await api("GET", "/db/profile/me/history", { token: u.token });
		check(h.json.rows.some((m) => m.id === matchId), "la partida sale en el historial");

		// Una baraja que no esta en el catalogo no tira la partida: se guarda sin baraja.
		const r2 = await api("POST", "/db/matches", { token: u.token, body: { ...good, deck_id: "no_existe" } });
		eq(r2.status, 201, "partida con baraja inventada");
		eq(psql(`SELECT coalesce(deck_id, 'null') FROM matches WHERE id = ${r2.json.rows[0].match_id}`), [["null"]], "baraja inventada guardada como null");
	},

	async avatar() {
		const u = await newUser();
		const up = (opts) => api("PUT", "/db/profile/me/avatar/upload", { token: u.token, ...opts });
		const avatarUrl = () => psql(`SELECT coalesce(avatar_url, 'null') FROM users WHERE id = ${u.id}`)[0][0];

		eq((await api("PUT", "/db/profile/me/avatar/upload", { raw: PNG_1x1, contentType: "image/png" })).status, 401, "sin token");

		let r = await up({ raw: Buffer.from("esto no es un png"), contentType: "image/png" });
		eq(r.status, 400, "texto disfrazado de PNG");
		r = await up({ raw: Buffer.from("hola"), contentType: "text/plain" });
		eq(r.status, 415, "tipo no admitido");
		const big = Buffer.concat([PNG_1x1, Buffer.alloc(1536 * 1024)]);
		r = await up({ raw: big, contentType: "image/png" });
		eq([r.status, r.json?.ok], [413, false], "mas de 1 MB (JSON del gateway)");
		eq(avatarUrl(), "null", "los rechazados no cambian el avatar");

		r = await up({ raw: PNG_1x1, contentType: "image/png" });
		eq(r.status, 200, "subida valida");
		const url1 = r.json.rows[0].avatar_url;
		check(/^\/db\/avatars\/\d+-[0-9a-f-]{36}\.png$/.test(url1), `url inesperada: ${url1}`);
		eq(avatarUrl(), url1, "avatar_url apuntado");

		let g = await api("GET", url1);
		eq([g.status, g.headers.get("content-type")], [200, "image/png"], "se sirve la imagen");
		check(g.buf.equals(PNG_1x1), "la imagen servida es la subida");

		const me = await api("GET", "/db/me", { token: u.token });
		eq([me.json.rows[0].avatar_url, me.json.rows[0].avatar_is_default], [url1, false], "/db/me da el avatar subido");

		// Una segunda subida borra la primera del disco.
		r = await up({ raw: PNG_1x1, contentType: "image/png" });
		const url2 = r.json.rows[0].avatar_url;
		check(url2 !== url1, "la segunda subida reutilizo el nombre");
		eq((await api("GET", url1)).status, 404, "la imagen vieja se borra");
		eq((await api("GET", url2)).status, 200, "la nueva se sirve");

		// Elegir uno del catalogo tambien borra la subida.
		r = await api("PUT", "/db/profile/me/avatar", { token: u.token, body: { avatar: "Avatar03" } });
		eq(r.status, 200, "avatar del catalogo");
		eq((await api("GET", url2)).status, 404, "al elegir del catalogo se borra la subida");

		// Y quitarlo tambien.
		r = await up({ raw: PNG_1x1, contentType: "image/png" });
		const url3 = r.json.rows[0].avatar_url;
		eq((await api("DELETE", "/db/profile/me/avatar", { token: u.token })).status, 204, "quitar avatar");
		eq((await api("GET", url3)).status, 404, "al quitarlo se borra la subida");
		eq(avatarUrl(), "null", "vuelve al de por defecto");

		// Nombres que no genera el servidor no se sirven.
		for (const evil of ["/db/avatars/1-x.png", "/db/avatars/package.json", "/db/avatars/server.js"]) {
			eq((await api("GET", evil)).status, 404, `ruta ${evil}`);
		}
		// Con "..%2f" nginx normaliza la ruta, la saca de /db/ y contesta la
		// web estatica (index.html): no llega al gateway ni sale ningun fichero.
		const trav = "/db/avatars/..%2f..%2f..%2fetc%2fpasswd";
		const t = await api("GET", trav);
		check(!t.buf.toString().includes("root:x:0:0") && !String(t.headers.get("content-type")).startsWith("image/"),
			"la ruta con ..%2f devolvio un fichero");
		// Y el gateway, si le llega tal cual, tampoco la sirve.
		const direct = execFileSync("docker", ["exec", "transcendence_frontend", "sh", "-c",
			`wget -S -O /dev/null "http://db_gateway:3000${trav}" 2>&1 || true`], { encoding: "utf8" });
		check(/HTTP\/1\.1 404/.test(direct), `el gateway no dio 404 a ${trav}: ${direct.slice(0, 200)}`);
	},

	async wsauth() {
		const u = await newUser();
		const refused = async (protocols, what) => {
			try {
				const c = await wsOpen(protocols);
				c.ws.close();
				throw new Failure(`se acepto la conexion ${what}`);
			} catch (err) {
				if (err instanceof Failure) throw err;
				eq(err.status, 401, `conexion ${what}`);
			}
		};
		await refused(undefined, "sin token");
		await refused(["chinchon.v1"], "sin subprotocolo de token");
		await refused(["chinchon.v1", "bearer.basura"], "con token basura");
		await refused(["chinchon.v1", `bearer.${forgedToken(u.username)}`], "con token de otra clave");
		await refused(["chinchon.v1", `bearer.${forgedToken("nadie_" + u.username, JWT_SECRET)}`], "con token bueno de un usuario que no existe");

		const c = await wsAs(u);
		eq(c.protocol, "chinchon.v1", "subprotocolo elegido");
		wsSend(c, { type: "create_room" });
		await wsWait(c, ofType("welcome"), "welcome con token valido");
		closeAll(c);
	},

	async wsidentity() {
		const a = await newUser();
		const b = await newUser();
		const ca = await wsAs(a);
		const cb = await wsAs(b);

		// Los dos intentan hacerse pasar por otro.
		wsSend(ca, { type: "create_room", username: "admin", user_id: 1 });
		const wa = await wsWait(ca, ofType("welcome"), "welcome de A");
		eq([wa.username, wa.user_id], [a.username, a.id], "A es quien dice su token");

		wsSend(cb, { type: "join_room", code: wa.room_code, username: a.username, user_id: a.id });
		const wb = await wsWait(cb, ofType("welcome"), "welcome de B");
		eq([wb.username, wb.user_id], [b.username, b.id], "B es quien dice su token");
		eq(wb.existing_players.map((p) => [p.username, p.user_id]), [[a.username, a.id]], "B ve a A con su identidad real");

		const joined = await wsWait(ca, ofType("player_joined"), "player_joined en A");
		eq([joined.username, joined.user_id], [b.username, b.id], "A ve a B con su identidad real");

		wsSend(ca, { type: "start_game" });
		const start = await wsWait(cb, ofType("start_game"), "start_game en B");
		eq(start.players.map((p) => p.user_id), [a.id, b.id], "la plantilla lleva los user_id de los tokens");
		closeAll(ca, cb);
	},

	async wsmatch() {
		const { a, b, ca, cb, idA, idB } = await startedRoom();
		const [[wa0, la0]] = psql(`SELECT wins, losses FROM users WHERE id = ${a.id}`);
		const [[wb0, lb0]] = psql(`SELECT wins, losses FROM users WHERE id = ${b.id}`);
		const result = {
			type: "match_result", max_points: 100, deck_id: "pixel",
			seats: [{ id: idA, score: 104, is_winner: false }, { id: idB, score: 37, is_winner: true }],
		};

		// El que no es anfitrion no puede guardar.
		wsSend(cb, result);
		eq((await wsWait(cb, ofType("error"), "error a B")).code, "NOT_HOST", "match_result de B");

		// Control positivo: lo que B manda si llega a A...
		wsSend(cb, { type: "game_action", action: { type: "draw", source: "deck" } });
		const act = await wsWait(ca, ofType("game_action"), "game_action de B en A");
		eq(act.from, idB, "from lo pone el servidor");
		// ...pero un match_saved inventado no.
		wsSend(cb, { type: "match_saved", match_id: 999999 });
		await sleep(600);
		check(!ca.inbox.some((m) => m.type === "match_saved"), "un match_saved del cliente llego a A");

		// Resultados mal formados.
		for (const [what, seats] of [
			["falta un asiento", [result.seats[0]]],
			["jugador ajeno", [result.seats[0], { id: 987654, score: 1, is_winner: true }]],
			["repetido", [result.seats[1], result.seats[1]]],
			["sin ganador", result.seats.map((s) => ({ ...s, is_winner: false }))],
		]) {
			wsSend(ca, { ...result, seats });
			eq((await wsWait(ca, ofType("error"), `error (${what})`)).code, "BAD_RESULT", `match_result ${what}`);
		}

		wsSend(ca, result);
		const sa = await wsWait(ca, ofType("match_saved"), "match_saved en A");
		const sb = await wsWait(cb, ofType("match_saved"), "match_saved en B");
		eq(sa.match_id, sb.match_id, "el mismo id a los dos");
		const matchId = sa.match_id;
		check(matchId !== 999999, "match_id inventado");

		eq(psql(`SELECT is_online, max_points, deck_id FROM matches WHERE id = ${matchId}`), [["t", "100", "pixel"]], "fila de matches");
		eq(psql(`SELECT seat, user_id, name, kind, score, is_winner FROM match_players WHERE match_id = ${matchId} ORDER BY seat`),
			[["1", String(a.id), a.username, "human", "104", "f"], ["2", String(b.id), b.username, "human", "37", "t"]],
			"asientos con las cuentas de los tokens");
		eq(psql(`SELECT wins, losses FROM users WHERE id = ${a.id}`), [[wa0, String(Number(la0) + 1)]], "derrota de A");
		eq(psql(`SELECT wins, losses FROM users WHERE id = ${b.id}`), [[String(Number(wb0) + 1), lb0]], "victoria de B");

		wsSend(ca, result);
		eq((await wsWait(ca, ofType("error"), "error al repetir")).code, "ALREADY_SAVED", "guardar dos veces");
		eq(Number(psql(`SELECT count(*) FROM match_players WHERE user_id = ${a.id}`)[0][0]), 1, "solo una partida para A");
		closeAll(ca, cb);
	},

	async wsclose() {
		const { ca, cb, code, idA, idB } = await startedRoom();

		// B no puede cerrar la sala a mitad de partida.
		wsSend(cb, { type: "match_ended" });
		eq((await wsWait(cb, ofType("error"), "error a B")).code, "NOT_FINISHED", "match_ended de B antes de guardar");
		check(!ca.inbox.some((m) => m.type === "match_ended"), "A recibio match_ended de B");

		// Con la partida guardada, cualquiera la cierra.
		wsSend(ca, { type: "match_result", max_points: 100, deck_id: null,
			seats: [{ id: idA, score: 0, is_winner: true }, { id: idB, score: 120, is_winner: false }] });
		await wsWait(ca, ofType("match_saved"), "match_saved");
		wsSend(cb, { type: "match_ended" });
		await wsWait(ca, ofType("match_ended"), "match_ended en A");
		await wsWait(cb, ofType("match_ended"), "match_ended en B");

		// La sala ya no existe.
		const c = await newUser();
		const cc = await wsAs(c);
		wsSend(cc, { type: "join_room", code });
		eq((await wsWait(cc, ofType("error"), "error al unirse")).code, "ROOM_NOT_FOUND", "unirse a la sala cerrada");

		// Y nadie queda dentro: lo que manden ya no va a ninguna sala.
		wsSend(ca, { type: "deck_sync", order: [] });
		eq((await wsWait(ca, ofType("error"), "error a A")).code, "NOT_IN_ROOM", "A tras cerrar");
		closeAll(ca, cb, cc);
	},

	async ports() {
		// Control positivo: por nginx el backend si responde.
		const game = await api("GET", "/");
		eq(game.status, 200, "el juego en 9443");
		const health = await api("GET", "/api/health");
		eq([health.status, health.buf.toString()], [200, "OK"], "el backend por nginx");

		const published = execFileSync("docker", ["port", "transcendence_backend"], { encoding: "utf8" }).trim();
		eq(published, "", "puertos publicados del backend");

		const open = await new Promise((resolve) => {
			const s = net.connect({ host: "127.0.0.1", port: 8080 });
			s.setTimeout(2000);
			s.once("connect", () => { s.destroy(); resolve(true); });
			s.once("timeout", () => { s.destroy(); resolve(false); });
			s.once("error", () => resolve(false));
		});
		eq(open, false, "localhost:8080 accesible desde el host");
	},
};

// ── main ────────────────────────────────────────────────────────────────────

const wanted = process.argv[2] ?? "all";
const order = wanted === "all" ? Object.keys(sections) : [wanted];

for (const name of order) {
	if (!(name in sections)) {
		console.error(`seccion desconocida: ${name}. Hay: ${Object.keys(sections).join(" ")}`);
		process.exit(2);
	}
	try {
		await sections[name]();
		console.log(`E2E ${name} PASSED`);
	} catch (err) {
		console.error(`E2E ${name} FAILED: ${err.message}`);
		process.exit(1);
	}
}
