extends CanvasLayer
class_name UIIngame

@export var names : Array[Label]
@export var scores : RichTextLabel
@export var scoresbg : Panel

# Dictionary has = { key = id, agent}
func show_player(pl: PlayerData, id :int):
	if pl != null:
		names[id].text = pl.display_name


func show_scoreboard(players: Array[PlayerData]):
	var score_text := ""
	for pl in players:
		var s = "%s : %d\n" % [pl.display_name, pl.score]
		score_text = str(score_text, s)
	scores.text = score_text
	
	scores.visible = true
	scoresbg.visible = true

func hide_scoreboard():
	scores.visible = false
	scoresbg.visible = false
	
