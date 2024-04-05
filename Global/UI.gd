extends CanvasLayer

func initialize_as_client() -> void:
	$Chat.start()

func fade_out() -> void:
	$FadeLayer/AP.play('fade_out')
	await $FadeLayer/AP.animation_finished

func fade_in() -> void:
	$SceneNameLabel/AP.stop() # if this was already playing, end it now for the new scene.
	$FadeLayer/AP.play('fade_in')
	await $FadeLayer/AP.animation_finished

func animate_scene_name(new_scene_name:String) -> void:
	$SceneNameLabel.text = new_scene_name
	$SceneNameLabel/AP.play('fade_in_out')
	
func set_input_display_visibility(value:bool) -> void:
	$action_input_display.visible = value

func update_timer(human_readable_time:String) -> void:
	$Timer.text = human_readable_time
