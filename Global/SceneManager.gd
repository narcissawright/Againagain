extends CanvasLayer

var changing = false

signal changing_scene(scene_name:String)
signal new_scene(scene_name:String)
signal scene_fade_finished

func _ready() -> void:
	$FadeLayer.modulate.a = 0.0
	
func insta_change_scene(scene:String) -> void:
	if changing:
		Debug.printf("busy changing...")
		return
	changing = true
	get_tree().change_scene_to_file(scene)
	changing = false 

func change_scene(scene:String) -> void:
	if changing: 
		Debug.printf("busy changing...")
		return
	changing = true
	emit_signal("changing_scene", scene)
	ResourceLoader.load_threaded_request(scene)
	$AnimationPlayer.play('fade_out')
	await $AnimationPlayer.animation_finished
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		current_scene.queue_free()
		await current_scene.tree_exited
	
	emit_signal("new_scene", scene)
	#Debug.printf("Before ready")
	
	var s = ResourceLoader.load_threaded_get(scene)
	current_scene = s.instantiate()
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene(current_scene)
	#Debug.printf ("after ready")
	$AnimationPlayer.play('fade_in')
	await $AnimationPlayer.animation_finished
	emit_signal("scene_fade_finished")
	changing = false

# add Reload current scene?
