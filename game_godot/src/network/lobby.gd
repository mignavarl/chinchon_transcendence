extends Control

# =============================================================================
# lobby_online.gd
#
# Al entrar en esta escena ya se sabe (via LobbyIntent) si el jugador
# quiere crear sala o unirse a una existente. Flujo:
#
#  1. Se conecta al WebSocket.
#  2. En cuanto conecta, manda "create_room" o "join_room" con la identidad
#     del jugador (username y user_id del login, vacíos si es invitado).
#  3. Recibe "welcome" -> guarda my_network_id, room_code, is_host y quién
#     estaba ya en la sala.
#  4. "player_joined" / "player_left" -> actualiza lista de espera.
#  5. Solo el host ve el botón "Empezar partida".
#  6. Al pulsar empezar, se manda "start_game". La plantilla la monta el
#     servidor y vuelve en el "start_game" que recibe todo el mundo: así los
#     asientos, los nombres y los user_id son los mismos en todas las máquinas
#     y el anfitrión puede guardar UNA sola partida con todos identificados.
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
# network_id -> { "id": int, "username": String, "user_id": int }
# user_id es -1 para quien juega sin cuenta.
var roster: Dictionary = {}
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
	# En cuanto hay conexión, actuamos según lo decidido en la pantalla previa.
	# La identidad va en el mensaje de entrada: el servidor la guarda y la
	# reparte, que es lo que permite ver nombres reales en la mesa y apuntar
	# la partida a nombre de cada uno.
	if LobbyIntent.is_host_intent():
		status_label.text = "Creando sala..."
		WebSocketClient.send({
			"type": "create_room",
			"username": Auth.username,
			"user_id": Auth.user_id,
		})
	else:
		status_label.text = "Uniéndose a la sala %s..." % LobbyIntent.pending_join_code
		WebSocketClient.send({
			"type": "join_room",
			"code": LobbyIntent.pending_join_code,
			"username": Auth.username,
			"user_id": Auth.user_id,
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
			# Quién es el anfitrión lo decide el servidor (el primero que
			# entró), no la pantalla anterior.
			is_host = bool(data.get("is_host", LobbyIntent.is_host_intent()))

			# El servidor no me devuelve mi propia ficha en "welcome": mi
			# nombre ya lo sé, y los demás lo reciben en "player_joined".
			_remember_player({
				"id": my_network_id,
				"username": Auth.username,
				"user_id": Auth.user_id,
			})
			for p in data.get("existing_players", []):
				_remember_player(p)

			room_code_label.text = "Código de sala: %s" % room_code
			start_button.visible = is_host
			_refresh_player_list()

		"player_joined":
			_remember_player(data)
			_refresh_player_list()

		"player_left":
			roster.erase(int(data["id"]))
			_refresh_player_list()

		"error":
			status_label.text = data.get("message", "Error desconocido")

		"start_game":
			if _game_starting:
				return
			_game_starting = true
			# La plantilla viene del servidor ya ordenada por id de jugador.
			_start_match(data.get("players", []))


# Guarda (o actualiza) la ficha de un jugador. Un invitado no manda nombre,
# así que se le pone uno para que la mesa y el historial no salgan en blanco.
func _remember_player(player: Dictionary) -> void:
	var id := int(player.get("id", -1))
	if id < 0:
		return

	var who := str(player.get("username", "")).strip_edges()
	if who.is_empty():
		who = "Jugador %d" % id

	var uid = player.get("user_id")
	roster[id] = {
		"id": id,
		"username": who,
		"user_id": int(uid) if uid != null else -1,
	}


# ── UI ───────────────────────────────────────────────────────────────────────

func _refresh_player_list() -> void:
	for child in player_list_container.get_children():
		child.queue_free()

	var sorted_ids := roster.keys()
	sorted_ids.sort()

	for id in sorted_ids:
		var label := Label.new()
		var suffix := " (tú)" if id == my_network_id else ""
		label.text = "%s%s" % [roster[id]["username"], suffix]
		label.label_settings = LabelSettings.new()
		#label.set("theme_override_colors/font_color", Color("2c2c2c"))
		#label.add_theme_font_override("font", load("res://assets/Pangolin-Regular.ttf"))
		label.label_settings.font_color = Color("2c2c2c")
		label.label_settings.font_size = 56
		label.label_settings.font = load("res://assets/Pangolin-Regular.ttf")
		player_list_container.add_child(label)

	status_label.text = "Jugadores en sala: %d / %d" % [roster.size(), MAX_PLAYERS_PER_ROOM]

	#if is_host:
		#start_button.disabled = roster.size() < 1


# ── Inicio de partida ────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if _game_starting:
		return

	# Sin plantilla: la monta el servidor con quien haya en la sala y la
	# devuelve en el "start_game" que recibimos todos.
	WebSocketClient.send({ "type": "start_game" })


func _start_match(roster_from_server: Array) -> void:
	var config := _build_game_config(roster_from_server)
	GameConfigHandler.set_config(config)
	SceneLoader.change_scene("res://src/main_game/chinchon/MainRefactor.tscn", "LobbyMenu")


# La plantilla llega del servidor ordenada por id de jugador, así que todas
# las máquinas construyen la misma lista en el mismo orden: los asientos (y
# con ellos los de match_players) coinciden.
func _build_game_config(roster_from_server: Array) -> GameConfig:
	var players: Array[PlayerData] = []
	var hand_idx := 0

	for entry in roster_from_server:
		var net_id := int(entry.get("id", -1))
		var uid = entry.get("user_id")

		var p := PlayerData.new()
		p.id = players.size()
		p.network_id = net_id
		p.user_id = int(uid) if uid != null else -1
		p.hand_idx = hand_idx
		p.is_local = (net_id == my_network_id)
		p.type = PlayerData.Type.HUMAN if p.is_local else PlayerData.Type.NETWORK
		p.display_name = str(entry.get("username", "Jugador %d" % net_id))
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


func _on_exit_button_up() -> void:
	SceneLoader.change_scene("res://src/network/online_menu.tscn", self.name)
	#TODO: desconectar al salir
