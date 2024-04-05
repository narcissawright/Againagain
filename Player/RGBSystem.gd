extends Node2D

var rotation_array = ["red", "green", "blue"]
var current:String = "green"
var current_idx:int = 1

const palette = {
	"green": Color("00c000"),
	"red": Color("ff3838"),
	"blue": Color("0c60ff")
}

func _ready() -> void:
	set_mesh_color(palette[current])
	$Red.modulate = palette.red
	$Green.modulate = palette.green
	$Blue.modulate = palette.blue
	# outline colors could be algorithmic but right now lazy

func _physics_process(_delta) -> void:
	Debug.write(current)
	if $AP.is_playing():
		return
	if SInput.is_queued("rotate_left"):
		current_idx = (current_idx - 1) % 3
		switch_to(rotation_array[current_idx])
	elif SInput.is_queued("rotate_right"):
		current_idx = (current_idx + 1) % 3
		switch_to(rotation_array[current_idx])

func switch_to(next:String) -> void:
	set_mesh_color(palette[next])
	$AP.play(current + "_to_" + next)
	# Can check on the 'current' value and find special inbetweens like yellow
	if (current == "red" and next == "green") or (current == "green" and next == "red"):
		current = "yellow"
	elif (current == "green" and next == "blue") or (current == "blue" and next == "green"):
		current = "cyan"
	elif (current == "blue" and next == "red") or (current == "red" and next == "blue"):
		current = "magenta"
	await $AP.animation_finished
	current = next

func set_mesh_color(color:Color) -> void:
	%MeshInstance3D.set("instance_shader_parameters/my_color", color)
