extends Node
class_name UIManager

@export var chinchon_manager : GameManager
@export var canvas : UIIngame

var players : Dictionary = {}
var player_data : Array[PlayerData]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	players = chinchon_manager.agents
	
	player_data =  _get_datas()
	canvas.setup_players(player_data)
	canvas.hide_scoreboard()
	for p in players.size():
		canvas.show_player(player_data[p],p)


func _get_datas() -> Array[PlayerData]:
	var arr : Array[PlayerData]
	for p in players.size():
		arr.append(players[p].data)
	return arr

func _on_scoreboard_mouse_entered() -> void:
	canvas.show_scoreboard(player_data)

func _on_scoreboard_mouse_exited() -> void:
	canvas.hide_scoreboard()
