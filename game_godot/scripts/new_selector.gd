extends Control

@export var dic_decks : Script
@export var chinchon_man : Script

static var my_decks = []
var deck
var own_keys

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	own_keys = get_keys_owned()
	deck = search_deck_in_use(chinchon_man.deck_selected)
	change_deck(deck.id)
	print("size own = ", own_keys.size())
	print("size my = ", my_decks.size())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func search_deck_in_use(name_deck):
	for i in own_keys:
		if i.id == name_deck:
			return i

func change_deck(d):
	$FondoMenu/Nombre.text = d
	var img_path = "res://assets/cards/%s/oros_1.png" % [d]
	var card = load(img_path)
	$FondoMenu/FondoCartas/Oros.texture = card
	img_path = "res://assets/cards/%s/copas_1.png" % [d]
	card = load(img_path)
	$FondoMenu/FondoCartas/Copas.texture = card
	img_path = "res://assets/cards/%s/espadas_1.png" % [d]
	card = load(img_path)
	$FondoMenu/FondoCartas/Espadas.texture = card
	img_path = "res://assets/cards/%s/bastos_1.png" % [d]
	card = load(img_path)
	$FondoMenu/FondoCartas/Bastos.texture = card

func get_keys_owned():
	var keys = []
	for i in my_decks:
		print(i)
		if i:
			keys.push_back(i)
	return keys

func _on_nombre_button_up() -> void:
	chinchon_man.change_deck(deck.id)
	SceneLoader.change_scene( "res://scenes/bar.tscn", self.name)


func _on_izquierda_button_up() -> void:
	if own_keys.size() == 1:
		return
	var i = search_key(deck.id) - 1
	print ("izquierda <-- i = ", i, " - deck = ", i)
	if i < 0:
		print("MU PEQUEÑO")
		deck = own_keys[own_keys.size() - 1]
	else:
		deck = own_keys[i]
	#print("cambiamos a deck ", deck)
	change_deck(deck.id)


func _on_derecha_button_up() -> void:
	if own_keys.size() == 1:
		return
	var i = search_key(deck.id) + 1
	print ("derecha --> i = ", i, " - deck = ", i)
	if i >= own_keys.size():
		print("MU GRANDE")
		deck = own_keys[0]
	else:
		deck = own_keys[i]
	change_deck(deck.id)

func search_key(key):
	var n = 0
	for i in own_keys:
		if i.id == key:
			print("encuentro = ", key)
			return n
		n = n + 1
	print("----NO ENCUENTRO NADA----")
	return own_keys.size()
