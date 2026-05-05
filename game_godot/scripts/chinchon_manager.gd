extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_SLOT = 2
const COLLISION_MASK_DECK = 4

var timer
var game_ended := false

var players = []
var active_player = 0
var card_drawn_this_turn := false

@export var deck : Node2D
@export var slot : Node2D
@export var card_in_slot : Node2D

var card_textures = {}

static var deck_selected = "española"

@export var card_scene : PackedScene
@export var player_hand : Node2D
@export var opponent_hand : Node2D
@export var card_database : Script
@export var card_manager : Node2D

@export var punt_player : Label
@export var punt_oppo : Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer = $"../Timer"
	timer.one_shot = true
	timer.wait_time = 1.0
	generate_deck()
	start_game()

func _process(delta: float) -> void:
	print(deck.cards.size())
	if deck.cards.size() == 0:
		reshuffle_deck()

func start_game():
	#TODO: for each player draw 7 cards
	for i in 7:
		var c = draw_card()
		add_card_to_player_hand(c,0)
		await get_tree().create_timer(0.1).timeout
		c = draw_card()
		c.flipped = true
		add_card_to_player_hand(c,1)
		await get_tree().create_timer(0.1).timeout
	var c = draw_card()
	card_manager.animate_card_to_position(c, slot.position)
	slot.add_card_to_stack(c)


func end_turn():
	card_drawn_this_turn = false
	active_player = 1
	#TODO: active_player++
	opponent_turn()

func get_card_in_slot() -> Node2D:
	return slot.top_card 


func opponent_turn():
	timer.start()
	await timer.timeout
	if game_ended:
		print("OH NO")
		return
	var c = draw_card()
	c.flipped = true
	add_card_to_player_hand(c,1)
	timer.start()
	await timer.timeout
	var rand_idx = randi_range(0, opponent_hand.player_hand.size() - 1)
	card_manager.opponent_card_to_slot(opponent_hand.player_hand[rand_idx])
	active_player = 0

func generate_deck():
	for suit in card_database.SUITS:
		for number in card_database.NUMBERS:
			var img_path =  "res://assets/cards/%s/%s_%d.png" % [deck_selected, suit["id"], number["value"]]
			#print("path: %s", img_path)
			card_textures[img_path] = load(img_path)
			var card = {
				"id": "%s_%d" % [suit["id"], number["value"]],
				"suit": suit,
				"number": number,
				"img": img_path,
				"deck": deck_selected,
			}
			var card_object = card_manager.instantiate_card(card)
			card_object.flipped = true
			card_object.position = deck.position
			#print("imagen cargada %s", img_path)
			deck.add_card_to_stack(card_object)
	deck.suffle_stack()

func raycast_click():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		print(result_collision_mask)
		match result_collision_mask:
			COLLISION_MASK_CARD:
				var card_found = result[0].collider.get_parent()
				if card_found and card_drawn_this_turn:
					card_manager.animate_card_to_position(card_found, slot.position)
					slot.add_card_to_stack(card_found)
					player_hand.remove_card_from_hand(card_found)
					end_turn()
			COLLISION_MASK_DECK:
				print("deck")
				#deck_reference.draw_card()
			COLLISION_MASK_SLOT:
				print("slot")
				if !card_drawn_this_turn:
					var sl = result[0].collider.get_parent()
					var card = sl.get_top_card()
					add_card_to_player_hand(card, 0)
					card_drawn_this_turn = true


func raycast_right_click():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var card_found = result[0].collider.get_parent()
		if card_found:
			card_found.flipped = true
			card_manager.animate_card_to_position(card_found, slot.position)
			slot.add_card_to_stack(card_found)
			player_hand.remove_card_from_hand(card_found)
			game_ended = true

func close_game():
	raycast_right_click()
	#TODO: iniciar puntuaciones
	if game_ended:
		end_round()

func end_round():
	player_hand.show_hand()
	opponent_hand.show_hand()
	opponent_hand.hand_y_position += 50
	opponent_hand.update_hand_positions()

	await get_tree().create_timer(0.15).timeout 

	_display_combinations(player_hand.player_hand, 0)
	_display_combinations(opponent_hand.player_hand, 1)

