extends Node2D

func _process(_t:float) -> void:
	
	%left_pos.position = SInput.get_left_stick() * 31.0
	var length:float = SInput.get_left_stick().length()
	if is_equal_approx(length, 1.0):
		%left_bounds.self_modulate = Palette.c('blue_energy')
		%left_pos.modulate = Palette.c('white')
	elif is_equal_approx(length, 0.0):
		%left_bounds.self_modulate = Palette.c('disabled_grey')
		%left_pos.modulate = Palette.c('grey')
	else:
		%left_bounds.self_modulate = Palette.c('grey')
		%left_pos.modulate = Palette.c('white')

	%right_pos.position = SInput.get_right_stick() * 31.0
	length = SInput.get_right_stick().length()
	if is_equal_approx(length, 1.0):
		%right_bounds.self_modulate = Palette.c('blue_energy')
		%right_pos.modulate = Palette.c('white')
	elif is_equal_approx(length, 0.0):
		%right_bounds.self_modulate = Palette.c('disabled_grey')
		%right_pos.modulate = Palette.c('grey')
	else:
		%right_bounds.self_modulate = Palette.c('grey')
		%right_pos.modulate = Palette.c('white')
