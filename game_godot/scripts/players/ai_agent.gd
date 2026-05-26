class_name AIAgent
extends PlayerAgent

var _ai := OpponentAI.new()
var _timer: SceneTreeTimer
var _think_time := 0.5

func request_action(game_state: Dictionary) -> void:
	var hand      = game_state["hand"]
	var top_card  = game_state["top_discard"]
	var tree      = game_state["tree"]

	_timer = tree.create_timer(_think_time)
	await _timer.timeout

	var source = _ai.decide_draw(hand, top_card)
	action_taken.emit({ "type": "draw", "source": source })

	_timer = tree.create_timer(_think_time)
	await _timer.timeout

	var to_discard = _ai.decide_discard(hand)
	if _ai.should_close(hand):
		action_taken.emit({ "type": "close", "card": to_discard })
	else:
		action_taken.emit({ "type": "discard", "card": to_discard })
