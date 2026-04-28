extends Node2D

var timer
var game_ended := false

@export var deck : Node2D
@export var slot : Node2D
@export var card_in_slot : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer = $"../Timer"
	timer.one_shot = true
	timer.wait_time = 1.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func end_turn():
	var card = get_card_in_slot()
	if card and card.flipped:
		game_ended = true
	opponent_turn()

func get_card_in_slot() -> Node2D:
	return slot.top_card 

func _on_end_turn_button_pressed() -> void:
	end_turn()

func opponent_turn():
	timer.start()
	await timer.timeout
	if game_ended:
		print("OH NO")
		return
	$"../Deck".card_drawn_this_turn = false
	$"../Deck".draw_card_opponent()
	timer.start()
	await timer.timeout
	var rand_idx = randi_range(0, $"../OpponentHand".player_hand.size() - 1)
	$"../CardManager".opponent_card_to_slot($"../OpponentHand".player_hand[rand_idx])
	$"../Deck".card_drawn_this_turn = false
