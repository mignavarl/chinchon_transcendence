extends Control

# =============================================================================
# lobby_online.gd
#
# Al entrar en esta escena ya se sabe (via LobbyIntent) si el jugador
# quiere crear sala o unirse a una existente. Flujo:
#
#  1. Se conecta al WebSocket.
#  2. En cuanto conecta, manda "create_room" o "join_room" según el intent.
#  3. Recibe "welcome" -> guarda my_network_id, room_code, is_host.
#  4. "player_joined" / "player_left" -> actualiza lista de espera.
#  5. Solo el host ve el botón "Empezar partida".
#  6. Al pulsar empezar, se manda "start_game" con la lista de ids congelada.
# =============================================================================

@export var num_ai_bots: int = 0
@export var game_scene_path: String = "res://scenes/game.tscn"

@onready var room_code_label: Label = %RoomCodeLabel
@onready var player_list_container: VBoxContainer = %PlayerListContainer
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel

const MAX_PLAYERS_PER_ROOM := 4  # debe coincidir con Room.MAX_PLAYERS en el backend

var my_network_id: int = -1
var room_code: String = ""
var is_host: bool = false
var connected_ids: Array[int] = []
var _game_starting: bool = false


func _ready() -> void:
	WebSocketClient.connected.connect(_on_socket_connected)
	WebSocketClient.disconnected.connect(_on_socket_disconnected)
	WebSocketClient.message_received.connect(_on_message_received)

	start_button.pressed.connect(_on_start_pressed)
	start_button.visible = false

	status_label.text = "Conectando..."
	WebSocketClient.connect_to_server(_get_websocket_url())


# ── Conexión ─────────────────────────────────────────────────────────────────

func _get_websocket_url() -> String:
	if OS.has_feature("web"):
		var host: String = JavaScriptBridge.eval("window.location.hostname", true)
		var port: String = JavaScriptBridge.eval("window.location.port", true)
		var protocol: String = JavaScriptBridge.eval("window.location.protocol", true)
		var scheme := "wss" if protocol == "https:" else "ws"
		var port_suffix := (":" + port) if port != "" else ""
		return "%s://%s%s/ws/game" % [scheme, host, port_suffix]
	else:
		return "ws://localhost:8080/ws/game"

func _on_socket_connected() -> void:
	# En cuanto hay conexión, actuamos según lo decidido en la pantalla previa
	if LobbyIntent.is_host_intent():
		status_label.text = "Creando sala..."
		WebSocketClient.send({ "type": "create_room" })
	else:
		status_label.text = "Uniéndose a la sala %s..." % LobbyIntent.pending_join_code
		WebSocketClient.send({
			"type": "join_room",
			"code": LobbyIntent.pending_join_code
		})


func _on_socket_disconnected() -> void:
	status_label.text = "Conexión perdida."
	start_button.disabled = true


# ── Mensajes de red ──────────────────────────────────────────────────────────

func _on_message_received(data: Dictionary) -> void:
	match data.get("type"):
		"welcome":
			my_network_id = data["id"]
			room_code = data["room_code"]
			is_host = LobbyIntent.is_host_intent()

			if my_network_id not in connected_ids:
				connected_ids.append(my_network_id)

			var existing: Array = data.get("existing_players", [])
			for id in existing:
				var int_id := int(id)
				if int_id not in connected_ids:
					connected_ids.append(int_id)
 
			room_code_label.text = "Código de sala: %s" % room_code
			start_button.visible = is_host
			_refresh_player_list()

		"player_joined":
			var id: int = data["id"]
			if id not in connected_ids:
				connected_ids.append(id)
			_refresh_player_list()

		"player_left":
			var id: int = data["id"]
			connected_ids.erase(id)
			_refresh_player_list()

		"error":
			status_label.text = data.get("message", "Error desconocido")

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

func _refresh_player_list() -> void:
	for child in player_list_container.get_children():
		child.queue_free()

	var sorted_ids := connected_ids.duplicate()
	sorted_ids.sort()

	for id in sorted_ids:
		var label := Label.new()
		var suffix := " (tú)" if id == my_network_id else ""
		label.text = "Jugador %d%s" % [id, suffix]
		label.label_settings = LabelSettings.new()
		#label.set("theme_override_colors/font_color", Color("2c2c2c"))
		#label.add_theme_font_override("font", load("res://assets/Pangolin-Regular.ttf"))
		label.label_settings.font_color = Color("2c2c2c")
		label.label_settings.font_size = 56
		label.label_settings.font = load("res://assets/Pangolin-Regular.ttf")
		player_list_container.add_child(label)

	status_label.text = "Jugadores en sala: %d / %d" % [connected_ids.size(), MAX_PLAYERS_PER_ROOM]

	#if is_host:
		#start_button.disabled = connected_ids.size() < 1


# ── Inicio de partida ────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	print("enviamos msg")
	if _game_starting:
		return
	
	var sorted_ids := connected_ids.duplicate()
	sorted_ids.sort()

	WebSocketClient.send({
		"type": "start_game",
		"player_ids": sorted_ids
	})


func _start_match(sorted_network_ids: Array[int]) -> void:
	var config := _build_game_config(sorted_network_ids)
	GameConfigHandler.set_config(config)
	SceneLoader.change_scene("res://src/main_game/chinchon/MainRefactor.tscn", "LobbyMenu")


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
	config.is_host = is_host
	return config


func _on_start_button_mouse_entered() -> void:
	$OnlineMode/StartButton/Label.visible = true
	pass # Replace with function body.


func _on_start_button_mouse_exited() -> void:
	$OnlineMode/StartButton/Label.visible = false
	pass # Replace with function body.
