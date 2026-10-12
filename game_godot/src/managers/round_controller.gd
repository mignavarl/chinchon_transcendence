class_name RoundController
extends Node

signal round_ended(results: Array[Dictionary])
# results es un array ordenado igual que players:
# [{ "player": PlayerData, "points": int, "won": bool }, ...]

@export var evaluator_script: Script

var _evaluator: CardEvaluator

func _ready() -> void:
	_evaluator = CardEvaluator.new()

# Devuelve el resultado de evaluar todas las manos al final de la ronda.
# hands_map: Dictionary { player_id -> Array[card_node] }
func evaluate_round(players: Array[PlayerData], hands_map: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var min_points := INF

	for player in players:
		if player.eliminated:
			continue
		var hand = hands_map[player.id]
		var eval = _evaluator.check_best_hand(hand)
		var pts  = eval["leftover_points"]
		results.append({
			"player":  player,
			"points":  pts,
			"groups":  eval["groups"],
			"leftover": eval["leftover"],
		})
		if pts < min_points:
			min_points = pts
	
	for i in range(results.size()):
		var still_leftover = []
		for card in results[i]["leftover"]:
			var placed = false
			for j in range(results.size()):
				if _evaluator.try_attach_card(results[j]["groups"], card):
					placed = true
					break
			if not placed:
				still_leftover.append(card)
		
		var still_pts = _evaluator.sum_values(still_leftover)
		if results[i]["points"] > still_pts:
			results[i]["leftover"] = still_leftover
			results[i]["points"] = still_pts
	
	# Marcar ganadores (mínimo de puntos)
	for r in results:
		debug_results(r)
		r["won"] = (r["points"] == min_points)
	# Acumular score en PlayerData
	for r in results:
		r["player"].score += r["points"]

	round_ended.emit(results)
	return results

func debug_results(results):
	print("Player results ", results["player"].id ," :")
	print("Points: ", results["points"])
	print("Groups: ", results["groups"])
	print("Sobras: ", results["leftover"])
