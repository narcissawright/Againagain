extends Node
# CLIENT

var use_localhost = true

var peer = ENetMultiplayerPeer.new()
var peer_id:int = -1

# do I wanna keep a bunch of variables here?
var username:String
var logged_in := false
var version_mismatch := false

const Sensitive = preload('res://Netcode/ClientExclusive/sensitive_data.gd')

const port = 8888
const ip = "localhost"
const CLIENT_VERSION:String = "0.1"
const SECRETKEY_PATH:String = "user://secret.key"
const USERNAME_LENGTH_MAX = 16
const USERNAME_LENGTH_MIN = 1

signal error
signal connection_failed
signal connection_status_changed
signal failed_login
signal successful_login
signal key_created
signal username_availability
signal seed_from_server
signal leaderboard_received

enum { # connection status
	DISCONNECTED, 
	CONNECTING, 
	CONNECTED
	}

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
	Debug.printf("Starting Client.")
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	# connect multiplayer signals
	multiplayer.connected_to_server.connect(self._connected_to_server)
	multiplayer.connection_failed.connect(self._connection_failed)
	multiplayer.server_disconnected.connect(self._server_disconnected)
	
	# attempt connection
	connect_to_server()

func connect_to_server() -> void:
	Debug.printf("Connecting...")
	if use_localhost:
		peer.create_client("localhost", port)
	else:
		peer.create_client(Sensitive.ip, port)
	multiplayer.set_multiplayer_peer(peer)
	emit_signal('connection_status_changed', get_connection_status())
	await Utils.timer(3.0)
	# If we don't connect within x seconds, give up.
	if get_connection_status() == CONNECTING:
		peer.close()

func _connected_to_server() -> void:
	Debug.printf("Connected.")
	peer_id = multiplayer.get_unique_id()
	
	get_node("InstanceChecker").queue_free()
	emit_signal('connection_status_changed', get_connection_status())
	if FileAccess.file_exists(SECRETKEY_PATH):
		login()
	else:
		create_key()
		login()
	
func _connection_failed() -> void:
	Debug.printf("Connection failed.")
	emit_signal('connection_failed')
	emit_signal('connection_status_changed', get_connection_status())
	logged_in = false

func _server_disconnected() -> void:
	Debug.printf("Server disconnected.")
	emit_signal("connection_status_changed", get_connection_status())
	logged_in = false

func get_connection_status() -> int:
	return peer.get_connection_status()

#func username_is_valid(passed_username:String) -> bool:
	#passed_username = passed_username.to_lower()
	#if passed_username.length() < USERNAME_LENGTH_MIN: return false 
	#if passed_username.length() > USERNAME_LENGTH_MAX: return false
	#var regex := RegEx.new()
	#regex.compile('^[\\w.]+') #a-z A-Z 0-9 _
	#var result = regex.search(passed_username)
	#if result != null:
		#if result.get_string() == passed_username:
			#return true
	#return false
	#
#func is_username_available(passed_username:String) -> void:
	#CtS_is_username_available.rpc_id(1, passed_username)

func create_key():
	Debug.printf("Creating secret key")
	var secretkey:String = Crypto.new().generate_random_bytes(32).hex_encode()
	# Write user key file
	var file = FileAccess.open(SECRETKEY_PATH, FileAccess.WRITE)
	file.store_line(secretkey)
	file.close()
	emit_signal('key_created')

func login() -> void:
	Debug.printf("Login")
	if get_connection_status() == CONNECTED:
		var file = FileAccess.open(SECRETKEY_PATH, FileAccess.READ)
		var secretkey:String = file.get_line().sha256_text()
		file.close()
		CtS_login.rpc_id(1, CLIENT_VERSION, secretkey)
		secretkey = ''
	else:
		Debug.printf("not connected - cannot provide_credentials")

func request_seed(level_name:String) -> void:
	CtS_request_seed.rpc_id(1, level_name)

func here_is_a_replay(compressed_replay:Dictionary) -> void:
	CtS_validate_replay.rpc_id(1, compressed_replay)
	
func request_leaderboard(level_name:String) -> void:
	CtS_request_leaderboard.rpc_id(1, level_name)


@rpc func StC_disconnect(error_code:int) -> void:
	Debug.printf("Disconnect - error " + str(error_code))
	peer.close()
	emit_signal('error', error_code)
	if error_code == Error.VERSION_MISMATCH:
		version_mismatch = true
		Debug.printf("Version mismatch!")

@rpc func StC_successful_login(passed_username:String) -> void:
	username = passed_username
	Debug.printf("Successful login as " + username)
	logged_in = true
	emit_signal('successful_login')

@rpc func StC_username_availability(available:bool, passed_username:String) -> void:
	emit_signal('username_availability', available, passed_username)

@rpc func StC_provide_seed(passed_seed:int) -> void:
	Debug.printf("Seed from server: " + str(passed_seed))
	emit_signal('seed_from_server', passed_seed)

@rpc func StC_provide_leaderboard(level_name:String, entries:Array) -> void:
	emit_signal("leaderboard_received", level_name, entries)

@rpc func StC_replay_failed(): 
	pass

@rpc func StC_replay_syncd(): 
	pass


# Defined on server side only.
@rpc func CtS_is_username_available() -> void: pass
@rpc func CtS_login() -> void: pass
@rpc func CtS_request_seed() -> void: pass
@rpc func CtS_validate_replay() -> void: pass
@rpc func CtS_request_leaderboard() -> void: pass
