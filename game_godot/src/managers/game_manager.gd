extends Node2D
class_name GameManager

signal round_closed

# ── Exports de escena ────────────────────────────────────────────────────────
@export var deck:         CardSlot
@export var slot:         CardSlot
@export var card_manager: CardManager
@export var player_hands: Array[Node2D]
@export var card_scene:   PackedScene
@export var card_database: Script

@export var turn_controller:  TurnController
@export var round_controller: RoundController

# ── Estado ───────────────────────────────────────────────────────────────────
var config: GameConfig
var agents: Dictionary = {}
var game_ended  := true
var card_drawn_this_turn := false
var current_round := 0
# True en cuanto queda un solo jugador vivo: la partida ya esta guardada y
# no se juegan mas rondas.
var match_over := false
# Id de la fila de matches, una vez escrita. Online lo pone el anfitrion y
# lo reparte por la sala, asi que acaba siendo el mismo en todas las maquinas.
var saved_match_id := -1

static var deck_selected := "española"

var CARD_SPACING  = 150
var GROUP_SPACING = 220


func setup() -> void:
	config = GameConfigHandler.take_config()
	_build_agents()
	turn_controller.setup(config.players, 0)
	turn_controller.turn_started.connect(_on_turn_started)
	deck.set_collision_mask(4)
	slot.set_collision_mask(2)

	if config.is_online:
		WebSocketClient.message_received.connect(_on_network_message)

	start_game()

func _deck_generation():
	if config.is_online and not config.is_host:
		_generate_deck(false)
		_deck_sync_received = false
		await _wait_for_deck_sync()
	else:
		_generate_deck(true)
		if config.is_online:
			print("Envio el orden a todos")
			_broadcast_deck_order()
			await _wait_for_deck_sync()

# ── Sincronización del mazo (solo online) ───────────────────────────────────

var _deck_sync_received := false

func _broadcast_deck_order() -> void:
	var order: Array = []
	for card in deck.cards:
		order.append(card.id)
	print(order)
	WebSocketClient.send({
		"type": "deck_sync",
		"order": order
	})


func _wait_for_deck_sync() -> void:
	while not _deck_sync_received:
		await get_tree().process_frame


func _apply_deck_order(order: Array) -> void:
	var by_id := {}
	for card in deck.cards:
		by_id[card.id] = card

	var new_order: Array = []
	for id in order:
		if by_id.has(id):
			new_order.append(by_id[id])
		else:
			push_error("Carta recibida en deck_sync no encontrada localmente: %s" % id)

	deck.cards = new_order
	deck.top_card = deck.cards[0] if deck.cards.size() > 0 else null
	#deck.update_visual()

	_deck_sync_received = true


func _on_network_message(data: Dictionary) -> void:
	match data.get("type"):
		"game_action":
			var sender_id: int = data.get("from")
			var agent := _find_network_agent_by_id(sender_id)
			if agent:
				agent.receive_remote_action(data["action"])
 
		"deck_sync":
			print(data["order"])
			_apply_deck_order(data["order"])
			
		"player_eliminated":
			_apply_player_elimination(data["player_id"])
 
		"next_round":
			restart_game()

		"match_saved":
			saved_match_id = int(data["match_id"])

func _find_network_agent_by_id(network_id: int) -> NetworkAgent:
	for agent in agents.values():
		if agent is NetworkAgent and agent.remote_network_id == network_id:
			return agent
	return null

func _find_player_by_id(player_id: int) -> PlayerData:
	for p in config.players:
		if p.id == player_id:
			return p
	return null

func _build_agents() -> void:
	for player in config.players:
		var agent: PlayerAgent
		match player.type:
			PlayerData.Type.HUMAN:
				agent = HumanAgent.new(player)
				player_hands[get_visual_slot_index(player)].set_visibility(true)
				if config.is_online and player.is_local:
					agent.action_taken.connect(_broadcast_local_action)
			PlayerData.Type.AI:
				agent = AIAgent.new(player)
			PlayerData.Type.NETWORK:
				agent = NetworkAgent.new(player)
		agent.action_taken.connect(_on_action_taken.bind(player))
		agents[player.id] = agent

