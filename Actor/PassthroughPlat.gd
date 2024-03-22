extends MeshInstance3D

@onready var collision = $StaticBody3D/CollisionShape3D

func _physics_process(_delta) -> void:
	collision.disabled = (collision.global_position.y > Utils.get_player().global_position.y) \
		if true \
		else false
	
	if collision.global_position.y > Utils.get_player().global_position.y:
		collision.disabled = true
	else:
		collision.disabled = false
