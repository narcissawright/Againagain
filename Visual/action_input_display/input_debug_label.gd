extends RichTextLabel

@onready var actions:Array[StringName] = SInput.action_list

func _process(_t:float) -> void:
	text = Palette.bb('grey') + '[ ' + Palette.bb_end
	for i in range (actions.size()):
		if SInput.is_pressed(actions[i]):
			if SInput.is_just_pressed(actions[i]):
				text += Palette.bb('white')
			else:
				text += Palette.bb('blue_energy')
		else:
			text += Palette.bb('disabled_grey')
		text += '"' + actions[i] + '"' + Palette.bb_end
		if i < actions.size() - 1:
			text += Palette.bb('disabled_grey') + ', '
	text += Palette.bb('grey') + ' ]' + Palette.bb_end
