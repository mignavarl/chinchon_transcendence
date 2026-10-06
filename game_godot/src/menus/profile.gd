extends Control

# =============================================================================
# profile.gd
#
# Pantalla de perfil: nombre, avatar, lista de amigos e historial.
#
# Todo lo que se ve aqui sale del servidor a traves de ProfileApi
# (src/network/profile_api.gd), que es quien habla con /db/profile/*. En este
# fichero no hay ni una consulta: solo se piden cosas y se pintan.
# =============================================================================

# Colores de la lista de amigos. Son los mismos que ya estaban puestos a mano
# en la version anterior de este fichero.
const COLOR_ONLINE := Color(0.272, 0.8, 0.278)
const COLOR_OFFLINE := Color(0.8, 0.278, 0.278)

# Color del texto de los blocs, igual que los titulos de profile.tscn.
const COLOR_BLOC := Color(0.2784314, 0.2784314, 0.2784314)

const HISTORIAL_FILAS := 10

# Se guarda el catalogo la primera vez que se pide: no cambia mientras se
# juega, asi que no hace falta volver a pedirlo cada vez que se abre el picker.
var _avatares: Array = []

# El historial se pide solo la primera vez que se abre el panel.
var _historial_cargado := false

var _mi_avatar_url := ""

@onready var _label_user: Label = $user_profile/HBoxContainer/labels/Label_user
@onready var _line_user: LineEdit = $user_profile/HBoxContainer/edit/user
@onready var _avatar: TextureButton = $user_profile/avatar
@onready var _boton_act: Button = $user_profile/act_user
@onready var _lista_amigos: VBoxContainer = $friends/friends_list
@onready var _plantilla_amigo: Label = $friends/friends_list/Label
@onready var _line_friend: LineEdit = $friends/VBoxContainer/line_friend
@onready var _boton_add: Button = $friends/VBoxContainer/add_friend
@onready var _max_amigos: Label = $friends/max_friends

# Contenedores del historial. No estan en profile.tscn: el panel solo trae los
# dos blocs y sus titulos, asi que las filas se cuelgan de aqui al arrancar.
var _hist_partidas: VBoxContainer
#var _hist_puntos: VBoxContainer


func _ready() -> void:
	_max_amigos.visible = false

	# El panel del historial no trae visible = false en profile.tscn, asi que
	# arrancaba abierto y su "rug" (1920x1080) tapaba el perfil entero. Se
	# cierra aqui y no en la escena para no chocar con quien la este tocando.
	$historial_menu.visible = false

	_montar_historial()

	# Sin sesion resuelta no se pide nada: todas las rutas /me contestarian 401.
	# Se juega igual, pero el perfil se queda como una ficha vacia.
	if not Auth.can_save():
		_sin_sesion()
		return

	_label_user.text = Auth.username
	_line_user.text = Auth.username

	await _cargar_perfil()
	await _cargar_amigos()


# =============================================================================
# PERFIL
# =============================================================================

func _cargar_perfil() -> void:
	var res: Dictionary = await ProfileApi.get_profile()
	if not res.ok:
		_avisar(_label_user, res.error)
		return

	var filas: Array = res.data.get("rows", [])
	if filas.is_empty():
		return

	var yo: Dictionary = filas[0]

	_label_user.text = str(yo.get("username", Auth.username))
	_line_user.text = str(yo.get("username", ""))
	_poner_avatar(str(yo.get("avatar_url", "")))


# Carga la textura del avatar. Las rutas del catalogo son res:// de cosas que
# ya vienen dentro del juego; las subidas por el usuario ("/db/avatars/...")
# se descargan del gateway. De las dos se encarga ProfileApi.load_avatar().
# Si no se pudiera cargar, se deja la textura que trae la escena en vez de
# dejarlo en blanco.
func _poner_avatar(url: String) -> void:
	if url.is_empty():
		return

	_mi_avatar_url = url

	if url.begins_with("res://") and not ResourceLoader.exists(url):
		push_warning("el avatar %s no existe en el export" % url)
		return

	var tex := await ProfileApi.load_avatar(url)
	if tex:
		_avatar.texture_normal = tex


