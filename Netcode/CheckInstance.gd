extends Node

# This node sticks around to preserve TCPServer long enough for the other instances to get port blocked.
# This way, one instance can be a server and another can be a client!

var instance_num := -1
var instance_socket: TCPServer 

func check() -> void:
	# This is a project running from the editor! Let's check which instance we are
	instance_socket = TCPServer.new()
	for n in range(0,4):
		if instance_socket.listen(5000 + n) == OK:
			instance_num = n
			break
	assert(instance_num >= 0, "Unable to determine instance number. Seems like all TCP ports are in use")

	if instance_num == 0:
		# This is a makeshift server running from the Godot editor!
		Events.emit_signal('is_editor_server')
		# This means we aren't headless right now, so lets unprioritize this window.
		var window = get_tree().get_root()
		window.mode = Window.MODE_WINDOWED
		window.current_screen = 1
		window.size = Vector2i(1600, 900)
	else:
		# Bring the client to the front.
		var window = get_tree().get_root()
		window.move_to_foreground()
	
	Debug.printf("Instance #" + str(instance_num))
