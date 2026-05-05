extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_mouse_entered() -> void:
	print("entro")
	$Play/MeshInstance3D.get_active_material(0).albedo_color = Color.DARK_ORCHID

func _on_play_mouse_exited() -> void:
	print("entro")
	$Play/MeshInstance3D.get_active_material(0).albedo_color = Color.WHITE


func _on_play_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_gacha_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		get_tree().change_scene_to_file("res://scenes/gachapon.tscn")


func _on_gacha_mouse_entered() -> void:
	print("entro")
	$Gacha/MeshInstance3D.get_active_material(0).albedo_color = Color.DARK_ORCHID


func _on_gacha_mouse_exited() -> void:
	print("entro")
	$Gacha/MeshInstance3D.get_active_material(0).albedo_color = Color.WHITE
