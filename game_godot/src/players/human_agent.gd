class_name HumanAgent
extends PlayerAgent

var _waiting := false

func request_action(game_state: Dictionary) -> void:
	_waiting = true

func notify_draw(source: String) -> void:
	if not _waiting:
		return
	action_taken.emit({ "type": "draw", "source": source })

func notify_discard(card) -> void:
	if not _waiting:
		return
	_waiting = false
	action_taken.emit({ "type": "discard", "card": card })

func notify_close(card) -> void:
	if not _waiting:
		return
	_waiting = false
	action_taken.emit({ "type": "close", "card": card })
