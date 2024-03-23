extends CanvasLayer

var changing = false

signal changing_scene(scene_name:String)
signal new_scene(scene_name:String)
signal scene_fade_finished

func get_current_scene_name() -> StringName:
	return get_tree().get_current_scene().name

func get_scene_path(scene_name:String) -> String:
	return "res://Scenes/"+scene_name+"/"+scene_name+".tscn"

func scene_exists(scene_name:String) -> bool:
	var scene_path = get_scene_path(scene_name)
	return ResourceLoader.exists(scene_path)

func _ready() -> void:
	$FadeLayer.modulate.a = 0.0
	
func insta_change_scene(scene_name:String) -> void:
	if not is_valid_scene_change(scene_name):
		return
	changing = true
	get_tree().change_scene_to_file(get_scene_path(scene_name))
	changing = false



func is_valid_scene_change(scene_name:String) -> bool:
	if changing: 
		Debug.printf("busy changing...")
		return false
	if not scene_exists(scene_name):
		Debug.printf(scene_name + " - invalid scene. Check path?")
		return false
	return true

func change_scene(scene_name:String) -> void:
	if not is_valid_scene_change(scene_name):
		return
	
	changing = true
	emit_signal("changing_scene", scene_name)
	var scene_path = get_scene_path(scene_name)
	ResourceLoader.load_threaded_request(scene_path)
	$AnimationPlayer.play('fade_out')
	await $AnimationPlayer.animation_finished
	
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		current_scene.queue_free()
		await current_scene.tree_exited
	
	emit_signal("new_scene", scene_name)
	#Debug.printf("Before ready")
	
	var s = ResourceLoader.load_threaded_get(scene_path)
	current_scene = s.instantiate()
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene(current_scene)
	#Debug.printf ("after ready")
	$AnimationPlayer.play('fade_in')
	await $AnimationPlayer.animation_finished
	emit_signal("scene_fade_finished")
	changing = false

func reload_current_scene() -> void:
	change_scene(get_current_scene_name())
