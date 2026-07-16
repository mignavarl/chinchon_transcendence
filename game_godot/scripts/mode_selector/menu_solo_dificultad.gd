extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_única_button_up() -> void:
	SceneLoader.change_scene( "res://scenes/MainRefactor.tscn", "ModeSelector")

func _on_easy_button_up() -> void:
	pass # Replace with function body.

func _on_normal_button_up() -> void:
	pass # Replace with function body.

func _on_hard_button_up() -> void:
	pass # Replace with function body.
