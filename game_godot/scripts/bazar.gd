extends Node3D

@export var decks : Script
@export var selector : Script
@export var dic_decks : Script

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"Gacha/Mostrador Gacha/Caja".visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_keys_unowned(dict):
	var keys = []
	for d in dict.keys():
		if !dict[d]:
			print("Elegible: ", d)
			keys.push_back(d)
	return keys

func get_deck(dic, rarity):
	var elegible_keys = get_keys_unowned(dic)
	if elegible_keys.size() <= 0:
		print("Tengo todas")
		#$Label.text = "Todas las %s conseguidas" % rarity
		#$Label.set("theme_override_colors/font_color", Color(0.594, 0.004, 1.309, 1.0))
		#$Label.visible = true
		#$"../Deck_win".visible = false
		return false
	var r = randi() % elegible_keys.size()
	var rk = elegible_keys[r]
	print("rk = ", rk)
	var img_path = "res://assets/cards/%s/oros_1.png" % [rk]
	var card_win = load(img_path)
	
	var material_one = $"Gacha/Mostrador Gacha/Caja/Baraja".get_surface_override_material(0)
	material_one.albedo_texture = card_win
	$"Gacha/Mostrador Gacha/Caja/Baraja".set_surface_override_material(0, material_one)
	
	#$"Gacha/Mostrador Gacha/Caja/Baraja".set_surface_override_material()
	#$"../Deck_win".texture = card_win
	
	dic[rk] = 1
	selector.my_decks.push_back(get_dictionary_of_id(rk))
	print("Añado el deck: ", dic[rk])
	return true

func get_dictionary_of_id(id):
	for d in decks.DECKS:
		if d["id"] == id:
			return d

func randomizador():
	var rarity = randi() % 100 + 1
	var elegible
	if rarity <= 50:
		elegible = get_keys_unowned(dic_decks.dic_common)
		if elegible.size() == 0:
			randomizador()
			return
		#$Label.text = "Común"
		#$Label.set("theme_override_colors/font_color", Color(0.399, 1.582, 1.454, 1.0))
		#$Label.visible = true
		if get_deck(dic_decks.dic_common, "comunes"):
			return
	if rarity <= 75:
		elegible = get_keys_unowned(dic_decks.dic_uncommon)
		if elegible.size() == 0:
			randomizador()
			return
		#$Label.text = "Infrecuente"
		#$Label.set("theme_override_colors/font_color", Color(0.0, 1.582, 0.192, 1.0))
		#$Label.visible = true
		if get_deck(dic_decks.dic_uncommon, "Infrecuentes"):
			return
	if rarity <= 93:
		elegible = get_keys_unowned(dic_decks.dic_rare)
		if elegible.size() == 0:
			randomizador()
			return
		#$Label.text = "Raro"
		#$Label.set("theme_override_colors/font_color", Color(0.69, 0.168, 0.394, 1.0))
		#$Label.visible = true
		if get_deck(dic_decks.dic_rare, "raras"):
			return
	if rarity <= 100:
		elegible = get_keys_unowned(dic_decks.dic_legen)
		if elegible.size() == 0:
			randomizador()
			return
		#$Label.text = "Legendario"
		#$Label.set("theme_override_colors/font_color", Color(1.582, 0.794, 0.049, 1.0))
		#$Label.visible = true
		if get_deck(dic_decks.dic_legen, "legendarias"):
			return
	#$Label.text = "Todas conseguidas"
	#$Label.set("theme_override_colors/font_color", Color(0.0, 0.0, 0.0, 1.0))
	#$Label.visible = true
	#$"../Deck_win".visible = false


func have_all():
	for i in dic_decks.dic_common:
		if !dic_decks.dic_common[i]:
			return true
	for i in dic_decks.dic_uncommon:
		if !dic_decks.dic_uncommon[i]:
			return true
	for i in dic_decks.dic_rare:
		if !dic_decks.dic_rare[i]:
			return true
	for i in dic_decks.dic_legen:
		if !dic_decks.dic_legen[i]:
			return true
	return false


func _on_mostrador_2_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		print("cliko")
		if !have_all():
			print("tengo todas")
			return
		randomizador()
		$"Gacha/Mostrador Gacha/Caja".visible = true
		$AnimationPlayer.play("Gacha")
