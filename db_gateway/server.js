// Gateway entre el juego y Postgres.
//
// El juego corre en el navegador (WASM), asi que no puede abrir un socket TCP
// contra Postgres directamente. Manda un POST a /db/query, nginx lo reenvia
// aqui, y este servicio ejecuta la SQL contra la base de datos y devuelve
// las filas en JSON.
//
// El prefijo es /db/ y no /api/ porque /api/ lo ocupa el backend de Spring.

import Fastify from "fastify";
import pg from "pg";

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const app = Fastify({ logger: true });

// Cabeceras obligatorias para Godot 4 web (SharedArrayBuffer / Threads).
// nginx las pone en el bloque server, pero un bloque location con sus propios
// add_header no hereda los de arriba, asi que /db/ se quedaria sin ellas.
// Por eso las anadimos tambien aqui.
app.addHook("onSend", async (_req, reply, payload) => {
	reply.header("Cross-Origin-Opener-Policy", "same-origin");
	reply.header("Cross-Origin-Embedder-Policy", "require-corp");
	return payload;
});

// Comprueba que la base de datos responde.
app.get("/db/health", async (_req, reply) => {
	try {
		await pool.query("SELECT 1");
		return { ok: true };
	} catch (err) {
		reply.code(500);
		return { ok: false, error: String(err.message ?? err) };
	}
});

// La tuberia de consultas. Body: { sql: string, params?: any[] }
app.post("/db/query", async (req, reply) => {
	const { sql, params } = req.body ?? {};

	if (typeof sql !== "string" || sql.length === 0) {
		reply.code(400);
		return { ok: false, error: "falta el campo 'sql'" };
	}
	if (params !== undefined && !Array.isArray(params)) {
		reply.code(400);
		return { ok: false, error: "'params' tiene que ser un array" };
	}

	try {
		const result = await pool.query(sql, params ?? []);
		return { ok: true, rows: result.rows, rowCount: result.rowCount };
	} catch (err) {
		reply.code(500);
		return { ok: false, error: String(err.message ?? err) };
	}
});

const port = Number(process.env.GATEWAY_PORT ?? 3000);

app.listen({ host: "0.0.0.0", port }).catch((err) => {
	app.log.error(err);
	process.exit(1);
});
