// Subir un avatar propio.
//
// El subject pide poder subir tu propia imagen, con uno por defecto si no
// subes nada. El catalogo de avatars.js sigue valiendo; esto es lo otro.
//
// Metodos:
//   PUT  /db/profile/me/avatar/upload   cuerpo = la imagen tal cual (no multipart)
//   GET  /db/avatars/:file              sirve una imagen subida (publica)
//
// Se manda la imagen en crudo con su Content-Type (image/png, image/jpeg o
// image/webp) porque es lo que HTTPRequest.request_raw() de Godot sabe hacer
// sin montar un multipart a mano.
//
// Las imagenes se guardan en disco (volumen "avatars" en docker-compose) y en
// users.avatar_url queda "/db/avatars/<fichero>". Las del catalogo siguen
// siendo rutas res://, asi que el cliente distingue una de otra por el prefijo.

import { randomUUID } from "node:crypto";
import { mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import path from "node:path";

import { requireUser } from "./auth.js";

export const AVATAR_DIR = process.env.AVATAR_DIR ?? "/data/avatars";
export const UPLOADED_PREFIX = "/db/avatars/";

// 1 MiB. nginx deja pasar un poco mas (client_max_body_size en /db/) para que
// el que corte sea este servicio y conteste con JSON, no nginx con HTML.
const MAX_BYTES = 1024 * 1024;

// Tipo -> extension y firma de los primeros bytes. Se mira la firma y no solo
// la cabecera Content-Type, que la pone el cliente y puede mentir.
const FORMATS = {
	"image/png": { ext: "png", matches: (b) => b.length >= 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
	"image/jpeg": { ext: "jpg", matches: (b) => b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
	"image/webp": { ext: "webp", matches: (b) => b.length >= 12 && b.toString("ascii", 0, 4) === "RIFF" && b.toString("ascii", 8, 12) === "WEBP" },
};

const CONTENT_TYPE_BY_EXT = Object.fromEntries(
	Object.entries(FORMATS).map(([type, f]) => [f.ext, type]),
);

// Solo nombres generados aqui: <user_id>-<uuid>.<ext>. Nada de "..", barras
// ni nombres que elija el cliente.
const FILE_RE = /^\d+-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|webp)$/;

// Borra del disco un avatar subido que ya no se usa. Si la url es del
// catalogo (res://) o no hay, no hace nada. Un fallo al borrar solo deja un
// fichero huerfano, no merece tumbar la peticion.
export async function removeUploadedAvatar(url, log) {
	if (typeof url !== "string" || !url.startsWith(UPLOADED_PREFIX)) {
		return;
	}
	const file = url.slice(UPLOADED_PREFIX.length);
	if (!FILE_RE.test(file)) {
		return;
	}
	try {
		await unlink(path.join(AVATAR_DIR, file));
	} catch (err) {
		if (err.code !== "ENOENT") {
			log?.warn({ err }, "no se pudo borrar el avatar viejo");
		}
	}
}

export default async function avatarUploadRoutes(app, options) {
	const { pool } = options;

	await mkdir(AVATAR_DIR, { recursive: true });

	app.addContentTypeParser(
		Object.keys(FORMATS),
		{ parseAs: "buffer", bodyLimit: MAX_BYTES },
		(_req, body, done) => done(null, body),
	);

	// Los errores de Fastify (413 demasiado grande, 415 tipo no admitido)
	// salen con su propio formato; aqui se pasan al { ok, error } de siempre.
	app.setErrorHandler((err, req, reply) => {
		if (err.statusCode === 413) {
			return reply.code(413).send({ ok: false, error: "la imagen no puede pasar de 1 MB" });
		}
		if (err.statusCode === 415) {
			return reply.code(415).send({ ok: false, error: "solo se admiten PNG, JPEG o WEBP" });
		}
		req.log.error(err);
		return reply.code(err.statusCode ?? 500).send({ ok: false, error: "error del servidor" });
	});

	app.put("/db/profile/me/avatar/upload", { preHandler: requireUser(pool) }, async (req, reply) => {
		const type = String(req.headers["content-type"] ?? "").split(";")[0].trim().toLowerCase();
		const format = FORMATS[type];
		const body = req.body;

		if (format === undefined || !Buffer.isBuffer(body)) {
			return reply.code(415).send({ ok: false, error: "solo se admiten PNG, JPEG o WEBP" });
		}
		if (body.length === 0) {
			return reply.code(400).send({ ok: false, error: "la imagen esta vacia" });
		}
		if (!format.matches(body)) {
			return reply.code(400).send({ ok: false, error: "el fichero no es la imagen que dice ser" });
		}

		const file = `${req.userId}-${randomUUID()}.${format.ext}`;
		await writeFile(path.join(AVATAR_DIR, file), body, { flag: "wx" });

		const url = UPLOADED_PREFIX + file;
		let old;
		try {
			const { rows } = await pool.query(
				`UPDATE users u SET avatar_url = $2
				   FROM (SELECT avatar_url FROM users WHERE id = $1 FOR UPDATE) prev
				  WHERE u.id = $1
				 RETURNING prev.avatar_url AS old_url`,
				[req.userId, url],
			);
			old = rows[0]?.old_url;
		} catch (err) {
			// Si no se pudo apuntar, la imagen nueva no la usa nadie.
			await removeUploadedAvatar(url, req.log);
			throw err;
		}

		await removeUploadedAvatar(old, req.log);

		return {
			ok: true,
			rows: [{ id: req.userId, avatar_url: url, avatar_is_default: false }],
			rowCount: 1,
		};
	});

	// Publica: los avatares se ensenan en la lista de amigos y en la mesa.
	app.get("/db/avatars/:file", async (req, reply) => {
		const file = req.params.file ?? "";
		if (!FILE_RE.test(file)) {
			return reply.code(404).send({ ok: false, error: "no existe" });
		}

		let data;
		try {
			data = await readFile(path.join(AVATAR_DIR, file));
		} catch (err) {
			if (err.code === "ENOENT") {
				return reply.code(404).send({ ok: false, error: "no existe" });
			}
			throw err;
		}

		const ext = file.slice(file.lastIndexOf(".") + 1);
		return reply
			.header("Content-Type", CONTENT_TYPE_BY_EXT[ext])
			.header("X-Content-Type-Options", "nosniff")
			.header("Cache-Control", "public, max-age=31536000, immutable")
			.send(data);
	});
}
