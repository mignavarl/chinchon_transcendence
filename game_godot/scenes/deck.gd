extends Node2D

#Poner la baraja entera
var player_deck = 8

@export var card_scene : PackedScene
@export var player_hand : Node2D
func _ready() -> void:
	pass
	
func draw_card():
	#var card_drawn = player_deck[0]
	#player_deck.erase(card_drawn)
	#if player_deck.size() == 0:
	player_deck -= 1
	if player_deck == 0:
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
	
	print("draw card")
	var new_card = card_scene.instantiate()
	#new_card.position = Vector2(1000, 0)
	new_card.position = $".".global_position
	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	player_hand.add_card_to_hand(new_card)
