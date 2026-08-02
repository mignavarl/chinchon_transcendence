extends Control

# =============================================================================
# Lobby.gd
#
# Flujo:
#  1. Al entrar, se conecta al WebSocket (URL detectada automáticamente).
#  2. Recibe "welcome" -> guarda su propio network_id.
#  3. Recibe "player_joined" / "player_left" -> actualiza la lista visible.
#  4. El jugador con el network_id más bajo es considerado "host" y ve el
#     botón de "Empezar partida" activo.
#  5. Al pulsar empezar, el host manda "start_game" con la lista de ids
#     congelada. Todos (incluido el host) reaccionan a ese mensaje igual.
# =============================================================================

@export var num_ai_bots: int = 0 
@export var game_scene_path: String = "res://scenes/game.tscn"

@onready var player_list_container: VBoxContainer = %PlayerListContainer
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel

var my_network_id: int = -1
var connected_ids: Array[int] = []
var _game_starting: bool = false


func _ready() -> void:
	WebSocketClient.connected.connect(_on_socket_connected)
	WebSocketClient.disconnected.connect(_on_socket_disconnected)
	WebSocketClient.message_received.connect(_on_message_received)

	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true

	status_label.text = "Conectando..."
	WebSocketClient.connect_to_server(_get_websocket_url())


# ── Conexión ─────────────────────────────────────────────────────────────────

func _get_websocket_url() -> String:
	if OS.has_feature("web"):
		var host: String = JavaScriptBridge.eval("window.location.hostname", true)
		var protocol: String = JavaScriptBridge.eval("window.location.protocol", true)
		var scheme := "wss" if protocol == "https:" else "ws"
		return "%s://%s/ws/game" % [scheme, host]
	else:
		# Fallback para probar desde el editor (no exportado a web)
		return "ws://localhost:8080/ws/game"


func _on_socket_connected() -> void:
	status_label.text = "Conectado. Esperando jugadores..."


func _on_socket_disconnected() -> void:
	status_label.text = "Conexión perdida."
	start_button.disabled = true


# ── Mensajes de red ──────────────────────────────────────────────────────────

func _on_message_received(data: Dictionary) -> void:
	match data.get("type"):
		"welcome":
			my_network_id = data["id"]
			if my_network_id not in connected_ids:
				connected_ids.append(my_network_id)
			_refresh_ui()

		"player_joined":
			var id: int = data["id"]
			if id not in connected_ids:
				connected_ids.append(id)
			_refresh_ui()

		"player_left":
			var id: int = data["id"]
			connected_ids.erase(id)
			_refresh_ui()

		"start_game":
			if _game_starting:
				return
			_game_starting = true
			var ids: Array = data["player_ids"]
			var frozen_ids: Array[int] = []
			for i in ids:
				frozen_ids.append(int(i))
			_start_match(frozen_ids)


# ── UI ───────────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	for child in player_list_container.get_children():
		child.queue_free()

	var sorted_ids := connected_ids.duplicate()
	sorted_ids.sort()

	for id in sorted_ids:
		var label := Label.new()
		var suffix := " (tú)" if id == my_network_id else ""
		var host_suffix := " [HOST]" if id == sorted_ids[0] else ""
		label.text = "Jugador %d%s%s" % [id, suffix, host_suffix]
		player_list_container.add_child(label)

	status_label.text = "Conectados: %d" % connected_ids.size()

	# Solo el host (network_id más bajo) puede pulsar empezar
	var is_host :bool = connected_ids.size() > 0 and my_network_id == sorted_ids[0]
	start_button.disabled = not is_host or connected_ids.size() < 1


# ── Inicio de partida ────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if _game_starting:
		return

	var sorted_ids := connected_ids.duplicate()
	sorted_ids.sort()

	# El host manda la lista congelada a todos (incluido él mismo la recibirá también)
	WebSocketClient.send({
		"type": "start_game",
		"player_ids": sorted_ids
	})


func _start_match(sorted_network_ids: Array[int]) -> void:
	var config := _build_game_config(sorted_network_ids)
	GameConfigHandler.set_config(config)
	SceneLoader.change_scene("res://src/main_game/chinchon/MainRefactor.tscn", self.name)


func _build_game_config(sorted_network_ids: Array[int]) -> GameConfig:
	var players: Array[PlayerData] = []
	var hand_idx := 0

	for net_id in sorted_network_ids:
		var p := PlayerData.new()
		p.id = players.size()
		p.network_id = net_id
		p.hand_idx = hand_idx
		p.is_local = (net_id == my_network_id)
		p.type = PlayerData.Type.HUMAN if p.is_local else PlayerData.Type.NETWORK
		p.display_name = "Jugador %d" % net_id
		players.append(p)
		hand_idx += 1

	for i in num_ai_bots:
		var ai := PlayerData.new()
		ai.id = players.size()
		ai.hand_idx = hand_idx
		ai.type = PlayerData.Type.AI
		ai.display_name = "Bot %d" % (i + 1)
		players.append(ai)
		hand_idx += 1

	var config := GameConfig.new()
	config.players = players
	config.is_online = true
	return config
