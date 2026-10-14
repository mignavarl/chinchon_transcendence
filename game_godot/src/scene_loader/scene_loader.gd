extends Node2D

@export var animation_player : AnimationPlayer

func change_scene(target: String, from: String) -> void:
	## If you have an opening animation, wait for it to finish
	animation_player.play("fade_in")
	await animation_player.animation_finished
	ResourceLoader.load_threaded_request(target)

	while ResourceLoader.load_threaded_get_status(target) != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().create_timer(0.1).timeout
	
	var target_scene := ResourceLoader.load_threaded_get(target) as PackedScene	
	## Add target scene to tree and unload the old scene
	get_tree().root.add_child(target_scene.instantiate())
	get_tree().root.get_node(from).queue_free()
	## If you have an ending animation, play it
	animation_player.play("fade_out")
	
