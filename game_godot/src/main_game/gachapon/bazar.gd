extends Node3D

@export var decks : Script
@export var selector : Script
@export var dic_decks : Script

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Gacha/MostradorGacha/Caja.visible = false
	$Gacha/MostradorGacha/Boton_guardar.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# The Konami Code sequence using Godot 4 Key constants
const KONAMI_CODE = [
	KEY_UP, KEY_UP,
	KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT,
	KEY_LEFT, KEY_RIGHT,
	KEY_B, KEY_A
]

var code_index: int = 0

func _unhandled_input(event: InputEvent) -> void:
	# Only process when a key is pressed (prevents firing twice per keystroke)
	if event is InputEventKey and event.pressed:
		var current_key = event.keycode
		
		# Check if the pressed key matches the current step in the sequence
		if current_key == KONAMI_CODE[code_index]:
			code_index += 1
			
			# Check if we reached the end of the code
			if code_index == KONAMI_CODE.size():
				_trigger_konami_code()
				code_index = 0 # Reset after triggering
		else:
			# Incorrect input resets the sequence
			code_index = 0

func _trigger_konami_code() -> void:
	for i in dic_decks.dic_common.keys():
		if !dic_decks.dic_common[i]:
			dic_decks.dic_common[i] = 1
			selector.my_decks.push_back(get_dictionary_of_id(i))
	for i in dic_decks.dic_uncommon.keys():
		if !dic_decks.dic_uncommon[i]:
			dic_decks.dic_uncommon[i] = 1
			selector.my_decks.push_back(get_dictionary_of_id(i))
	for i in dic_decks.dic_rare.keys():
		if !dic_decks.dic_rare[i]:
			dic_decks.dic_rare[i] = 1
			selector.my_decks.push_back(get_dictionary_of_id(i))
	for i in dic_decks.dic_legen.keys():
		if !dic_decks.dic_legen[i]:
			dic_decks.dic_legen[i] = 1
			selector.my_decks.push_back(get_dictionary_of_id(i))



func get_keys_unowned(dict):
	var keys = []
	for d in dict.keys():
		if !dict[d]:
			keys.push_back(d)
	return keys

func get_deck(dic):
	var elegible_keys = get_keys_unowned(dic)
	var r = randi() % elegible_keys.size()
	var rk = elegible_keys[r]
	print("rk = ", rk)
	
	var img_oro = "res://assets/cards/%s/oros_1.png" % [rk]
	var card_oro = load(img_oro)
	var material_oro = $Gacha/MostradorGacha/Caja/Baraja/Oros.get_surface_override_material(0)
	material_oro.albedo_texture = card_oro
	$Gacha/MostradorGacha/Caja/Baraja/Oros.set_surface_override_material(0, material_oro)
	
	var img_copa = "res://assets/cards/%s/copas_1.png" % [rk]
	var card_copa = load(img_copa)
	var material_copa = $Gacha/MostradorGacha/Caja/Baraja/Copas.get_surface_override_material(0)
	material_copa.albedo_texture = card_copa
	$Gacha/MostradorGacha/Caja/Baraja/Copas.set_surface_override_material(0, material_copa)
	
	var img_esp = "res://assets/cards/%s/espadas_1.png" % [rk]
	var card_esp = load(img_esp)
	var material_esp = $Gacha/MostradorGacha/Caja/Baraja/Espadas.get_surface_override_material(0)
	material_esp.albedo_texture = card_esp
	$Gacha/MostradorGacha/Caja/Baraja/Espadas.set_surface_override_material(0, material_esp)
	
	var img_basto = "res://assets/cards/%s/bastos_1.png" % [rk]
	var card_basto = load(img_basto)
	var material_basto = $Gacha/MostradorGacha/Caja/Baraja/Bastos.get_surface_override_material(0)
	material_basto.albedo_texture = card_basto
	$Gacha/MostradorGacha/Caja/Baraja/Bastos.set_surface_override_material(0, material_basto)
	
	dic[rk] = 1
	selector.my_decks.push_back(get_dictionary_of_id(rk))
	_save_deck(rk)
	return true


# Apunta la baraja en la base de datos. Un invitado sin cuenta juega igual,
# pero la baraja se le queda solo en memoria hasta que cierre el navegador.
func _save_deck(deck_id: String) -> void:
	if not Auth.can_save():
		return

	Database.grant_deck(Auth.user_id, deck_id, func(res: Dictionary) -> void:
		if not res.ok:
			push_warning("no se pudo guardar la baraja %s: %s" % [deck_id, res.error])
	)

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
		var light_effeccts = $Gacha/MostradorGacha/Caja/CPUParticles3D.mesh.get_material()
		light_effeccts.albedo_color = Color(0.35, 0.903, 1.0, 0.18)
		get_deck(dic_decks.dic_common)
	elif rarity <= 75:
		elegible = get_keys_unowned(dic_decks.dic_uncommon)
		if elegible.size() == 0:
			randomizador()
			return
		var light_effeccts = $Gacha/MostradorGacha/Caja/CPUParticles3D.mesh.get_material()
		light_effeccts.albedo_color = Color(0.0, 0.752, 0.48, 0.161)
		get_deck(dic_decks.dic_uncommon)
	elif rarity <= 93:
		elegible = get_keys_unowned(dic_decks.dic_rare)
		if elegible.size() == 0:
			randomizador()
			return
		var light_effeccts = $Gacha/MostradorGacha/Caja/CPUParticles3D.mesh.get_material()
		light_effeccts.albedo_color = Color(1.0, 0.349, 0.354, 0.2)
		get_deck(dic_decks.dic_rare)
	elif rarity <= 100:
		elegible = get_keys_unowned(dic_decks.dic_legen)
		if elegible.size() == 0:
			randomizador()
			return
		var light_effeccts = $Gacha/MostradorGacha/Caja/CPUParticles3D.mesh.get_material()
		light_effeccts.albedo_color = Color(2.432, 2.077, 0.499, 0.184)
		get_deck(dic_decks.dic_legen)


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
		if !have_all():
			print("tengo todas")
			return
		randomizador()
		$Gacha/MostradorGacha/Caja.visible = true
		$Gacha/MostradorGacha/Boton_guardar.visible = true
		$AnimationPlayer.play("Gacha")
		$Gacha/MostradorGacha/Caja/Baraja.visible = true
		

func _on_puerta_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("Exit")
		SceneLoader.change_scene( "res://src/menus/main_menu.tscn", self.name)


func _on_puerta_mouse_entered() -> void:
	$AnimationPlayer.play("Exit_hover")


func _on_puerta_mouse_exited() -> void:
	$AnimationPlayer.play_backwards("Exit_hover")


func _on_boton_guardar_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("Back_gacha")
