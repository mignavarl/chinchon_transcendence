@tool
extends EditorPlugin


func _enable_plugin() -> void:
	print("iniciado")


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _input(event: InputEvent) -> void:
	print(event)


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
