extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Facil/Label.visible = false
	$Normal/Label.visible = false
	$Dificil/Label.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_facil_mouse_entered() -> void:
	$Facil/Label.visible = true


func _on_facil_mouse_exited() -> void:
	$Facil/Label.visible = false


func _on_normal_mouse_entered() -> void:
	$Normal/Label.visible = true


func _on_normal_mouse_exited() -> void:
	$Normal/Label.visible = false


func _on_dificil_mouse_entered() -> void:
	$Dificil/Label.visible = true


func _on_dificil_mouse_exited() -> void:
	$Dificil/Label.visible = false
