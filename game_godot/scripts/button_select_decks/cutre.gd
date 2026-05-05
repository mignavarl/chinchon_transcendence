extends VBoxContainer

@export var make_deck : Script
@export var deck : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_cutre_button_up() -> void:
	make_deck.change_deck(deck)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_texture_button_button_up() -> void:
	make_deck.change_deck(deck)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