# ── Inicio de partida ────────────────────────────────────────────────────────
func _ready() -> void:
	if (!GameConfigHandler.has_config()):
		var cfg = GameConfig.new()
		var human = PlayerData.new()
		human.id = num_players
		human.display_name = "Tú"
		human.type = PlayerData.Type.HUMAN
		human.hand_idx = num_players
		human.is_local = true
		num_players += 1
		cfg.players.append(human)
		for i in ConfigManager.get_selected_bots():
			cfg.players.append(create_bot("Paco"))
		GameConfigHandler.set_config(cfg)
		
	setup()

func start_game() -> void:
	await _deck_generation()
	game_ended = false
	current_round += 1
	await _deal_cards()
	var c = draw_card()
	card_manager.animate_card_to_position(c, slot.position, slot.rotation)
	slot.add_card_to_stack(c)
	turn_controller.start_first_turn()

func restart_game() -> void:
	for h in player_hands:
		h.clear_hand()
	deck.empty_stack()
	slot.empty_stack()
	card_manager.clear_cards_in_scene()
	start_game()

# ── Turno ────────────────────────────────────────────────────────────────────
func _on_turn_started(player: PlayerData) -> void:
	card_drawn_this_turn = false
	var game_state = _build_game_state(player)
	agents[player.id].request_action(game_state)

func _build_game_state(player: PlayerData) -> Dictionary:
	return {
		"hand":        player_hands[get_visual_slot_index(player)].player_hand,
		"top_discard": slot.top_card,
		"tree":        get_tree(),
	}

func get_visual_slot_index(player: PlayerData) -> int:
	# player_hands[0] = Bottom, [1] = Left, [2] = Top, [3] = Right
	var local_player := _get_local_player()
	if local_player == null:
		return player.hand_idx

	var num_players := config.players.size()
	var offset := (player.hand_idx - local_player.hand_idx + num_players) % num_players
	return offset

func _on_action_taken(action: Dictionary, player: PlayerData) -> void:
	if action.get("type") in ["discard", "close"] and action.has("card_id") and not action.has("card"):
		var resolved_card = _find_card_in_hand(action["card_id"], player)
		if resolved_card == null:
			push_error("No se encontró la carta %s en la mano del jugador %d" % [action["card_id"], player.id])
			return
		action["card"] = resolved_card
	match action["type"]:
		"draw":
			var card = draw_card() if action["source"] == "deck" else draw_discard()
			card.flipped = (player.type != PlayerData.Type.HUMAN or not player.is_local)
			player_hands[get_visual_slot_index(player)].add_card_to_hand(card)
			card_drawn_this_turn = true
		"discard":
			_do_discard(action["card"], player)
			turn_controller.advance()
		"close":
			game_ended = true
			_do_discard(action["card"], player)
			await get_tree().create_timer(0.2).timeout
			end_round()

func _broadcast_local_action(action: Dictionary) -> void:
	var payload := action.duplicate()

	if payload.has("card"):
		payload["card_id"] = payload["card"].id
		payload.erase("card")

	WebSocketClient.send({
		"type": "game_action",
		"action": payload
	})

func _find_card_in_hand(card_id, player: PlayerData):
	var hand = player_hands[get_visual_slot_index(player)].player_hand
	for card in hand:
		if card.id == card_id:
			return card
	return null

func _do_discard(card, player: PlayerData) -> void:
	card.flipped = game_ended
	card_manager.animate_card_to_position(card, slot.position, slot.rotation)
	slot.add_card_to_stack(card)
	player_hands[get_visual_slot_index(player)].remove_card_from_hand(card)

