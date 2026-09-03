extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$HBoxContainer/edit/user.text = Auth.username
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_act_user_button_up() -> void:
	#TODO: para cambiar el nombre de usuario
	var new_user = $HBoxContainer/edit/user.text


func _on_area_avatar_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action("mouse_click"):
		pass #TODO: para cambiar la foto del avatar
	pass # Replace with function body.
