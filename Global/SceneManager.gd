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
	UI.get_node('FadeLayer').modulate.a = 0.0
	Utils.set_priority(self, 'scenemanager')
	
func insta_change_scene(scene_name:String) -> void:
	if not is_valid_scene_change(scene_name):
		return
	changing = true
	get_tree().change_scene_to_file(get_scene_path(scene_name))
	changing = false

func free_current_scene() -> void:
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		current_scene.queue_free()
		#await current_scene.tree_exited

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
	#UI.get_node('SceneNameLabel').text = scene_name
	var scene_path = get_scene_path(scene_name)
	ResourceLoader.load_threaded_request(scene_path)
	await UI.fade_out()
	#UI.get_node('AnimationPlayer').play('fade_out')
	#await UI.get_node('AnimationPlayer').animation_finished
	
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		current_scene.queue_free()
		await current_scene.tree_exited
	
	#emit_signal("new_scene", scene_name)
	# CAUTION syncing the input recording start time might depend on loading time or something
	
	var s = ResourceLoader.load_threaded_get(scene_path)
	current_scene = s.instantiate()
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene(current_scene)
	
	emit_signal("new_scene", scene_name)
	
	#UI.get_node('AnimationPlayer').play('fade_in')
	#await UI.get_node('AnimationPlayer').animation_finished
	await UI.fade_in()
	
	emit_signal("scene_fade_finished")
	changing = false
	UI.animate_scene_name(scene_name)
	#UI.get_node('AnimationPlayer').play('scene_name_fade_in_out')

func reload_current_scene() -> void:
	change_scene(get_current_scene_name())
