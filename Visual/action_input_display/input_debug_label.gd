extends RichTextLabel

@onready var actions:Array[StringName] = SInput.action_list

func _process(_t:float) -> void:
	text = owner.bb('grey') + '[ ' + owner.bb_end
	for i in range (actions.size()):
		if SInput.is_pressed(actions[i]):
			if SInput.is_just_pressed(actions[i]):
				text += owner.bb('white')
			else:
				text += owner.bb('blue_energy')
		else:
			text += owner.bb('disabled_grey')
		text += '"' + actions[i] + '"' + owner.bb_end
		if i < actions.size() - 1:
			text += owner.bb('disabled_grey') + ', '
	text += owner.bb('grey') + ' ]' + owner.bb_end
