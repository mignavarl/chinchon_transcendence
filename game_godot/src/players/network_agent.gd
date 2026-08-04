class_name NetworkAgent
extends PlayerAgent

var remote_network_id: int

func _init(player_data: PlayerData) -> void:
	super._init(player_data)
	remote_network_id = player_data.network_id


func request_action(_game_state: Dictionary) -> void:
	pass

func receive_remote_action(action: Dictionary) -> void:
	action_taken.emit(action)
