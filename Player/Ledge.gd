extends "PlayerState.gd"

'''
Problems:
- Low ledge failure (feet through floor)

Additions:
- wall kick state?
'''


const HEIGHT_OFFSET:float = 1.75
var player_radius:float

enum {NONE, ATTACHING, ON_LEDGE, CLIMB_UP}
var ledge_state = NONE

var ledge_timeout = false

# ledgecast() result:
var lc:Dictionary # ledge_normal, ledge_position, wall_normal

func _ready() -> void:
	player_radius = owner.get_node("CollisionShape3D").shape.radius

func enter() -> void:
	owner.velocity = Vector3.ZERO
	ledge_state = ATTACHING
	current_attach_frame = 0
	#%carrie_placeholder.hide()
	#%carrie_ledgegrab.show()

func exit() -> void:
	ledge_state = NONE
	#%carrie_placeholder.show()
	#%carrie_ledgegrab.hide()
	for child in get_children():
		child.free()
	timeout()
	
func timeout() -> void:
	ledge_timeout = true
	await Utils.timer(0.5)
	ledge_timeout = false

const minimum_attach_frames:int = 6
var current_attach_frame:int = 0

func attach_process() -> bool:
	# Rotation
	
	# I suspect that not using a fixed angle rate may be better...
	# ie. fast rot during the first few frames, getting slower as it approaches attach.
	# so doing awkward things like grabbing a ledge while facing the wrong way still
	# snaps relatively quickly, while ledge movement left/right to a different normal
	# still takes a moment instead of being near instantaneous.
	var angle_rate = PI/20.0
	var angle_to:float = (-owner.basis.z).signed_angle_to(-lc.wall_normal, Vector3.UP)
	var angle_completed = false
	if abs(angle_to) < angle_rate:
		angle_completed = true
	angle_to = clampf(angle_to, -angle_rate, angle_rate)
	owner.rotate_y(angle_to)
	
	# Position
	var move_rate = 0.05
	var target_pos:Vector3 = get_target_pos()
	owner.position = owner.position.move_toward(target_pos, move_rate)
	
	# Check
	if owner.position.is_equal_approx(target_pos):
		if angle_completed:
			return true
	return false

func process_state() -> void:
	match ledge_state:
		ATTACHING:
			Debug.write("attaching")
			var attached:bool = attach_process()
			if attached:
				if current_attach_frame < minimum_attach_frames:
					current_attach_frame += 1
				else:
					ledge_state = ON_LEDGE
		ON_LEDGE:
			Debug.write("on_ledge")
			
			var dir = get_movement_dir()
			var dir_2d = Vector2(dir.x, dir.z)
			var wall_normal_2d = Vector2(lc.wall_normal.x, lc.wall_normal.z)
			var wall_cross_2d = wall_normal_2d.orthogonal()
			
			var x = dir_2d.dot(wall_cross_2d)
			var y = -dir_2d.dot(wall_normal_2d)
			
			#Debug.write("Ledge: " + str(lc))
			#Debug.write("X: " + str(x) + "  Y: " + str(y))
			if SInput.is_queued("jump"):
				# Consider some animation about climb up vs fall off (jump back also?)
				if y >= 0.0:
					# can the player actually climb up here?
					# and how do I check for that 
					if true:
						#%carrie_placeholder.show()
						#%carrie_ledgegrab.hide()
						ledge_state = CLIMB_UP
						return
				else:
					owner.state = "Air"
					return
			
			x = smoothstep(0.1, 0.85, abs(x)) * sign(x)
			# perhaps if the y value is high the x value should be zero.
			# that way you are sure you're not pressing near the climb/drop direction.
			
			var move_speed = 1.5
			owner.velocity = x*move_speed * Vector3(wall_cross_2d.x, 0, wall_cross_2d.y)
			var kc:KinematicCollision3D = owner.move_and_collide(owner.velocity / 60.0)
			if kc:
				lc = ledgecast(-kc.get_normal())
				if lc.is_empty():
					lc = ledgecast(-owner.basis.z)
			else:
				lc = ledgecast(-owner.basis.z)
			
			if lc.is_empty():
				owner.state = "Air"
				return
			
			var attached:bool = attach_process()
			if not attached:
				# not resetting attach frames here because I want
				# to not delay if it's not the initial attach.
				ledge_state = ATTACHING
				return
			
		CLIMB_UP:
			Debug.write("climb_up")
			var move_rate = 0.065
			var target_pos:Vector3 = lc.ledge_position
			#target_pos += -lc.wall_normal * player_radius
			owner.position = owner.position.move_toward(target_pos, move_rate)
			if owner.position.is_equal_approx(target_pos):
				owner.state = "Ground"

