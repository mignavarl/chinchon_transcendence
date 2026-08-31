extends Node

signal connected
signal disconnected
signal message_received(data: Dictionary)

var socket: WebSocketPeer
var _connected: bool = false

func connect_to_server(url: String) -> void:
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(url)
	if err != OK:
		push_error("No se pudo conectar: %s" % err)

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
		if _connected:
			_connected = false
			disconnected.emit()

func send(data: Dictionary) -> void:
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func is_connected_to_server() -> bool:
	return _connected
	

func disconnect_socket():
	socket.close()
