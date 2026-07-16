extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
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
