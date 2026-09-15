extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_exit_button_up() -> void:
	if not Auth.is_logged_in():
		SceneLoader.change_scene("res://src/menus/loginScene.tscn", self.name)
	else:
		SceneLoader.change_scene("res://src/menus/ajustes.tscn", self.name)
