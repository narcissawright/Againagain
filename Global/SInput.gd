extends Node

enum Mode {NO_INPUT, LIVE_INPUT, FROM_REPLAY}

var current_mode = Mode.NO_INPUT

var device_id:int = 0

var action_list:Array[StringName]
var this_frame:Dictionary
var buffer_queue:Dictionary
const MAX_BUFFER_TIME:int = 8 # frames

var replay:Array
var replay_index:int = 0 # Which frame?

func _init() -> void:
	# Set action list. Filter out the built-in ui actions.
	action_list = InputMap.get_actions().filter(func(action): return not action.begins_with("ui_"))
	
	# Initiate this_frame
	clear_this_frame()
	
	# Initiate buffer_queue
	clear_buffer_queue()

func clear_this_frame() -> void:
	this_frame = {
		'Act': [],
		'just_pressed': [],
		'LS': Vector2.ZERO,
		'RS': Vector2.ZERO,
		'L2': 0.0,
		'R2': 0.0
	}

func clear_buffer_queue() -> void:
	for action in action_list:
		buffer_queue[action] = 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Utils.set_priority(self, "input")

func change_mode(new_mode:Mode) -> void:
	#Debug.printf("Changing to mode: " + new_mode)
	clear_this_frame()
	clear_buffer_queue()
	current_mode = new_mode

func _physics_process(_delta:float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		set_physics_process(false)
		get_tree().quit()
		#Game.prepare_quit()
		return
	
	if current_mode == Mode.FROM_REPLAY and replay_index > replay.size()-1:
		change_mode(Mode.NO_INPUT)
		Debug.printf("End of Replay. size: " + str(replay.size()))
		return
	
	if current_mode == Mode.NO_INPUT:
		return
	
	# Store previous actions to detect just pressed:
	var prev_actions:Array = this_frame.get('Act', []).duplicate()
	
	# Get this frame from live or replay:
	match current_mode:
		Mode.LIVE_INPUT:  
			live_input()
		Mode.FROM_REPLAY: 
			from_replay()
			replay_index += 1
	
	# Analyze (buffer, just pressed)
	for action in buffer_queue:
		if buffer_queue[action] > 0:  buffer_queue[action] += 1
		if buffer_queue[action] > MAX_BUFFER_TIME:  buffer_queue[action] = 0
	
	this_frame['just_pressed'] = []
	for action in this_frame['Act']:
		if not prev_actions.has(action):
			this_frame['just_pressed'].append(action)
			buffer_queue[action] = 1

func init_recording() -> void:
	if current_mode != Mode.LIVE_INPUT:
		return
	replay = []

#var debug_positions = []
func record_frame() -> void: # from external call?
	var stripped_input = strip_input_data(this_frame)
	replay.append(stripped_input)
	
	# remove this later:
	#debug_positions.append(Utils.get_player().global_position)

func compress_replay(data:Array) -> Dictionary:
	var packed:PackedByteArray = var_to_bytes(data)
	var packed_ZSTD:PackedByteArray = packed.compress(FileAccess.COMPRESSION_ZSTD)
	var compressed_replay := {
		'buffer_size': packed.size(),
		'packed_zstd': packed_ZSTD
	}
	Debug.printf ("Packed replay. " + str(compressed_replay.buffer_size) + " B -> " + str(packed_ZSTD.size()) + " B.")
	return compressed_replay

func decompress_replay(replay_info:Dictionary) -> Array:
	var packed:PackedByteArray = replay_info.packed_zstd.decompress(replay_info.buffer_size, FileAccess.COMPRESSION_ZSTD)
	var decompressed:Array = bytes_to_var(packed)
	return decompressed

func stop_recording() -> void:
	# give replays METADATA !!!!!!
	
	#Debug.printf(str(replay_data))
	change_mode(Mode.NO_INPUT)
	Debug.printf("Stopped recording. frames: " + str(replay.size()))
	#ResourceSaver.save(replay, "user://replay.res")
	
	var compressed_replay:Dictionary = compress_replay(replay)
	
	if OS.has_feature('editor'):
		var decompressed_replay:Array = decompress_replay(compressed_replay)
		assert(decompressed_replay == replay)
	
	Network.here_is_a_replay(compressed_replay)

# from Server.gd
func prepare_replay_verification(passed_replay:Array) -> void:
	current_mode = Mode.NO_INPUT
	replay = passed_replay
	replay_index = 0
	SceneManager.new_scene.connect(start_replay)

func start_replay(_scene:String) -> void:
	SceneManager.new_scene.disconnect(start_replay)
	change_mode(Mode.FROM_REPLAY)

func strip_input_data(frame_of_input:Dictionary) -> Dictionary:
	# Convert to recorded form (strip zero'd stuff)
	var stripped = frame_of_input.duplicate(true)
	if stripped['Act'].is_empty(): stripped.erase('Act')
	stripped.erase('just_pressed')
	if stripped['LS'].is_zero_approx(): stripped.erase('LS')
	if stripped['RS'].is_zero_approx(): stripped.erase('RS')
	if is_zero_approx(stripped['L2']): stripped.erase('L2')
	if is_zero_approx(stripped['R2']): stripped.erase('R2')
	return stripped

func live_input() -> void:
	# Boolean button actions
	this_frame['Act'] = []
	for action in action_list:
		if Input.is_action_pressed(action):
			this_frame['Act'].append(action)
	# Joysticks
	var raw := Vector2.ZERO
	raw.x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	raw.y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	this_frame['LS'] = clean_stick(raw)
	raw.x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
	raw.y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	this_frame['RS'] = clean_stick(raw)
	# Analog Shoulders
	this_frame['L2'] = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT)
	this_frame['R2'] = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT)
	
func from_replay() -> void:
	# Boolean button actions.
	this_frame['Act'] = replay[replay_index].get("Act", []).duplicate()
	# Joysticks
	this_frame['LS'] = replay[replay_index].get('LS', Vector2.ZERO)
	this_frame['RS'] = replay[replay_index].get('RS', Vector2.ZERO)
	# Analog Shoulder
	this_frame['L2'] = replay[replay_index].get('L2', 0.0)
	this_frame['R2'] = replay[replay_index].get('R2', 0.0)
	
func clean_stick(dir:Vector2) -> Vector2:
	# numbers may need adjustment based on what controller the player is using.
	var deadzone = 0.05  # minimum stick input needed to trigger a reaction
	var maxzone = 1.0    # maximum stick input (cannot go higher)
	
	var raw_length:float = dir.length()
	var new_length:float = inverse_lerp(deadzone, maxzone, raw_length)
	new_length = clamp(new_length, 0.0, 1.0)
	# minimum length of 0, maximum length of 1.
	return dir.normalized() * new_length


# EXTERNAL QUERY FUNCTIONS:

# SInput.is_just_pressed(action)
func is_just_pressed(action:String) -> bool:
	return this_frame['just_pressed'].has(action)

# SInput.is_pressed(action)
func is_pressed(action:String) -> bool:
	return this_frame['Act'].has(action)

# SInput.is_queued(action)
func is_queued(action:String) -> bool:
	if buffer_queue[action] > 0:
		buffer_queue[action] = 0  # Consumes the input!
		return true
	return false

# SInput.get_left_stick()
func get_left_stick() -> Vector2:
	return this_frame['LS']

# SInput.get_right_stick()
func get_right_stick() -> Vector2:
	return this_frame['RS']
