extends SubViewport

const PRESSED_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const NOT_PRESSED_COLOR := Color(0.0, 0.0, 0.0, 0.333)

func _ready() -> void:
	set_physics_process(false)
	hide_joypad()
	Input.joy_connection_changed.connect(self.joy_connection_changed)
	SInput.device_set.connect(self.device_set)
	
	if SInput.is_device_set():
		device_set(false) # false means do not play animation V_V
		return
	
	render_joypad_list()

func joy_connection_changed(_device:int, _connected:bool) -> void:
	# for some reason this signal seems unreliable w/ PS5 controller :\
	render_joypad_list()

func hide_joypad() -> void:
	$dualsense.modulate.a = 0.0
	
	for child in $dualsense.get_children():
		child.modulate = PRESSED_COLOR
	
	$dualsense/base.modulate.a = 0.875
	$dualsense/stick_outer_edges.modulate.a = 0.75

func render_joypad_list(highlight_id:int = -1) -> void:
	var joypads:Dictionary = SInput.list_connected_joypads()
	if joypads.size() == 0:
		$Connected.text = "[color=#f22]No joypads connected![/color]\nGame unplayable!!"
	else:
		$Connected.text = "[color=#88f]Connected joypads:[/color]\n"
		for id in joypads.keys():
			var joytext = '[color=#555]●[/color] ' + joypads[id]
			if id == highlight_id:
				$Connected.text += '[bgcolor=#225]' + joytext + '[/bgcolor]\n'
			else:
				$Connected.text += joytext + '\n'

func device_set(play_animation=true) -> void:
	Input.joy_connection_changed.disconnect(self.joy_connection_changed)
	SInput.device_set.disconnect(self.device_set)
	
	$PressAnyButton.hide()
	
	if play_animation:
		var flashtime = 0.05
		for _x in range(4):
			render_joypad_list(SInput.device_id)
			await Utils.timer(flashtime)
			render_joypad_list()
			await Utils.timer(flashtime)
	
	$Device_Id.show()
	$Device_Id.text = '[center][color=#223]device_id ' + str(SInput.device_id) + '[/color]\n' + Input.get_joy_name(SInput.device_id) + '[/center]'
	$Connected.hide()
	
	$dualsense.modulate.a = 0.75
	process_joypad_display()
	set_physics_process(true)
	
	#Events.emit_signal('controller_monitor_finished')

func get_modulate(btn_id:JoyButton) -> Color:
	if Input.is_joy_button_pressed(SInput.device_id, btn_id):
		return PRESSED_COLOR
	return NOT_PRESSED_COLOR

func get_analog_trigger_modulate(pressure:float) -> Color:
	return NOT_PRESSED_COLOR.lerp(PRESSED_COLOR, pressure)

func get_stick_modulate(stick:Vector2) -> Color:
	# vector length squared is faster to compute than length.
	if is_equal_approx(stick.length_squared(), 1.0):
		return Color(0.5, 0.75, 1.0, 1.0) # Full press
	elif is_equal_approx(stick.length_squared(), 0.0):
		return Color(0.2, 0.35, 0.6, 1.0) # No press 
	return Color(0.3, 0.5, 1.0, 1.0) # Partial press

func _physics_process(_t:float) -> void:
	process_joypad_display()

const JOY_DIST:float = 5.0
func process_joypad_display():
	$dualsense/left_stick.position = SInput.get_left_stick() * JOY_DIST
	$dualsense/left_stick.modulate = get_stick_modulate(SInput.get_left_stick())
	
	$dualsense/right_stick.position = SInput.get_right_stick() * JOY_DIST
	$dualsense/right_stick.modulate = get_stick_modulate(SInput.get_right_stick())
	
	$dualsense/x.modulate = get_modulate(JOY_BUTTON_A)
	$dualsense/circle.modulate = get_modulate(JOY_BUTTON_B)
	$dualsense/square.modulate = get_modulate(JOY_BUTTON_X)
	$dualsense/triangle.modulate = get_modulate(JOY_BUTTON_Y)
	
	$dualsense/dup.modulate = get_modulate(JOY_BUTTON_DPAD_UP)
	$dualsense/ddown.modulate = get_modulate(JOY_BUTTON_DPAD_DOWN)
	$dualsense/dleft.modulate = get_modulate(JOY_BUTTON_DPAD_LEFT)
	$dualsense/dright.modulate = get_modulate(JOY_BUTTON_DPAD_RIGHT)
	
	$dualsense/start.modulate = get_modulate(JOY_BUTTON_START)
	$dualsense/select.modulate = get_modulate(JOY_BUTTON_BACK)
	
	$dualsense/l1.modulate = get_modulate(JOY_BUTTON_LEFT_SHOULDER)
	$dualsense/l2.modulate = get_analog_trigger_modulate(SInput.get_L2())
	$dualsense/l3.position = $dualsense/left_stick.position
	$dualsense/l3.modulate = get_modulate(JOY_BUTTON_LEFT_STICK)

	$dualsense/r1.modulate = get_modulate(JOY_BUTTON_RIGHT_SHOULDER)
	$dualsense/r2.modulate = get_analog_trigger_modulate(SInput.get_R2())
	$dualsense/r3.position = $dualsense/right_stick.position
	$dualsense/r3.modulate = get_modulate(JOY_BUTTON_RIGHT_STICK)
	
