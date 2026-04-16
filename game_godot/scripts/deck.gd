extends Node2D

#Poner la baraja entera
var player_deck = []

var card_textures = {}

static var deck_selected = "española"

@export var card_scene : PackedScene
@export var player_hand : Node2D
@export var opponent_hand : Node2D
@export var card_database : Script

var card_drawn_this_turn = false

func _ready() -> void:
	generate_deck()
	for n in 7:
		draw_card()
		card_drawn_this_turn = false
		draw_card_opponent()
		card_drawn_this_turn = false
	
func draw_card():
	if card_drawn_this_turn:
		return
	var card_drawn = player_deck[0]
	player_deck.erase(card_drawn)
	if player_deck.size() == 0:
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
	
	add_card_to_player_idx(card_drawn, 0)

func draw_card_opponent():
	if card_drawn_this_turn:
		return
	var card_drawn = player_deck[0]
	player_deck.erase(card_drawn)
	if player_deck.size() == 0:
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
	
	add_card_to_player_idx(card_drawn, 42)

func add_card_to_player_idx(card_drawn, idx):
	if idx == 0:
		var new_card = card_scene.instantiate()
		new_card.get_child(0).texture = card_textures[card_drawn.img]
		new_card.init_values(card_drawn.id, card_drawn.suit, card_drawn.number, card_drawn.img)
		new_card.position = $".".global_position
		$"../CardManager".add_child(new_card)
		new_card.name = card_drawn.id
		player_hand.add_card_to_hand(new_card)
		card_drawn_this_turn = true
	else:
		var new_card = card_scene.instantiate()
		new_card.flipped = true
		#new_card.get_child(0).texture = card_textures[card_drawn.img]
		new_card.init_values(card_drawn.id, card_drawn.suit, card_drawn.number, card_drawn.img)
		new_card.position = $".".global_position
		$"../CardManager".add_child(new_card)
		new_card.name = card_drawn.id
		opponent_hand.add_card_to_hand(new_card)
		print("Roba enemigo")
		print(opponent_hand.player_hand.size())


func generate_deck():
	print("pongo el deck: ", deck_selected)
	for suit in card_database.SUITS:
		for number in card_database.NUMBERS:
			var img_path =  "res://assets/cards/%s/%s_%d.png" % [deck_selected, suit["id"], number["value"]]
			#print("path: %s", img_path)
			card_textures[img_path] = load(img_path)
			var card = {
				"id": "%s_%d" % [suit["id"], number["value"]],
				"suit": suit,
				"number": number,
				"img": img_path,
				"deck": deck_selected,
			}
			#print("imagen cargada %s", img_path)
			player_deck.append(card)
	shuffle_deck()

func shuffle_deck():
	player_deck.shuffle()
