extends Node

# =============================================================================
# profile_api.gd
#
# Autoload ("ProfileApi") para todo lo del perfil: nombre, avatar, amigos e
# historial. Habla con las rutas /db/profile/* del db_gateway.
#
# No confundir con los otros dos autoloads de red:
#   Auth     (auth.gd)     -> login y registro, guarda el token
#   Database (database.gd) -> barajas, monedas, gachapon y partidas offline
#   ProfileApi (esto)      -> rutas REST de verdad, la SQL esta en el servidor
#
# Aqui NO se manda SQL: se pide un recurso con el metodo que toca y el servidor
# decide la consulta. Cada metodo HTTP quiere decir una cosa distinta:
#
#   GET     leer, no cambia nada
#   HEAD    igual que el GET pero sin cuerpo: solo interesa el codigo
#   POST    una accion que puede fallar aunque repitas lo mismo (renombrar)
#   PATCH   cambiar SOLO los campos que mandas, el resto se queda igual
#   PUT     reemplazar el valor entero (repetirlo deja lo mismo)
#   DELETE  quitar / volver a lo de por defecto
#
# Todas las funciones se usan con await y devuelven el mismo diccionario:
#   { ok = true,  status = 200, data = {...} }
#   { ok = false, status = 409, data = {...}, error = "..." }
#
# Uso:
#   var res = await ProfileApi.get_profile()
#   if res.ok:
#       print(res.data.rows[0].username)
#   else:
#       print(res.error)
# =============================================================================


# Lo mismo que hace auth.gd: los codigos conocidos se traducen aqui para que
# las pantallas no tengan que saber nada de HTTP.
const MENSAJES := {
	0: "No se pudo conectar con el servidor",
	400: "Los datos no son validos",
	401: "Hay que volver a iniciar sesion",
	403: "Esa cuenta ya no existe",
	404: "No se encontro",
	409: "Ya esta cogido",
	500: "Error del servidor",
}


# =============================================================================
# PERFIL
# =============================================================================

# GET: la ficha del usuario con todas las estadisticas: 
# user_id, username, name, avatar_url, avatar_is_default, coins, deck_selected, create_at, 
# last_seen, wins, losses, games_played, games_won, games_lost, online_games, offline_games,
# win_rate, best_score, worst_score, avg_score, total_points, first_played, last_played,
# current_streak, streak_is_win, longest_win_streak, favourite_deck y decks_owned. 
# Trae UNA fila en data.rows[0], incluso si no ha jugado nunca (los contadores van a 0).
func get_profile() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/db/profile/me")


# PATCH: cambia solo lo que le pases. update_profile({ "name": "Miguelito" })
# NO toca el avatar, y al contrario igual. Campos validos: "name" y "avatar"
# (el id del catalogo, o null para volver al de por defecto).
func update_profile(fields: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_PATCH, "/db/profile/me", fields)


# HEAD: solo para saber si el nombre esta libre antes de intentar el cambio,
# y poder avisar mientras se escribe sin pedir toda una ficha.
# Devuelve true si esta libre. Si no hay conexion tambien devuelve false: en la
# duda, mejor no decirle a nadie que un nombre esta libre.
func is_username_free(user: String) -> bool:
	var res: Dictionary = await request(HTTPClient.METHOD_HEAD, "/db/profile/username/" + user.uri_encode())
	return res.status == 404


# POST: cambia el nombre de usuario. Va aparte del PATCH porque el username es
# con lo que se hace login y es lo que lleva dentro el token.
#
# OJO: si sale bien, data.reauth_required viene a true y el token que hay
# guardado ya NO vale, porque apunta al nombre viejo. Hay que hacer login otra
# vez. Devuelve 409 si otro lo tiene.
func change_username(new_user: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/db/profile/me/username",
		{ "username": new_user })


# =============================================================================
# AVATAR
# =============================================================================

# GET: los avatares que se pueden elegir. Cada fila trae { id, url, name },
# donde url es una ruta res:// que se carga con load(). No hace falta token.
func get_avatar_catalog() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/db/profile/avatars")


