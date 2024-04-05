extends Node

func enter() -> void:
	pass
func exit() -> void:
	pass
func process_state() -> void:
	pass

func get_movement_dir() -> Vector3:
	if owner.is_locked():
		return Vector3.ZERO
	
	var input_dir = SInput.get_left_stick()
	if input_dir.is_equal_approx(Vector2.ZERO):
		return Vector3.ZERO
	
	var camera = Utils.get_camera()
	var camera_dir = camera.global_transform.basis.z
	camera_dir.y = 0.0
	camera_dir = camera_dir.normalized()
	return (camera_dir * input_dir.y) + (camera_dir.rotated(Vector3.UP, PI/2.0) * input_dir.x)

func generic_calc_velocity(dir:Vector3, frames_to_converge:int) -> void:
	var speed = 6.0
	var accel = speed / float(frames_to_converge)
	var movement := Vector3(dir.x * speed, 0, dir.z * speed)
	owner.horizontal_velocity = owner.horizontal_velocity.move_toward(movement, accel)

func apply_gravity(gravity_modifier:float = 1.0) -> void:
	owner.velocity.y -= 9.8 / 60.0 * gravity_modifier
	owner.velocity.y = max(-100.0, owner.velocity.y) # Terminal

func can_overlap(pos:Vector3) -> bool:
	# purely an overlap test, no motion.
	var query = PhysicsShapeQueryParameters3D.new()
	var collider = owner.get_node("CollisionShape3D")
	query.shape = collider.shape.duplicate()
	query.shape.radius -= 0.01 # need a safe margin to prevent tangent overlap
	query.shape.height -= 0.01
	query.transform = Transform3D(Basis(), pos + collider.position)
	query.collision_mask = Layers.Solid
	var space = owner.get_world_3d().direct_space_state
	var result:Dictionary = space.get_rest_info(query)
#	if not result.is_empty():
#		print(pos)
#		print(result)
	return result.is_empty()
