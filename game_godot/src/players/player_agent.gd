class_name PlayerAgent
extends RefCounted


# Señal que emite cuando el jugador ha decidido su acción.
# action es un Dictionary con:
#   { "type": "draw",    "source": "deck"|"discard" }
#   { "type": "discard", "card": CardData }
#   { "type": "close",   "card": CardData }
signal action_taken(action: Dictionary)

var data: PlayerData

func _init(player_data: PlayerData) -> void:
	data = player_data

func request_action(game_state: Dictionary) -> void:
	pass
