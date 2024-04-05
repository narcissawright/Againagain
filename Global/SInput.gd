extends Node

enum Mode {NO_INPUT, LIVE_INPUT, FROM_REPLAY}
var current_mode = Mode.LIVE_INPUT

var device_id:int = 0 # hardcoded at zero for the time being
var action_list:Array[StringName] # list of input actions

var this_frame:Dictionary # holds input information about the current frame
var buffer_queue:Dictionary # keeping track of what actions are buffered
const MAX_BUFFER_TIME:int = 8 # frames

func _init() -> void:
	# Set action list. Filter out the built-in ui actions.
	action_list = InputMap.get_actions().filter(func(action): return not action.begins_with("ui_"))
	clear_this_frame() # Initiate this_frame
	clear_buffer_queue() # Initiate buffer_queue

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
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Utils.set_priority(self, "input")

func change_mode(new_mode:Mode) -> void:
	#Debug.printf("Changing to mode: " + str(new_mode))
	clear_this_frame()
	clear_buffer_queue()
	current_mode = new_mode
	UI.set_input_display_visibility(current_mode != Mode.NO_INPUT)

func _physics_process(_delta:float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		set_physics_process(false)
		get_tree().quit()
		#Game.prepare_quit()
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
	
	# Analyze (buffer, just pressed)
	for action in buffer_queue:
		if buffer_queue[action] > 0:  buffer_queue[action] += 1
		if buffer_queue[action] > MAX_BUFFER_TIME:  buffer_queue[action] = 0
	
	this_frame['just_pressed'] = []
	for action in this_frame['Act']:
		if not prev_actions.has(action):
			this_frame['just_pressed'].append(action)
			buffer_queue[action] = 1

func clean_stick(dir:Vector2) -> Vector2:
	# numbers may need adjustment based on what controller the player is using.
	var deadzone = 0.05  # minimum stick input needed to trigger a reaction
	var maxzone = 1.0    # maximum stick input (cannot go higher)
	
	var raw_length:float = dir.length()
	var new_length:float = inverse_lerp(deadzone, maxzone, raw_length)
	new_length = clamp(new_length, 0.0, 1.0)
	# minimum length of 0, maximum length of 1.

	return dir.normalized() * new_length

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
	this_frame['Act'] = TimeAttack.r.inputs[TimeAttack.r.index].get("Act", []).duplicate()
	# Joysticks
	this_frame['LS'] = TimeAttack.r.inputs[TimeAttack.r.index].get('LS', Vector2.ZERO)
	this_frame['RS'] = TimeAttack.r.inputs[TimeAttack.r.index].get('RS', Vector2.ZERO)
	# Analog Shoulder
	this_frame['L2'] = TimeAttack.r.inputs[TimeAttack.r.index].get('L2', 0.0)
	this_frame['R2'] = TimeAttack.r.inputs[TimeAttack.r.index].get('R2', 0.0)

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
