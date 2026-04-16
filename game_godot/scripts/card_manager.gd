extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2

var screen_size
var card_being_dragged
var player_hand_reference

@export var input_manager : Node2D
@export var card_slot_reference : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	input_manager.connect("left_mouse_button_release", on_left_click_release)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), 
			clamp(mouse_pos.y, 0, screen_size.y))
	$"../Label".text = "Cartas en la mano " + str($"../PlayerHand".player_hand.size())

#func _input(event):
	#if event is InputEventMouseButton  and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed:
			#var card = raycast_check_for_card()
			#if card:
				#start_drag(card)
		#else:
			#finish_drag()

func start_drag(card):
	card.scale = Vector2(1, 1)
	card_being_dragged = card

func send_card_to_slot(card):
	animate_card_to_position(card, card_slot_reference.global_position)
	player_hand_reference.remove_card_from_hand(card)
	card_slot_reference.add_card_to_slot(card)

func finish_drag():
	if card_being_dragged:
		card_being_dragged.scale = Vector2(1.05, 1.05)
		var card_slot_found = raycast_check_for_card_slot()
		if card_slot_found:
			card_being_dragged.position = card_slot_found.position
			card_slot_found.add_card_to_slot(card_being_dragged)
			player_hand_reference.remove_card_from_hand(card_being_dragged)
		else:
			player_hand_reference.add_card_to_hand(card_being_dragged)
		card_being_dragged = null

#func raycast_check_for_card():
	#var space_state = get_world_2d().direct_space_state
	#var params = PhysicsPointQueryParameters2D.new()
	#params.position = get_global_mouse_position()
	#params.collide_with_areas = true
	#params.collision_mask = COLLISION_MASK_CARD
	#var result = space_state.intersect_point(params)
	#if result.size() > 0:
		#return get_card_with_highest_z_index(result)
	#return null

func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(params)
	print(result)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if (current_card.z_index > highest_z_index):
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card


func on_left_click_release():
	if card_being_dragged:
		finish_drag()


func animate_card_to_position(card, new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, 0.1)