# ── Fin de ronda ─────────────────────────────────────────────────────────────
func end_round() -> void:
	round_closed.emit()
	for hand_node in player_hands:
		hand_node.show_hand()

	await get_tree().create_timer(0.15).timeout

	# Construir mapa id→hand para el evaluador
	var hands_map: Dictionary = {}
	for player in config.players:
		hands_map[player.id] = player_hands[get_visual_slot_index(player)].player_hand

	var results = round_controller.evaluate_round(config.players, hands_map)

	_check_player_scores()

	for r in results:
		var hand_node = player_hands[get_visual_slot_index(r["player"])]
		_display_combinations(hand_node, r)

	# La partida se acaba cuando solo queda un jugador que no haya llegado
	# a max_points. Las rondas no la terminan: se juegan las que hagan falta.
	# El flag evita guardar dos veces si end_round se vuelve a entrar.
	if not match_over and config.players.size() > 1 \
			and turn_controller.active_player_count() <= 1:
		match_over = true
		_save_match()

func _check_player_scores():
	for pl in config.players:
		if pl.score >= config.max_points and !pl.eliminated:
			_eliminate_player(pl)

func _eliminate_player(player: PlayerData) -> void:
	print("eliminamos al jugador ", player.id)
	if config.is_online and config.is_host:
		WebSocketClient.send({
			"type": "player_eliminated",
			"player_id": player.id
		})
	_apply_player_elimination(player.id)
 
 
# Pasar a la ronda siguiente (el boton "Volver" de la mesa).
func _advance_to_next_round() -> void:
	if match_over:
		return

	if not config.is_online:
		restart_game()
		return

	# Online la ronda la abre el anfitrion: manda "next_round" y el servidor
	# se lo devuelve a todos, el incluido, asi que la mesa se reinicia a la
	# vez en todas las maquinas. Al resto el boton no les hace nada.
	if config.is_host:
		WebSocketClient.send({ "type": "next_round" })


func _apply_player_elimination(net_id : int):
	var elim := _find_player_by_id(net_id)
	
	if elim == null:
		return
	elim.eliminated = true
	turn_controller.remove_player(elim.id)

# ── Guardado de la partida ──────────────────────────────────────────────────

# Escribe la partida y sus asientos en la base de datos, y suma la victoria o
# la derrota a cada usuario que la haya jugado.
#
# ONLINE: la guarda SOLO el anfitrion, y sale UNA fila de matches con todos
# los asientos identificados. El nombre y el user_id de cada jugador llegan
# desde el lobby (el servidor los reparte al entrar en la sala), asi que la
# partida aparece en el historial de todos, no solo en el del que la escribio.
# Si guardara cada cliente saldrian tantas partidas como jugadores, cada una
# con un solo asiento con usuario.
#
# El id que devuelve el INSERT se reparte por la sala en "match_saved": es la
# referencia comun para pedir despues los detalles de esa partida.
func _save_match() -> void:
	if config.is_online and not config.is_host:
		return

	var seats: Array = []
	var results: Array = []
	var seen_users := {}
	var anyone_registered := false

	# El asiento sale de la posicion en config.players, no de hand_idx: ese
	# es un indice visual y match_players.seat solo admite de 1 a 4, asi que
	# un hand_idx mayor tumbaria el INSERT entero, partida incluida.
	for i in config.players.size():
		var p: PlayerData = config.players[i]
		var won := _is_winner(p)
		var uid = _seat_user_id(p)

		# match_players tiene UNIQUE (match_id, user_id): la misma cuenta no
		# puede ocupar dos asientos. Pasa al probar con dos pestañas y el
		# mismo login, y tumbaria el INSERT entero, asi que el segundo
		# asiento se apunta sin usuario en vez de perder la partida.
		if uid != null and seen_users.has(uid):
			push_warning("la cuenta %d ocupa dos asientos, el segundo se guarda sin usuario" % uid)
			uid = null

		if uid != null:
			seen_users[uid] = true
			anyone_registered = true
			results.append({ "user_id": uid, "won": won })

		seats.append({
			"seat":      i + 1,
			"user_id":   uid,
			"name":      p.display_name,
			"kind":      _db_kind(p),
			"score":     p.score,
			"is_winner": won,
		})

	# Una partida en la que no juega ninguna cuenta no saldria en ningun
	# historial, asi que no se guarda.
	if not anyone_registered:
		return

	Database.save_match(config.is_online, config.max_points, deck_selected, seats,
		func(res: Dictionary) -> void:
			if not res.ok:
				push_error("no se pudo guardar la partida: %s" % res.error)
				return

			if res.rows.is_empty():
				push_error("la partida se guardo pero no devolvio id")
				return

			saved_match_id = int(res.rows[0]["match_id"])
			print("partida %d guardada con %d asientos" % [saved_match_id, res.rows.size()])

			if config.is_online:
				WebSocketClient.send({
					"type": "match_saved",
					"match_id": saved_match_id,
				})
	)

	Database.add_results(results, func(res: Dictionary) -> void:
		if not res.ok:
			push_error("no se pudieron guardar los resultados: %s" % res.error)
	)


