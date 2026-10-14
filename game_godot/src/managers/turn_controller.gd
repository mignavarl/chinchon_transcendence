class_name TurnController
extends Node

signal turn_started(player_data: PlayerData)
signal turn_ended(player_data: PlayerData)

var _players: Array[PlayerData] = []
var _current_idx: int = 0
var _eliminated_idx: Array[int] = []

var current_player: PlayerData:
	get: return _players[_current_idx]

func setup(players: Array[PlayerData], starting_idx: int = -1) -> void:
	_players = players
	_eliminated_idx.clear()
	if starting_idx < 0:
		_current_idx = randi_range(0, _players.size() - 1)
	else:
		_current_idx = starting_idx

func advance() -> void:
	turn_ended.emit(current_player)
	_current_idx = _next_active_idx(_current_idx)
	turn_started.emit(current_player)

func remove_player(id : int):
	if id in _eliminated_idx:
		return
	_eliminated_idx.append(id)

func start_first_turn() -> void:
	if current_player.id in _eliminated_idx:
		_current_idx = _next_active_idx(_current_idx)
	turn_started.emit(current_player)

func active_player_count() -> int:
	return _players.size() - _eliminated_idx.size()

func _next_active_idx(from_idx : int):
	var idx := from_idx
	var attemps := 0
	while attemps < _players.size():
		idx = (idx + 1) % _players.size()
		if _players[idx].id not in _eliminated_idx:
			return idx
		attemps += 1
	return from_idx
