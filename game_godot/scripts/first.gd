extends Control

@export var decks : Script
@export var selector : Script

static var dic_common = {}
static var dic_uncommon = {}
static var dic_rare = {}
static var dic_legen = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in decks.DECKS:
		if i["rarity"] == "common":
			dic_common.get_or_add(i["id"])
		elif  i["rarity"] == "uncommon":
			dic_uncommon.get_or_add(i["id"])
		elif  i["rarity"] == "rare":
			dic_rare.get_or_add(i["id"])
		elif  i["rarity"] == "legendary":
			dic_legen.get_or_add(i["id"])
		if i["id"] == "española":
			selector.my_decks.push_back(i)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