# PUT: pone un avatar del catalogo. Es PUT y no PATCH porque el avatar es un solo valor:
# lo que mandas pasa a ser el estado completo, y repetir la llamada deja lo
# mismo. avatar_id tiene que ser uno de los del catalogo.
func set_avatar(avatar_id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_PUT, "/db/profile/me/avatar",
		{ "avatar": avatar_id })


# DELETE: quita el avatar elegido y se vuelve al de por defecto.
# Contesta 204 (sin cuerpo), asi que solo hay que mirar res.ok.
func reset_avatar() -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, "/db/profile/me/avatar")


# PUT: sube una imagen propia como avatar. bytes es el fichero tal cual y
# mime "image/png", "image/jpeg" o "image/webp". Maximo 1 MB. Si va bien,
# data.rows[0].avatar_url es la ruta nueva ("/db/avatars/..."), que se pinta
# con load_avatar().
# 400 si el fichero no es la imagen que dice, 413 si pasa de 1 MB, 415 si el
# tipo no es de los admitidos.
func upload_avatar(bytes: PackedByteArray, mime: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())

	var headers := PackedStringArray(["Content-Type: " + mime])
	if Auth.is_logged_in():
		headers.append("Authorization: Bearer " + Auth.token)

	var err := http.request_raw(_api_base() + "/db/profile/me/avatar/upload",
		headers, HTTPClient.METHOD_PUT, bytes)
	if err != OK:
		http.queue_free()
		return { "ok": false, "status": 0, "data": {}, "error": MENSAJES[0] }
 
	var done: Array = await http.request_completed
	http.queue_free()
	if done[0] != HTTPRequest.RESULT_SUCCESS:
		return { "ok": false, "status": 0, "data": {}, "error": MENSAJES[0] }
	print("HTTP ", done[1], " -> ", done[3].get_string_from_utf8())
	return _parse(done[1], done[3])


# Convierte un avatar_url en una textura, sea del catalogo o subido.
#   "res://..."        -> viene dentro del juego, se carga con load()
#   "/db/avatars/..."  -> subido por un usuario, se descarga del gateway
# Devuelve null si no se pudo cargar. Las descargadas se guardan en memoria:
# el nombre del fichero cambia en cada subida, asi que nunca se quedan viejas.
var _avatar_cache := {}

func load_avatar(url: String) -> Texture2D:
	if url.begins_with("res://"):
		return load(url) as Texture2D
	if not url.begins_with("/db/avatars/"):
		return null
	if _avatar_cache.has(url):
		return _avatar_cache[url]

	var http := HTTPRequest.new()
	add_child(http)
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())
	if http.request(_api_base() + url) != OK:
		http.queue_free()
		return null

	var done: Array = await http.request_completed
	http.queue_free()
	if done[0] != HTTPRequest.RESULT_SUCCESS or done[1] != 200:
		return null

	var image := Image.new()
	var body: PackedByteArray = done[3]
	var err := ERR_FILE_UNRECOGNIZED
	match url.get_extension():
		"png":  err = image.load_png_from_buffer(body)
		"jpg":  err = image.load_jpg_from_buffer(body)
		"webp": err = image.load_webp_from_buffer(body)
	if err != OK:
		return null

	var texture := ImageTexture.create_from_image(image)
	_avatar_cache[url] = texture
	return texture


# =============================================================================
# AMIGOS
# =============================================================================

# GET: la lista de amigos, ya ordenada como se pinta (primero los conectados).
# Cada fila trae { id, username, name, avatar_url, is_online, is_mutual, ... }.
# Ademas viene data.is_full y data.max_friends, para saber si toca ensenar el
# aviso de "maximo de amigos" sin tener el numero escrito en la pantalla.
func get_friends() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/db/profile/me/friends")


# POST: anade por nombre de usuario, que es lo que se escribe en la caja.
# 404 si no existe nadie con ese nombre, 409 si ya lo tenias o si has llegado
# al tope (en ese caso data.is_full viene a true). Si va bien, contesta 201 y
# data.rows[0] es la ficha del recien anadido, para poder pintar la fila sin
# volver a pedir la lista entera.
func add_friend(user: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/db/profile/me/friends",
		{ "username": user })


