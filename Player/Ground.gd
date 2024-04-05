extends "PlayerState.gd"

const FRAMES_TO_CONVERGE:int = 10
var air_transition_frames:int = 0

func enter() -> void:
	air_transition_frames = 0
	
	# Remove excess speed
	if owner.horizontal_velocity.length() > 6.0:
		owner.horizontal_velocity = owner.horizontal_velocity.normalized() * 6.0

func process_state() -> void:
	var dir:Vector3 = get_movement_dir()
	generic_calc_velocity(dir, FRAMES_TO_CONVERGE)
	apply_gravity()
	
	owner.move_and_slide()
	handle_rot(dir)
	
	check_for_exit_condition()
	
func check_for_exit_condition():
	if not owner.is_on_floor():
		air_transition_frames += 1
		if air_transition_frames > 4:
			owner.state = "Air"
			return
	else:
		air_transition_frames = 0
	
	if not owner.is_locked():
		if SInput.is_queued("jump"):
			owner.state = 'InitJump'
			return

func handle_rot(dir:Vector3) -> void:
	if dir.is_equal_approx(Vector3.ZERO):
		return
	
	var strength = dir.length()
	var dir_norm = dir.normalized()
	var forwards = -owner.basis.z
	
	if is_equal_approx(dir_norm.dot(forwards), 1.0):
		# Already facing the correct direction
		return
	
	var max_rot = PI/16.0
	var angle = forwards.signed_angle_to(dir, Vector3.UP)
	angle = clamp(angle, -max_rot, max_rot)
	angle *= strength # duno about this, maybe velocity should factor in.
	owner.rotate_y(angle)