# --- Cambiar el nombre de usuario --------------------------------------------

# OJO con el nodo: el LineEdit esta en user_profile/HBoxContainer/edit/user,
# no en HBoxContainer/edit/user. La ruta corta apuntaba a un nodo que no
# existe y devolvia null.
func _on_act_user_button_up() -> void:
	if not Auth.can_save():
		_avisar(_label_user, "<iniciar_sesion>")
		return

	var nuevo := _line_user.text.strip_edges()

	if nuevo.is_empty():
		_avisar(_label_user, "<escribe_nombre>")
		return
	if nuevo == Auth.username:
		return

	# Se bloquea el boton mientras va la peticion: si no, dando dos veces se
	# manda el cambio dos veces.
	_boton_act.disabled = true

	# HEAD primero, solo para poder avisar sin llegar a intentar el cambio.
	# El POST lo vuelve a comprobar de todas formas: entre estas dos llamadas
	# otro podria pillar el nombre.
	if not await ProfileApi.is_username_free(nuevo):
		_boton_act.disabled = false
		_avisar(_label_user, "<nombre_usado>")
		_line_user.text = Auth.username
		return

	var res: Dictionary = await ProfileApi.change_username(nuevo)
	_boton_act.disabled = false

	if not res.ok:
		_avisar(_label_user, res.error)
		_line_user.text = Auth.username
		return

	if res.data.get("unchanged", false):
		return

	# El token lleva dentro el nombre viejo, asi que ya no vale para nada: a
	# partir de aqui cualquier ruta /me contestaria 403. Toca entrar otra vez.
	_label_user.text = nuevo
	if res.data.get("reauth_required", false):
		_avisar(_label_user, "<volver_sesion>")
		$Exit.disabled = true
		$Exit.text = "<volver_sesion>"
		Auth.logout()


# --- Cambiar el avatar -------------------------------------------------------

func _on_avatar_button_up() -> void:
	if not Auth.can_save():
		_avisar(_label_user, "<iniciar_sesion>")
		return

	if _avatares.is_empty():
		var res: Dictionary = await ProfileApi.get_avatar_catalog()
		if not res.ok:
			_avisar(_label_user, res.error)
			return
		_avatares = res.data.get("rows", [])

	_abrir_picker()


# El picker no esta en profile.tscn: se monta aqui con lo que devuelve el
# catalogo, asi que anadir un avatar nuevo es tocar solo el servidor.
func _abrir_picker() -> void:
	var popup := PopupPanel.new()
	popup.title = "Avatar"

	var caja := VBoxContainer.new()
	popup.add_child(caja)

	var rejilla := GridContainer.new()
	rejilla.columns = 4
	caja.add_child(rejilla)

	for avatar in _avatares:
		var url := str(avatar.get("url", ""))
		var boton := TextureButton.new()
		boton.custom_minimum_size = Vector2(140, 140)
		boton.ignore_texture_size = true
		boton.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		boton.tooltip_text = str(avatar.get("name", ""))

		if ResourceLoader.exists(url):
			boton.texture_normal = load(url)

		# PUT: el avatar es un solo valor, lo que se manda pasa a ser el estado
		# completo. Volver a pulsar el mismo deja lo mismo.
		boton.pressed.connect(func() -> void:
			popup.hide()
			await _elegir_avatar(str(avatar.get("id", "")))
		)
		rejilla.add_child(boton)

	# DELETE: quitar el elegido y volver al de por defecto. Es lo que le da
	# sentido al NULL de la columna: "no ha elegido" y "eligio el primero" no
	# son lo mismo.
	var quitar := Button.new()
	quitar.text = "<quitar_avatar>"
	quitar.pressed.connect(func() -> void:
		popup.hide()
		await _quitar_avatar()
	)
	caja.add_child(quitar)

	add_child(popup)
	popup.popup_centered()
	# El popup se monta cada vez, asi que se tira al cerrarlo y no se van
	# acumulando nodos escondidos por la escena.
	popup.popup_hide.connect(popup.queue_free)


