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
		label.append_text('db.leaderboard[' + level_name +']')
		label.newline()
		label.push_color(entry_color)
		for entry in Network.db.leaderboard[level_name].entries:
			label.append_text(entry.username +" "+ entry.final_time +" "+ entry.date_achieved )
			label.newline()
		label.pop()
