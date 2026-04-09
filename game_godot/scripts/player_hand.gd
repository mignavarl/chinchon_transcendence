extends Node2D

const HAND_COUNT = 8
const CARD_SCENE_PATH = "res://scenes/card.tscn"
const CARD_WIDTH = 150
const CARD_HEIGHT = 100
const HAND_Y_POSITION = 500

@export var card_scene : PackedScene

var player_hand = []
var center_screen_x
var hand_y_position

func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2
	hand_y_position = get_viewport().size.y - CARD_HEIGHT + 30
	#var card_scene = preload(CARD_SCENE_PATH)
	


func add_card_to_hand(card):
	if (card not in player_hand):
		player_hand.insert(0, card)
		update_hand_positions()
	else:
		animate_card_to_position(card, card.starting_position)
	card.get_node("Area2D/CollisionShape2D").disabled = false


func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions()

func update_hand_positions():
	for i in range(player_hand.size()):
		var new_position = Vector2(calculate_card_position(i), hand_y_position)
		var card = player_hand[i]
		card.starting_position = new_position
		animate_card_to_position(card, new_position)


func calculate_card_position(index):
	var total_width = (player_hand.size() - 1) * CARD_WIDTH
	var x_offset = center_screen_x + index * CARD_WIDTH - total_width / 2
	return x_offset


func animate_card_to_position(card, new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, 0.1)
