extends VBoxContainer

func _ready() -> void:
	Network.connect('leaderboard_received', self.render_lb)
	
func render_lb(level_name:String, entries:Array) -> void:
	$level_name.text = '[center]' + level_name + '[/center]'
	
	var num_entries = 0
	for entry in entries:
		num_entries += 1
		if num_entries > 25:
			continue
		new_cell(Leaderboard.rank_string(entry.rank))
		new_cell(entry.current_name)
		new_cell(TimeAttack.human_readable_time(entry.frame_count))
		new_cell(entry.date_achieved)
		
		# TODO Zebra stripes, other styling, make it look nice. .. ..

func new_cell(label_text:String) -> void:
	var l = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = label_text
	$GridContainer.add_child(l)
	
