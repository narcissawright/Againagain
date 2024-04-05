extends Node
@export var is_server:bool
@export var use_instance_checker:bool

func _ready() -> void:
	if OS.has_feature('editor') and use_instance_checker:
		# Running via the editor, check which instance.
		Events.is_editor_server.connect(self.is_editor_server)
		Network.get_node("InstanceChecker").check()
	
	if OS.has_feature('server'):  # Exported (proper) server setup
		is_server = true
	
	if is_server:
		initiate_server()
	else:
		initiate_client_and_game()

func is_editor_server() -> void:
	# via InstanceChecker
	is_server = true

func initiate_server() -> void:
	# TODO test setting these only when actually doing replay verification
	var MAX_SIMULATION_SPEED = 5 # I've had it sync at like 10000x speed but ymmv
	Engine.time_scale = MAX_SIMULATION_SPEED
	Engine.physics_ticks_per_second *= MAX_SIMULATION_SPEED
	Engine.max_physics_steps_per_frame *= MAX_SIMULATION_SPEED
	SInput.change_mode(SInput.Mode.NO_INPUT)
	Network.set_script(load("res://Netcode/ServerExclusive/Server.gd"))
	Network.start()

func initiate_client_and_game() -> void:
	SInput.change_mode(SInput.Mode.LIVE_INPUT)
	Network.set_script(load("res://Netcode/ClientExclusive/Client.gd"))
	if use_instance_checker:
		Network.use_localhost = true
	Network.start()
	UI.initialize_as_client()
	call_deferred('go_to_main_menu')

func go_to_main_menu() -> void:
	SceneManager.insta_change_scene('MainMenu')
