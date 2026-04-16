extends Node2D

const HAND_COUNT = 8
const CARD_SCENE_PATH = "res://scenes/card.tscn"
@export var CARD_WIDTH = 150
@export var CARD_HEIGHT = 100
@export var HAND_Y_POSITION = 1010

@export var card_scene : PackedScene

var player_hand = []
var center_screen_x
var hand_y_position

func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2
	hand_y_position = HAND_Y_POSITION
	#var card_scene = preload(CARD_SCENE_PATH)



func add_card_to_hand(card):
	if (card not in player_hand):
		var i = 0
		while i < player_hand.size():
			if player_hand[i].position.x > card.position.x:
				player_hand.insert(i,card)
				update_hand_positions()
				return
			i += 1
		player_hand.push_back(card)
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

func sorting_algorithm(a, b):
	if a.suit != b.suit:
		return a.suit["id"] < b.suit["id"]
	else:
		return a.value["value"] < b.value["value"]

func sort_card_by_number(a, b):
	return a.value["value"] < b.value["value"]

func sort_hand_suit():
	player_hand.sort_custom(sorting_algorithm)
	player_hand.sort_custom(sorting_algorithm)
	update_hand_positions()

func sort_hand_number():
	player_hand.sort_custom(sort_card_by_number)
	update_hand_positions()
