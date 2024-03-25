extends Node

# Network
var network = ENetMultiplayerPeer.new()
const PORT = 8888
const MAX_CONNECTIONS = 1000  #4095 is the cap

# Game version
var version:String = "0.1" # Game version must match client.

# Session information
var peer_list:Dictionary = {} # {peerid: userid}
var session:Dictionary = {}   # {userid: {unix_time_start, rng_seed, level_name}}

# Database
var db:Database

# Visual
var display = preload('res://Netcode/ServerExclusive/ServerDisplay/ServerDisplay.tscn')

# Validation etc
const SEED_TIMESTAMP_LENIENCY:int = 10 # seconds
const USERNAME_LENGTH_MAX = 16
const USERNAME_LENGTH_MIN = 1
const Sensitive = preload('res://Netcode/ServerExclusive/sensitive_data.gd')

enum Error {
	ARGUMENT_TYPE_MISMATCH,
	VERSION_MISMATCH,
	USERNAME_INVALID,
	USERNAME_RESERVED,
	SECRETKEY_MISMATCH,
	NOT_LOGGED_IN,
	BAD_DATA
	}

func start() -> void:
	# Load Database
	if ResourceLoader.exists(Database.path):
		db = ResourceLoader.load(Database.path)
		Debug.printf("Loaded Database from file")
	else:
		db = Database.new()
		Debug.printf("New Database")
	db.create_missing_leaderboards()
	
	# Display
	display = display.instantiate()
	add_child(display)
	
	# Create Server
	network.create_server(PORT, MAX_CONNECTIONS)
	
	# Connect Signals
	multiplayer.peer_connected.connect(self.peer_connected)
	multiplayer.peer_disconnected.connect(self.peer_disconnected)
	TimeAttack.replay_syncd.connect(self.replay_syncd)
	TimeAttack.replay_failed.connect(self.replay_failed)
	
	# Start Server
	multiplayer.set_multiplayer_peer(network)
	Debug.printf("Server started on port " + str(PORT))
	get_node("InstanceChecker").queue_free()

func peer_connected(peerid:int) -> void:
	Debug.printf("Peer#" + str(peerid) + " connected!")
	#StC_request_identity.rpc_id(peer_id)

func peer_disconnected(peerid:int) -> void:
	if peer_list.has(peerid):
		var username = db.userid_to_username[peer_list[peerid]]
		Debug.printf(username + " disconnected.")
		peer_list.erase(peerid)
		display.update()
	else:
		Debug.printf("Peer#" + str(peerid) + " disconnected.")

func username_is_valid(passed_username:String) -> bool:
	if passed_username.length() < USERNAME_LENGTH_MIN: return false 
	if passed_username.length() > USERNAME_LENGTH_MAX: return false
	var regex := RegEx.new()
	regex.compile('^[\\w.]+') #a-z A-Z 0-9 _
	var result = regex.search(passed_username)
	if result != null:
		if result.get_string() == passed_username:
			return true
	return false

func username_is_reserved(passed_username:String) -> bool:
	if Sensitive.RESERVED.has(passed_username): 
		return true
	return false

func dictionary_is_valid(dict, validation:Dictionary) -> bool:
	if typeof(dict) != TYPE_DICTIONARY: 
		return false
	for property_name in validation:
		if not dict.has(property_name): 
			return false
	for property in dict:
		if typeof(dict[property]) != validation[property]:
			return false
	return true

func level_name_is_valid(level_name) -> bool:
	if typeof(level_name) != TYPE_STRING:
		return false
	if not TimeAttack.levels.has(level_name):
		return false
	if not db.leaderboard.has(level_name):
		Debug.printf("db doesn't have level_name ?")
		return false
	if not SceneManager.scene_exists(level_name):
		return false
	return true

func replay_syncd(r:Replay) -> void:
	var peerid = peer_list.find_key(r.userid)
	
	# Update Leaderboard
	db.leaderboard[r.level_name].add_entry(r)
	db.save()
	display.update()
	
	StC_replay_syncd.rpc_id(peerid)

func replay_failed(r:Replay) -> void:
	Debug.printf("REPLAY FAILED!")
	r.print_contents()
	var peerid = peer_list.find_key(r.userid)
	StC_replay_failed.rpc_id(peerid)

# Client -> Server calls:
# These need to be validated very well to prevent any malicious input.
@rpc('any_peer') func CtS_is_username_available(username) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate types
	if typeof(username) != TYPE_STRING:
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	# Validate username
	username = username.to_lower()
	if not username_is_valid(username):
		StC_username_availability.rpc_id(peerid, false, username)
		return
	if username_is_reserved(username):
		StC_username_availability.rpc_id(peerid, false, username)
		return
	if db.username_is_taken(username):
		StC_username_availability.rpc_id(peerid, false, username)
		return
	
	StC_username_availability.rpc_id(peerid, true, username)

