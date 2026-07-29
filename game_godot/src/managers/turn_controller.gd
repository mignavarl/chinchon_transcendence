class_name TurnController
extends Node

signal turn_started(player_data: PlayerData)
signal turn_ended(player_data: PlayerData)

var _players: Array[PlayerData] = []
var _current_idx: int = 0

var current_player: PlayerData:
	get: return _players[_current_idx]

func setup(players: Array[PlayerData], starting_idx: int = -1) -> void:
	_players = players
	if starting_idx < 0:
		_current_idx = randi_range(0, _players.size() - 1)
	else:
		_current_idx = starting_idx

func advance() -> void:
	turn_ended.emit(current_player)
	_current_idx = (_current_idx + 1) % _players.size()
	turn_started.emit(current_player)

func start_first_turn() -> void:
	turn_started.emit(current_player)
