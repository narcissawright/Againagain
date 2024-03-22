extends Resource
class_name Database

@export var secretkey_to_userid:Dictionary = {}
@export var userid_to_username:Dictionary = {}
@export var leaderboard:Dictionary = {}

func username_is_taken(username:String) -> bool:
	if reserved.has(username): return true
	if userid_to_username.values().has(username): return true
	return false

const reserved:Array = [
	'melancholy',
	'melancholy337',
	'yumetea',
	'yume_tea',
	'yume_tea_',
	'narcissa',
	'narcissawright',
	'cosmo',
	'cosmowright',
	'kirbyssb',
	'lagufirtnec',
	'phoenixdevice',
	'aesthetika',
	'rue',
	'anon',
	'admin',
	'user',
	'username',
	'version'
	]

#
#func _init() -> void:
	#var lb = {}
	#lb['level_name'] = [{
		#'replay_file': PackedByteArray,
		#'seed': int,
		#'username': player_ids_to_usernames[player_id],
		#'frame_count': int,
		#'final_position_sync': Vector3
	#}]
	#for level in levels:
		#data[level] = {}
