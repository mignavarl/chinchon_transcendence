extends CanvasLayer
class_name UIIngame

@export var names : Array[Label]
@export var player_list : Array[PlayerData]
@export var scores : RichTextLabel
@export var scoresbg : Panel

@export var turn_controller : TurnController
@export var game_manager : GameManager

func _ready() -> void:
	turn_controller.turn_ended.connect(on_end_turn)
	turn_controller.turn_started.connect(on_start_turn)
	game_manager.round_closed.connect(toggle_restart_button_visibility)

func setup_players(players : Array[PlayerData]):
	player_list = players

func show_player(pl: PlayerData):
	if pl != null:
		names[game_manager.get_visual_slot_index(pl)].text = pl.display_name


func show_scoreboard(players: Array[PlayerData]):
	var score_text := ""
	for pl in players:
		var s = "%s : %d\n" % [pl.display_name, pl.score]
		score_text = str(score_text, s)
	scores.text = score_text
	
	scores.visible = true
	scoresbg.visible = true

func toggle_restart_button_visibility(vis = true):
	if game_manager.config.is_online and not game_manager.config.is_host:
		return
	$Control/Restart.visible = vis

func hide_scoreboard():
	scores.visible = false
	scoresbg.visible = false
	

func on_end_turn(pl : PlayerData):
	var idx = game_manager.get_visual_slot_index(pl)
	print("Se acabo el turno de ", idx)
	names[idx].get_child(0).visible = false

func on_start_turn(pl : PlayerData):
	var idx = game_manager.get_visual_slot_index(pl)
	print("Se inicio el turno de ", idx)
	names[idx].get_child(0).visible = true
	


#---BORRAR----DEBUG---------------------
func _on_salir_borrar_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/bar.tscn", "Main")
#---------------------------------------


func _on_restart_pressed() -> void:
	toggle_restart_button_visibility(false)
