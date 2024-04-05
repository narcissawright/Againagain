extends Node

var r := Replay.new()
const levels = ['Corners']

var validation_queue:Array

signal replay_syncd(r:Replay)
signal replay_failed(r:Replay)
signal finished_replay_validation()

var replay_desync_reported = false # Debugger for linux server

func _ready() -> void:
	set_physics_process(false)
	Utils.set_priority(self, "timeattack")
	SceneManager.new_scene.connect(check_new_scene)

func check_new_scene(scene_name:String) -> void:
	#Debug.printf("check_new_scene " + scene_name + ", SInput mode " + str(SInput.current_mode))
	if levels.has(scene_name):
		if SInput.current_mode == SInput.Mode.LIVE_INPUT:
			Events.player_reached_goal.connect(goal)
			set_physics_process(true)

func _physics_process(_delta:float) -> void:
	#if SceneManager.changing:
		#Debug.printf(str(SceneManager.changing) + " " + str(r.index))
	#Debug.printf("PhysicsProcess: " + str(get_tree().get_frame()))
	
	match SInput.current_mode:
		SInput.Mode.LIVE_INPUT:
			r.record_frame(SInput.this_frame)
		SInput.Mode.FROM_REPLAY:
			if Replay.RECORD_PLAYER_XFORM and not replay_desync_reported:
				# Debug sync check; player position (and more) every frame
				var replay_xform:Transform3D = r.player_xform[r.index]
				var replay_velocity:Vector3 = r.player_velocity[r.index]
				var replay_camera_o:Vector3 = r.camera_orientation[r.index]
				var current_xform:Transform3D = Utils.get_player().global_transform
				var current_velocity:Vector3 = Utils.get_player().velocity
				var current_camera_o:Vector3 = Utils.get_camera().orientation
				if not replay_xform.is_equal_approx(current_xform):
					Debug.printf("F:" + str(r.index) + " R" + str(replay_xform) + " != C" + str(current_xform))
					assert(false)
					#replay_desync_reported = true 
				if not replay_velocity.is_equal_approx(current_velocity):
					Debug.printf("F:" + str(r.index) + " RV" + str(replay_velocity) + " != CV" + str(current_velocity))
					assert(false)
					#replay_desync_reported = true 
				if not replay_camera_o.is_equal_approx(current_camera_o):
					Debug.printf("F:" + str(r.index) + " RCO" + str(replay_camera_o) + " != CCO" + str(current_camera_o))
					assert(false)
					#replay_desync_reported = true 
	
	r.index += 1
	if SInput.current_mode == SInput.Mode.FROM_REPLAY:
		if r.index > r.inputs.size()-1:
			end_of_replay()
	
	Debug.write("frame_count: " + str(r.index))
	Debug.write("timer: " + human_readable_time(r.index))
	UI.update_timer(human_readable_time(r.index))

# Goal reached (live input)

func goal() -> void:
	set_physics_process(false)
	Events.player_reached_goal.disconnect(goal)
	Debug.printf(human_readable_time(r.index) + " - " + str(r.index) + " Frames")
	UI.update_timer(human_readable_time(r.index))
	SInput.change_mode(SInput.Mode.NO_INPUT)
	r.final_position_sync = Utils.get_player().global_position
	r.compress()
	var replay_data:Dictionary = r.get_client_to_server_replay_data()
	Debug.printf("Sending replay to server...")
	Network.here_is_a_replay(replay_data)
	SceneManager.change_scene('MainMenu') # note lb doesnt update when the confirm happens, cringe.

# REPLAYS

# from Server.gd
func add_replay_to_validation_queue(passed_replay:Replay) -> void:
	validation_queue.append(passed_replay)
	if validation_queue.size() == 1:
		validate_next()
	
func validate_next() -> void:
	# The queue system is tested and works!
	SInput.change_mode(SInput.Mode.NO_INPUT)
	r = validation_queue[0]
	r.index = 0
	SceneManager.new_scene.connect(start_replay)
	SceneManager.change_scene(r.level_name)

func start_replay(_scene:String) -> void:
	SceneManager.new_scene.disconnect(start_replay)
	SInput.change_mode(SInput.Mode.FROM_REPLAY)
	set_physics_process(true)

func end_of_replay() -> void:
	set_physics_process(false)
	SInput.change_mode(SInput.Mode.NO_INPUT)
	#Debug.printf("End of Replay.")
	replay_desync_reported = false
	#Debug.printf(human_readable_time(r.index) + " - " + str(r.index) + " Frames")
	
	if Utils.get_player().global_position.is_equal_approx(r.final_position_sync):
		Debug.printf("Replay Sync'd!")
		emit_signal('replay_syncd', r.duplicate())
	else:
		Debug.printf("REPLAY FAILED!")
		emit_signal('replay_failed', r.duplicate())
	
	validation_queue.erase(r)
	if not validation_queue.is_empty():
		validate_next()
	else:
		emit_signal('finished_replay_validation')

func human_readable_time(frames:int) -> String:
	@warning_ignore("integer_division")
	var minutes:int = frames / (60*60)
	var seconds:float = fmod(float(frames) / 60.0, 60.0)
	var time:String = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2).pad_decimals(2)
	return time
