extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$play/Label.visible = false
	$online/Label.visible = false
	$".".visible = true
	$"../ia_difficult".visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_online_button_up() -> void:
	SceneLoader.change_scene( "res://src/network/online_menu.tscn", "ModeSelector")

func _on_exit_button_up() -> void:
	SceneLoader.change_scene( "res://src/menus/bar.tscn", "ModeSelector")
