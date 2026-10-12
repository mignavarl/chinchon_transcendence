extends Control

# Pantalla de entrada del juego. Los dos botones llaman al backend de Spring
# a traves del autoload Auth; hasta que no hay token no se pasa al menu.

@export var selector : Script
@export var decks : Script

@onready var user_input: LineEdit = %User
@onready var pass_input: LineEdit = %Pass
@onready var login_button: Button = %LoginButton
@onready var signup_button: Button = %SignupButton
@onready var info: Label = %Info

static var dic_common = {}
static var dic_uncommon = {}
static var dic_rare = {}
static var dic_legen = {}


func _ready() -> void:
	info.text = ""
	user_input.grab_focus()
	TranslationServer.set_locale(ConfigManager.get_language())

func _on_login_button_pressed() -> void:
	var user := user_input.text.strip_edges()
	var password := pass_input.text
	if not _fields_ok(user, password):
		return

	_set_busy(true, "<entrando>")
	Auth.login(user, password, _on_login_done)


func _on_signup_button_pressed() -> void:
	var user := user_input.text.strip_edges()
	var password := pass_input.text
	if not _fields_ok(user, password):
		return

	_set_busy(true, "<creando_cuenta>")
	# El signup no devuelve token, asi que en cuanto la cuenta existe se
	# hace el login normal para entrar con ella.
	Auth.signup(user, password, func(res: Dictionary) -> void:
		if not res.ok:
			_set_busy(false, res.error)
			return
		info.text = "<cuenta_creada>"
		Auth.login(user, password, _on_login_done)
	)


# Enter en cualquiera de los dos campos hace login, para no obligar a soltar
# el teclado e ir al boton con el raton.
func _on_field_text_submitted(_text: String) -> void:
	_on_login_button_pressed()


func _on_login_done(res: Dictionary) -> void:
	if not res.ok:
		_set_busy(false, res.error)
		pass_input.clear()
		return
	create_decks()
	var my_decks = await Database.get_my_decks()
	for i in my_decks.data.rows:
		selector.my_decks.push_back(i)
	SceneLoader.change_scene("res://src/menus/main_menu.tscn", self.name)
	#get_tree().change_scene_to_file("res://scenes/first.tscn")


func create_decks():
	for i in decks.DECKS:
		if i["rarity"] == "common":
			dic_common.get_or_add(i["id"])
		elif  i["rarity"] == "uncommon":
			dic_uncommon.get_or_add(i["id"])
		elif  i["rarity"] == "rare":
			dic_rare.get_or_add(i["id"])
		elif  i["rarity"] == "legendary":
			dic_legen.get_or_add(i["id"])


func _fields_ok(user: String, password: String) -> bool:
	if user.is_empty() or password.is_empty():
		info.text = "<pon_user_pass>"
		return false
	return true



# Mientras la peticion esta en el aire los botones se bloquean, que si no
# se puede mandar el mismo login tres veces a base de clicks.
func _set_busy(busy: bool, message: String) -> void:
	login_button.disabled = busy
	signup_button.disabled = busy
	info.text = message


func _on_privacity_button_up() -> void:
	SceneLoader.change_scene("res://scripts/privacy.tscn", self.name)
