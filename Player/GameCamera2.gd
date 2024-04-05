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

# Stored data for ladder mode
var ladder_forwards:Vector3

# Camera Reset
const cam_reset_max_frames:float = 60.0 # frames @ 60fps
var cam_reset_current_frame:float = 0.0   # stored as float to avoid integer division

var camera_target:Marker3D

func _ready() -> void:
	orientation = orientation_default
	distance = distance_default
	camera_target = Utils.get_camera_target()
	
	Utils.set_priority(self, 'camera') # Player code runs first.
	
	Events.connect("ladder_camera", _on_ladder_camera)
	Events.connect("normal_camera", _on_normal_camera)

func _physics_process(_t:float) -> void:
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
	raycast_and_final_position()
	
func raycast_and_final_position() -> void:
	# Update Position using 5 raycasts...
	var target:Vector3 = camera_target.global_position  # Target position
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
	
	# one more raycast
	#query.from = global_position
	#query.to = final_pos 
	#var final_result = space_state.intersect_ray(query)
	#if final_result:
		#Debug.write("final result " + str(final_result))
		#final_pos = final_result.position.move_toward(global_position, radius)
		#$Debug1.position = unproject_position(final_result.position)
		#$Debug2.position = unproject_position(final_pos)
	
	# Update camera position
	look_at_from_position(final_pos, target, Vector3.UP) # look at player from final position
	orientation = (global_transform.origin - target).normalized() # update current position



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
	orientation = orientation_default.rotated(Vector3.UP, camera_target.global_rotation.y)

func realign_camera() -> void:
	current_mode = CameraMode.REALIGN
	if next_mode == CameraMode.NORMAL:
		reset_orientation_goal()
	# if next mode is not NORMAL, orientation_goal was set elsewhere.

func reset_orientation_goal() -> void:
	orientation_goal = orientation_default.rotated(Vector3.UP, camera_target.global_rotation.y)

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
	$Debug1.position = unproject_position(camera_target.global_position)
	$Debug2.position = unproject_position(camera_target.global_position + player.horizontal_velocity)
	
	var movement_target = player.horizontal_velocity
	
	orientation -= movement_target.normalized() * 0.01
	orientation = orientation.normalized()
	
	


func _on_normal_camera() -> void:
	current_mode = CameraMode.NORMAL
	next_mode = CameraMode.NORMAL

func _on_ladder_camera(lf:Vector3, _midpoint:Vector3) -> void:
	ladder_forwards = lf
	orientation_goal = ladder_clamp_orientation()
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
	orientation = ladder_clamp_orientation()

func ladder_clamp_orientation() -> Vector3:
	var amt = remap(orientation.dot(ladder_forwards), -1.0, 0.5, 1.0, 0.0)
	amt = clamp(amt, 0.0, 1.0)
	var o = orientation.slerp(ladder_forwards, amt)
	return o.normalized()
	

