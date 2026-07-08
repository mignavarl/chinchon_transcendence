extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Solo/Label.visible = false
	$Gente/Label.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_gente_mouse_entered() -> void:
	$Gente/Label.visible = true


func _on_gente_mouse_exited() -> void:
	$Gente/Label.visible = false


func _on_solo_mouse_entered() -> void:
	$Solo/Label.visible = true


func _on_solo_mouse_exited() -> void:
	$Solo/Label.visible = false
