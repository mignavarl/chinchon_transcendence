extends Control

@export var decks : Script
@export var make_deck : Script
@export var vbox: VBoxContainer

static var my_decks = []

#funcion para cambiar la baraja. Los botones llaman a esta para cambiarla. Todos para una

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# funcion para poner visible las barajas
	var own_keys = get_keys_owned()
	print("size own = ", own_keys.size())
	print("size my = ", my_decks.size())
	for i in own_keys.size():
		var name = own_keys[i]
		var d = "$%s" % [name]
		vbox = get_node(name)
		vbox.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_keys_owned():
	var keys = []
	for i in my_decks:
		if i:
			keys.push_back(i)
	return keys
