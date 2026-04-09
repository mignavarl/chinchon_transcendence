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

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_click"):
		held_frame_counter = 0
		click_frame = 0
	elif Input.is_action_pressed("mouse_click"):
		held_frame_counter += 1
	click_frame += 1
	if click_frame > 5 and held_frame_counter:
		if held_frame_counter >= 5:
			if Input.is_action_just_released("mouse_click"):
				held_frame_counter = 0
				print("suelto")
				emit_signal("left_mouse_button_release")
			else:
				emit_signal("left_mouse_button_pressed")
				if !card_manager_reference.card_being_dragged:
					raycast_drag()
		else:
			print("hice_click")
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
			held_frame_counter = 0

#func _input(event):
	#if event is InputEventMouseButton  and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed:
			#emit_signal("left_mouse_button_clicked")
			#raycast_at_cursor()
		#else:
			#emit_signal("left_mouse_button_release")
			
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
			if card_found:
				card_manager_reference.send_card_to_slot(card_found)
				#card_manager_reference.start_drag(card_found)
		elif result_collision_mask == COLLISION_MASK_DECK:
			deck_reference.draw_card()
		elif result_collision_mask == COLLISION_MASK_SLOT:
			var card = card_slot_reference.get_top_card()
			if player_hand_reference.player_hand.size() <= 7:
				player_hand_reference.add_card_to_hand(card)
				print("añadimos a la mano %s",  card.id)
				
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
