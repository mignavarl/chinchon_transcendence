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
	get_tree().change_scene_to_file("res://src/network/online_menu.tscn")
