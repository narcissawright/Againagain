extends "PlayerState.gd"

"""
player rot logic when jumping off?
jump physics improvement?
handle reaching top of a ladder w/ no ground?
"""

# vertical movement max speeds while on ladder.
const LADDER_MOVE_SPEED_UP:float = 5.0
const LADDER_MOVE_SPEED_DOWN:float = 7.0

# Set in _ready function, using player collider.
var player_spacing:float
var detach_spacing:float 

# ladder node -- can call enable_collision() or disable_collision(),
# and check properties like global_position, global_rotation, and height.
var current_ladder:Node3D

enum {OFF, ATTACHING, LADDER_MOVEMENT, DETACH_TOP}

var attach_state = OFF
var attach_point:Vector3
var side:int = 1 # front = 1, rear = -1.


func _ready() -> void:
	Events.connect("ladder_touched", ladder_touched)
	var shape = owner.get_node("CollisionShape3D").shape
	player_spacing = shape.radius + 0.01
	detach_spacing = shape.radius + 0.06 # detach player outside of the ladder Area

func ladder_touched(ladder:Node3D) -> void:
	if owner.is_locked(): return
	current_ladder = ladder
	if owner.state != "Ladder":
		current_ladder.disable_collision()
		if can_swap_to_ladder_state():
			owner.state = "Ladder"
			return
		current_ladder.enable_collision()

func can_swap_to_ladder_state() -> bool:
	# This function sets: attach_point, side
	attach_point = Vector3.ZERO
	side = 1
	
	var current_rung:int
	if owner.velocity.y < 0.0:
		current_rung = get_lower_rung()
	else:
		current_rung = get_upper_rung()
	current_rung = clampi(current_rung, 1, current_ladder.height * 3 - 1)
	
	var rung_exact_pos = current_ladder.global_position
	rung_exact_pos.y = get_rung_pos(current_rung).y
	
	var player_xz = owner.position * Vector3(1.0, 0.0, 1.0)
	var ladder_xz = current_ladder.global_position * Vector3(1.0, 0.0, 1.0)
	var relative_back = player_xz - (ladder_xz + ladder_forwards())
	var relative_front = player_xz - (ladder_xz - ladder_forwards())
	
	if relative_front.length_squared() > relative_back.length_squared():
		side = -1
	
	attach_point = rung_exact_pos - (ladder_forwards() * side * player_spacing)
	
	if at_top(): 
		# code here to determine which side we are interested in.
		# need checks on both sides to see which sides are free
		attach_point = rung_exact_pos - (ladder_forwards() * side * player_spacing)
		debug_view_collision_shape_new_pos(attach_point)
		if test_move(owner.position, attach_point):
			# current side is blocked, but what about the other side?
			side = -side
			attach_point = rung_exact_pos - (ladder_forwards() * side * player_spacing)
			debug_view_collision_shape_new_pos(attach_point)
			# two checks for far side:
			# 1. horizontal
			var to:Vector3 = attach_point
			to.y = owner.position.y
			if test_move(owner.position, to):
				return false
			# 2. vertical
			var from = attach_point
			from.y = owner.position.y
			if test_move(from, attach_point):
				return false
	
	else:
		# not at the top -- just move the collider directly to attach point
		if test_move(owner.position, attach_point):
			return false
		
		# Check control stick for more attach logic
		var dir = get_movement_dir().normalized()
		if dir.is_equal_approx(Vector3.ZERO):
			# Control stick neutral, but what about facing dir
			if (-owner.basis.z).dot(ladder_forwards() * side) < 0.0:
				return false
		if dir.dot(ladder_forwards() * side) < 0.0:
			return false
	
	# all checks passed, we can attach.
	return true

func enter() -> void:
	attach_state = ATTACHING
	owner.velocity = Vector3.ZERO
	var midpoint = current_ladder.global_position + Vector3.UP*current_ladder.height
	Events.emit_signal('ladder_camera', -ladder_forwards()*side, midpoint)

func process_state() -> void:
	match attach_state:
		ATTACHING:
			var angle_to:float = (-owner.basis.z).signed_angle_to(ladder_forwards() * side, Vector3.UP)
			angle_to = clampf(angle_to, -PI/20.0, PI/20.0)
			owner.rotate_y(angle_to)
			var move_rate = 0.05
			if at_top():
				move_rate = 0.03
				# maybe animate this differently to avoid foot clipping
			owner.position = owner.position.move_toward(attach_point, move_rate)
			if owner.position.is_equal_approx(attach_point):
				if is_equal_approx(angle_to, 0.0):
					attach_state = LADDER_MOVEMENT
	
		LADDER_MOVEMENT:
			#Debug.printf(str(get_current_rung()))
			
			if SInput.is_just_pressed('jump'):
				ladder_jump()
				return
			
			# movement speed logic
			var strength = -SInput.get_left_stick().y
			var dir_dot_ladder = get_movement_dir().dot(ladder_forwards() * side)
			strength += (dir_dot_ladder * 0.6)
			var strength_sign = sign(strength)
			strength = absf(strength)
			strength = smoothstep(0.2, 1.2, strength)
			strength *= strength_sign
			strength = clamp(strength, -1.0, 1.0)
			Debug.write("ls:  " + str(-SInput.get_left_stick().y))
			Debug.write("dot: " + str(dir_dot_ladder))
			Debug.write("str: " + str(strength))
			var intended_velocity := Vector3.UP
			if strength_sign == 1:
				intended_velocity *= strength * LADDER_MOVE_SPEED_UP
			else:
				intended_velocity *= strength * LADDER_MOVE_SPEED_DOWN
			owner.velocity = owner.velocity.move_toward(intended_velocity, 0.5)
			
			# Check for top
			if at_top(): # and owner.velocity.y > 0 ... ?:
				var rung_exact_pos = get_rung_pos(current_ladder.height * 3)
				
				# uses negative side -- checking for top detach onto solid ground
				attach_point = rung_exact_pos - (ladder_forwards() * -side * detach_spacing)
				
				debug_view_collision_shape_new_pos(attach_point)
				if can_overlap(attach_point) and ground_check(attach_point):
					attach_state = DETACH_TOP
					owner.velocity = Vector3.ZERO
					return
				
				# Switch Sides (may not implement):
