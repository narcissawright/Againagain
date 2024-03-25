extends Resource
class_name Replay

const RECORD_DEBUG_POSITIONS = false

var index:int = 0 # where are we in the replay (frame #)
var inputs:Array # uncompressed array of dictionaries
@export var packed_zstd:PackedByteArray # two steps: var_to_bytes, compress (ZSTD)
@export var buffer_size:int # size of decompressed packedbytearray (for packed_zstd)
@export var rng_seed:int # from server
@export var final_position_sync:Vector3 # final player position
@export var frame_count:int # also size() of inputs
@export var final_time:String # stringified version of frame count. xx:xx.xx
@export var level_name:String # or "scene_name" :P
@export var unix_time_start:int # from server?
@export var unix_time_end:int # from server
@export var userid:int # incremental id, user 0, user 1 etc. maps to display name.
@export var username:String # display name, not permanent
@export var date_achieved:String # YYYY-MM-DD
@export var rank_when_set:int # 1 == WR when set
@export var attempt_count:int # how many resets did the player do
var debug_positions:Array # only used when debugging

func print_contents() -> void:
	#Debug.printf("inputs.size() " + str(inputs.size()))
	Debug.printf("packed_zstd.size() " + str(packed_zstd.size()))
	Debug.printf([buffer_size, rng_seed, final_position_sync, frame_count, final_time, level_name, unix_time_start, unix_time_end, userid, username, date_achieved, rank_when_set, attempt_count])
	#Debug.printf("debug_positions.size() " + str(debug_positions.size()))


func record_frame(input:Dictionary) -> void: # from external call
	var stripped_input = SInput.strip_input_data(input)
	inputs.append(stripped_input)
	if RECORD_DEBUG_POSITIONS:
		debug_positions.append(Utils.get_player().global_position)

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
	if RECORD_DEBUG_POSITIONS: 
		dict.debug_positions = debug_positions
	return dict
	
func prepare_download() -> Dictionary:
	var dict := {
		'packed_zstd': packed_zstd,
		'buffer_size': buffer_size,
		'rng_seed': rng_seed,
		'final_position_sync': final_position_sync,
		'frame_count': frame_count,
		'final_time': final_time,
		'level_name': level_name,
		'unix_time_start': unix_time_start,
		'unix_time_end': unix_time_end,
		'userid': userid,
		'username': username,
		'date_achieved': date_achieved,
		'rank_when_set': rank_when_set,
		'attempt_count': attempt_count
	}
	return dict

func reconstruct_from_server_side(data:Dictionary) -> void:
	# rng_seed, packed_zstd, buffer_size, final_pos_sync, level_name
	index = 0
	rng_seed = data.rng_seed
	packed_zstd = data.packed_zstd
	buffer_size = data.buffer_size
	final_position_sync = data.final_position_sync
	level_name = data.level_name
	if RECORD_DEBUG_POSITIONS:
		debug_positions = data.debug_positions
	decompress()
	frame_count = inputs.size()

	# Client side when initiating session:
	# -seed DONE
	# -level DONE
	
	# Server side when initiating session: 
	# Kind of done? should the TimeAttack script handle the session data? and the queue...
	# -userid 
	# -unix time start
	# -seed
	# -level
	
	# Client can store a single replay in TimeAttack.r
	# Server needs to store information for multiple ongoing sessions...
	
	# Client side when finishing session, sent to server: (DONE!)
	# -replay file (compressed) 
	# -buffer size 
	# -final position sync

	# Server side when receiving replay:
	# -unix time end DONE
	# -use TimeAttack.r to construct replay object and initiate validation test DONE
	
	# -create a validation queue to block other users from simultaneous verification / overwriting
	
	# Server side replay validation:
	# -does userid map to seed
	# -does replay length fit within unix timestamp bounds, roughly
	# -does it sync (final_position_sync) after resimulation

	# After verification:
	# -Creation of additional metadata (see below)
	# -Update leaderboard
	# -Let Client know time was validated
	# -Create replay file
	# -send replay file back to client to download locally also? :think:
	
	# final replay file which is downloadable or saved on the computer:
	# Let's include as much metadata as possible
	# -seed
	# -userid
	# -display name (at time of performance, can also check the updated display name...)
	# -replay file (still compressed) & buffer size
	# -length in frames & human readable time
	# -date achieved (readable) & unix timestamps (start & end)
	# -which level
	# -"WR when set" (rank when set?)
	# -total attempt count?

