extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_esp_button_up() -> void:
	TranslationServer.set_locale("es")
	ConfigManager.set_language("es")


func _on_cat_button_up() -> void:
	TranslationServer.set_locale("ca")
	ConfigManager.set_language("ca")


func _on_eus_button_up() -> void:
	TranslationServer.set_locale("eu")
	ConfigManager.set_language("eu")


func _on_exit_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/main_menu.tscn", self.name)


func _on_privacity_button_up() -> void:
	SceneLoader.change_scene("res://scripts/privacy.tscn", self.name)
