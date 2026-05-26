extends Node2D

var starting_position
var starting_rotation: float = 0.0
var id
var suit
var value
var img

@export var flipped = false

@export var back_img : Texture2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if img and back_img:
		if flipped:
			$CardImage.texture = back_img
		else:
			$CardImage.texture = load(img)

func init_values(in_id, in_suit, in_value, in_img):
	id = in_id
	suit = in_suit
	value = in_value
	img = in_img

func _on_area_2d_mouse_entered() -> void:
	highlight_card(self, true)

func _on_area_2d_mouse_exited() -> void:
	highlight_card(self, false)
	
func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(1.05, 1.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1, 1)
		card.z_index = 1
