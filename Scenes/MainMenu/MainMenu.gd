extends Node2D

func _ready() -> void:
	Network.connection_status_changed.connect(self.connection_status_changed)
	connection_status_changed(Network.get_connection_status())
	
func connection_status_changed(status:MultiplayerPeer.ConnectionStatus) -> void:
	match status:
		Network.DISCONNECTED: # MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
			$ServerMsg.text += "Disconnected."
		Network.CONNECTING: # MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
			$ServerMsg.text += "Connecting..."
		Network.CONNECTED: # MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
			$ServerMsg.text += "Connected!"
	$ServerMsg.text += '\n'

func _input(event:InputEvent) -> void:
	# only place in the whole project where I don't get input via SInput.. for some reason
	if event.is_action_pressed("start"):
		set_process_input(false)
		if Network.get_connection_status() == Network.CONNECTED:
			Network.seed_from_server.connect(start_with_seed)
			Network.request_seed()
		else:
			start_with_seed(0)

func start_with_seed(passed_seed:int) -> void:
	Debug.printf("Starting with seed " + str(passed_seed))
	SceneManager.change_scene('Corners')
