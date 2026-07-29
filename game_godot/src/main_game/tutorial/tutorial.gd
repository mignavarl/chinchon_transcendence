extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"1".visible = true
	$"2".visible = false
	$"3".visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_exit_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/bar.tscn", self.name)
