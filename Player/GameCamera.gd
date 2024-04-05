extends Camera3D

# Settings
var invert_x = false
var invert_y = false
const sensitivity:float = 0.0333

# How far can the camera go below or above the character.
const Y_MIN:float = PI/8.0  # Don't use values lower than ~0.001

# Camera distance from target
var distance:float
const distance_default:float = 4.2

# Orientation is a normalized vector where 0,0,0 is the camera target. Camera points at 0,0,0.
# It represents the camera's position relative to the target, not factoring in distance.
# It defines what raycasts should take place, which ultimately determine rotation & position.
const orientation_default := Vector3(0, 0.242536, 0.970143) # Vector3(0, 1, 4).normalized()
var orientation:Vector3
var orientation_goal:Vector3

# Current mode
enum CameraMode {NORMAL, REALIGN, LADDER}
var current_mode:CameraMode = CameraMode.NORMAL
var next_mode:CameraMode

# Camera targets
var camera_targets : Array = []

# Camera Reset
const cam_reset_max_frames:float = 60.0 # frames @ 60fps
var cam_reset_current_frame:float = 0.0   # stored as float to avoid integer division

func _ready() -> void:
	orientation = orientation_default
	distance = distance_default
	
	# Player code runs first.
	Utils.set_priority(self, 'camera')
	
	# Set player as camera target if player is in scene
	camera_targets.append(Utils.get_player().get_node("CameraTarget"))
	
	Events.connect("ladder_camera", _on_ladder_camera)
	Events.connect("normal_camera", _on_normal_camera)
	#%FadeLayer.modulate = Color(1,1,1,0)  # Need this to prevent alpha being set to max at start

func update_orientation() -> void:
	var dir = SInput.get_right_stick()
	# Handle inverted camera controls (currently unused)
	if invert_x: dir.x = -dir.x
	if invert_y: dir.y = -dir.y
	
	# Get cross vector for the up/down rotation
	var cross:Vector3 = orientation.cross(Vector3.UP).normalized()
	assert (cross != Vector3.ZERO)
	
	# Horizontal (dir.x) - very easy
	orientation = orientation.rotated(Vector3.UP, -dir.x * sensitivity)
	
	# Vertical (dir.y) - complex because we wanna prevent it from going too far.
	var rot_amount = (dir.y * sensitivity) # Rotation in radians
	var current_angle = acos(orientation.y)
	# current_angle:
	# Vector3.UP = 0.0, Vector3.DOWN = PI
	# y position in radians.

	# Another way to think about what's going on is that when the rotation happens,
	# rot_amount is being subtracted from acos(orientation.y)
	# acos(orientation.y) = acos(orientation.y) - rot_amount

	# Handle case of being near threshold:
	# appropriate range for current_angle is: threshold <---> PI-threshold
	
#	var threshold = fposmod(Y_MIN * sign(rot_amount), PI)
	if sign(rot_amount) == -1:
		var threshold = PI - Y_MIN
		if (current_angle - rot_amount) > threshold:
			rot_amount = current_angle - threshold
	else:
		var threshold = Y_MIN
		if (current_angle - rot_amount) < threshold:
			rot_amount = current_angle - threshold
	
	# Finally, perform vertical rotation
	orientation = orientation.rotated(cross, rot_amount)
	orientation = orientation.normalized() # Normalize

func instant_realign() -> void:
	orientation = orientation_default.rotated(Vector3.UP, camera_targets[0].global_rotation.y)

func realign_camera() -> void:
	current_mode = CameraMode.REALIGN
	if next_mode == CameraMode.NORMAL:
		reset_orientation_goal()
	# if next mode is not NORMAL, orientation_goal was set elsewhere.

func reset_orientation_goal() -> void:
	orientation_goal = orientation_default.rotated(Vector3.UP, camera_targets[0].global_rotation.y)

