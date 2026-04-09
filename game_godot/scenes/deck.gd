extends Node2D

#Poner la baraja entera
var player_deck = []

@export var card_scene : PackedScene
@export var player_hand : Node2D
@export var card_database : Script

func _ready() -> void:
	generate_deck()
	
func draw_card():
	var card_drawn = player_deck[0]
	player_deck.erase(card_drawn)
	if player_deck.size() == 0:
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
	
	print("draw card")
	print(card_drawn.id)
	var new_card = card_scene.instantiate()
	new_card.get_child(0).texture = ResourceLoader.load(card_drawn.img)
	#new_card.position = Vector2(1000, 0)
	new_card.position = $".".global_position
	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	player_hand.add_card_to_hand(new_card)

func generate_deck():
	for suit in card_database.SUITS:
		for number in card_database.NUMBERS:
			var card = {
				"id": "%s_%d" % [suit["id"], number["value"]],
				"suit": suit,
				"number": number,
				"img": "res://assets/cards/%s/%d.png" % [suit["id"], number["value"]],
			}
			player_deck.append(card)
	shuffle_deck()

func shuffle_deck():
	player_deck.shuffle()
