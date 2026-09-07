// Verificacion de los JWT que firma el backend de Spring.
//
// Los tokens los emite AuthController (/api/auth/login) y los firma
// JwtService con HS256. Aqui solo se comprueban: este servicio nunca
// crea tokens.
//
// OJO con la clave. JwtService hace esto:
//
//     byte[] keyBytes = Base64.getEncoder().encode(SECRET_KEY.getBytes());
//     return Keys.hmacShaKeyFor(keyBytes);
//
// Es decir, base64-CODIFICA el secreto y usa esos bytes ASCII como clave
// HMAC; no lo descodifica. Hay que repetir el mismo paso o la firma no
// cuadra nunca y todo responde 401. No "arreglar" esto por un lado solo:
// si se cambia, hay que cambiarlo en los dos servicios a la vez, y todos
// los tokens ya emitidos dejan de valer.

import jwt from "jsonwebtoken";

// El mismo valor por defecto que tiene el backend, para que quien no haya
// puesto JWT_SECRET en su .env siga funcionando.
const SECRET = process.env.JWT_SECRET ?? "change-in-production-change-in-production";

const KEY = Buffer.from(Buffer.from(SECRET, "utf8").toString("base64"), "utf8");

// Devuelve el username del token, o null si el token falta, esta manipulado
// o ha caducado (valen 24h).
export function usernameFromToken(authorizationHeader) {
	const header = authorizationHeader ?? "";
	if (!header.startsWith("Bearer ")) {
		return null;
	}

	const token = header.slice("Bearer ".length).trim();
	if (token.length === 0) {
		return null;
	}

	try {
		// algorithms fijo a proposito: sin esto, un token con "alg": "none"
		// se aceptaria sin firma.
		const claims = jwt.verify(token, KEY, { algorithms: ["HS256"] });
		const sub = claims?.sub;
		return typeof sub === "string" && sub.length > 0 ? sub : null;
	} catch {
		return null;
	}
}

// preHandler para las rutas que hablan de "el usuario que llama".
//
// El token solo trae el username, asi que aqui se resuelve el id de la fila,
// que es lo que necesitan las consultas. Queda en req.userId / req.username.
//
// 401 = no hay token o no vale.
// 403 = el token es bueno pero el usuario ya no existe (cuenta borrada).
export function requireUser(pool) {
	return async function (req, reply) {
		const username = usernameFromToken(req.headers.authorization);
		if (username === null) {
			return reply.code(401).send({ ok: false, error: "hace falta iniciar sesion" });
		}

		let rows;
		try {
			({ rows } = await pool.query(
				"SELECT id, username FROM users WHERE username = $1",
				[username],
			));
		} catch (err) {
			req.log.error(err);
			return reply.code(500).send({ ok: false, error: "no se pudo consultar el usuario" });
		}

		if (rows.length === 0) {
			return reply.code(403).send({ ok: false, error: "la cuenta ya no existe" });
		}

		req.userId = rows[0].id;
		req.username = rows[0].username;
	};
}
