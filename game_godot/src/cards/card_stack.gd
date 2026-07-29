extends Node2D
class_name CardSlot


var cards = []
var top_card : Node2D

@export var drawable := true
@export var putable := true

func _ready() -> void:
	print($Area2D.collision_mask)

func update_visual():
	if cards.size() <= 0:
		return
	for card in cards:
		card.rotation = rotation
		card.visible = false
	cards[0].visible = true
	cards[0].z_index = 0

func add_card_to_stack(card):
	if putable:
		card.get_node("Area2D/CollisionShape2D").disabled = true
		cards.push_front(card)
		card.z_index = 1
		await get_tree().create_timer(0.2).timeout
		update_visual()
		top_card = card

func get_top_card():
	if drawable:
		var card = cards.pop_front()
		if !card:
			return
		card.visible = true
		card.get_node("Area2D/CollisionShape2D").disabled = false
		if card.flipped:
			card.flipped = false
		update_visual()
		return card
	return

func suffle_stack():
	cards.shuffle()
	top_card = cards[0]
	update_visual()

func empty_stack():
	cards.clear()
	update_visual()

func set_collision_mask(i):
	$Area2D.collision_layer = i
	$Area2D.collision_mask = i
