@tool
extends Node3D

var ladder_piece:String = "res://Actor/ladder/ladder_loopable.glb"
var ladder_top:String = "res://Actor/ladder/ladder_top.glb"

@export_range(1, 20) var height:int = 1:
	set(new_height):
		if height == new_height: return
		height = new_height
		for child in $pieces.get_children():
			child.free()
		for i in range (height):
			add_ladder_piece(i, ladder_piece)
			if i == height-1: 
				add_ladder_piece(i, ladder_top)
		redefine_area3d(height)
		redefine_collision(height)
	get:
		return height

# used by tool script
func add_ladder_piece(i:int, path:String) -> Node3D:
	var l = load(path).instantiate()
	$pieces.add_child(l)
	l.owner = self
	l.position.y = i
	return l

# used by tool script
func redefine_area3d(h:int) -> void:
	var col  = $Area/CollisionShape3D
	var shape = BoxShape3D.new()
	var tall = float(h) + (1.0 / 3.0) - 0.2
	shape.size = Vector3(0.7, tall, 0.2)
	col.position.y = tall / 2.0
	col.shape = shape

# used by tool script
func redefine_collision(h:int) -> void:
	var col = $StaticBody3D/CollisionShape3D
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.6, float(h), 0.1)
	col.position.y = float(h) / 2.0
	col.shape = shape
	$StaticBody3D/top_piece_1.position.y = float(h) + ((1.0 / 3.0) - 0.05) / 2.0
	$StaticBody3D/top_piece_2.position.y = float(h) + ((1.0 / 3.0) - 0.05) / 2.0

# These 3 functions are called by ladder state script:
func disable_collision() -> void:
	$StaticBody3D.collision_layer = 0
func enable_collision() -> void:
	$StaticBody3D.collision_layer = Layers.Actor
func timeout() -> void:
	# Prevent being grabbed again for a moment.
	$Area.monitoring = false
	await Utils.timer(0.45)
	$Area.monitoring = true

func _physics_process(_delta) -> void:
	if $Area.monitoring:
		for body in $Area.get_overlapping_bodies():
			if body.is_in_group("Player"):
				Events.emit_signal("ladder_touched", self)
