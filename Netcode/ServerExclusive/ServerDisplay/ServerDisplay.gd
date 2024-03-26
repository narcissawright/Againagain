extends Control

@onready var label = $RichTextLabel

var entry_color := Color(0.5, 0.5, 1.0)

func _ready() -> void:
	update()

func update() -> void:
	label.clear()
	label.append_text("SERVER DISPLAY")
	label.newline() 
	
	label.newline() 
	label.append_text("peer_list")
	label.newline() 
	label.push_color(entry_color)
	for peerid in Network.peer_list:
		label.append_text("peerid " + str(peerid) + ": userid " + str(Network.peer_list[peerid]))
		label.newline()
	label.pop()
	
	label.newline()
	label.append_text("session")
	label.newline() 
	label.push_color(entry_color)
	for userid in Network.session:
		label.append_text("userid " + str(userid) + ": ")
		label.append_text(str(Network.session[userid]))
		label.newline() 
	label.pop()
	
	label.newline()
	label.append_text("db.secretkey_to_userid")
	label.newline() 
	label.push_color(entry_color)
	for key in Network.db.secretkey_to_userid:
		label.append_text("[Hidden] : " + str(Network.db.secretkey_to_userid[key]))
		label.newline() 
	label.pop()
	
	label.newline()
	label.append_text("db.userid_to_username")
	label.newline() 
	label.push_color(entry_color)
	for userid in Network.db.userid_to_username:
		label.append_text(str(userid) +" : "+ Network.db.userid_to_username[userid])
		label.newline() 
	label.pop()
	
	for level_name in Network.db.leaderboard:
		label.newline()
		label.append_text('db.leaderboard.' + level_name)
		label.newline()
		label.push_color(entry_color)
		label.append_text("packed_zstd.size() ")
		label.append_text("buffer_size ")
		label.append_text("rng_seed ")
		label.append_text("final_position_sync ")
		label.append_text("frame_count ")
		label.append_text("final_time ")
		label.append_text("level_name ")
		label.append_text("unix_time_start ")
		label.append_text("unix_time_end ")
		label.append_text("userid ")
		label.append_text("username ")
		label.append_text("date_achieved ")
		label.append_text("rank_when_set ")
		label.append_text("attempt_count ")
		label.newline()
		
		for r in Network.db.leaderboard[level_name].entries:
			label.append_text(str(r.packed_zstd.size()) + " ")
			label.append_text(str(r.buffer_size) + " ")
			label.append_text(str(r.rng_seed) + " ")
			label.append_text(str(r.final_position_sync) + " ")
			label.append_text(str(r.frame_count) + " ")
			label.append_text(str(r.final_time) + " ")
			label.append_text(r.level_name + " ")
			label.append_text(str(r.unix_time_start) + " ")
			label.append_text(str(r.unix_time_end) + " ")
			label.append_text(str(r.userid) + " ")
			label.append_text(r.username + " ")
			label.append_text(r.date_achieved + " ")
			label.append_text(str(r.rank_when_set) + " ")
			label.append_text(str(r.attempt_count) + " ")
			
			
			#label.append_text("inputs.size() " + str(r.inputs.size()) + " ")
			#label.append_text("packed_zstd.size() " + str(r.packed_zstd.size()) + " ")
			#label.append_text("buffer_size " + str(r.buffer_size) + " ")
			#label.append_text("rng_seed " + str(r.rng_seed) + " ")
			#label.append_text("final_position_sync " + str(r.final_position_sync) + " ")
			#label.append_text("frame_count " + str(r.frame_count) + " ")
			#label.append_text("final_time " + str(r.final_time) + " ")
			#label.append_text("level_name " + str(r.level_name) + " ")
			#label.append_text("unix_time_start " + str(r.unix_time_start) + " ")
			#label.append_text("unix_time_end " + str(r.unix_time_end) + " ")
			#label.append_text("userid " + str(r.userid) + " ")
			#label.append_text("username " + r.username + " ")
			#label.append_text("date_achieved " + r.date_achieved + " ")
			#label.append_text("rank_when_set " + str(r.rank_when_set) + " ")
			#label.append_text("attempt_count " + str(r.attempt_count) + " ")
			#label.append_text("debug_positions.size() " + str(r.debug_positions.size()) + " ")
			label.newline()
		label.pop()
