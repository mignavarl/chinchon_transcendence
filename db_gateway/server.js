// Gateway entre el juego y Postgres.
//
// El juego corre en el navegador (WASM), asi que no puede abrir un socket TCP
// contra Postgres directamente. Habla por HTTP con este servicio (nginx le
// reenvia todo lo de /db/) y aqui estan escritas las consultas.
//
// Aqui NO se ejecuta SQL que venga de fuera. Antes habia un POST /db/query que
// corria la SQL que mandase el navegador, sin token: cualquiera podia darse
// monedas, inventarse partidas o borrar tablas. Cada cosa que el juego
// necesita es ahora una ruta con su consulta fija y su token.
//
// El prefijo es /db/ y no /api/ porque /api/ lo ocupa el backend de Spring.

import Fastify from "fastify";
import pg from "pg";

import avatarUploadRoutes from "./avatar_upload.js";
import { DEFAULT_AVATAR_URL } from "./avatars.js";
import friendsRoutes from "./friends_routes.js";
import gameRoutes from "./game_routes.js";
import profileRoutes from "./profile_routes.js";

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

// Rutas REST: perfil, amigos, juego (barajas, gachapon, partidas) y avatares.
//
// Estas NO reciben SQL: la consulta esta escrita en el servidor y de fuera
// solo llegan valores, que van por $1, $2... Ademas piden token (el que firma
// el backend de Spring al hacer login), asi que cada peticion sabe de quien
// es sin que el cliente diga "soy el usuario 3".
//
// Se registran antes del listen() a proposito: una ruta anadida despues no
// entraria. Heredan el hook onSend de arriba por estar en la misma instancia,
// asi que las cabeceras COOP/COEP tambien salen en estas respuestas.
app.register(profileRoutes, { pool });
app.register(friendsRoutes, { pool, defaultAvatarUrl: DEFAULT_AVATAR_URL });
app.register(gameRoutes, { pool, defaultAvatarUrl: DEFAULT_AVATAR_URL });
app.register(avatarUploadRoutes, { pool });

const port = Number(process.env.GATEWAY_PORT ?? 3000);

app.listen({ host: "0.0.0.0", port }).catch((err) => {
	app.log.error(err);
	process.exit(1);
});
