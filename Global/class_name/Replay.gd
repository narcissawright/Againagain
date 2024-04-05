extends Resource
class_name Replay

const RECORD_PLAYER_XFORM = true
var player_xform:Array # only used when debugging
var player_velocity:Array # only used when debugging
var camera_orientation:Array # only used when debugging

var index:int = 0 # where are we in the replay (frame #)
var inputs:Array # uncompressed array of dictionaries
@export var packed_zstd:PackedByteArray # two steps: var_to_bytes, compress (ZSTD)
@export var buffer_size:int # size of decompressed packedbytearray (for packed_zstd)
@export var rng_seed:int # from server
@export var final_position_sync:Vector3 # final player position
@export var frame_count:int # also size() of inputs
#@export var final_time:String # stringified version of frame count. xx:xx.xx
@export var level_name:String # or "scene_name" :P
@export var unix_time_start:int # from server?
@export var unix_time_end:int # from server
@export var date_achieved:String # YYYY-MM-DD
@export var userid:int # incremental id, user 0, user 1 etc. maps to display name.
#@export var name_when_set:String # display name, not permanent
@export var rank_when_set:int # 1 == WR when set
#@export var attempt_count:int # how many resets did the player do

func print_contents() -> void:
	Debug.printf([packed_zstd.size(), buffer_size, rng_seed, final_position_sync, frame_count, level_name, unix_time_start, unix_time_end, userid, date_achieved, rank_when_set])

func record_frame(input:Dictionary) -> void: # called from TimeAttack.gd
	var stripped_input = SInput.strip_input_data(input)
	inputs.append(stripped_input)
	if RECORD_PLAYER_XFORM:
		player_xform.append(Utils.get_player().global_transform)
		player_velocity.append(Utils.get_player().velocity)
		camera_orientation.append(Utils.get_camera().orientation)

func compress() -> void:
	var packed:PackedByteArray = var_to_bytes(inputs)
	packed_zstd = packed.compress(FileAccess.COMPRESSION_ZSTD)
	buffer_size = packed.size()
	Debug.printf ("Packed replay. " + str(buffer_size) + " B -> " + str(packed_zstd.size()) + " B.")

func decompress() -> void:
	var packed:PackedByteArray = packed_zstd.decompress(buffer_size, FileAccess.COMPRESSION_ZSTD)
	inputs = bytes_to_var(packed)

func get_client_to_server_replay_data() -> Dictionary:
	var dict := {
		"rng_seed": rng_seed,
		"packed_zstd": packed_zstd,
		"buffer_size": buffer_size,
		"final_position_sync": final_position_sync,
		"level_name": level_name
	}
	if RECORD_PLAYER_XFORM: 
		dict.player_xform = player_xform
		dict.player_velocity = player_velocity
		dict.camera_orientation = camera_orientation
	return dict

func reconstruct_from_server_side(data:Dictionary) -> void:
	# rng_seed, packed_zstd, buffer_size, final_pos_sync, level_name
	index = 0
	rng_seed = data.rng_seed
	packed_zstd = data.packed_zstd
	buffer_size = data.buffer_size
	final_position_sync = data.final_position_sync
	level_name = data.level_name
	if RECORD_PLAYER_XFORM:
		player_xform = data.player_xform
		player_velocity = data.player_velocity
		camera_orientation = data.camera_orientation
	decompress()
	frame_count = inputs.size()

func prepare_download() -> Dictionary:
	var dict := {
		'packed_zstd': packed_zstd,
		'buffer_size': buffer_size,
		'rng_seed': rng_seed,
		'final_position_sync': final_position_sync,
		'frame_count': frame_count,
		#'final_time': final_time,
		'level_name': level_name,
		'unix_time_start': unix_time_start,
		'unix_time_end': unix_time_end,
		'userid': userid,
		#'name_when_set': name_when_set,
		'date_achieved': date_achieved,
		'rank_when_set': rank_when_set,
		#'attempt_count': attempt_count
	}
	return dict

	# Client side when initiating session:
	# -seed
	# -level_name
	
	# Server side when initiating session: 
	# -userid 
	# -unix time start
	# -seed
	# -level_name
	
	# Client can store a single replay in TimeAttack.r
	# Server can store information for multiple ongoing sessions...
	
	# Client side when finishing session, sent to server:
	# -replay file (compressed) 
	# -buffer size 
	# -final position sync

	# Server side when receiving replay:
	# -unix time end
	# -reconstruct replay object and initiate validation test
	# -uses validation queue to block other users from simultaneous verification / overwriting
	
	# Server side replay validation:
	# -does userid map to seed
	# -does replay length fit within unix timestamp bounds, roughly
	# -does it sync (final_position_sync) after resimulation

	# After verification:
	# -Update leaderboard
	
	# TODO
	# Let Client know time was validated?
	# Downloadable replay files:
	# -level_name
	# -seed
	# -userid 
	#- name when set? userid alone (offline) would fail to show a name ...
	# -replay file (still compressed) & buffer size
	# -length in frames
	#- unix timestamps (start & end)
	# -date achieved (readable)  - store this or no?
	# -rank_when_set
	# -(maybe) total attempt count?
