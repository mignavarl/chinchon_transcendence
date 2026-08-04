extends Node


enum Intent { HOST, JOIN }

var pending_intent: Intent = Intent.HOST
var pending_join_code: String = ""


func set_host_intent() -> void:
	pending_intent = Intent.HOST
	pending_join_code = ""


func set_join_intent(code: String) -> void:
	pending_intent = Intent.JOIN
	pending_join_code = code.strip_edges().to_upper()


func is_host_intent() -> bool:
	return pending_intent == Intent.HOST
