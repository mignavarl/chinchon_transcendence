extends Node

# =============================================================================
# database.gd
#
# Autoload para hablar con la base de datos desde cualquier parte del juego.
# El juego corre en el navegador, asi que no se conecta a Postgres
# directamente: manda la SQL por HTTP al gateway (/api/query) y este la
# ejecuta y devuelve las filas.
#
# Uso:
#   Database.query("SELECT * FROM demo WHERE id = $1", [1], func(res):
#       if res.ok:
#           print(res.rows)
#       else:
#           push_error(res.error)
#   )
#
# Los valores van SIEMPRE en el array de params ($1, $2, ...), nunca pegados
# a mano dentro del string de la SQL.
# =============================================================================


# Ejecuta la consulta y llama a callback(result: Dictionary).
# result = { ok = true, rows = [...], rowCount = n }  si va bien
# result = { ok = false, error = "..." }              si falla
func query(sql: String, params: Array, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	# En el editor el certificado es autofirmado, asi que hay que saltarse
	# la validacion. En web de esto ya se encarga el navegador.
	if not OS.has_feature("web"):
		http.set_tls_options(TLSOptions.client_unsafe())

	http.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			var text := body.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data == null or not (data is Dictionary):
				callback.call({ "ok": false, "error": "respuesta invalida (codigo %d)" % code })
			else:
				callback.call(data)
	)

	var url := _api_base() + "/api/query"
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify({ "sql": sql, "params": params })

	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		callback.call({ "ok": false, "error": "no se pudo enviar la peticion: %s" % err })


# Mismo origen que la pagina, igual que hace lobby.gd con el WebSocket.
# Asi no hay hosts escritos a mano y nginx puede hacer de proxy.
func _api_base() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true))
	return "https://localhost:9090"  # fallback para ejecutar desde el editor