# DELETE: lo quita de TU lista. Si el otro te tiene anadido, eso es suyo y no
# se toca. Contesta 204 (sin cuerpo).
func remove_friend(friend_id: int) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE,
		"/db/profile/me/friends/%d" % friend_id)


# HEAD: comprobar si ya lo tienes, sin traerte la lista entera.
func is_friend(friend_id: int) -> bool:
	var res: Dictionary = await request(HTTPClient.METHOD_HEAD,
		"/db/profile/me/friends/%d" % friend_id)
	return res.status == 200


# =============================================================================
# HISTORIAL
# =============================================================================

# GET: las ultimas partidas terminadas. Cada fila trae la puntuacion y el
# puesto del usuario, y en "rivales" un array con los demas asientos.
# El servidor recorta el limit a 50 como maximo.
func get_history(limit: int = 10) -> Dictionary:
	return await request(HTTPClient.METHOD_GET,
		"/db/profile/me/history?limit=%d" % limit)

# =============================================================================
# RANKING
# =============================================================================
func get_ranking(limit: int = 5) -> Dictionary:
	return await request(HTTPClient.METHOD_GET,
		"/db/ranking?scope=global&limit=%d" % limit)

# =============================================================================
# INTERNO
# =============================================================================

# El nucleo: por aqui pasan todos los metodos.
#
# Se hace un HTTPRequest por llamada y se tira al acabar, igual que en auth.gd
# y database.gd. Es de sobra para pantallas de menu, donde hay una peticion
# cada vez que se pulsa algo, no una por frame.
func request(method: int, path: String, body = null) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	# En el editor el certificado es autofirmado y hay que saltarse la
	# validacion. En web de esto ya se encarga el navegador.
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())

	# auth_headers() ya mete el "Authorization: Bearer ..." si hay sesion.
	var headers := Auth.auth_headers()
	var payload := "" if body == null else JSON.stringify(body)

	var err := http.request(_api_base() + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {
			"ok": false,
			"status": 0,
			"data": {},
			"error": MENSAJES[0],
		}

	# request_completed manda [result, code, headers, body].
	var done: Array = await http.request_completed
	http.queue_free()

	var result: int = done[0]
	var code: int = done[1]
	var raw: PackedByteArray = done[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": 0,
			"data": {},
			"error": MENSAJES[0],
		}

	return _parse(code, raw)


# Traduce la respuesta a { ok, status, data } / { ok, status, data, error }.
#
# Hay dos casos sin cuerpo que hay que tratar antes de intentar parsear nada:
# el HEAD, que nunca trae cuerpo por definicion, y el 204 del DELETE.
func _parse(code: int, raw: PackedByteArray) -> Dictionary:
	var ok := code >= 200 and code < 300

	if code == 204 or raw.is_empty():
		var sin_cuerpo := { "ok": ok, "status": code, "data": {} }
		if not ok:
			sin_cuerpo["error"] = _mensaje(code, {})
		return sin_cuerpo

	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}

	var res := { "ok": ok, "status": code, "data": data }
	if not ok:
		res["error"] = _mensaje(code, data)
	return res


# El gateway manda el motivo en "error", asi que se prefiere ese texto (es mas
# concreto: dice QUE nombre esta cogido, no solo que algo lo esta). El
# diccionario de arriba es el respaldo para cuando no manda nada.
func _mensaje(code: int, data: Dictionary) -> String:
	var del_servidor := str(data.get("error", ""))
	if not del_servidor.is_empty():
		return del_servidor
	if MENSAJES.has(code):
		return MENSAJES[code]
	return "Error del servidor (%d)" % code


# Mismo origen que la pagina, igual que auth.gd y database.gd. Asi no hay
# hosts escritos a mano y nginx puede hacer de proxy.
func _api_base() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true))
	return "https://localhost:9443"  # fallback para ejecutar desde el editor
