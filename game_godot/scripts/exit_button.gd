extends Button


func _on_button_up() -> void:
	SceneLoader.change_scene( "res://scenes/main_menu.tscn", $"..".name)
