class_name CardEvaluator
extends RefCounted

const VALID_VALUES = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]
const SUITS = ["oros", "copas", "espadas", "bastos"]


func check_best_hand(cards: Array) -> Dictionary:
	var all_groups = []
	
	for suit in ["oros", "copas", "espadas", "bastos"]:
		var stairs = find_stairs(cards, suit)
		for stair in stairs:
			if stair.size() == cards.size():
				return {
					"groups": [stair],
					"leftover": [],
					"leftover_points": -25
				}
		all_groups.append_array(stairs)
	
	for value in [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]:
		var group = find_group(cards, value)
		if group.size() >= 3:
			all_groups.append(group)
	print(all_groups)
	return find_best_combination(cards, all_groups)


func find_stairs(cards: Array, suit: String) -> Array:
	var suited = cards.filter(func(c): return c.suit == suit)
	suited.sort_custom(func(a, b): return a.value < b.value)
	
	var stairs = []
	var current = []
	
	for card in suited:
		if current.is_empty():
			current.append(card)
		elif card.value == current.back().value + 1:
			current.append(card)
		elif card.value == 10 and card.value == current.back().value + 3:
			current.append(card)
		else:
			if current.size() >= 3:
				stairs.append(current.duplicate())
			current = [card]
	
	if current.size() >= 3:
		stairs.append(current.duplicate())
	
	return stairs


func find_group(cards: Array, value: int) -> Array:
	return cards.filter(func(c): return c.value == value)


func find_best_combination(cards: Array, all_groups: Array) -> Dictionary:
	var best = {
		"groups": [],
		"leftover": cards.duplicate(),
		"leftover_points": _sum_values(cards)
	}
	
	_try_combinations(cards, all_groups, [], best)
	return best


func _try_combinations(cards: Array, remaining_groups: Array, chosen: Array, best: Dictionary):
	var used = []
	for g in chosen:
		used.append_array(g)
	
	var leftover = cards.filter(func(c): return not used.has(c))
	var points = _sum_values(leftover)
	
	if points == 0:
		points = -10
	
	if points < best["leftover_points"]:
		best["groups"] = chosen.duplicate()
		best["leftover"] = leftover
		best["leftover_points"] = points
	
	for i in range(remaining_groups.size()):
		var group = remaining_groups[i]
		
		var available = group.filter(func(c): return not used.has(c))
		
		if available.size() >= 3:
			var next_groups = remaining_groups.slice(i + 1)
			_try_combinations(cards, next_groups, chosen + [available], best)

func _sum_values(cards: Array) -> int:
	var total = 0
	for c in cards:
		total += c.value
	return total
