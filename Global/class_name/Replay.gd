extends Resource
class_name Replay

var index:int = 0 # where are we in the replay (frame #)
@export var inputs:Array # uncompressed array of dictionaries
@export var packed_zstd:PackedByteArray # two steps: var_to_bytes, compress (ZSTD)
@export var buffer_size:int # size of decompressed packedbytearray (for packed_zstd)
@export var rng_seed:int # from server
@export var final_position_sync:Vector3 # final player position
@export var frame_count:int # also size() of inputs
@export var final_time:String # stringified version of frame count. xx:xx.xx
@export var level_name:String # or "scene_name" :P
@export var unix_start_time:int # from server?
@export var unix_end_time:int # from server
@export var userid:int # incremental id, user 0, user 1 etc. maps to display name.
@export var username:String # display name, not permanent
@export var date_achieved:String # YYYY-MM-DD
@export var rank_when_set:int # 1 == WR when set
@export var attempt_count:int # how many resets did the player do
@export var debug_positions:Array # only used when debugging

func record_frame(input:Dictionary) -> void: # from external call
	var stripped_input = SInput.strip_input_data(input)
	inputs.append(stripped_input)
	#debug_positions.append(Utils.get_player().global_position)

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
		"userid": userid,
		"rng_seed": rng_seed,
		"packed_zstd": packed_zstd,
		"buffer_size": buffer_size,
		"final_position_sync": final_position_sync,
		"level_name": level_name,
		"frame_count": frame_count
	}
	return dict

func reconstruct_from_server_side(data:Dictionary) -> void:
	index = 0
	userid = data.userid
	rng_seed = data.rng_seed
	packed_zstd = data.packed_zstd
	buffer_size = data.buffer_size
	final_position_sync = data.final_position_sync
	level_name = data.level_name
	frame_count = data.frame_count
	decompress()

	# client side whilst creating a replay:
	# -seed
	# -replay file (compressed)
	# -buffer size 
	# -final position sync
	# -# of frames (slightly redundant) (can be found by decompressing and reading the replay size)
	# -which level
	
	# stored in Server session memory:
	# -seed mapped to the userid who requested the seed
	# -seed mapped to unix start time
	# -seed mapped to which level is being played?
	
	# Server also gets:
	# -unix end time when the replay is received?
	
	# Server verifies:
	# -the level actually completes on the final frame
	# -the final position sync works
	# -the unix time for the seed did not expire (contrast replay length with unix timestamps)
	
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
