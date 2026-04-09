extends Node2D

signal hovered
signal hovered_off

var starting_position
var id
var suit
var value
var img

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_parent().connect_card_signals(self)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func init_values(in_id, in_suit, in_value, in_img):
	id = in_id
	suit = in_suit
	value = in_value
	img = in_img

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