@rpc('any_peer') func CtS_login(client_version, secretkey) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate types
	if typeof(client_version) != TYPE_STRING: 
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if typeof(secretkey) != TYPE_STRING:
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	# Check if client game version matches server version.
	if client_version != version:
		StC_disconnect.rpc_id(peerid, Error.VERSION_MISMATCH)
		Debug.printf("wrong game version!")
		return
	
	# scramble key further using a fixed string
	# ideally from a server exclusive file, not included in any public repo
	# you can never change the string once you are actually saving keys in production!
	secretkey += Sensitive.SCRAMBLE_STRING.sha256_text()
	secretkey = secretkey.sha256_text()
	
	if db.secretkey_to_userid.has(secretkey):
		# EXISTING USER
		#if peer_list.has(peerid): ???
		var userid:int = db.secretkey_to_userid[secretkey]
		var username:String = db.userid_to_username[userid]
		peer_list[peerid] = userid
		Debug.printf("Successful login: " + username)
		StC_successful_login.rpc_id(peerid, username)
	else:
		# NEW USER
		var userid:int = db.secretkey_to_userid.size()
		var username:String = "anon" + str(userid)
		db.secretkey_to_userid[secretkey] = db.secretkey_to_userid.size()
		db.userid_to_username[userid] = username
		Debug.printf("New user created: " + username)
		db.save()
		peer_list[peerid] = userid
		Debug.printf("Successful login: " + username)
		StC_successful_login.rpc_id(peerid, username)
	
	display.update()

@rpc('any_peer') func CtS_request_seed(level_name) -> void:
	# Validate peer
	var peerid = multiplayer.get_remote_sender_id()
	if not peer_list.has(peerid):
		StC_disconnect.rpc_id(peerid, Error.NOT_LOGGED_IN)
		return
	
	# Validate types
	if not level_name_is_valid(level_name):
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)

	var rng_seed = randi()
	var userid:int = peer_list[peerid]
	session[userid] = {
		'unix_time_start': Utils.get_unix_time(),
		'rng_seed': rng_seed,
		'level_name': level_name
	}
	display.update()
	StC_provide_seed.rpc_id(peerid, rng_seed)

@rpc ('any_peer') func CtS_validate_replay(replay) -> void:
	# Validate peer
	var peerid = multiplayer.get_remote_sender_id()
	if not peer_list.has(peerid):
		StC_disconnect.rpc_id(peerid, Error.NOT_LOGGED_IN)
		return
	
	# Validate types
	var validation = {
		"buffer_size": TYPE_INT,
		"packed_zstd": TYPE_PACKED_BYTE_ARRAY,
		"level_name": TYPE_STRING,
		"rng_seed": TYPE_INT,
		"final_position_sync": TYPE_VECTOR3
	}
	if not dictionary_is_valid(replay, validation):
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not level_name_is_valid(replay.level_name):
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
	
	var userid:int = peer_list[peerid] # get userid
	
	# Validate session vs replay:
	if not session.has(userid):
		StC_disconnect.rpc_id(peerid, Error.BAD_DATA)
		return
	if replay.rng_seed != session[userid].rng_seed:
		StC_disconnect.rpc_id(peerid, Error.BAD_DATA)
		return
	if replay.level_name != session[userid].level_name:
		StC_disconnect.rpc_id(peerid, Error.BAD_DATA)
		return
	
	# in SESSION (server validated already):
	# userid: unix_time_start, rng_seed, level_name
	# in REPLAY (arbitrary dict from client):
	# rng_seed, packed_zstd, buffer_size, final_pos_sync, level_name
	
	var r := Replay.new()
	r.reconstruct_from_server_side(replay)
	Debug.printf("Got replay of size " + str(r.inputs.size()))
	# DANGER malicious client can send bad buffer_size / packed_zstd and crash server?!
	# May need to look into other forms of decompression, and test bytes_to_var more etc.
	
	# Set additional properties (should this go in the replay script?)
	r.unix_time_start = session[userid].unix_time_start
	r.unix_time_end = Utils.get_unix_time()
	r.userid = userid
	r.username = db.userid_to_username[userid]
	r.final_time = TimeAttack.human_readable_time(r.inputs.size())
	r.date_achieved = Utils.get_date_from_unix_time(r.unix_time_start) # start or end?
	
	# Has the seed expired?
	var unix_time_difference:int = r.unix_time_end - r.unix_time_start
	@warning_ignore("integer_division")
	var runtime_seconds:int = r.inputs.size() / 60
	if unix_time_difference > runtime_seconds + SEED_TIMESTAMP_LENIENCY:
		StC_disconnect.rpc_id(peerid, Error.BAD_DATA)
		return
	
	TimeAttack.add_replay_to_validation_queue(r)

@rpc ('any_peer') func CtS_request_leaderboard(level_name) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate type
	if not level_name_is_valid(level_name):
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	var entries:Array = db.leaderboard[level_name].prepare_download()
	StC_provide_leaderboard.rpc_id(peerid, level_name, entries)

# Server -> Client calls: (implemented client-side only)
# Godot's rpc system requires the same rpc function 
# names be present both in the client and the server.
@rpc func StC_disconnect(): pass # error_id:int
@rpc func StC_successful_login(): pass 
@rpc func StC_username_availability(): pass # available:bool
@rpc func StC_provide_seed(): pass
@rpc func StC_provide_leaderboard(): pass
@rpc func StC_replay_failed(): pass
@rpc func StC_replay_syncd(): pass # should these be 1 rpc func?
