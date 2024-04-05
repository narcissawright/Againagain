extends Node3D

# todo: make some scenes of old unused maps for the CRTs w/ rotating camera. decorative element.

# a note on the 'Case' material - I tried using triplanar UV with generated noise for normalmap
# and it fucking crashes my AMD drivers, so right now there's sadly no bumpmap on the material.
# oh well.

@export_enum('off', 'controller', 'account') var current_channel: String

var screen:Dictionary = {
	'off':        preload("res://Actor/crt/screens/screen_off.tscn"),
	'controller': preload("res://Actor/crt/screens/screen_controller.tscn"),
	#'account':    preload("res://Actor/crt/screens/screen_account.tscn"),
	}

func _ready():
	var instance = screen[current_channel].instantiate()
	add_child(instance)
	var subviewport = instance.get_child(0) # SubViewport is always the only child here.
	var texture:ViewportTexture = subviewport.get_texture()
	var material = $Screen.mesh.surface_get_material(0)
	material = material.duplicate() # make unique via duplication
	material.emission_texture = texture
	$Screen.mesh.surface_set_material(0, material)
