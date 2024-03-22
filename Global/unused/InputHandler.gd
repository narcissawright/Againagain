extends Node

'''
It might be nice to track the # of frames any button/action has been held for.
might be a common need in scripts ...
dunno how this might interact with lockplayer.
'''

var device_id = -1   # no device set initially, hence the -1
signal device_set

# set at the start of each frame! use this instead of get_joy_axis.
var left_stick:Vector2
var right_stick:Vector2
var L2:float
var R2:float
#var L2_delta:float
#var R2_delta:float

const SHOULDER_THRESHOLD:float = 0.5 # to count as 'pressed' in various circumstances

# unused
var left_stick_smashed:bool = false
var left_stick_smash_dir:Vector2
const SMASH_EASE:int = 4 # frames. ease of inputting a smash input
const SMASH_ACTIVE:int = 4 # frames. how long left_stick_smashed is true for.

func _ready() -> void:
	Utils.set_priority(self, 'input')
	set_process_mode(Node.PROCESS_MODE_ALWAYS) # no pause
	set_physics_process(false) # don't run yet.

func start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Input.joy_connection_changed.connect(self.joy_connection_changed)
	set_device(0)
	set_physics_process(true)

func joy_connection_changed(_device:int, _connected:bool) -> void:
	pass
	# sometimes unreliable with PS5 controller? (maybe)
	#Debug.printf('joy_connection_changed: '+str(device)+" -> "+str(connected))

func list_connected_joypads() -> Dictionary:
	var dict = {}
	for i in Input.get_connected_joypads():
		dict[i] = Input.get_joy_name(i)
	return dict

#func _input(e:InputEvent) -> void:
	## this _input function is only used to set the device, then is disabled.
	#if e is InputEventJoypadMotion:
		#if e.axis == JOY_AXIS_TRIGGER_LEFT or e.axis == JOY_AXIS_TRIGGER_RIGHT:
			#if e.axis_value > SHOULDER_THRESHOLD:
				#set_device(e.device)
	#elif e is InputEventJoypadButton:
		#if e.button_index < 15:
			#set_device(e.device)

func is_anything_pressed() -> bool:
	# Check for button input
	for button_index in range(15):
		if Input.is_joy_button_pressed(device_id, button_index):
			return true
	# Check for L2 and R2 input
	if L2 > SHOULDER_THRESHOLD or R2 > SHOULDER_THRESHOLD:
		return true
	return false

func is_device_set() -> bool:
	return device_id > -1

func set_device(device:int) -> void:
	device_id = device
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)
				event.device = device_id
				InputMap.action_add_event(action, event)
	emit_signal('device_set')
	set_process_input(false)

func _physics_process(_t:float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		set_physics_process(false)
		get_tree().quit()
		#Game.prepare_quit()
		return
	
	if not is_device_set():
		return
	
	# get joystick input for each frame
	var raw := Vector2.ZERO
	raw.x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	raw.y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	left_stick = clean_stick(raw)
	raw.x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
	raw.y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	right_stick = clean_stick(raw)
	
	# get analog trigger deltas and set current analog trigger values
	#L2_delta = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT) - L2
	#R2_delta = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) - R2
	L2 = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT)
	R2 = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT)
	
	process_buffer_queue()

var buffer_queue:Dictionary = {}
var buffer_actions:Array = ["jump"]
const BUFFER_WINDOW = 10 # frames

func process_buffer_queue() -> void:
	for action in buffer_actions:
		if Input.is_action_just_pressed(action):
			buffer_queue[action] = 0
		elif buffer_queue.has(action) and not Input.is_action_pressed(action):
			# I wonder .. about buffering the shortest jump possible
			# HRM...
			if buffer_queue[action] > 5:
				buffer_queue.erase(action)
	
	for action in buffer_queue:
		buffer_queue[action] += 1
		if buffer_queue[action] > BUFFER_WINDOW:
			buffer_queue.erase(action)
	
	Debug.write("Queue: " + str(buffer_queue))

func is_action_queued(action:String) -> bool:
	if buffer_queue.has(action): 
		buffer_queue.erase(action) # Consumes the action
		return true
	return false
	

var smash_frames:int = SMASH_EASE+1
func _unused_left_stick_smash_input_check() -> void:
	# Smash Input
	if left_stick_smashed:
		smash_frames -= 1
		if smash_frames == 0:
			left_stick_smashed = false
			left_stick_smash_dir = Vector2.ZERO
			smash_frames = SMASH_EASE+1 # ensure out of range
	else:
		var len_squared = left_stick.length_squared() # faster code
		if len_squared < 0.0625: # 0.25 ^ 2
			smash_frames = 0
		else:
			if len_squared < 0.81: # 0.9 ^ 2
				smash_frames += 1
			else:
				if smash_frames <= SMASH_EASE:
					smash_frames = SMASH_ACTIVE
					left_stick_smashed = true
					left_stick_smash_dir = left_stick.normalized()
					#print ("Smash Input!")

func clean_stick(dir:Vector2) -> Vector2:
	# numbers may need adjustment based on what controller the player is using.
	var deadzone = 0.05  # minimum stick input needed to trigger a reaction
	var maxzone = 1.0    # maximum stick input (cannot go higher)
	
	var raw_length:float = dir.length()
	var new_length:float = inverse_lerp(deadzone, maxzone, raw_length)
	new_length = clamp(new_length, 0.0, 1.0)
	# minimum length of 0, maximum length of 1.
	return dir.normalized() * new_length

# these 4 functions are to determine if a generic direction is pressed
# either through dpad or left joystick. it is more reliable than ui_up, etc.
func up_pressed() -> bool:
	if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP): return true 
	if left_stick.y < -0.5: return true
	return false
func down_pressed() -> bool:
	if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN): return true 
	if left_stick.y > 0.5: return true
	return false
func left_pressed() -> bool:
	if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT): return true 
	if left_stick.x < -0.5: return true
	return false
func right_pressed() -> bool:
	if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT): return true 
	if left_stick.x > 0.5: return true
	return false





# For Reference
#var mapping:Dictionary = {
#	0: "✖", # A
#	1: "○", # B
#	2: "□", # X
#	3: "△", # Y
#	4: "share", # or 'select' or 'back'
#	5: "ps", # might also use this as the select button?
#	6: "start",
#	7: "L3",
#	8: "R3",
#	9: "L",
#	10: "R",
#	11: "d-up",
#	12: "d-down",
#	13: "d-left",
#	14: "d-right"
#}

# Ideas for more input to set in _physics_process:

#var dpad:Vector2i  # dpad can have values like (-1, 0), (1, -1), etc.
#var d_up:bool    # individual D buttons
#var d_down:bool  # L+R and U+D cannot be pressed simultaneously
#var d_left:bool
#var d_right:bool
#
#var up_pressed:bool    # these use logic involving both the left stick and the dpad
#var down_pressed:bool  # to determine if a generic direction is pressed, for menus etc.
#var left_pressed:bool
#var right_pressed:bool 
#
#var l1:bool
#var l2:float  # analog shoulder, range 0 to 1
#var l3:bool
#
#var r1:bool
#var r2:float
#var r3:bool
#
#var a:bool  # face buttons, might change the name
#var b:bool
#var x:bool
#var y:bool
#
#var start:bool
#var select:bool  # also known as the share, or back button
