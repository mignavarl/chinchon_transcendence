extends Node2D
class_name PlayerHand

enum HandPosition { BOTTOM, TOP, LEFT, RIGHT }

@export var CARD_WIDTH = 150
@export var CARD_HEIGHT = 100
@export var CARD_SPACING = 150        # Separación entre cartas (horizontal/vertical según lado)
@export var HAND_OFFSET = 60          # Distancia desde el borde de pantalla
@export var hand_position: HandPosition = HandPosition.BOTTOM
@export var card_scene: PackedScene

var is_visible := false
var player_hand = []
var viewport_size: Vector2

func _ready() -> void:
	viewport_size = get_viewport().size

func get_hand_origin() -> Vector2:
	match hand_position:
		HandPosition.BOTTOM: return Vector2(viewport_size.x / 2, viewport_size.y - HAND_OFFSET)
		HandPosition.TOP:    return Vector2(viewport_size.x / 2, HAND_OFFSET)
		HandPosition.LEFT:   return Vector2(HAND_OFFSET, viewport_size.y / 2)
		HandPosition.RIGHT:  return Vector2(viewport_size.x - HAND_OFFSET, viewport_size.y / 2)
	return Vector2.ZERO

func get_card_rotation() -> float:
	match hand_position:
		HandPosition.TOP:   return PI          
		HandPosition.LEFT:  return -PI / 2 
		HandPosition.RIGHT: return PI / 2 
		_:                  return 0.0

func calculate_card_position(index: int) -> Vector2:
	var origin = get_hand_origin()
	var count  = player_hand.size()
	var offset = index * CARD_SPACING - (count - 1) * CARD_SPACING / 2.0

	match hand_position:
		HandPosition.BOTTOM, HandPosition.TOP:
			return origin + Vector2(offset, 0)
		HandPosition.LEFT, HandPosition.RIGHT:
			return origin + Vector2(0, offset)
	return origin

func add_card_to_hand(card) -> void:
	card.flipped = !is_visible
	if card not in player_hand:
		var inserted = false
		for i in range(player_hand.size()):
			var cur = player_hand[i]
			var is_before = false
			match hand_position:
				HandPosition.BOTTOM, HandPosition.TOP:
					is_before = cur.position.x > card.position.x
				HandPosition.LEFT, HandPosition.RIGHT:
					is_before = cur.position.y > card.position.y
			if is_before:
				player_hand.insert(i, card)
				inserted = true
				break
		if not inserted:
			player_hand.push_back(card)
		update_hand_positions()
	else:
		animate_card_to_position(card, card.starting_position, card.starting_rotation)
	card.get_node("Area2D/CollisionShape2D").disabled = false

func remove_card_from_hand(card) -> void:
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions()

func update_hand_positions() -> void:
	var rot = get_card_rotation()
	for i in range(player_hand.size()):
		var card     = player_hand[i]
		var new_pos  = calculate_card_position(i)
		card.starting_position = new_pos
		card.starting_rotation = rot
		animate_card_to_position(card, new_pos, rot)

func animate_card_to_position(card, new_position: Vector2, new_rotation: float) -> void:
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(card, "position", new_position, 0.1)
	tween.parallel().tween_property(card, "rotation", new_rotation, 0.1)

func sorting_algorithm(a, b) -> bool:
	return a.suit < b.suit if a.suit != b.suit else a.value < b.value

func sort_card_by_number(a, b) -> bool:
	return a.value < b.value

func sort_hand_suit() -> void:
	player_hand.sort_custom(sorting_algorithm)
	update_hand_positions()

func sort_hand_number() -> void:
	player_hand.sort_custom(sort_card_by_number)
	update_hand_positions()

func show_hand() -> void:
	for c in player_hand:
		c.flipped = false

func set_visibility(visible):
	is_visible = visible

func is_card_in_hand(card):
	return card in player_hand
