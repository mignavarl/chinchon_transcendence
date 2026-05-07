class_name OpponentAI
extends RefCounted

var evaluator : CardEvaluator

func _init() -> void:
	evaluator = CardEvaluator.new()

func decide_draw(hand, discard_top) -> String:
	if discard_top == null:
		return "deck"
	var current = evaluator.check_best_hand(hand)["leftover_points"]
	var simulated = hand.duplicate()
	simulated.append(discard_top)
	var improved = evaluator.check_best_hand(simulated)["leftover_points"]
	return "discard" if improved < current else "deck"

func decide_discard(hand: Array):
	var best_points = INF
	var worst_card = null
	for card in hand:
		var simulated = hand.filter(func(c): return c != card)
		var points = evaluator.check_best_hand(simulated)["leftover_points"]
		if points < best_points:
			best_points = points
			worst_card = card
	return worst_card

func should_close(hand: Array) -> bool:
	var result = evaluator.check_best_hand(hand)
	return result["leftover_points"] <= 5
