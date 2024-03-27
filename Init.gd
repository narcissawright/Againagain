extends Node
@export var is_server:bool

func is_editor_server() -> void:
	is_server = true

func _ready() -> void:
	if OS.has_feature('editor'):
		# The project running via the editor, check which instance.
		Events.is_editor_server.connect(self.is_editor_server)
		Network.get_node("InstanceChecker").check()
	
	if is_server: # from the export bool, OR from the instance check...
		initiate_server()
	else:
		initiate_client_and_game()

func initiate_server() -> void:
	# TODO test setting these only when actually doing replay verification
	var MAX_SIMULATION_SPEED = 3 # this can actually be like 10,000 and it still syncs
	Engine.time_scale = MAX_SIMULATION_SPEED
	Engine.physics_ticks_per_second *= MAX_SIMULATION_SPEED
	Engine.max_physics_steps_per_frame *= MAX_SIMULATION_SPEED
	SInput.change_mode(SInput.Mode.NO_INPUT)
	Network.set_script(load("res://Netcode/ServerExclusive/Server.gd"))
	Network.start()

func initiate_client_and_game() -> void:
	SInput.change_mode(SInput.Mode.LIVE_INPUT)
	Network.set_script(load("res://Netcode/ClientExclusive/Client.gd"))
	Network.start()
	call_deferred('go_to_main_menu')

func go_to_main_menu() -> void:
	SceneManager.insta_change_scene('MainMenu')
