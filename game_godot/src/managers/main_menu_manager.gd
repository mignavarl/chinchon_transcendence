extends Node3D


func _ready() -> void:
	$profile/HBoxContainer/user.text = Auth.username
	Database.get_user(Auth.user_id, func(res:Dictionary) -> void:
		if not res.ok:
			push_warning("no se pudo conseguir el usuario")
		var avatar = load(res.rows[0].avatar_url)
		print("mi avatar: %s" % avatar)
		if not avatar:
			pass
		else:
			$profile/HBoxContainer/avatar.texture = avatar
		)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_mouse_entered() -> void:
	$Fondo/Farolas/Farola/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola/OmniLight3D2.light_energy = 0.15
	$Fondo/Farolas/Farola4/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola4/OmniLight3D2.light_energy = 0.15

	#$Play/PlantaBaja.get_active_material(0).albedo_color = Color.DARK_ORCHID

func _on_play_mouse_exited() -> void:
	$Fondo/Farolas/Farola/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola/OmniLight3D2.light_energy = 0.1
	$Fondo/Farolas/Farola4/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola4/OmniLight3D2.light_energy = 0.1

	#$Play/PlantaBaja.get_active_material(0).albedo_color = Color.WHITE


func _on_play_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("play_animation")
		SceneLoader.change_scene( "res://src/menus/bar.tscn", self.name)


func _on_gacha_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("gacha_animation")
		SceneLoader.change_scene( "res://src/main_game/gachapon/bazar.tscn", self.name)


func _on_gacha_mouse_entered() -> void:
	$Fondo/Farolas/Farola3/OmniLight3D.light_energy = 0.15
	$Fondo/Farolas/Farola3/OmniLight3D2.light_energy = 0.15

	#$Gacha/PlantaBaja.get_active_material(0).albedo_color = Color.DARK_ORCHID


func _on_gacha_mouse_exited() -> void:
	$Fondo/Farolas/Farola3/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola3/OmniLight3D2.light_energy = 0.1
	#$Gacha/PlantaBaja.get_active_material(0).albedo_color = Color.WHITE


func _on_casas_fondo_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		SceneLoader.change_scene( "res://src/menus/ajustes.tscn", self.name)


func _on_casas_fondo_mouse_entered() -> void:
	$Fondo/Farolas/Farola5/OmniLight3D.light_energy = 0.30
	$Fondo/Farolas/Farola5/OmniLight3D2.light_energy = 0.30
	$Fondo/CasasFondo/Cartel/Sprite3D.flip_h = true


func _on_casas_fondo_mouse_exited() -> void:
	$Fondo/Farolas/Farola5/OmniLight3D.light_energy = 0.1
	$Fondo/Farolas/Farola5/OmniLight3D2.light_energy = 0.1
	$Fondo/CasasFondo/Cartel/Sprite3D.flip_h = false


func _on_user_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/profile.tscn", self.name)


func _on_avatar_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		SceneLoader.change_scene("res://src/menus/profile.tscn", self.name)
