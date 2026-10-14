extends Node

var pending_config: GameConfig = null

func set_config(config: GameConfig) -> void:
	pending_config = config

func take_config() -> GameConfig:
	var config := pending_config
	pending_config = null
	return config

func has_config() -> bool:
	return pending_config != null
