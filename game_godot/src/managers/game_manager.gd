extends Node2D
class_name GameManager


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

static var deck_selected := "española"

var CARD_SPACING  = 150
var GROUP_SPACING = 220


func setup() -> void:
	config = GameConfigHandler.take_config()
	_build_agents()
	turn_controller.setup(config.players)
	turn_controller.turn_started.connect(_on_turn_started)
	deck.set_collision_mask(4)
	slot.set_collision_mask(2)

	if config.is_online:
		WebSocketClient.message_received.connect(_on_network_message)

	if config.is_online and not config.is_host:
		print("genero deck pero no shuffleo")
		#_generate_deck(false)
		_generate_deck(false)
		_deck_sync_received = false
		await _wait_for_deck_sync()
	else:
		print("genero deck y shuffleo")
		#_generate_deck(true)
		_generate_deck(true)
		if config.is_online:
			print("Envio el orden a todos")
			_broadcast_deck_order()
			await _wait_for_deck_sync()

	start_game()


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

func _find_network_agent_by_id(network_id: int) -> NetworkAgent:
	for agent in agents.values():
		if agent is NetworkAgent and agent.remote_network_id == network_id:
			return agent
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
			_do_discard(action["card"], player)
			game_ended = true
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
	card.flipped = false
	card_manager.animate_card_to_position(card, slot.position, slot.rotation)
	slot.add_card_to_stack(card)
	player_hands[get_visual_slot_index(player)].remove_card_from_hand(card)

# ── Fin de ronda ─────────────────────────────────────────────────────────────
func end_round() -> void:
	for hand_node in player_hands:
		hand_node.show_hand()

	await get_tree().create_timer(0.15).timeout

	# Construir mapa id→hand para el evaluador
	var hands_map: Dictionary = {}
	for player in config.players:
		hands_map[player.id] = player_hands[get_visual_slot_index(player)].player_hand

	var results = round_controller.evaluate_round(config.players, hands_map)

	for r in results:
		var hand_node = player_hands[get_visual_slot_index(r["player"])]
		_display_combinations(hand_node, r)

	# La partida son max_rounds rondas: cuando se juega la ultima, se guarda.
	if current_round >= config.max_rounds:
		_save_match()


# ── Guardado de la partida ──────────────────────────────────────────────────

# Escribe la partida y sus asientos en la base de datos, y suma la victoria o
# la derrota al usuario que juega en esta maquina.
#
# En el Chinchon gana el que MENOS puntos suma, y el score de PlayerData es el
# acumulado de todas las rondas, asi que el ganador sale de comparar totales.
# Puede haber empate y por eso is_winner va por asiento.
#
# En online cada cliente guarda su propia copia de la partida: por la red solo
# viajan los nombres, un cliente no sabe el id de usuario de los demas y sus
# asientos se apuntan sin usuario.
func _save_match() -> void:
	# Una partida de invitado no seria de nadie y no saldria en ningun
	# historial, asi que no se guarda.
	if not Auth.can_save():
		return

	var best_score := _best_score()
	var seats: Array = []

	for p in config.players:
		seats.append({
			"seat":      p.hand_idx + 1,
			"user_id":   Auth.user_id if p.is_local else null,
			"name":      p.display_name,
			"kind":      _db_kind(p),
			"score":     p.score,
			"is_winner": p.score == best_score,
		})

	Database.save_match(config.is_online, config.max_rounds, deck_selected, seats,
		func(res: Dictionary) -> void:
			if not res.ok:
				push_warning("no se pudo guardar la partida: %s" % res.error)
	)

	var local := _get_local_player()
	if local == null:
		return

	Database.add_result(Auth.user_id, local.score == best_score, func(res: Dictionary) -> void:
		if not res.ok:
			push_warning("no se pudo guardar el resultado: %s" % res.error)
	)


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
			var card_node = _find_card_node(hand_node.player_hand, group[i])
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
			var c = draw_card()
			print(c, " a ", player.display_name)
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
	restart_game()
