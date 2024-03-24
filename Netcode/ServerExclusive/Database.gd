extends Resource
class_name Database

@export var secretkey_to_userid:Dictionary = {}
@export var userid_to_username:Dictionary = {}
@export var leaderboard:Dictionary = {}

func username_is_taken(username:String) -> bool:
	if userid_to_username.values().has(username): return true
	return false
