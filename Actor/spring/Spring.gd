@tool
extends Area3D

var spring_colors:Dictionary = {
	10.0: Color(1.0, 0.25, 0.25),
	15.0: Color(0.75, 0.5, 0.25),
	20.0: Color(0.5, 0.75, 0.5),
	25.0: Color(0.25, 1.0, 0.25),
	30.0: Color(0.25, 0.25, 1.0)
}

@export_range(10.0, 30.0, 5.0) var velocity:float = 10.0:
	set(new_velocity):
		if spring_colors.has(new_velocity):
			$Model/Board.set_instance_shader_parameter("my_color", spring_colors[new_velocity])
		velocity = new_velocity
	get:
		return velocity
		

func _on_body_entered(body):
	$AudioStreamPlayer.play()
	if body.has_method("spring"):
		body.spring(velocity)
