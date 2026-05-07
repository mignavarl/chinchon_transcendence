extends Button

@export var decks : Script
@export var selector : Script

var dic_common = {}
var dic_uncommon = {}
var dic_rare = {}
var dic_legen = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.visible = false # Replace with function body.
	for i in decks.DECKS:
		if i["rarity"] == "common":
			dic_common.get_or_add(i["id"])
		elif  i["rarity"] == "uncommon":
			dic_uncommon.get_or_add(i["id"])
		elif  i["rarity"] == "rare":
			dic_rare.get_or_add(i["id"])
		elif  i["rarity"] == "legendary":
			dic_legen.get_or_add(i["id"])


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
		$Label.text = "Todas las %s conseguidas" % rarity
		$Label.set("theme_override_colors/font_color", Color(0.594, 0.004, 1.309, 1.0))
		$Label.visible = true
		$"../Deck_win".visible = false
		return false
	var r = randi() % elegible_keys.size()
	var rk = elegible_keys[r]
	print("rk = ", rk)
	var img_path = "res://assets/cards/%s/oros_1.png" % [rk]
	var card_win = load(img_path)
	$"../Deck_win".visible = true
	$"../Deck_win".texture = card_win
	
	var new_position = Vector2(876, 485)
	$"../Deck_win".position = new_position
	$"../Deck_box".visible = false
	dic[rk] = 1
	selector.my_decks.push_back(rk)
	print("Añado el deck: ", dic[rk])
	return true


func _on_button_up() -> void:
	var rarity = randi() % 100 + 1
	if rarity <= 50:
		$Label.text = "Común"
		$Label.set("theme_override_colors/font_color", Color(0.399, 1.582, 1.454, 1.0))
		$Label.visible = true
		if get_deck(dic_common, "comunes"):
			return
	if rarity <= 75:
		$Label.text = "Infrecuente"
		$Label.set("theme_override_colors/font_color", Color(0.0, 1.582, 0.192, 1.0))
		$Label.visible = true
		if get_deck(dic_uncommon, "Infrecuentes"):
			return
	if rarity <= 93:
		$Label.text = "Raro"
		$Label.set("theme_override_colors/font_color", Color(0.69, 0.168, 0.394, 1.0))
		$Label.visible = true
		if get_deck(dic_rare, "raras"):
			return
	if rarity <= 100:
		$Label.text = "Legendario"
		$Label.set("theme_override_colors/font_color", Color(1.582, 0.794, 0.049, 1.0))
		$Label.visible = true
		if get_deck(dic_legen, "legendarias"):
			return
	$Label.text = "Todas conseguidas"
	$Label.set("theme_override_colors/font_color", Color(0.0, 0.0, 0.0, 1.0))
	$Label.visible = true
	$"../Deck_win".visible = false