#func update_orientation_goal_complex_logic_unused() -> void:
	## to be improved? blend facing direction w/ control stick distance?
	#var input_dir = SInput.get_left_stick()
	#if input_dir.is_equal_approx(Vector2.ZERO):
		#orientation_goal = orientation_default.rotated(Vector3.UP, camera_targets[0].global_rotation.y)
	#else:
		#var camera_forwards = basis.z
		#camera_forwards.y = 0.0
		#camera_forwards = camera_forwards.normalized()
		#var camera_sideways:Vector3 = camera_forwards.rotated(Vector3.UP,PI/2.0)
		#var direction:Vector3 = (camera_forwards*input_dir.y)+(camera_sideways*input_dir.x)
		#direction = -direction.normalized()
		#orientation_goal = direction*orientation_default.z + Vector3(0,orientation_default.y,0)

func realignment_process() -> void:
	# this function has potential improvement.
	# the following two lines seem 'messy':
	
	# 1.   if orientation.dot(orientation_goal) > 0.9999:
	# this is the condition to exit the realignment state.
	# it kinda doesn't "feel elegant" but maybe i'm nitpicking.
	
	# 2.   xz = xz.slerp(xz_goal, cam_reset_current_frame / cam_reset_total_frames)
	# this is trying to do a 1/60 step rotation, but the xz has already moved.
	# so on frame 2 it's moving 2/60th of the remaining 59 distance. weird.
	# it creates sort of bezier curve on both ends though, which "looks fine"
	
	if orientation.dot(orientation_goal) > 0.9999:
		orientation = orientation_goal
		current_mode = next_mode
		cam_reset_current_frame = 0.0
	else:
		cam_reset_current_frame += 1.0
		
		# new_y is the final y position in a normalized vec3
		var new_y = lerp(orientation.y, orientation_goal.y, cam_reset_current_frame / cam_reset_max_frames)
		var xz = Vector2(orientation.x, orientation.z).normalized()
		var xz_goal = Vector2(orientation_goal.x, orientation_goal.z).normalized()
		#var xz_angle_to = xz.angle_to(xz_goal)
		#Debug.graph(xz_angle_to, "xz_angle_to")
		
		xz = xz.slerp(xz_goal, cam_reset_current_frame / cam_reset_max_frames) # horizontal rotation
		# need to multiply the xz values by a multiplier so new_pos is unit length
		xz *= sqrt(1.0 - new_y * new_y) # Thanks Syn and Eta
		orientation = Vector3(xz.x, new_y, xz.y) # should be ~unit length

func auto() -> void:
	var player = Utils.get_player()
	# TODO make this not suck
	$Debug1.position = unproject_position(camera_targets[0].global_position)
	$Debug2.position = unproject_position(camera_targets[0].global_position + player.horizontal_velocity)
	
	#var movement_target = camera_targets[0].global_position.lerp(player.horizontal_velocity, 0.5)
	var movement_target = player.horizontal_velocity
	
	orientation -= movement_target.normalized() * 0.01
	orientation = orientation.normalized()
	# first attempt
	#orientation -= (v_xz * 0.001)
	#orientation = orientation.normalized()
	
	
	

