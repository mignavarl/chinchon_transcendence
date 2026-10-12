extends Node

signal connected
signal disconnected
# El servidor no llego a aceptar la conexion: sin sesion, token caducado o
# servidor caido. Desde el navegador no se puede saber cual de las tres.
signal connection_failed
signal message_received(data: Dictionary)

# Lo que el servidor espera (JwtHandshakeInterceptor.java): se ofrecen dos
# subprotocolos, este y "bearer.<token>". El navegador no deja mandar la
# cabecera Authorization al abrir un WebSocket, y asi el token no va en la URL.
const PROTOCOL := "chinchon.v1"

var socket: WebSocketPeer
var _connected: bool = false

func connect_to_server(url: String, token: String) -> void:
	socket = WebSocketPeer.new()
	_connected = false
	socket.supported_protocols = PackedStringArray([PROTOCOL, "bearer." + token])
	# En el editor el certificado es autofirmado; en web ya se encarga el navegador.
	var tls: TLSOptions = null
	if not OS.has_feature("web"):
		tls = TLSOptions.client_unsafe()
	var err = socket.connect_to_url(url, tls)
	if err != OK:
		push_error("No se pudo conectar: %s" % err)
		socket = null
		connection_failed.emit()

func _process(_delta: float) -> void:
	if socket == null:
		return

	socket.poll()
	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			connected.emit()
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			var data = JSON.parse_string(packet)
			if data:
				message_received.emit(data)

	elif state == WebSocketPeer.STATE_CLOSED:
		# Se suelta el socket para no volver a avisar en cada frame.
		socket = null
		if _connected:
			_connected = false
			disconnected.emit()
		else:
			connection_failed.emit()

func send(data: Dictionary) -> void:
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func is_connected_to_server() -> bool:
	return _connected


func disconnect_socket():
	if socket:
		socket.close()
