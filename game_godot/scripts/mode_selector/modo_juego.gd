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


func _on_gente_mouse_entered() -> void:
	$online/Label.visible = true


func _on_gente_mouse_exited() -> void:
	$online/Label.visible = false


func _on_solo_mouse_entered() -> void:
	$play/Label.visible = true


func _on_solo_mouse_exited() -> void:
	$play/Label.visible = false

func _on_solo_button_up() -> void:
	$".".visible = false
	$"../ia_difficult".visible = true
