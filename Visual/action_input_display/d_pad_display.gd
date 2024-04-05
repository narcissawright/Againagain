extends Node2D

#func _process(_t:float) -> void:
	#for sprite in get_children():
		#if Input.is_action_pressed(sprite.name):
			#if Input.is_action_just_pressed(sprite.name):
				#sprite.modulate = owner.c('white')
			#else:
				#sprite.modulate = owner.c('blue_energy')
		#else:
			#sprite.modulate = owner.c('disabled_grey')