#				debug_view_collision_shape_new_pos(rung_exact_pos)
#				if can_overlap(rung_exact_pos):
#					rung_exact_pos = get_rung_pos(current_ladder.height * 3 - 1)
#					if can_overlap(rung_exact_pos - (ladder_forwards() * -side * player_spacing)):
#						side = -side
#						attach_point = rung_exact_pos - (ladder_forwards() * side * player_spacing)
#						debug_view_collision_shape_new_pos(attach_point)
#						attach_state = ATTACHING
#						return
				
				# Prevent moving higher than possible
				# note that player may stop at various locations -- kind of an eror.
				if owner.velocity.y > 0: 
					owner.velocity.y = 0
			
			if get_lower_rung() < 0:
				detached()
				return
			
			# Move
			owner.move_and_slide()
			if owner.is_on_floor():
				# this kinda works.
				# also lol yet another detach spacing variable (0.11), here...
				owner.position -= (ladder_forwards() * side * 0.11)
				# it might be too snappy? DETACH_BOTTOM state?
				detached()
		
		DETACH_TOP:
			owner.global_position = owner.global_position.move_toward(attach_point, 0.055)
			if owner.global_position.is_equal_approx(attach_point):
				detached()

func ladder_jump() -> void:
	# problems:
	# the player rotates instantly which looks bad.
	owner.velocity = Vector3.ZERO
	owner.state = "InitJump"
	var dir = get_movement_dir().normalized()
	if dir.is_equal_approx(Vector3.ZERO):
		return
	owner.rotation.y = Vector3.FORWARD.signed_angle_to(dir, Vector3.UP)
	# could a tween be used here? a bit weird.
	# what about a universal player rotation function that uses goal_rotation

func detached() -> void:
	if ground_check(owner.position):
		owner.state = "Ground"
	else:
		owner.state = "Air"

func exit() -> void:
	attach_state = OFF
	attach_point = Vector3.ZERO
	side = 1
	current_ladder.enable_collision()
	current_ladder.timeout()
	Events.emit_signal('normal_camera')


# Physics Checks

func test_move(from:Vector3, to:Vector3) -> bool:
	# tests a motion
	var xform = owner.transform
	xform.origin = from
	return owner.test_move(xform, to - xform.origin)

func debug_view_collision_shape_new_pos(pos:Vector3) -> void:
	# enable Visible Collision Shapes to see it.
	for staticbody in get_children():
		staticbody.free()
	var k = owner.get_node("CollisionShape3D").duplicate()
	var sb = StaticBody3D.new()
	sb.collision_layer = 0
	sb.collision_mask = 0
	add_child(sb)
	sb.call_deferred('add_child', k)
	k.position = pos + k.position

func ground_check(pos:Vector3) -> bool:
	# tiny raycast just above the pos, downwards.
	var space = owner.get_world_3d().direct_space_state  # Space for physics checks
	var from = pos + (Vector3.UP * 0.01)
	var to = pos - (Vector3.UP * 0.01)
	var query = PhysicsRayQueryParameters3D.create(from, to, 1)
	var result = space.intersect_ray(query)
	return not result.is_empty()


# Get Rung Info / Helper Functions

# these functions don't check if the rung exists, just the would-be index.
func get_lower_rung() -> int:
	var player_pos_relative = owner.position.y - current_ladder.global_position.y
	return int(floorf(player_pos_relative * 3.0))
func get_upper_rung() -> int:
	var player_pos_relative = owner.position.y - current_ladder.global_position.y
	return int(ceilf(player_pos_relative * 3.0))
func get_current_rung() -> int:
	var player_pos_relative = owner.position.y - current_ladder.global_position.y
	return int(roundf(player_pos_relative * 3.0))
func get_rung_pos(rung_index:int) -> Vector3:
	var rung_pos = current_ladder.global_position
	rung_pos.y += float(rung_index) / 3.0
	return rung_pos
func get_rung_count() -> int:
	return current_ladder.height * 3
func at_top() -> bool:
	return get_current_rung() >= current_ladder.height * 3
func ladder_forwards() -> Vector3:
	return -current_ladder.global_transform.basis.z
