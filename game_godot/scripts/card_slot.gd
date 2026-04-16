extends Node2D

var cards = []

func _ready() -> void:
	print($Area2D.collision_mask)

func update_visual():
	var i = 0
	for card in cards:
		if i == 0:
			card.visible = true
		else:
			await get_tree().create_timer(0.1).timeout
			card.visible = false
		i = 1

func add_card_to_slot(card):
	card.get_node("Area2D/CollisionShape2D").disabled = true
	cards.push_front(card)
	card.z_index = 0
	update_visual()
	
func get_top_card():
	var card = cards.pop_front()
	if !card:
		return
	card.visible = true
	card.get_node("Area2D/CollisionShape2D").disabled = false
	update_visual()
	return card
