extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	list_friends()
	#$HBoxContainer/edit/user.text = Auth.username
	$friends/max_friends.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_act_user_button_up() -> void:#TODO: para cambiar el nombre de usuario
	var new_user = $HBoxContainer/edit/user.text
	pass


func list_friends():#TODO: llista de amigos
	for i in 10:#maximo 10 amigos
		var friend = $friends/friends_list/Label.duplicate()
		friend.text = "manolo" #nombre del amigo
		friend.visible = true
		#mirar si el amigo está onine, entonces cambiar el color
		friend.set("theme_override_colors/font_color", Color(0.8, 0.278, 0.278)) #offline
		friend.set("theme_override_colors/font_color", Color(0.272, 0.8, 0.278)) #online
		$friends/friends_list.add_child(friend)
	pass


func _on_add_friend_button_up() -> void:#TODO: para añadir nuevo amigo (maximo 10 amigos)
	#si ya tiene 10 amigos y pulsa  $friends/max_friends.visible = true
	var new_friend = $friends/VBoxContainer/line_friend.text
	#añadir new_friend a la lista de amigos
	pass # Replace with function body.
	

func _on_avatar_button_up() -> void:#TODO: para cambiar la foto
	pass # Replace with function body.
	
func _on_exit_button_up() -> void:
	SceneLoader.change_scene("res://src/menus/main_menu.tscn", self.name)


#------------------------------------------------------
#-------------------HISTORIAL--------------------------
#------------------------------------------------------

func _on_historial_button_button_up() -> void:
	$historial_menu.visible = true


func _on_exit_historial_button_up() -> void:
	$historial_menu.visible = false
