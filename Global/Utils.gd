extends Node

# await Utils.timer(1.0)
func timer(time:float) -> void:
	await get_tree().create_timer(time).timeout
	return

# Get nodes easily:
func get_player() -> CharacterBody3D:
	var nodes = get_tree().get_nodes_in_group("Player")
	assert (nodes.size() == 1, str(nodes.size()))
	return nodes[0]
func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

# Process priority - all in 1 place:
const PRIORITY_MAP:Dictionary = {
	"debug": -2,
	"input": -1,
	"player": 0,
	"camera": 1 
}
func set_priority(node:Node, mode:String) -> void:
	node.process_priority         = PRIORITY_MAP[mode]
	node.process_physics_priority = PRIORITY_MAP[mode]

func get_unix_time() -> int:
	var unix_time := int(Time.get_unix_time_from_system())
	unix_time -= 21600 # let's go Central! 
	# not gonna factor in daylight savings though.
	return unix_time

func get_date_from_unix_time(unix_time:int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_time).get_slice('T', 0)

