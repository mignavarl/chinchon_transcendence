extends Node3D




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_mouse_entered() -> void:
	print("entro")
	$Fondo/Farolas/Farola/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola/OmniLight3D2.light_energy = 0.15
	$Fondo/Farolas/Farola4/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola4/OmniLight3D2.light_energy = 0.15

	#$Play/PlantaBaja.get_active_material(0).albedo_color = Color.DARK_ORCHID

func _on_play_mouse_exited() -> void:
	print("entro")
	$Fondo/Farolas/Farola/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola/OmniLight3D2.light_energy = 0.1
	$Fondo/Farolas/Farola4/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola4/OmniLight3D2.light_energy = 0.1

	#$Play/PlantaBaja.get_active_material(0).albedo_color = Color.WHITE


func _on_play_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("play_animation")
		SceneLoader.change_scene( "res://scenes/bar.tscn", self.name)


func _on_gacha_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("gacha_animation")
		SceneLoader.change_scene( "res://scenes/bazar.tscn", self.name)


func _on_gacha_mouse_entered() -> void:
	print("entro")
	$Fondo/Farolas/Farola3/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola3/OmniLight3D2.light_energy = 0.15

	#$Gacha/PlantaBaja.get_active_material(0).albedo_color = Color.DARK_ORCHID


func _on_gacha_mouse_exited() -> void:
	print("entro")
	$Fondo/Farolas/Farola3/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola3/OmniLight3D2.light_energy = 0.1
	#$Gacha/PlantaBaja.get_active_material(0).albedo_color = Color.WHITE
