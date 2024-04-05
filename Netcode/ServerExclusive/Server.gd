extends Node

# Network
var network = ENetMultiplayerPeer.new()
const MAX_CONNECTIONS = 1000  #4095 is the cap
const IS_SERVER = true

# Session information
var peer_list:Dictionary = {} # {peerid: userid}
var session:Dictionary = {}   # {userid: {unix_time_start, rng_seed, level_name}}

# Database
var db:Database

# Visual
var display = preload('res://Netcode/ServerExclusive/ServerDisplay/ServerDisplay.tscn')

# Validation etc
const SEED_TIMESTAMP_LENIENCY:int = 10 # seconds
const Sensitive = preload('res://Netcode/ServerExclusive/sensitive_data.gd')

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
	network.create_server(NetworkConst.PORT, MAX_CONNECTIONS)
	
	# Connect Signals
	multiplayer.peer_connected.connect(self.peer_connected)
	multiplayer.peer_disconnected.connect(self.peer_disconnected)
	TimeAttack.replay_syncd.connect(self.replay_syncd)
	TimeAttack.replay_failed.connect(self.replay_failed)
	TimeAttack.finished_replay_validation.connect(self.finished_replay_validation)
	
	# Start Server
	multiplayer.set_multiplayer_peer(network)
	Debug.printf("Server started on port " + str(NetworkConst.PORT))
	
	get_node("InstanceChecker").free_after_awhile()

func peer_connected(peerid:int) -> void:
	Debug.printf("Peer#" + str(peerid) + " connected!")
	#StC_request_identity.rpc_id(peer_id)

func peer_disconnected(peerid:int) -> void:
	if peer_list.has(peerid):
		var username = db.userid_to_username[peer_list[peerid]]
		Debug.printf(username + " disconnected.")
		session.erase(peer_list[peerid])
		peer_list.erase(peerid)
		display.update()
	else:
		Debug.printf("Peer#" + str(peerid) + " disconnected.")

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

func username_is_available(username:String) -> bool:
	username = username.to_lower()
	if not Utils.username_is_valid(username):
		return false
	if username_is_reserved(username):
		return false
	if db.username_is_taken(username):
		return false
	return true

func username_is_reserved(passed_username:String) -> bool:
	if Sensitive.RESERVED.has(passed_username): 
		return true
	return false

func replay_syncd(r:Replay) -> void:
	var peerid = peer_list.find_key(r.userid)
	
	# Update Leaderboard
	db.leaderboard[r.level_name].add_entry(r)
	db.save()
	display.update()
	
	StC_replay_syncd.rpc_id(peerid)

func replay_failed(r:Replay) -> void:
	#Debug.printf("REPLAY FAILED!")
	#r.print_contents()
	var peerid = peer_list.find_key(r.userid)
	StC_replay_failed.rpc_id(peerid)

func finished_replay_validation() -> void:
	SceneManager.free_current_scene()
	display.show()

# Client -> Server calls:
# These need to be validated very well to prevent any malicious input.
@rpc('any_peer') func CtS_login(client_version, secretkey) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate types
	if typeof(client_version) != TYPE_STRING: 
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
		return
	if typeof(secretkey) != TYPE_STRING:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	# Check if client game version matches server version.
	if client_version != NetworkConst.VERSION:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.VERSION_MISMATCH)
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

@rpc('any_peer') func CtS_send_chat_message(msg) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate
	if typeof(msg) != TYPE_STRING:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not peer_list.has(peerid):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.NOT_LOGGED_IN)
		return
	
	var username = db.userid_to_username[peer_list[peerid]]
	msg = Utils.sanitize(msg)
	Debug.printf(username + ": " + msg)
	if msg.length() == 0:
		return
	
	var msg_array:PackedStringArray = msg.split(' ')
	var name_change_chat_command = ['/nick', '!nick', '/username', '!username', '/name', '!name']
	if name_change_chat_command.has(msg_array[0]):
		if username_is_available(msg_array[1]):
			Debug.printf("Name Change: " + username + " -> " + msg_array[1])
			db.userid_to_username[peer_list[peerid]] = msg_array[1]
			db.save()
			StC_username_change_authorized.rpc_id(peerid, msg_array[1])
		else:
			StC_server_message.rpc_id(peerid, "Username "+msg_array[1]+" not available.")
		return
	
	# If it's not a chat command, send it as a chat message.
	StC_chat_message_received.rpc(username, msg)


@rpc('any_peer') func CtS_request_seed(level_name) -> void:
	# Validate peer
	var peerid = multiplayer.get_remote_sender_id()
	if not peer_list.has(peerid):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.NOT_LOGGED_IN)
		return
	
	# Validate types
	if not level_name_is_valid(level_name):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)

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
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.NOT_LOGGED_IN)
		return
	
	# Validate types
	var validation = {
		"buffer_size": TYPE_INT,
		"packed_zstd": TYPE_PACKED_BYTE_ARRAY,
		"level_name": TYPE_STRING,
		"rng_seed": TYPE_INT,
		"final_position_sync": TYPE_VECTOR3
	}
	if Replay.RECORD_PLAYER_XFORM:
		validation.player_xform = TYPE_ARRAY
		validation.player_velocity = TYPE_ARRAY
		validation.camera_orientation = TYPE_ARRAY
	if not dictionary_is_valid(replay, validation):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
		return
	if not level_name_is_valid(replay.level_name):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
	
	var userid:int = peer_list[peerid] # get userid
	
	# Validate session vs replay:
	if not session.has(userid):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.BAD_DATA)
		return
	if replay.rng_seed != session[userid].rng_seed:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.BAD_DATA)
		return
	if replay.level_name != session[userid].level_name:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.BAD_DATA)
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
	#r.name_when_set = db.userid_to_username[userid]
	r.date_achieved = Utils.get_date_from_unix_time(r.unix_time_end)
	
	# Has the seed expired?
	var unix_time_difference:int = r.unix_time_end - r.unix_time_start
	@warning_ignore("integer_division")
	var runtime_seconds:int = r.inputs.size() / 60
	if unix_time_difference > runtime_seconds + SEED_TIMESTAMP_LENIENCY:
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.BAD_DATA)
		return
	
	display.hide()
	TimeAttack.add_replay_to_validation_queue(r)

@rpc ('any_peer') func CtS_request_leaderboard(level_name) -> void:
	var peerid = multiplayer.get_remote_sender_id()
	
	# Validate type
	if not level_name_is_valid(level_name):
		StC_disconnect.rpc_id(peerid, NetworkConst.Error.ARGUMENT_TYPE_MISMATCH)
		return
	
	var entries:Array = db.leaderboard[level_name].prepare_download()
	for entry in entries:
		entry.current_name = db.userid_to_username[entry.userid]
		entry.erase('userid')
	StC_provide_leaderboard.rpc_id(peerid, level_name, entries)

# Server -> Client calls: (implemented client-side only)
# Godot's rpc system requires the same rpc function 
# names be present both in the client and the server.
@rpc func StC_disconnect(): pass # error_id:int
@rpc func StC_successful_login(): pass 
@rpc func StC_chat_message_received(): pass
@rpc func StC_server_message(): pass
@rpc func StC_username_change_authorized(): pass
@rpc func StC_provide_seed(): pass
@rpc func StC_provide_leaderboard(): pass
@rpc func StC_replay_failed(): pass
@rpc func StC_replay_syncd(): pass # should these be 1 rpc func?
