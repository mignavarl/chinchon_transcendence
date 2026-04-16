extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_release
signal left_mouse_button_pressed

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_SLOT = 2
const COLLISION_MASK_DECK = 4

@export var card_manager_reference : Node2D
@export var deck_reference : Node2D
@export var card_slot_reference : Node2D
@export var player_hand_reference : Node2D

var held_frame_counter = 0
var click_frame = 0

enum ClickState { IDLE, PENDING, DRAGGING }

var click_state = ClickState.IDLE
var hold_timer = 0.0
const HOLD_THRESHOLD = 0.15

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_action_D"):
		player_hand_reference.sort_hand_number()
	if Input.is_action_just_pressed("debug_action_S"):
		player_hand_reference.sort_hand_suit()
	match click_state:
		ClickState.IDLE:
			if Input.is_action_just_pressed("mouse_click"):
				click_state = ClickState.PENDING
				hold_timer = 0.0
		ClickState.PENDING:
			if Input.is_action_just_released("mouse_click"):
				print("click")
				emit_signal("left_mouse_button_clicked")
				raycast_at_cursor()
				click_state = ClickState.IDLE
			else:
				hold_timer += delta
				if hold_timer >= HOLD_THRESHOLD:
					click_state = ClickState.DRAGGING
		ClickState.DRAGGING:
			if Input.is_action_just_released("mouse_click"):
				print("suelto drag")
				emit_signal("left_mouse_button_release")
				click_state = ClickState.IDLE
			else:
				emit_signal("left_mouse_button_pressed")
				if !card_manager_reference.card_being_dragged:
					raycast_drag()

func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		print(result_collision_mask)
		if result_collision_mask == COLLISION_MASK_CARD:
			var card_found = result[0].collider.get_parent()
			if card_found and deck_reference.card_drawn_this_turn:
				card_manager_reference.send_card_to_slot(card_found)
		elif result_collision_mask == COLLISION_MASK_DECK:
			deck_reference.draw_card()
		elif result_collision_mask == COLLISION_MASK_SLOT:
			if !deck_reference.card_drawn_this_turn:
				var card = card_slot_reference.get_top_card()
				if card:
					player_hand_reference.add_card_to_hand(card)
					deck_reference.card_drawn_this_turn = true
				
func raycast_drag():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var card_found = result[0].collider.get_parent()
		if card_found:
			card_manager_reference.start_drag(card_found)
