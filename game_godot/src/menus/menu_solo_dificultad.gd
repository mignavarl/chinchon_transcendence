extends Control

@export var list_buttons : Array[Button]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var i = ConfigManager.get_selected_bots()
	
	list_buttons[i-1].button_pressed = true
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_única_button_up() -> void:
	SceneLoader.change_scene( "res://src/main_game/chinchon/MainRefactor.tscn", "ModeSelector")

func _on_easy_button_up() -> void:
	pass # Replace with function body.

func _on_normal_button_up() -> void:
	pass # Replace with function body.

func _on_hard_button_up() -> void:
	pass # Replace with function body.



func _on__toggled(toggled_on: bool, quantity: int) -> void:
	if toggled_on:
		print("Creamos => ", quantity)
		ConfigManager.set_selected_bots(quantity)
		print (ConfigManager.get_selected_bots())
