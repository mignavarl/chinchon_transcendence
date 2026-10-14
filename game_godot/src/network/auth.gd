extends Node

# =============================================================================
# auth.gd
#
# Autoload para el login contra el backend de Spring (/api/auth).
# El juego corre en el navegador, asi que la peticion va por HTTP al mismo
# origen que sirve la pagina y nginx hace de proxy hacia el backend.
#
# No confundir con Database (database.gd): aquel habla con el db_gateway
# (barajas, monedas, partidas), este solo hace login/registro y guarda el
# token JWT.
#
# Uso:
#   Auth.login("miguel", "1234", func(res):
#       if res.ok:
#           print(Auth.token)
#       else:
#           print(res.error)
#   )
# =============================================================================

signal logged_in(username: String)
signal logged_out()

# Token JWT que devuelve el backend al hacer login. Vale 24h y hay que
# mandarlo en la cabecera Authorization para todo lo que no sea /api/auth.
var token: String = ""
var username: String = ""

# Id de la fila en la tabla users. El backend de Spring solo devuelve el
# token, asi que se pregunta aparte al db_gateway (GET /db/me, con el token).
# Solo sirve para saber si hay cuenta: el servidor nunca se fia de un id que
# mande el cliente, lo saca del token. -1 mientras no haya nadie dentro.
var user_id: int = -1


func is_logged_in() -> bool:
	return not token.is_empty()


# Si esto es false, se juega igual pero nada se apunta en la base de datos.
func can_save() -> bool:
	return user_id > 0


# Cabeceras para llamar a un endpoint protegido (/api/user/me, etc).
func auth_headers() -> PackedStringArray:
	if token.is_empty():
		return ["Content-Type: application/json"]
	return ["Content-Type: application/json", "Authorization: Bearer " + token]


func logout() -> void:
	token = ""
	username = ""
	user_id = -1
	logged_out.emit()


# POST /api/auth/login
# callback(result) con result = { ok = true } o { ok = false, error = "..." }.
# Si va bien, el token y el username quedan guardados aqui.
func login(user: String, password: String, callback: Callable) -> void:
	_post("/api/auth/login", { "username": user, "password": password },
		_on_login_response.bind(user, callback))


func _on_login_response(res: Dictionary, user: String, callback: Callable) -> void:
	if not res.ok:
		callback.call(res)
		return

	token = str(res.data.get("token", ""))
	username = user
	# Antes de dar la entrada por buena se resuelve el id, que a partir de
	# aqui ya se juega y hace falta para guardar. Va con el token recien
	# guardado, asi que es la fila del que acaba de entrar y de nadie mas.
	var me: Dictionary = await Database.get_me()
	var rows: Array = me.data.get("rows", []) if me.ok else []
	if not rows.is_empty():
		user_id = int(rows[0]["id"])
	else:
		# Se entra igual: el token vale, pero sin id no se guarda nada.
		user_id = -1
		push_warning("no se pudo resolver el id de %s (%s), no se guardaran barajas ni partidas"
			% [username, me.get("error", "sin filas")])

	logged_in.emit(username)
	callback.call(res)


# POST /api/auth/signup
# Solo crea la cuenta: el backend no devuelve token aqui, asi que despues
# hay que llamar a login() para entrar.
func signup(user: String, password: String, callback: Callable) -> void:
	_post("/api/auth/signup", { "username": user, "password": password }, callback)


# =============================================================================
# INTERNO
# =============================================================================

# Manda el JSON y traduce la respuesta a { ok, data } / { ok, error }.
func _post(path: String, payload: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	# Mismo caso que en database.gd: en el editor el certificado es
	# autofirmado y hay que saltarse la validacion. En web ya va el navegador.
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())

	http.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			callback.call(_parse_response(code, body.get_string_from_utf8()))
	)

	var err := http.request(_api_base() + path, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		callback.call({ "ok": false, "error": "No se pudo conectar con el servidor" })


# El backend contesta con JSON tanto en el 200 como en los errores.
# Los mensajes se montan aqui a partir del codigo para que las pantallas
# no tengan que saber nada de HTTP.
func _parse_response(code: int, text: String) -> Dictionary:
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		data = {}

	if code == 200:
		return { "ok": true, "data": data }

	# Los casos conocidos se traducen aqui; para el resto se enseña el texto
	# que mande el backend, y si no manda ninguno, el codigo pelado.
	var message := ""
	match code:
		0:   message = "No se pudo conectar con el servidor"
		400: message = "Faltan el usuario o la contraseña"
		401: message = "Usuario o contraseña incorrectos"
		409: message = "Ese nombre de usuario ya esta cogido"
		_:
			message = str(data.get("error", ""))
			if message.is_empty():
				message = "Error del servidor (%d)" % code

	return { "ok": false, "error": message, "code": code }


# Mismo origen que la pagina, igual que database.gd y lobby.gd. Asi no hay
# hosts escritos a mano y nginx puede hacer de proxy hacia el backend.
func _api_base() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true))
	return "https://localhost:9443"  # fallback para ejecutar desde el editor
