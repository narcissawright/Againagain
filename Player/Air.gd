extends "PlayerState.gd"

func _ready() -> void:
	assert (%Ledge is Node)

var peak_height:float
var air_time_at_peak:int
func enter() -> void:
	peak_height = owner.global_position.y
	air_time_at_peak = 0

func exit() -> void:
	pass
	#Debug.printf("Peak Height: " + str(peak_height) + " on air_frame " + str(air_time_at_peak))
	#Debug.printf("Total air time: " + str(owner.air_frames))

func process_state() -> void:
	var dir:Vector3 = get_movement_dir()
	air_calc_velocity(dir)
	apply_gravity(2.0)
	owner.move_and_slide()
	if owner.is_on_floor():
		owner.state = "Ground"
	
	%Ledge.detect_attach(dir)
	
	#if owner.global_position.y > peak_height:
		#peak_height = owner.global_position.y
		#air_time_at_peak = owner.air_frames
	#peak_height = max(owner.global_position.y, peak_height)

func air_calc_velocity(dir:Vector3) -> void:
	var air_result = inverse_lerp(15.0, 30.0, float(owner.air_frames))
	var speed = 6.0 + clamp(air_result, 0.0, 1.0)
	var accel = speed / 60.0
	
	var pullback_calc = 1.0
	#var pullback_max_str = 2.0
	if not dir.is_equal_approx(Vector3.ZERO):
		var pullback = dir.dot(owner.velocity*Vector3(1,0,1).normalized())
		pullback_calc  = (1.0 - smoothstep(-0.5, 0.0, pullback)) + 1.0
		#pullback_calc = (1.0 - smoothstep(-0.5, 0.0, pullback)) * (pullback_max_str - 1.0) + 1.0
		accel *= pullback_calc
	Debug.write("Air pullback str: " + str(pullback_calc))
	
	var movement := Vector3(dir.x * speed, 0, dir.z * speed)
	owner.horizontal_velocity = owner.horizontal_velocity.move_toward(movement, accel)
	
	#var movement := Vector3(dir.x * accel, 0, dir.z * accel)
	#var h_velocity = (owner.velocity*Vector3(1,0,1)) + movement
	# instead of adding movement find relative distance ... or something! ack!

#func air_calc_velocity(dir:Vector3) -> void:
	##var dir:Vector3 = get_movement_dir()
##	var h_velocity:Vector3 = owner.velocity * Vector3(1,0,1)
##	var dotty:float = dir.dot(h_velocity.normalized())
##
	#var speed = 7.0
	#var accel = speed / 50.0
	#var movement := Vector3(dir.x * speed, 0, dir.z * speed)
	#var h_velocity = (owner.velocity*Vector3(1,0,1)).move_toward(movement, accel)
	#owner.velocity.x = h_velocity.x
	#owner.velocity.z = h_velocity.z
