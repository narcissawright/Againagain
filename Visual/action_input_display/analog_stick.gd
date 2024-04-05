extends Node2D

func _process(_t:float) -> void:
	
	%left_pos.position = SInput.get_left_stick() * 31.0
	var length:float = SInput.get_left_stick().length()
	if is_equal_approx(length, 1.0):
		%left_bounds.self_modulate = owner.c('blue_energy')
		%left_pos.modulate = owner.c('white')
	elif is_equal_approx(length, 0.0):
		%left_bounds.self_modulate = owner.c('disabled_grey')
		%left_pos.modulate = owner.c('grey')
	else:
		%left_bounds.self_modulate = owner.c('grey')
		%left_pos.modulate = owner.c('white')

	%right_pos.position = SInput.get_right_stick() * 31.0
	length = SInput.get_right_stick().length()
	if is_equal_approx(length, 1.0):
		%right_bounds.self_modulate = owner.c('blue_energy')
		%right_pos.modulate = owner.c('white')
	elif is_equal_approx(length, 0.0):
		%right_bounds.self_modulate = owner.c('disabled_grey')
		%right_pos.modulate = owner.c('grey')
	else:
		%right_bounds.self_modulate = owner.c('grey')
		%right_pos.modulate = owner.c('white')
