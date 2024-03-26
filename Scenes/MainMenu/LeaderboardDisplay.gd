extends VBoxContainer

func _ready() -> void:
	Network.connect('leaderboard_received', self.render_lb)
	
func render_lb(level_name:String, entries:Array) -> void:
	$level_name.text = '[center]' + level_name + '[/center]'
	
	for entry in entries:
		#var rank:String = Leaderboard.rank_string(entry.rank)
		#var s:String = rank+" "+entry.username+" "+entry.final_time+" "+entry.date_achieved
		#Debug.printf(s)
		new_cell(Leaderboard.rank_string(entry.rank))
		new_cell(entry.username)
		new_cell(entry.final_time)
		new_cell(entry.date_achieved)
		
		# TODO Zebra stripes, other styling, make it look nice. .. ..

func new_cell(label_text:String) -> void:
	var l = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = label_text
	$GridContainer.add_child(l)
	
