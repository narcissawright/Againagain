@tool
extends Node

@export var is_server:bool:
	get:
		return is_server
	set(value):
		is_server = value
		if Engine.is_editor_hint(): 
			# Only useful if manually marking the project as Server.
			# Most of the time I'll be running 2 instances from editor, and won't use this.
			if is_server:
				ProjectSettings.set_setting("editor/run/main_run_args", "--headless")
				print("ProjectSettings: set --headless")
			else:
				ProjectSettings.set_setting("editor/run/main_run_args", "")
				print("ProjectSettings: clear --headless")

func _is_editor_server() -> void:
	is_server = true

func _ready() -> void:
	if Engine.is_editor_hint(): 
		return  # Don't execute tool script
	
	if OS.has_feature('editor'):
		# The project running via the editor, check which instance.
		Events.is_editor_server.connect(_is_editor_server)
		Network.get_node("InstanceChecker").check()
	else:
		Network.get_node("InstanceChecker").queue_free()
	
	if is_server: # from the export bool, OR from the instance check...
		initiate_server()
	else:
		initiate_client_and_game()

func initiate_server() -> void:
	var MAX_SIMULATION_SPEED = 300
	Engine.time_scale = MAX_SIMULATION_SPEED
	Engine.physics_ticks_per_second *= MAX_SIMULATION_SPEED
	Engine.max_physics_steps_per_frame *= MAX_SIMULATION_SPEED
	SInput.mode = "no_input"
	Network.set_script(load("res://Netcode/ServerExclusive/Server.gd"))
	Network.start()

func initiate_client_and_game() -> void:
	Network.set_script(load("res://Netcode/ClientExclusive/Client.gd"))
	Network.start()
	#InputHandler.start()
	call_deferred('go_to_main_menu')

func go_to_main_menu() -> void:
	SceneManager.insta_change_scene('res://MainMenu.tscn')
	#get_tree().change_scene_to_file('res://MainMenu.tscn')
