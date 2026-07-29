extends Node2D

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


# ── Setup (llamado desde el lobby) ───────────────────────────────────────────
func setup(cfg: GameConfig) -> void:
	config = cfg
	_build_agents()
	turn_controller.setup(config.players)
	turn_controller.turn_started.connect(_on_turn_started)
	deck.set_collision_mask(4)
	slot.set_collision_mask(2)

func _build_agents() -> void:
	for player in config.players:
		var agent: PlayerAgent
		match player.type:
			PlayerData.Type.HUMAN:
				agent = HumanAgent.new(player)
				player_hands[player.id].set_visibility(true)
			PlayerData.Type.AI:
				agent = AIAgent.new(player)
			PlayerData.Type.NETWORK:
				pass  #TODO: agent = NetworkAgent.new(player)
		agent.action_taken.connect(_on_action_taken.bind(player))
		agents[player.id] = agent

# ── Inicio de partida ────────────────────────────────────────────────────────
func _ready() -> void:
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
	#cfg.players.append(create_bot("Manolo"))
	#cfg.players.append(create_bot("El Anemias"))
	setup(cfg)
	start_game()

func start_game() -> void:
	game_ended = false
	current_round += 1
	_generate_deck()
	_generate_deck()
	await _deal_cards()
	var c = draw_card()
	card_manager.animate_card_to_position(c, slot.position, slot.rotation)
	slot.add_card_to_stack(c)
	turn_controller.start_first_turn()

# ── Turno ────────────────────────────────────────────────────────────────────
func _on_turn_started(player: PlayerData) -> void:
	card_drawn_this_turn = false
	var game_state = _build_game_state(player)
	agents[player.id].request_action(game_state)

func _build_game_state(player: PlayerData) -> Dictionary:
	return {
		"hand":        player_hands[player.hand_idx].player_hand,
		"top_discard": slot.top_card,
		"tree":        get_tree(),
	}

func _on_action_taken(action: Dictionary, player: PlayerData) -> void:
	match action["type"]:
		"draw":
			var card = draw_card() if action["source"] == "deck" else draw_discard()
			card.flipped = (player.type != PlayerData.Type.HUMAN or not player.is_local)
			player_hands[player.hand_idx].add_card_to_hand(card)
			card_drawn_this_turn = true
			# La IA encadena su siguiente acción sola desde AIAgent.
			# El humano espera otro input; HumanAgent ya está en _waiting.
		"discard":
			_do_discard(action["card"], player)
			turn_controller.advance()
		"close":
			_do_discard(action["card"], player)
			game_ended = true
			await get_tree().create_timer(0.2).timeout
			end_round()

func _do_discard(card, player: PlayerData) -> void:
	card.flipped = false
	card_manager.animate_card_to_position(card, slot.position, slot.rotation)
	slot.add_card_to_stack(card)
	player_hands[player.hand_idx].remove_card_from_hand(card)

# ── Fin de ronda ─────────────────────────────────────────────────────────────
func end_round() -> void:
	for hand_node in player_hands:
		hand_node.show_hand()

	await get_tree().create_timer(0.15).timeout

	# Construir mapa id→hand para el evaluador
	var hands_map: Dictionary = {}
	for player in config.players:
		hands_map[player.id] = player_hands[player.hand_idx].player_hand

	var results = round_controller.evaluate_round(config.players, hands_map)

	for r in results:
		var hand_node = player_hands[r["player"].hand_idx]
		_display_combinations(hand_node, r)

func _display_combinations(hand_node: Node2D, result: Dictionary) -> void:
	const CARD_SPACING  = 150
	const GROUP_SPACING = 220

	var origin      = hand_node.get_hand_origin()
	var rot         = hand_node.get_card_rotation()
	var is_vertical = hand_node.hand_position in [
		hand_node.HandPosition.LEFT,
		hand_node.HandPosition.RIGHT
	]

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
	for i in 7:
		for player in config.players:
			var c = draw_card()
			player_hands[player.hand_idx].add_card_to_hand(c)
			await get_tree().create_timer(0.05).timeout

func _reshuffle_deck() -> void:
	for c in slot.cards:
		deck.add_card_to_stack(c)
		c.flipped = true
		card_manager.animate_card_to_position(c, deck.position, deck.rotation)
	slot.empty_stack()
	deck.suffle_stack()

func _generate_deck() -> void:
	for suit in card_database.SUITS:
		for number in card_database.NUMBERS:
			var img_path = "res://assets/cards/%s/%s_%d.png" % [deck_selected, suit["id"], number["value"]]
			var card = {
				"id":     "%s_%d" % [suit["id"], number["value"]],
				"suit":   suit,
				"number": number,
				"img":    img_path,
				"deck":   deck_selected,
			}
			var card_object = card_manager.instantiate_card(card)
			card_object.flipped = true
			card_object.position = deck.position
			deck.add_card_to_stack(card_object)
	deck.suffle_stack()

func _find_card_node(hand: Array, card_data) -> Node:
	for node in hand:
		if node.suit == card_data.suit and node.value == card_data.value:
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
	setup(cfg)
	$"../JugarModo".visible = false
	start_game()


#func _on_solo_button_up() -> void:
	#$"../JugarModo".visible = false
	#$"../SoloDificultadIA".visible = true
#
#func _on_única_button_up() -> void:
	#$"../SoloDificultadIA".visible = false
	#start_game()