# El user_id con el que se apunta un asiento, o null si detras no hay cuenta
# (una IA, o alguien jugando de invitado). En local el user_id no viaja por
# ningun sitio, asi que el del jugador de esta maquina se coge de Auth.
func _seat_user_id(player: PlayerData):
	var uid := Auth.user_id if player.is_local else player.user_id
	return uid if uid > 0 else null


# Gana el que se queda sin llegar a max_points, que es justo el que no esta
# eliminado cuando la partida acaba. Si en la ultima ronda pasan del limite
# todos a la vez no queda nadie vivo, y entonces gana el que menos sume.
func _is_winner(player: PlayerData) -> bool:
	if turn_controller.active_player_count() > 0:
		return not player.eliminated
	return player.score == _best_score()


func _best_score() -> int:
	var best := config.players[0].score
	for p in config.players:
		if p.score < best:
			best = p.score
	return best


# Los mismos nombres que acepta la columna kind de match_players.
func _db_kind(player: PlayerData) -> String:
	match player.type:
		PlayerData.Type.AI:      return "ai"
		PlayerData.Type.NETWORK: return "network"
		_:                       return "human"

func _display_combinations(hand_node: Node2D, result: Dictionary) -> void:
	var origin      = hand_node.get_hand_origin()
	var rot         = hand_node.get_card_rotation()
	var is_vertical = hand_node.hand_position in [
		hand_node.HandPosition.LEFT,
		hand_node.HandPosition.RIGHT
	]
	if is_vertical:
		if hand_node.hand_position == hand_node.HandPosition.LEFT:
			origin += Vector2(250, 0)
		else:
			origin += Vector2(-250, 0)
	else:
		if hand_node.hand_position == hand_node.HandPosition.BOTTOM:
			origin += Vector2(0, -250)
		else:
			origin += Vector2(0, 250)

	var total_span := 0.0
	for i in range(result["groups"].size()):
		total_span += max(result["groups"][i].size() - 1, 0) * CARD_SPACING
		if i < result["groups"].size() - 1:
			total_span += GROUP_SPACING

	var cursor := -total_span / 2.0

	for group in result["groups"]:
		for i in range(group.size()):
			var card_node = _find_card_node_anywhere(hand_node.player_hand, group[i], player_hands)
			if card_node:
				var offset = cursor + i * CARD_SPACING
				var target = origin + (Vector2(0, offset) if is_vertical else Vector2(offset, 0))
				var tween  = get_tree().create_tween()
				tween.parallel().tween_property(card_node, "position", target, 0.15)
				tween.parallel().tween_property(card_node, "rotation", rot,    0.15)
		cursor += max(group.size() - 1, 0) * CARD_SPACING + GROUP_SPACING

	for card_data in result["leftover"]:
		var card_node = _find_card_node(hand_node.player_hand, card_data)
		if card_node:
			card_node.modulate = Color(1.0, 0.769, 0.758, 1.0)

