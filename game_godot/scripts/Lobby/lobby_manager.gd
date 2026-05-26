extends Node2D

var num_players := 0

func create_bot(name) -> PlayerData:
	var bot = PlayerData.new()
	bot.id = num_players
	bot.display_name = name
	bot.type = PlayerData.Type.AI
	bot.hand_idx = num_players
	num_players += 1
	return bot

func _on_start_button_up() -> void:
	var cfg = GameConfig.new()
	var human = PlayerData.new()
	human.id = num_players
	human.display_name = "Tú"
	human.type = PlayerData.Type.HUMAN
	human.hand_idx = num_players
	human.is_local = true
	num_players += 1
	cfg.players.append(human)
	cfg.players.append(create_bot("Paco"))
	cfg.players.append(create_bot("Manolo"))
	cfg.players.append(create_bot("El Anemias"))
	SceneLoader.change_scene( "res://scenes/MainRefactor.tscn", "Lobby")
	while ResourceLoader.load_threaded_get_status("res://scenes/MainRefactor.tscn") != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().create_timer(0.1).timeout
	get_node("ChinchonManager").setup(cfg)
