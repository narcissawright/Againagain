extends Resource
class_name Database

const path:String = 'user://Database.res'
@export var secretkey_to_userid:Dictionary = {}
@export var userid_to_username:Dictionary = {}
@export var leaderboard:Dictionary = {}

func create_missing_leaderboards() -> void:
	for level in TimeAttack.levels:
		if not leaderboard.has(level):
			Debug.printf("Creating leaderboard: " + level)
			leaderboard[level] = Leaderboard.new()
			save()

func save() -> void:
	var err = ResourceSaver.save(self, path)
	if err == OK:
		Debug.printf("Saved Database.")
	else:
		Debug.printf("Database did not save!!")
		Debug.printf(str(err))
	# maybe some way to save a database backup

func username_is_taken(username:String) -> bool:
	if userid_to_username.values().has(username): return true
	return false
