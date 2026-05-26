extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_SLOT = 2
const COLLISION_MASK_DECK = 4

var timer
var game_ended := false

var players : int = 4
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
@export var player_hands : Array[Node2D]
@export var card_database : Script
@export var card_manager : Node2D

@export var punt_player : Label
@export var punt_oppo : Label

@export_enum("Malo", "Decente", "Imposible") var difficulty

var evaluator := CardEvaluator.new()

var ai := OpponentAI.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer = $"../Timer"
	timer.one_shot = true
	timer.wait_time = 1.0
	generate_deck()
	player_hand.set_visibility(true)
	#generate_deck()
	#start_game()

func _process(delta: float) -> void:
	if deck.cards.size() == 0:
		reshuffle_deck()

func start_game():
	#TODO: for each player draw 7 cards
	for i in 7:
		for j in players:
			var c = draw_card()
			add_card_to_player_hand(c, j)
			await get_tree().create_timer(0.05).timeout
	var c = draw_card()
	card_manager.animate_card_to_position(c, slot.position, slot.rotation)
	slot.add_card_to_stack(c)

func _on_solo_button_up() -> void:
	$"../JugarModo".visible = false
	$"../SoloDificultadIA".visible = true

func _on_única_button_up() -> void:
	$"../SoloDificultadIA".visible = false
	start_game()

func end_turn():
	card_drawn_this_turn = false
	active_player += 1
	if active_player >= players:
		active_player = 0
		return
	opponent_turn()

func get_card_in_slot() -> Node2D:
	return slot.top_card 


func opponent_turn():
	timer.start()
	await timer.timeout
	if game_ended:
		return

	var draw_decision = ai.decide_draw(player_hands[active_player].player_hand, slot.top_card)
	var c
	if draw_decision == "deck":
		c = draw_card()
	else:
		c = draw_discard()
	
	c.flipped = true
	add_card_to_player_hand(c, active_player)

	timer.start()
	await timer.timeout

	var to_discard = ai.decide_discard(player_hands[active_player].player_hand)
	if ai.should_close(player_hands[active_player].player_hand):
		opponent_close(to_discard)
		return
	card_manager.hand_card_to_slot(player_hands[active_player], to_discard)
	
	end_turn()

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
					card_manager.animate_card_to_position(card_found, slot.position, slot.rotation)
					slot.add_card_to_stack(card_found)
					player_hand.remove_card_from_hand(card_found)
					end_turn()
			COLLISION_MASK_DECK:
				print("deck")
				#deck_reference.draw_card()
			COLLISION_MASK_SLOT:
				print("slot")
				if !card_drawn_this_turn:
					var sl = result[0].collider.get_parent().name
					var c
					if sl == "Deck":
						c = draw_card()
					else:
						c =draw_discard()
					add_card_to_player_hand(c, 0)
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
			card_manager.animate_card_to_position(card_found, slot.position, slot.rotation)
			slot.add_card_to_stack(card_found)
			player_hand.remove_card_from_hand(card_found)
			game_ended = true

func opponent_close(card):
	card.flipped = true
	card_manager.animate_card_to_position(card, slot.position, slot.rotation)
	slot.add_card_to_stack(card)
	player_hands[active_player].remove_card_from_hand(card)
	game_ended = true
	await get_tree().create_timer(0.2).timeout
	end_round()

func close_game():
	raycast_right_click()
	#TODO: iniciar puntuaciones
	if game_ended:
		end_round()

func end_round():
	for i in player_hands:
		i.show_hand()
	#player_hand.show_hand()
	#opponent_hand.show_hand()
	#opponent_hand.hand_y_position += 50
	#opponent_hand.update_hand_positions()

	await get_tree().create_timer(0.15).timeout 

	for i in player_hands:
		_display_combinations(i, i.player_hand)


func _display_combinations(hand_node, hand):
	var result = evaluator.check_best_hand(hand)

	var CARD_SPACING = 150
	var GROUP_SPACING = 220

	var origin = hand_node.get_hand_origin()
	var rot    = hand_node.get_card_rotation()
	var is_vertical = hand_node.hand_position == hand_node.HandPosition.LEFT or \
	 hand_node.hand_position == hand_node.HandPosition.RIGHT

	var total_span = 0.0
	for i in range(result["groups"].size()):
		var group = result["groups"][i]
		total_span += max(group.size() - 1, 0) * CARD_SPACING
		if i < result["groups"].size() - 1:
			total_span += GROUP_SPACING

	var cursor = -total_span / 2.0 

	for group in result["groups"]:
		for i in range(group.size()):
			var card_node = _find_card_node(hand, group[i])
			if card_node:
				var offset = cursor + i * CARD_SPACING
				var target = origin + (Vector2(0, offset) if is_vertical else Vector2(offset, 0))
				var tween = get_tree().create_tween()
				tween.parallel().tween_property(card_node, "position", target, 0.15)
				tween.parallel().tween_property(card_node, "rotation", rot, 0.15)
		cursor += max(group.size() - 1, 0) * CARD_SPACING + GROUP_SPACING

	for card_data in result["leftover"]:
		var card_node = _find_card_node(hand, card_data)
		if card_node:
			card_node.position.y -= 10
			card_node.modulate = Color(1.0, 0.769, 0.758, 1.0)

func _find_card_node(hand, card_data) -> Node:
	for node in hand:
		if node.suit == card_data["suit"] and node.value == card_data["value"]:
			return node
	return null


func draw_card():
	var card = deck.get_top_card()
	if deck.cards.size() == 0:
		reshuffle_deck()
	return card

func draw_discard():
	var card = slot.get_top_card()
	return card


func reshuffle_deck():
	slot.suffle_stack()
	for c in slot.cards:
		deck.add_card_to_stack(c)
		c.flipped = true
		card_manager.animate_card_to_position(c, deck.position, deck.rotation)
	slot.empty_stack()

func add_card_to_player_hand(card, idx):
	player_hands[idx].add_card_to_hand(card)

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
