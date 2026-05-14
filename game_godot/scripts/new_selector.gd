extends Control

@export var dic_decks : Script
@export var chinchon_man : Script

static var my_decks = []
var deck
var own_keys

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	deck = chinchon_man.deck_selected
	change_deck(deck)
	own_keys = get_keys_owned()
	print("size own = ", own_keys.size())
	print("size my = ", my_decks.size())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func change_deck(deck):
	$FondoMenu/Nombre.text = deck
	var img_path = "res://assets/cards/%s/oros_1.png" % [deck]
	var card = load(img_path)
	$FondoMenu/FondoCartas/Oros.texture = card
	img_path = "res://assets/cards/%s/copas_1.png" % [deck]
	card = load(img_path)
	$FondoMenu/FondoCartas/Copas.texture = card
	img_path = "res://assets/cards/%s/espadas_1.png" % [deck]
	card = load(img_path)
	$FondoMenu/FondoCartas/Espadas.texture = card
	img_path = "res://assets/cards/%s/bastos_1.png" % [deck]
	card = load(img_path)
	$FondoMenu/FondoCartas/Bastos.texture = card

func get_keys_owned():
	var keys = []
	for i in my_decks:
		if i:
			keys.push_back(i)
	return keys

func _on_nombre_button_up() -> void:
	chinchon_man.change_deck(deck)
	SceneLoader.change_scene( "res://scenes/bar.tscn", self.name)


func _on_izquierda_button_up() -> void:
	if own_keys.size() == 1:
		return
	var i = search_key(deck)
	if i == 0:
		i = own_keys.size()
	deck = own_keys[i - 1]


func _on_derecha_button_up() -> void:
	pass # Replace with function body.

func search_key(key):
	for i in own_keys:
		print("AAAAAAA")
		if i["id"] == key:
			return i
	return own_keys.size()