func _elegir_avatar(avatar_id: String) -> void:
	var res: Dictionary = await ProfileApi.set_avatar(avatar_id)
	if not res.ok:
		_avisar(_label_user, res.error)
		return

	var filas: Array = res.data.get("rows", [])
	if not filas.is_empty():
		_poner_avatar(str(filas[0].get("avatar_url", "")))


func _quitar_avatar() -> void:
	var res: Dictionary = await ProfileApi.reset_avatar()
	if not res.ok:
		_avisar(_label_user, res.error)
		return

	# El DELETE contesta 204, sin cuerpo, asi que no dice cual es el de por
	# defecto: se vuelve a pedir la ficha, que ya lo resuelve con el coalesce.
	await _cargar_perfil()


# =============================================================================
# AMIGOS
# =============================================================================

func _cargar_amigos() -> void:
	var res: Dictionary = await ProfileApi.get_friends()
	if not res.ok:
		_avisar(_max_amigos, res.error)
		return

	_pintar_amigos(res.data.get("rows", []))
	_max_amigos.visible = res.data.get("is_full", false)


# Vacia la lista y la vuelve a montar. Se salta la plantilla, que es el Label
# invisible que viene en la escena y hace de molde para las filas.
func _pintar_amigos(amigos: Array) -> void:
	for hijo in _lista_amigos.get_children():
		if hijo != _plantilla_amigo:
			hijo.queue_free()

	for amigo in amigos:
		_lista_amigos.add_child(_fila_amigo(amigo))


# Cada fila es el Label de la plantilla mas un boton para quitarlo. La
# plantilla se duplica para no repetir aqui la fuente ni el tamano: si en el
# editor se cambia el Label, las filas cambian con el.
func _fila_amigo(amigo: Dictionary) -> HBoxContainer:
	var fila := HBoxContainer.new()

	var nombre := _plantilla_amigo.duplicate() as Label
	nombre.visible = true
	nombre.text = str(amigo.get("name", amigo.get("username", "?")))
	nombre.set("theme_override_colors/font_color",
		COLOR_ONLINE if amigo.get("is_online", false) else COLOR_OFFLINE)
	nombre.tooltip_text = str(amigo.get("username", ""))
	fila.add_child(nombre)

	var quitar := Button.new()
	quitar.text = "x"
	quitar.tooltip_text = "<quitar_amigo>"
	var friend_id := int(amigo.get("id", 0))
	quitar.pressed.connect(func() -> void:
		await _quitar_amigo(friend_id)
	)
	fila.add_child(quitar)

	return fila


func _on_add_friend_button_up() -> void:
	if not Auth.can_save():
		_avisar(_max_amigos, "<iniciar_sesion>")
		return

	var nombre := _line_friend.text.strip_edges()
	if nombre.is_empty():
		return

	_boton_add.disabled = true
	var res: Dictionary = await ProfileApi.add_friend(nombre)
	_boton_add.disabled = false

	if not res.ok:
		# El tope de amigos llega como 409 con is_full, y es justo para lo que
		# esta el Label $friends/max_friends de la escena.
		if res.data.get("is_full", false):
			_max_amigos.visible = true
		_avisar(_max_amigos, res.error)
		return

	_line_friend.text = ""
	# Se vuelve a pedir la lista entera en vez de pegar la fila a mano: asi el
	# orden (conectados primero) y el is_full los sigue decidiendo el servidor.
	await _cargar_amigos()


func _quitar_amigo(friend_id: int) -> void:
	var res: Dictionary = await ProfileApi.remove_friend(friend_id)
	if not res.ok:
		_avisar(_max_amigos, res.error)
		return

	await _cargar_amigos()


# =============================================================================
# HISTORIAL
# =============================================================================

# Los dos blocs del panel solo traen el fondo y el titulo, asi que las filas
# van en dos VBoxContainer que se crean aqui: uno para las partidas y otro
# para las puntuaciones. Comparten separacion y altura de fila para que las
# lineas de los dos lados queden a la misma altura.

func _montar_historial() -> void:
	_hist_partidas = _columna_historial($historial_menu/left, 30.0, 600.0)
	#_hist_puntos = _columna_historial($historial_menu/right, 40.0, 560.0)


