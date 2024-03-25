extends Resource
class_name Leaderboard

@export var entries = []

func add_entry(r:Replay) -> void:
	# Don't store uncompressed inputs or debug positions
	r.inputs = []
	r.debug_positions = []
	r.rank_when_set = get_rank(r)
	entries.append(r)
	entries.sort_custom(sort_entries_by_frame_count)
	Debug.printf("Added entry to leaderboard: ")
	r.print_contents()

func sort_entries_by_frame_count(a:Replay, b:Replay) -> bool:
	if a.frame_count < b.frame_count:
		return true
	return false

func get_rank(r:Replay) -> int:
	var frame_counts := []
	for entry in entries:
		frame_counts.append(entry.frame_count)
	frame_counts.append(r.frame_count)
	frame_counts.sort()
	var rank:int = frame_counts.find(r.frame_count) + 1
	return rank

func prepare_download() -> Array:
	var lb_array = []
	for entry in entries:
		var replay_dict:Dictionary = entry.prepare_download()
		replay_dict.erase('packed_zstd')
		replay_dict.erase('buffer_size')
		replay_dict['rank'] = get_rank(entry)
		lb_array.append(replay_dict)
	return lb_array

static func rank_string(rank:int) -> String:
	var modulo_string:String = str(rank % 100).pad_zeros(2)
	if modulo_string[0] != '1':
		if modulo_string[1] == '1':
			return str(rank) + "st"
		elif modulo_string[1] == '2':
			return str(rank) + "nd"
		elif modulo_string[1] == '3':
			return str(rank) + "rd"
	return str(rank) + "th"
	
