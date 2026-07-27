extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$AnimationFan.play("Fan_move")


func _on_play_table_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("play_table")
		SceneLoader.change_scene( "res://scenes/mode_selector.tscn", self.name)


func _on_puerta_salida_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("exit")
		SceneLoader.change_scene( "res://scenes/main_menu.tscn", self.name)


func _on_cambio_barajas_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("change_deck")
		SceneLoader.change_scene( "res://scenes/new_selector.tscn", self.name)


func _on_salida_mouse_entered() -> void:
	$AnimationPlayer.play("hover_exit")


func _on_salida_mouse_exited() -> void:
	$AnimationPlayer.play_backwards("hover_exit")


func _on_play_table_mouse_entered() -> void:
	$Play_AnimationPlayer.play("hover_play")


func _on_play_table_mouse_exited() -> void:
	$Play_AnimationPlayer.play_backwards("hover_play")


func _on_cambio_barajas_mouse_entered() -> void:
	$Deck_AnimationPlayer.play("hover_deck")



func _on_cambio_barajas_mouse_exited() -> void:
	$Deck_AnimationPlayer.play_backwards("hover_deck")


func _on_tutorial_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		SceneLoader.change_scene( "res://scenes/tutorial.tscn", self.name)


func _on_tutorial_mouse_entered() -> void:
	$Tutorial/Anim_tuto.play("tutorial")
