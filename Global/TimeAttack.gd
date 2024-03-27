extends Node

var r := Replay.new()
const levels = ['Corners']

var validation_queue:Array

signal replay_syncd(r:Replay)
signal replay_failed(r:Replay)

func _ready() -> void:
	set_physics_process(false)
	Utils.set_priority(self, "timeattack")
	SceneManager.new_scene.connect(check_new_scene)

func check_new_scene(scene_name:String) -> void:
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
			record_frame()
		SInput.Mode.FROM_REPLAY:
			if Replay.RECORD_DEBUG_POSITIONS:
				# Debug sync check; player position every frame
				var replay_pos = r.debug_positions[r.index]
				var current_pos = Utils.get_player().global_position
				if not replay_pos.is_equal_approx(current_pos):
					Debug.printf("F:" + str(r.index) + " R" + str(replay_pos) + " != C" + str(current_pos))
	
	r.index += 1
	if SInput.current_mode == SInput.Mode.FROM_REPLAY:
		if r.index > r.inputs.size()-1:
			end_of_replay()
	
	Debug.write("frame_count: " + str(r.index))
	Debug.write("timer: " + human_readable_time(r.index))

func record_frame() -> void: 
	r.record_frame(SInput.this_frame)

func end_of_replay() -> void:
	set_physics_process(false)
	SInput.change_mode(SInput.Mode.NO_INPUT)
	Debug.printf("End of Replay.")
	Debug.printf(human_readable_time(r.index) + " - " + str(r.index) + " Frames")
	
	if Utils.get_player().global_position.is_equal_approx(r.final_position_sync):
		Debug.printf("Replay Sync'd!")
		emit_signal('replay_syncd', r.duplicate())
	else:
		emit_signal('replay_failed', r.duplicate())
	
	validation_queue.erase(r)
	if not validation_queue.is_empty():
		validate_next()

func goal() -> void:
	set_physics_process(false)
	Events.player_reached_goal.disconnect(goal)
	Debug.printf(human_readable_time(r.index) + " - " + str(r.index) + " Frames")
	SInput.change_mode(SInput.Mode.NO_INPUT)
	r.final_position_sync = Utils.get_player().global_position
	r.compress()
	var replay_data:Dictionary = r.get_client_to_server_replay_data()
	Debug.printf("Sending replay to server...")
	Network.here_is_a_replay(replay_data)

# from Server.gd
func add_replay_to_validation_queue(passed_replay:Replay) -> void:
	validation_queue.append(passed_replay)
	if validation_queue.size() == 1:
		validate_next()
	
func validate_next() -> void:
	assert(not validation_queue.is_empty())
	SInput.change_mode(SInput.Mode.NO_INPUT)
	r = validation_queue[0]
	r.index = 0
	SceneManager.new_scene.connect(start_replay)
	SceneManager.change_scene(r.level_name)

func start_replay(_scene:String) -> void:
	SceneManager.new_scene.disconnect(start_replay)
	SInput.change_mode(SInput.Mode.FROM_REPLAY)
	set_physics_process(true)

func human_readable_time(frames:int) -> String:
	@warning_ignore("integer_division")
	var minutes:int = frames / (60*60)
	var seconds:float = fmod(float(frames) / 60.0, 60.0)
	var time:String = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2).pad_decimals(2)
	return time