func _columna_historial(padre: Control, x: float, ancho: float) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	# Debajo del titulo, que ocupa hasta y=159 en los dos blocs.
	caja.position = Vector2(x, 180.0)
	caja.custom_minimum_size = Vector2(ancho, 560.0)
	caja.size = Vector2(ancho, 560.0)
	padre.add_child(caja)
	return caja


func _on_historial_button_button_up() -> void:
	$historial_menu.visible = true

	if _historial_cargado or not Auth.can_save():
		return

	# Se marca antes de pedirlo para que dar dos veces seguidas no lance dos
	# peticiones.
	_historial_cargado = true
	
	var res: Dictionary = await ProfileApi.get_history(HISTORIAL_FILAS)
	if not res.ok:
		_historial_cargado = false
		_fila_historial(_hist_partidas, res.error, COLOR_OFFLINE)
		return

	var partidas: Array = res.data.get("rows", [])

	if partidas.is_empty():
		_fila_historial(_hist_partidas, "<no_partidas>", COLOR_BLOC)
		return
	
	_mostrar_puntuacion()

	for partida in partidas:
		_fila_historial(_hist_partidas, _describir_partida(partida, "%d" % int(partida.get("score", 0))),
			COLOR_ONLINE if partida.get("is_winner", false) else COLOR_OFFLINE)
		# En el Chinchon gana el que MENOS puntua, asi que el color va por
		# is_winner y no por el numero.
		#_fila_historial(_hist_puntos, "%d" % int(partida.get("score", 0)),
		#	COLOR_ONLINE if partida.get("is_winner", false) else COLOR_OFFLINE)
		

# "12/03  online  vs Ana, Luis"
func _describir_partida(partida: Dictionary, texto: String) -> String:
	var trozos: PackedStringArray = []

	trozos.append(_fecha_corta(str(partida.get("ended_at", ""))))
	trozos.append("online" if partida.get("is_online", false) else "solo")

	# rivales lo monta Postgres como array JSON con los demas asientos.
	var rivales = partida.get("rivales")
	if rivales is Array and not rivales.is_empty():
		var nombres: PackedStringArray = []
		for rival in rivales:
			nombres.append(str(rival.get("name", "?")))
		trozos.append("vs " + ", ".join(nombres))
	trozos.append(texto)
	return "  ".join(trozos)


# ended_at llega como ISO ("2026-09-07T18:24:11.123Z"), y en el bloc solo cabe
# el dia y el mes.
func _fecha_corta(iso: String) -> String:
	if iso.length() < 10:
		return "?"
	return "%s/%s" % [iso.substr(8, 2), iso.substr(5, 2)]


func _fila_historial(columna: VBoxContainer, texto: String, color: Color) -> Label:
	var fila := _plantilla_amigo.duplicate() as Label
	fila.visible = true
	fila.text = texto
	fila.set("theme_override_colors/font_color", color)
	fila.set("theme_override_font_sizes/font_size", 30)
	columna.add_child(fila)
	return fila

func _mostrar_puntuacion() -> void:
	var profile: Dictionary = await ProfileApi.get_profile()
	var partidas = int(profile.data.rows[0].games_played)
	var ganadas = int(profile.data.rows[0].games_won)
	$historial_menu/right/title_punt/HBoxContainer/partidas/num_partidas.text = str(partidas)
	$historial_menu/right/title_punt/HBoxContainer/ganadas/num_ganadas.text = str(ganadas)

func _on_exit_historial_button_up() -> void:
	$historial_menu.visible = false


# =============================================================================
# UTILIDADES
# =============================================================================

func _on_exit_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/main_menu.tscn", self.name)


# Todavia no hay un sitio en la escena para los errores, asi que se reutiliza
# un Label que ya existe. Cuando haya uno propio, se cambia solo esta funcion.
func _avisar(donde: Label, texto: String) -> void:
	donde.visible = true
	donde.text = texto
	push_warning("perfil: %s" % texto)


# Sin sesion no se puede pedir nada, asi que se deja claro en pantalla en vez
# de ensenar los placeholders de la escena como si fueran datos.
func _sin_sesion() -> void:
	_label_user.text = "Sin sesion"
	_line_user.editable = false
	_boton_act.disabled = true
	_boton_add.disabled = true
	_line_friend.editable = false