func _physics_process(_t:float) -> void:
	if camera_targets.size() <= 0:
		return  # Prevent running code without camera targets

	match current_mode:
		CameraMode.NORMAL:
			#auto()
			if SInput.is_just_pressed('camera_realign'):
				realign_camera()
			update_orientation()
		CameraMode.REALIGN:
			realignment_process()
		CameraMode.LADDER:
			ladder()
	
	# Update Position using 5 raycasts...
	var target:Vector3 = camera_targets[0].global_position  # Target position
	var space_state = get_world_3d().direct_space_state  # Space for physics checks
	var radius = 0.1  # How far the parallel rays should be separated from the origin
	
	# Front Raycast
	var from = target + (orientation * radius)
	var to = target + (orientation * distance)
	var query = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collision_mask = Layers.Solid
	var result_front = space_state.intersect_ray(query)

	# Get cross vector
	var cross:Vector3 = orientation.cross(Vector3.UP).normalized()

	# Left Raycast
	query.from = target + (cross * radius)
	query.to = target + (orientation * distance) + (cross * radius) 
	var result_left = space_state.intersect_ray(query)
	
	# Right Raycast
	query.from = target + (-cross * radius)
	query.to = target + (orientation * distance) + (-cross * radius) 
	var result_right = space_state.intersect_ray(query)
	
	# Rotate the cross vector
	cross = cross.rotated(orientation.normalized(), PI / 2.0)
	
	# Bottom Raycast
	query.from = target + (cross * radius)
	query.to = target + (orientation * distance) + (cross * radius) 
	var result_bottom = space_state.intersect_ray(query)
	
	# Top Raycast
	query.from = target + (-cross * radius)
	query.to = target + (orientation * distance) + (-cross * radius) 
	var result_top = space_state.intersect_ray(query)
	
	# See what collided
	var collisions:Array[Vector3] = []
	if result_front:  collisions.append(result_front.position)
	if result_left:   collisions.append(result_left.position)
	if result_right:  collisions.append(result_right.position)
	if result_top:    collisions.append(result_top.position)
	if result_bottom: collisions.append(result_bottom.position)
	
	# Find min length.
	# Using .length_squared() saves compute here if multiple rays hit.
	var length:float = distance * distance 
	for pos in collisions:
		length = min(length, (pos - target).length_squared())
	
	# Find final position (where the camera will be located).
	var final_pos:Vector3
	if collisions.size() > 0:
		final_pos = target + (orientation * sqrt(length))
	else:
		final_pos = target + (orientation * distance)

	# Update camera position
	look_at_from_position(final_pos, target, Vector3.UP) # look at player from final position
	orientation = (global_transform.origin - target).normalized() # update current position
	
	# Emit new camera direction
	#emit_signal("camera_dir_changed", basis.z)

#func play_fade_in():
	#%FadeLayer.modulate = Color(1,1,1,1)
	#$AnimationPlayer.play("fade_in_default")
	#current = true
#
#func play_fade_out():
	#%FadeLayer.modulate = Color(1,1,1,0)
	#$AnimationPlayer.play("fade_out_default")
	#current = true


# # # Signal Methods # # # 


#func _on_animation_finished(anim_name):
	#if anim_name in ["fade_in_default", "fade_out_default"]:
		#Events.emit_signal("camera_fade_finished")
#
#func _on_Game_enter_scene(_scene_info):
	#play_fade_in()
	#instant_realign()
#
#func _on_Game_exit_scene():
	#play_fade_out()

#func _on_player_spawned(player):
	## Add player's CameraTarget to local camera_targets
	#if camera_targets.size() == 0:
		#camera_targets.append(player.get_node("CameraTarget"))
	#else:
		#camera_targets[0] = player.get_node("CameraTarget")
#
#func _on_player_respawned():
	#instant_realign()
	#play_fade_in()
#
#func _on_player_voided():
	#play_fade_out()

func _on_normal_camera() -> void:
	current_mode = CameraMode.NORMAL
	next_mode = CameraMode.NORMAL

var ladder_forwards:Vector3

func _on_ladder_camera(lf:Vector3, _midpoint:Vector3) -> void:
	ladder_forwards = lf
	orientation_goal = clamp_orientation()
	next_mode = CameraMode.LADDER
	realign_camera()

func ladder() -> void:
	# this func is kind of like update_orientation but skips the vertical clamping
	# in favor of the circular clamping from clamp_orientation()
	var dir = SInput.get_right_stick()
	if invert_x: dir.x = -dir.x
	if invert_y: dir.y = -dir.y
	var cross:Vector3 = orientation.cross(Vector3.UP).normalized()
	assert (cross != Vector3.ZERO)
	orientation = orientation.rotated(Vector3.UP, -dir.x * sensitivity)
	orientation = orientation.rotated(cross, dir.y * sensitivity)
	orientation = clamp_orientation()

func clamp_orientation() -> Vector3:
	var amt = remap(orientation.dot(ladder_forwards), -1.0, 0.5, 1.0, 0.0)
	amt = clamp(amt, 0.0, 1.0)
	var o = orientation.slerp(ladder_forwards, amt)
	return o.normalized()
	

