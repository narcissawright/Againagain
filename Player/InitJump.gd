extends "PlayerState.gd"

var jumpframes:int = 0
const MAX_JUMPFRAMES = 12
const MIN_JUMPFRAMES = 3
const FRAMES_TO_CONVERGE = 30

func enter() -> void:
	owner.velocity.y += 7.245
	jumpframes = 0

func exit() -> void:
	pass
	#Debug.printf("InitJump lasted " + str(jumpframes) + " frames.")

func process_state() -> void:
	var dir:Vector3 = get_movement_dir()
	generic_calc_velocity(dir, FRAMES_TO_CONVERGE)
	# make movetowards a lot stronger during initjump to make player facing/moving in the control stick dir!
	apply_gravity(0.46)
	owner.move_and_slide()
	jumpframes += 1
	
	if jumpframes >= MIN_JUMPFRAMES:
		if not SInput.is_pressed("jump"):
			owner.state = "Air"
			return
		if jumpframes >= MAX_JUMPFRAMES:
			owner.state = "Air"
			return
	
	#%Ledge.detect_attach(dir)
