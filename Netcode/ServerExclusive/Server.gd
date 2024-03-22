extends Node

# Network
var network = ENetMultiplayerPeer.new()
const PORT = 8888
const MAX_CONNECTIONS = 1000  #4095 is the cap

# Game version
var version:String = "0.1" # Game version must match client.

# Session information
var peer_list:Dictionary # { sessionid: userid }
var seed_time_pairs:Dictionary # { seed: unix_time }

# Database
var db_path:String = 'user://Database.res'
var db:Database

# Validation
const USERNAME_LENGTH_MAX = 16
const USERNAME_LENGTH_MIN = 1

enum Error {
	ARGUMENT_TYPE_MISMATCH,
	VERSION_MISMATCH,
	USERNAME_INVALID,
	USERNAME_RESERVED,
	SECRETKEY_MISMATCH,
	}

func load_db() -> void:
	# Database
	if ResourceLoader.exists(db_path):
		db = ResourceLoader.load(db_path)
		Debug.printf("Loaded Database from file")
	else:
		db = Database.new()
		Debug.printf("New Database")

func save_db() -> void:
	var err = ResourceSaver.save(db, db_path)
	if err == OK:
		Debug.printf("Saved Database.")
	else:
		Debug.printf("Database did not save!!")
		Debug.printf(str(err))
	# maybe some way to save a database backup

func start() -> void:
	#print(Utils.get_unix_time())
	#Debug.printf(Utils.get_date_from_unix_time(Utils.get_unix_time()))
	
	Debug.printf("Starting Server.")
	
	load_db()
	
	network.create_server(PORT, MAX_CONNECTIONS)
	
	# Connect Signals
	multiplayer.peer_connected.connect(self.peer_connected)
	multiplayer.peer_disconnected.connect(self.peer_disconnected)
	
	multiplayer.set_multiplayer_peer(network)
	Debug.printf("Server started on port " + str(PORT))
	 
func peer_connected(peer_id:int) -> void:
	Debug.printf("Peer#" + str(peer_id) + " connected!")
	#StC_request_identity.rpc_id(peer_id)
	
func peer_disconnected(peer_id:int) -> void:
	if peer_list.has(peer_id):
		var username = db.userid_to_username[peer_list[peer_id]]
		Debug.printf(username + " disconnected.")
		peer_list.erase(peer_id)
	else:
		Debug.printf("Peer#" + str(peer_id) + " disconnected.")

func username_is_valid(passed_username:String) -> bool:
	if passed_username == 'æsthetika': return true # special case for admin user.
	if passed_username.length() < USERNAME_LENGTH_MIN: return false 
	if passed_username.length() > USERNAME_LENGTH_MAX: return false
	var regex := RegEx.new()
	regex.compile('^[\\w.]+') #a-z A-Z 0-9 _
	var result = regex.search(passed_username)
	if result != null:
		if result.get_string() == passed_username:
			return true
	return false

# Client -> Server calls:
# These need to be validated very well to prevent any malicious input.
@rpc('any_peer') func CtS_is_username_available(username) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	# Validate types
	if typeof(username) != TYPE_STRING:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	# Validate username
	username = username.to_lower()
	if not username_is_valid(username):
		StC_username_availability.rpc_id(id, false, username)
		return
	if db.username_is_taken(username):
		StC_username_availability.rpc_id(id, false, username)
		return
	StC_username_availability.rpc_id(id, true, username)

@rpc('any_peer') func CtS_login(client_version, secretkey) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	# Validate types
	if typeof(client_version) != TYPE_STRING: 
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if typeof(secretkey) != TYPE_STRING:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	# Check if client game version matches server version.
	if client_version != version:
		StC_disconnect.rpc_id(id, Error.VERSION_MISMATCH)
		Debug.printf("wrong game version!")
		return
	
	secretkey += "KirbySSB wuz here".sha256_text()
	secretkey = secretkey.sha256_text()
	
	if db.secretkey_to_userid.has(secretkey):
		# EXISTING USER
		#if peer_list.has(id): ???
		var userid:int = db.secretkey_to_userid[secretkey]
		var username:String = db.userid_to_username[userid]
		peer_list[id] = userid
		Debug.printf("Successful login: " + username)
		StC_successful_login.rpc_id(id, username)
	else:
		# NEW USER
		var userid:int = db.secretkey_to_userid.size()
		var username:String = "anon" + str(userid)
		db.secretkey_to_userid[secretkey] = db.secretkey_to_userid.size()
		db.userid_to_username[userid] = username
		Debug.printf("New user created: " + username)
		save_db()
		peer_list[id] = userid
		Debug.printf("Successful login: " + username)
		StC_successful_login.rpc_id(id, username)

@rpc('any_peer') func CtS_request_seed() -> void:
	var id = multiplayer.get_remote_sender_id()
	var new_seed = randi()
	
	''' TODO: also assign this seed specificially to a userid '''
	seed_time_pairs[new_seed] = Utils.get_unix_time()
	Debug.printf("seed_time_pairs: " + str(seed_time_pairs))
	
	StC_provide_seed.rpc_id(id, new_seed)

@rpc ('any_peer') func CtS_validate_replay(replay) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	# Validate type
	if typeof(replay) != TYPE_DICTIONARY:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not replay.has('buffer_size'):
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not replay.has('packed_zstd'):
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if typeof(replay.buffer_size) != TYPE_INT:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if typeof(replay.packed_zstd) != TYPE_PACKED_BYTE_ARRAY:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	var decompressed_replay:Array = SInput.decompress_replay(replay)
	Debug.printf("Got replay of size " + str(decompressed_replay.size()))
	SInput.prepare_replay_verification(decompressed_replay)
	SceneManager.change_scene('res://Levels/Corners.tscn')

@rpc ('any_peer') func CtS_request_leaderboard(level_name) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	# Validate type
	if typeof(level_name) != TYPE_STRING:
		StC_disconnect.rpc_id(id, Error.ARGUMENT_TYPE_MISMATCH)
		return
	# check if level/lb exists ??
	
	var lb = {}
	StC_provide_leaderboard.rpc_id(id, lb[level_name])
	
	
	
	#print("Peer list: ", str(peer_list))
	
#@rpc('any_peer')
#func CtS_report_position(data:Dictionary) -> void:
#	pass

# Server -> Client calls:
# Godot's rpc system requires the same rpc function 
# names be present both in the client and the server.
# Implemented client-side only:
@rpc func StC_disconnect(): pass # error_id:int
@rpc func StC_successful_login(): pass 
@rpc func StC_username_availability(): pass # available:bool
@rpc func StC_provide_seed(): pass
@rpc func StC_provide_leaderboard(): pass
