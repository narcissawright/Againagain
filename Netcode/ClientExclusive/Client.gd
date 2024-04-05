extends Node
# CLIENT

var use_localhost = false

var peer = ENetMultiplayerPeer.new()
var peer_id:int = -1

# do I wanna keep a bunch of variables here?
var username:String
var logged_in := false # not really used at the moment

const Sensitive = preload('res://Netcode/ClientExclusive/sensitive_data.gd')
const SECRETKEY_PATH:String = "user://secret.key"
const IS_SERVER = false

signal connection_status_changed # chat, mainmenu
signal username_availability # used only in this script, not actually used by project
signal seed_from_server # used in mainmenu
signal leaderboard_received # used by lbdisplay

enum { # connection status
	DISCONNECTED, 
	CONNECTING, 
	CONNECTED
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
		peer.create_client("localhost", NetworkConst.PORT)
	else:
		peer.create_client(Sensitive.ip, NetworkConst.PORT)
	multiplayer.set_multiplayer_peer(peer)
	emit_signal('connection_status_changed', get_connection_status())
	await Utils.timer(3.0)
	# If we don't connect within x seconds, give up.
	if get_connection_status() == CONNECTING:
		peer.close()

func _connected_to_server() -> void:
	Debug.printf("Connected.")
	get_node("InstanceChecker").free_after_awhile()
	peer_id = multiplayer.get_unique_id()
	emit_signal('connection_status_changed', get_connection_status())
	if FileAccess.file_exists(SECRETKEY_PATH):
		login()
	else:
		create_key()
		login()
	
func _connection_failed() -> void:
	Debug.printf("Connection failed.")
	emit_signal('connection_status_changed', get_connection_status())
	logged_in = false

func _server_disconnected() -> void:
	Debug.printf("Server disconnected.")
	emit_signal("connection_status_changed", get_connection_status())
	logged_in = false

func get_connection_status() -> int:
	return peer.get_connection_status()

func create_key():
	Debug.printf("Creating secret key")
	var secretkey:String = Crypto.new().generate_random_bytes(32).hex_encode()
	# Write user key file
	var file = FileAccess.open(SECRETKEY_PATH, FileAccess.WRITE)
	file.store_line(secretkey)
	file.close()

# Functions leading into RPC calls (Client to Server):

func login() -> void:
	if get_connection_status() == CONNECTED:
		var file = FileAccess.open(SECRETKEY_PATH, FileAccess.READ)
		var secretkey:String = file.get_line().sha256_text()
		file.close()
		CtS_login.rpc_id(1, NetworkConst.VERSION, secretkey)
		secretkey = ''

func request_seed(level_name:String) -> void:
	if get_connection_status() == CONNECTED:
		CtS_request_seed.rpc_id(1, level_name)

func here_is_a_replay(compressed_replay:Dictionary) -> void:
	if get_connection_status() == CONNECTED:
		CtS_validate_replay.rpc_id(1, compressed_replay)
	
func request_leaderboard(level_name:String) -> void:
	if get_connection_status() == CONNECTED:
		CtS_request_leaderboard.rpc_id(1, level_name)

func send_chat_message(msg:String) -> void:
	if get_connection_status() == CONNECTED:
		CtS_send_chat_message.rpc_id(1, msg)

#func is_username_available(passed_username:String) -> void:
	#CtS_is_username_available.rpc_id(1, passed_username)

# RPC from Server:

@rpc func StC_disconnect(error_code:int) -> void:
	Debug.printf("Disconnect - error " + str(error_code))
	peer.close()
	if error_code == NetworkConst.Error.VERSION_MISMATCH:
		Debug.printf("Version mismatch!")

@rpc func StC_successful_login(passed_username:String) -> void:
	username = passed_username
	Debug.printf("Successful login as " + username)
	logged_in = true

#@rpc func StC_username_availability(available:bool, passed_username:String) -> void:
	#emit_signal('username_availability', available, passed_username)

@rpc func StC_provide_seed(passed_seed:int) -> void:
	Debug.printf("Seed from server: " + str(passed_seed))
	emit_signal('seed_from_server', passed_seed)

@rpc func StC_provide_leaderboard(level_name:String, entries:Array) -> void:
	emit_signal("leaderboard_received", level_name, entries)

@rpc func StC_replay_failed(): 
	pass

@rpc func StC_replay_syncd(): 
	pass

@rpc func StC_chat_message_received(sender:String, msg:String) -> void:
	Events.chat_message_received.emit(sender, msg)

@rpc func StC_username_change_authorized(new_name:String) -> void:
	username = new_name
	Events.server_message.emit("Username changed to " + new_name)
	
@rpc func StC_server_message(msg:String) -> void:
	Events.server_message.emit(msg)

# Defined on server side only:
#@rpc func CtS_is_username_available() -> void: pass
@rpc func CtS_login() -> void: pass
@rpc func CtS_request_seed() -> void: pass
@rpc func CtS_validate_replay() -> void: pass
@rpc func CtS_request_leaderboard() -> void: pass
@rpc func CtS_send_chat_message() -> void: pass
