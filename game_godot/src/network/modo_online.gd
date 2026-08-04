extends Control

# ASUNCIÓN: hay un LineEdit para el código de sala en algún lugar de esta escena.
# Ajusta la ruta $search/CodeInput al nodo real si no coincide.

@onready var code_input = %Code

func _ready() -> void:
	$info.visible = false
	pass

func _process(delta: float) -> void:
	pass


func _on_make_mouse_entered() -> void:
	$make/Label.visible = true

func _on_make_mouse_exited() -> void:
	$make/Label.visible = false

func _on_search_mouse_entered() -> void:
	$search/Label.visible = true

func _on_search_mouse_exited() -> void:
	$search/Label.visible = false


func _on_make_pressed() -> void:
	LobbyIntent.set_host_intent()
	SceneLoader.change_scene("res://src/network/lobby_online.tscn", "OnlineMenu")


func _on_search_pressed() -> void:
	var code: String = code_input.text
	if code.strip_edges().is_empty():
		$info.text = "Introduce un código de sala"
		$info.visible = true
		return

	LobbyIntent.set_join_intent(code)
	SceneLoader.change_scene("res://src/network/lobby_online.tscn", "OnlineMenu")
