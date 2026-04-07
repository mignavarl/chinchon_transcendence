extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_release

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_DECK = 4

@export var card_manager_reference : Node2D
@export var deck_reference : Node2D


func _ready() -> void:
	pass

func _input(event):
	if event is InputEventMouseButton  and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_release")
			
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
				card_manager_reference.start_drag(card_found)
		elif result_collision_mask == COLLISION_MASK_DECK:
			deck_reference.draw_card()
