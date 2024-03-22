extends Node2D

#func _process(_t:float) -> void:
	#if InputHandler.mouse_movement == Vector2.ZERO:
		#$mouse_sprite.modulate = Palette.c('disabled_grey')
	#else:
		#$mouse_sprite.modulate = Palette.c('blue_energy')
		#
	#var x = sqrt(abs(InputHandler.mouse_movement.x))
	#x *= sign(InputHandler.mouse_movement.x)
	#var y = sqrt(abs(InputHandler.mouse_movement.y))
	#y *= sign(InputHandler.mouse_movement.y)
	#
	#$mouse_sprite.position = Vector2(x, y)
