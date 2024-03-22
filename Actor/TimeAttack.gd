extends Node

var frame_count:int = 0

func _ready() -> void:
	Events.player_reached_goal.connect(goal)
	init_time_attack()

func init_time_attack() -> void:
	if SInput.mode == "live_input":
		SInput.init_recording()
	#Debug.printf("Ready: " + str(get_tree().get_frame()))

func _physics_process(_delta:float) -> void:
	#Debug.printf("PhysicsProcess: " + str(get_tree().get_frame()))
	if SInput.mode == "live_input":
		SInput.record_frame()
	#if SInput.mode == "from_replay":
		#var replay_pos = SInput.debug_positions[frame_count]
		#var current_pos = Utils.get_player().global_position
		#if replay_pos != current_pos:
			#Debug.printf("F:" + str(frame_count) + " R" + str(replay_pos) + " != C" + str(current_pos))
	
	frame_count += 1
	Debug.write("frame_count: " + str(frame_count))
	Debug.write("timer: " + human_readable_time(frame_count))

func human_readable_time(frames:int) -> String:
	@warning_ignore("integer_division")
	var minutes:int = frames / (60*60)
	var seconds:float = fmod(float(frames) / 60.0, 60.0)
	var time:String = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2).pad_decimals(2)
	return time

func goal() -> void:
	set_physics_process(false)
	if SInput.mode == "live_input":
		SInput.stop_recording()
	
	Debug.printf(human_readable_time(frame_count) + " - " + str(frame_count) + " Frames")
	Debug.printf(str(Utils.get_player().global_position))
	
	# reload scene
	SceneManager.change_scene('res://Levels/Corners.tscn')