# ── Input humano (desde raycasts) ────────────────────────────────────────────
func _on_input_manager_left_mouse_button_clicked() -> void:
	if game_ended:
		return
	var local_player = _get_local_player()
	if turn_controller.current_player != local_player:
		return
	var agent = agents[local_player.id] as HumanAgent
	if agent == null:
		return

	var space  = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	var result = space.intersect_point(params)
	if result.is_empty():
		return

	match result[0].collider.collision_mask:
		1:  # CARD
			if card_drawn_this_turn and !result[0].collider.get_parent().flipped:
				agent.notify_discard(result[0].collider.get_parent())
		4:  # DECK
			if not card_drawn_this_turn:
				agent.notify_draw("deck")
		2:  # SLOT
			if not card_drawn_this_turn:
				agent.notify_draw("discard")


func _on_input_manager_right_mouse_button_clicked() -> void:
	var local_player = _get_local_player()
	if turn_controller.current_player != local_player:
		return
	if not card_drawn_this_turn:
		return
	var agent = agents[local_player.id] as HumanAgent
	if agent == null:
		return

	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = 1
	var result = space.intersect_point(params)
	if result.is_empty():
		return
	agent.notify_close(result[0].collider.get_parent())

# ── Helpers ──────────────────────────────────────────────────────────────────
func _get_local_player() -> PlayerData:
	for p in config.players:
		if p.is_local:
			return p
	return null

func draw_card() -> Node2D:
	if deck.cards.is_empty():
		_reshuffle_deck()
	return deck.get_top_card()

func draw_discard() -> Node2D:
	return slot.get_top_card()

func _deal_cards() -> void:
	print("deal cards")
	for i in 7:
		for player in config.players:
			if player.eliminated:
				continue
			var c = draw_card()
			player_hands[get_visual_slot_index(player)].add_card_to_hand(c)
			await get_tree().create_timer(0.05).timeout

func _reshuffle_deck() -> void:
	for c in slot.cards:
		deck.add_card_to_stack(c)
		c.flipped = true
		card_manager.animate_card_to_position(c, deck.position, deck.rotation)
	slot.empty_stack()
	deck.suffle_stack()

func _generate_deck(shuffle: bool = true) -> void:
	for copy_index in 2:
		for suit in card_database.SUITS:
			for number in card_database.NUMBERS:
				var img_path = "res://assets/cards/%s/%s_%d.png" % [deck_selected, suit["id"], number["value"]]
				var card = {
					"id":     "%s_%d_c%d" % [suit["id"], number["value"], copy_index],
					"suit":   suit,
					"number": number,
					"img":    img_path,
					"deck":   deck_selected,
				}
				var card_object = card_manager.instantiate_card(card)
				card_object.flipped = true
				card_object.position = deck.position
				deck.add_card_to_stack(card_object)

	if shuffle:
		deck.suffle_stack()

func _find_card_node(hand: Array, card_data) -> Node:
	for node in hand:
		if node.suit == card_data.suit and node.value == card_data.value:
			hand.erase(node)
			return node
	return null

func _find_card_node_anywhere(hand: Array, card_data, all_hands: Array) -> Node:
	var node = _find_card_node(hand, card_data)
	if node:
		return node
	
	for h in all_hands:
		if h.player_hand == hand:
			continue
		node = _find_card_node(h.player_hand, card_data)
		if node:
			return node
	return null

static func change_deck(new_deck: String) -> void:
	deck_selected = new_deck

var num_players := 0

func create_bot(n) -> PlayerData:
	var bot = PlayerData.new()
	bot.id = num_players
	bot.display_name = n
	bot.type = PlayerData.Type.AI
	bot.hand_idx = num_players
	num_players += 1
	return bot

func _on_gente_button_up() -> void:
	var cfg = GameConfig.new()
	var human = PlayerData.new()
	human.id = num_players
	human.display_name = "Tú"
	human.type = PlayerData.Type.HUMAN
	human.hand_idx = num_players
	human.is_local = true
	num_players += 1
	cfg.players.append(human)
	cfg.players.append(create_bot("Paco"))
	cfg.players.append(create_bot("Manolo"))
	cfg.players.append(create_bot("El Anemias"))
	setup()
	$"../JugarModo".visible = false
	start_game()


func _on_restart_pressed() -> void:
	_advance_to_next_round()
