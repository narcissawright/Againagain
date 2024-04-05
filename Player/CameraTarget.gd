extends Marker3D

const DEBUG_VIEW = true

var height:float = 1.3 # meters from ground, near player head position

var player:CharacterBody3D

func _ready() -> void:
	player = Utils.get_player()
	$Debug.visible = DEBUG_VIEW

func _physics_process(_delta:float) -> void:
	# TODO collision detection, don't let it go through walls ... 
	var target_pos:Vector3 = player.global_position
	target_pos.y += height
	
	var look_ahead = player.horizontal_velocity / 4.0
	target_pos += look_ahead
	
	#var space_state = get_world_3d().direct_space_state
	#var query = PhysicsRayQueryParameters3D.create(global_position, target_pos, 1)
	#query.collision_mask = Layers.Solid
	#var result = space_state.intersect_ray(query)
	#if result:
		#target_pos = result.position
		#$Debug.mesh.material.albedo_color = Color(1.0, 0.0, 0.0)
	#else:
		#$Debug.mesh.material.albedo_color = Color(1.0, 1.0, 1.0)
	#$Debug2.global_position = target_pos
	
	#target_pos += player.horizontal_velocity
	global_position = global_position.lerp(target_pos, 0.1)
	
	global_position = player.global_position + (Vector3.UP * height) # comment this out to enable
	global_rotation = player.global_rotation
