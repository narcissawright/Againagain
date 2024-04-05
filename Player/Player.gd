extends CharacterBody3D

# Lockplayer:
var lock_list:Array = []
func is_locked() -> bool:
	return !lock_list.is_empty()
func lockplayer(reason:String) -> void:
	if not lock_list.has(reason):
		lock_list.append(reason)
func unlockplayer(reason:String) -> void:
	lock_list.erase(reason)

# State
var state:String = "Ground":
	set(s):
		if state_exists(s):
			get_state_node().exit()
			state = s
			get_state_node().enter()
	get:
		return state
func state_exists(s:String) -> bool:
	if $States.has_node(s): return true
	return false
func process_state() -> void:
	get_state_node().process_state()
func get_state_node() -> Node:
	return get_node("States/"+state)

# velocity with the y component zeroed out.
var horizontal_velocity:Vector3:
	set(value):
		horizontal_velocity = value
		velocity.x = value.x
		velocity.z = value.z
	get:
		return Vector3(velocity.x, 0.0, velocity.z)

# not on floor count - kind of annoying that its part of Player and not Air?
var air_frames:int = 0

func _ready() -> void:
	SceneManager.changing_scene.connect(self.changing_scene)
	SceneManager.scene_fade_finished.connect(self.scene_fade_finished)

func changing_scene(_scene:String) -> void:
	lockplayer('fade')
func scene_fade_finished() -> void:
	unlockplayer('fade')

func _physics_process(_delta) -> void:
	process_state()
	
	if is_on_floor(): air_frames  = 0
	else:             air_frames += 1

	debug_label()

func respawn() -> void:
	velocity = Vector3.ZERO
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	state = "Ground"
	Utils.get_camera().instant_realign()

func debug_label() -> void:
	pass
	Debug.write(state)
	Debug.write("position: " + str(position))
	Debug.write("velocity: " + str(velocity))
	Debug.write("rotation: " + str(rotation))
	Debug.write("h-vel: " + str(horizontal_velocity.length()))
	Debug.write("y-vel: " + str(velocity.y))
	Debug.write("air_frames: " + str(air_frames))
