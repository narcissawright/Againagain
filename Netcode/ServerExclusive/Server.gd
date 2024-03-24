extends Node

# Network
var network = ENetMultiplayerPeer.new()
const PORT = 8888
const MAX_CONNECTIONS = 1000  #4095 is the cap

# Game version
var version:String = "0.1" # Game version must match client.

# Session information
var peer_list:Dictionary = {} # { peerid: userid }
var session:Dictionary = {} # Temp data for each user for this session

# Database
var db_path:String = 'user://Database.res'
var db:Database

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
	TimeAttack.replay_syncd.connect(self.replay_syncd)
	TimeAttack.replay_failed.connect(self.replay_failed)
	
	multiplayer.set_multiplayer_peer(network)
	Debug.printf("Server started on port " + str(PORT))
	 
func peer_connected(peerid:int) -> void:
	Debug.printf("Peer#" + str(peerid) + " connected!")
	#StC_request_identity.rpc_id(peer_id)
	
func peer_disconnected(peerid:int) -> void:
	if peer_list.has(peerid):
		var username = db.userid_to_username[peer_list[peerid]]
		Debug.printf(username + " disconnected.")
		peer_list.erase(peerid)
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
		save_db()
		peer_list[peerid] = userid
		Debug.printf("Successful login: " + username)
		StC_successful_login.rpc_id(peerid, username)

@rpc('any_peer') func CtS_request_seed(level_name) -> void:
	# Validate peer
	var peerid = multiplayer.get_remote_sender_id()
	if not peer_list.has(peerid):
		StC_disconnect.rpc_id(peerid, Error.NOT_LOGGED_IN)
		return
	
	# Validate types
	if typeof(level_name) != TYPE_STRING: 
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not SceneManager.scene_exists(level_name):
		StC_disconnect.rpc_id(peerid, Error.ARGUMENT_TYPE_MISMATCH)
		return

	var rng_seed = randi()
	var userid:int = peer_list[peerid]
	session[userid] = {
		'unix_time_start': Utils.get_unix_time(),
		'rng_seed': rng_seed,
		'level_name': level_name
	}
	StC_provide_seed.rpc_id(peerid, rng_seed)

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
	
	session[userid].unix_time_end = Utils.get_unix_time()
	
	# in SESSION (server validated already):
	# userid: unix_time_start, rng_seed, level_name, unix_time_end
	# in REPLAY (arbitrary dict from client):
	# rng_seed, packed_zstd, buffer_size, final_pos_sync, level_name
	
	var r := Replay.new()
	r.reconstruct_from_server_side(replay)
	Debug.printf("Got replay of size " + str(r.inputs.size()))
	# ALERT malicious client can send bad buffer_size / packed_zstd and crash server?!
	# May need to look into other forms of decompression, and test bytes_to_var more etc.
	
	# Has the seed expired?
	var timestamp_seconds:int = session[userid].unix_time_end - session[userid].unix_time_start
	@warning_ignore("integer_division")
	var runtime_seconds:int = r.inputs.size() / 60
	if timestamp_seconds > runtime_seconds + SEED_TIMESTAMP_LENIENCY:
		StC_disconnect.rpc_id(peerid, Error.BAD_DATA)
		return
	
	TimeAttack.add_replay_to_validation_queue(r)

func replay_syncd(passed_replay:Replay) -> void:
	print(passed_replay)
	# is this passed object destroyed if the validation queue overwrites TimeAttack.r?
	# I may want to duplicate it.
	# I also need to find the peerid from the userid (backwards from what I normally do)
	
	# TODO - on success: more metadata, user name, attempt count, rank when set, date achieved, final time
	# TODO - on success: saving files.
	pass
	
func replay_failed(passed_replay:Replay) -> void:
	# which peer was bad?
	pass

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