func _display_combinations(hand, idx):
	var result = check_best_hand(hand)
	var points_label = punt_player if idx == 0 else punt_oppo
	points_label.text = str(result["leftover_points"])
	
	var base_y = 750 if idx == 0 else 250
	var CARD_SPACING = 150
	var GROUP_SPACING = 220
	var screen_center = get_viewport().size.x / 2.0
	

	var total_width = 0
	for group in result["groups"]:
		total_width += group.size() * CARD_SPACING
		total_width += GROUP_SPACING 
	total_width -= GROUP_SPACING
	
	var cursor_x = screen_center - total_width / 2.0
	
	for group in result["groups"]:
		for card_data in group:
			var card_node = _find_card_node(hand, card_data)
			if card_node:
				card_node.position = Vector2(cursor_x, base_y)
				cursor_x += CARD_SPACING
		cursor_x += GROUP_SPACING
	
	for card_data in result["leftover"]:
		var card_node = _find_card_node(hand, card_data)
		if card_node:
			card_node.modulate = Color(1.0, 0.769, 0.758, 1.0)

func _find_card_node(hand, card_data) -> Node:
	for node in hand:
		if node.suit == card_data["suit"] and node.value == card_data["value"]:
			return node
	return null

func check_best_hand(cards: Array) -> Dictionary:
	var all_groups = []
	
	for suit in ["oros", "copas", "espadas", "bastos"]:
		var stairs = find_stairs(cards, suit)
		all_groups.append_array(stairs)
	
	for value in [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]:
		var group = find_group(cards, value)
		if group.size() >= 3:
			all_groups.append(group)
	
	return find_best_combination(cards, all_groups)


func find_stairs(cards: Array, suit: String) -> Array:
	var suited = cards.filter(func(c): return c.suit == suit)
	suited.sort_custom(func(a, b): return a.value < b.value)
	
	var stairs = []
	var current = []
	
	for card in suited:
		if current.is_empty():
			current.append(card)
		elif card.value == current.back().value + 1:
			current.append(card)
		elif card.value == 10 and card.value == current.back().value + 3:
			current.append(card)
		else:
			if current.size() >= 3:
				stairs.append(current.duplicate())
			current = [card]
	
	if current.size() >= 3:
		stairs.append(current.duplicate())
	
	return stairs


func find_group(cards: Array, value: int) -> Array:
	return cards.filter(func(c): return c.value == value)


func find_best_combination(cards: Array, all_groups: Array) -> Dictionary:
	var best = {
		"groups": [],
		"leftover": cards.duplicate(),
		"leftover_points": _sum_values(cards)
	}
	
	_try_combinations(cards, all_groups, [], best)
	return best


func _try_combinations(cards: Array, remaining_groups: Array, chosen: Array, best: Dictionary):
	var used = []
	for g in chosen:
		used.append_array(g)
	
	var leftover = cards.filter(func(c): return not used.has(c))
	var points = _sum_values(leftover)
	
	if points == 0:
		points = -10
	
	if points < best["leftover_points"]:
		best["groups"] = chosen.duplicate()
		best["leftover"] = leftover
		best["leftover_points"] = points
	
	for i in range(remaining_groups.size()):
		var group = remaining_groups[i]
		var conflict = false
		for card in group:
			if used.has(card):
				conflict = true
				break
		if not conflict:
			var next_groups = remaining_groups.slice(i + 1)
			_try_combinations(cards, next_groups, chosen + [group], best)


func _sum_values(cards: Array) -> int:
	var total = 0
	for c in cards:
		total += c.value
	return total

func draw_card():
	var card = deck.get_top_card()
	if deck.cards.size() == 0:
		reshuffle_deck()
	return card

func reshuffle_deck():
	slot.suffle_stack()
	for c in slot.cards:
		deck.add_card_to_stack(c)
		c.flipped = true
		card_manager.animate_card_to_position(c, deck.position)
		
	slot.empty_stack()

func add_card_to_player_hand(card, idx):
	if idx == 0:
		player_hand.add_card_to_hand(card)
	else:
		opponent_hand.add_card_to_hand(card)

func _on_input_manager_left_mouse_button_clicked() -> void:
	if active_player == 0:
		raycast_click()

func _on_input_manager_left_mouse_button_pressed() -> void:
	pass # Replace with function body.

func _on_input_manager_left_mouse_button_release() -> void:
	pass # Replace with function body.

func _on_input_manager_right_mouse_button_clicked() -> void:
	if active_player == 0 and card_drawn_this_turn:
		close_game()

static func change_deck(new_deck):
	deck_selected = new_deck
