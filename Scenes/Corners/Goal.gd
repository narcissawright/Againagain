extends Area3D

func _on_body_entered(_body:PhysicsBody3D):
	Events.emit_signal('player_reached_goal')