func get_target_pos() -> Vector3:
	var target_pos:Vector3 = lc.ledge_position
	target_pos += (lc.wall_normal * player_radius) + (Vector3.DOWN * HEIGHT_OFFSET)
	return target_pos

func detect_attach(dir:Vector3) -> void:
	if ledge_timeout: return
	var ledge_dir = (-owner.basis.z).lerp(dir, dir.length()).normalized()
	lc = ledgecast(ledge_dir)
	if not lc.is_empty():
		if can_overlap(get_target_pos()):
			owner.state = "Ledge"

const ledge_ray_offset = 0.32
func ledgecast(detection_dir:Vector3, debug_draw:bool = false) -> Dictionary:
	
	if not is_equal_approx(detection_dir.y, 0.0):
		Debug.printf("Ledge detection vector: y component not zero")
		return {}
	if not detection_dir.is_normalized():
		Debug.printf("Ledge detection vector: not normalized.")
		return {}
	
	var space = owner.get_world_3d().direct_space_state
	var from:Vector3 = owner.position + (Vector3.UP * 2.0)
	from += detection_dir * ledge_ray_offset
	var to = from + (Vector3.DOWN * 0.65) + (detection_dir * ledge_ray_offset)
	var ray_query = PhysicsRayQueryParameters3D.create(from, to, Layers.Solid)
	var ray_result = space.intersect_ray(ray_query)
	
	if not ray_result:
		return {}  # no ray result
	
	var ledge_normal = ray_result.normal
	var ledge_pos_naive = ray_result.position
	
	if acos(ray_result.normal.y) > PI/4.0:
		return {}  # normal too slanted
	
	var from2 = owner.position
	from2.y = ledge_pos_naive.y - 0.05
	var to2 = ledge_pos_naive + Vector3.DOWN * 0.05
	var ray_query2 = PhysicsRayQueryParameters3D.create(from2, to2, Layers.Solid | Layers.Actor)
	var ray_result2 = space.intersect_ray(ray_query2)
	
	if not ray_result2:
		return {}  # no wall found
	if ray_result2.collider.collision_layer == Layers.Actor:
		return {} # do not ledgegrab at the ladder.
	
	var wall_pos = ray_result2.position
	var wall_normal = ray_result2.normal
	if wall_normal.abs().dot(Vector3.UP) > 0.125:
		return {} # wall too slanted
	
	var ledge_pos = wall_pos
	ledge_pos.y = ledge_pos_naive.y
	
	if debug_draw:
		# Debug view.
		for child in get_children():
			child.free()
		var imesh = ImmediateMesh.new()
		imesh.surface_begin(Mesh.PRIMITIVE_LINES)
		imesh.surface_add_vertex(from)
		imesh.surface_add_vertex(to)
		imesh.surface_add_vertex(from2)
		imesh.surface_add_vertex(wall_pos)
		imesh.surface_end()
		var lines = MeshInstance3D.new()
		lines.mesh = imesh
		add_child(lines)
		var sphere = MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		add_child(sphere)
		sphere.scale *= 0.1
		sphere.global_position = ledge_pos
		# end of debug
	
	return {
		"ledge_normal": ledge_normal,
		"ledge_position": ledge_pos,
		"wall_normal": wall_normal
	}
