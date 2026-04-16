extends Node

var timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer = $"../Timer"
	timer.one_shot = true
	timer.wait_time = 1.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_end_turn_button_pressed() -> void:
	opponent_turn()

func opponent_turn():
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	
	$"../Deck".draw_card_opponent()
	timer.start()
	await timer.timeout
	
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true
	$"../Deck".card_drawn_this_turn = false
