extends Node3D

@export var decks : Script
@export var selector : Script
@export var dic_decks : Script

var coins = 0
# Mientras hay una tirada en camino no se admite otra: el servidor ya lo
# impediria, pero asi no se cobran dos clics rapidos por error.
var _rolling := false

# Color de las particulas de la caja segun la rareza que ha tocado.
const RARITY_COLORS := {
	"common":    Color(0.35, 0.903, 1.0, 0.18),
	"uncommon":  Color(0.0, 0.752, 0.48, 0.161),
	"rare":      Color(1.0, 0.349, 0.354, 0.2),
	"legendary": Color(2.432, 2.077, 0.499, 0.184),
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Gacha/MostradorGacha/Caja.visible = false
	$Gacha/MostradorGacha/Boton_guardar.visible = false
	visible_coins()
	if not Auth.is_logged_in():
		return
	var res: Dictionary = await Database.get_me()
	if not res.ok:
		push_warning("no se pudo conseguir el usuario: %s" % res.error)
		return
	coins = int(res.data.rows[0].coins)
	visible_coins()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#visible_coins()
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
				$Gacha/MostradorGacha/AnimatedSprite3D.play("default")
				
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



# Pinta en la caja la baraja que ha tocado y la apunta en memoria. Que la
# tiene ya lo apunto el servidor al tirar; esto es solo lo que se ve.
func show_deck(rk: String, rarity: String) -> void:
	print("rk = ", rk)
	var light_effeccts = $Gacha/MostradorGacha/Caja/CPUParticles3D.mesh.get_material()
	light_effeccts.albedo_color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

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

	var dic = _dic_for_rarity(rarity)
	if dic != null:
		dic[rk] = 1
	var deck = get_dictionary_of_id(rk)
	if deck != null and not selector.my_decks.has(deck):
		selector.my_decks.push_back(deck)


func _dic_for_rarity(rarity: String):
	match rarity:
		"common":    return dic_decks.dic_common
		"uncommon":  return dic_decks.dic_uncommon
		"rare":      return dic_decks.dic_rare
		"legendary": return dic_decks.dic_legen
	return null

func get_dictionary_of_id(id):
	for d in decks.DECKS:
		if d["id"] == id:
			return d

# Tirar del gachapon. El sorteo y el cobro los hace el servidor en la misma
# transaccion (POST /db/me/gacha): si lo hiciera el cliente, cualquiera podria
# elegir baraja o no pagar la moneda.
func _on_mostrador_2_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		if _rolling or coins <= 0 or not Auth.is_logged_in():
			return
		_rolling = true
		var res: Dictionary = await Database.roll_gacha()
		_rolling = false

		if not res.ok:
			# 409: sin monedas o ya las tiene todas. No se le ha cobrado nada.
			if res.data.get("reason", "") == "no_coins":
				coins = 0
				visible_coins()
			push_warning("no se pudo tirar: %s" % res.error)
			return

		var row: Dictionary = res.data.rows[0]
		coins = int(row.coins)
		show_deck(str(row.deck_id), str(row.rarity))
		$Gacha/MostradorGacha/Caja.visible = true
		$Gacha/MostradorGacha/Boton_guardar.visible = true
		$AnimationPlayer.play("Gacha")
		$Gacha/MostradorGacha/Caja/Baraja.visible = true
		visible_coins()

func _on_puerta_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("Exit")
		SceneLoader.change_scene( "res://src/menus/main_menu.tscn", self.name)


func _on_puerta_mouse_entered() -> void:
	$AnimationPlayer2.play("Exit_hover")


func _on_puerta_mouse_exited() -> void:
	$AnimationPlayer2.play_backwards("Exit_hover")


func _on_boton_guardar_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		$AnimationPlayer.play("Back_gacha")

func visible_coins() -> void:
	$Camera3D/Coin_points/Label3D.text = "x %d" % coins
