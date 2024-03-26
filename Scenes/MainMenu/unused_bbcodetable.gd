extends RichTextLabel

# This sucks -- table wont expand to fill richtextlabel.
# I think bbcode [table] is too half-baked to really use.

func _ready() -> void:
	#set_cell_size_override(Vector2(250, 20), Vector2(250, 20))
	var str:String = "[center][table=4]"
	str += '[cell ratio=0.125][font_size=14]Rank[/font_size][/cell]'
	str += '[cell ratio=0.375][font_size=14]Name[/font_size][/cell]'
	str += '[cell ratio=0.25][font_size=14]Time[/font_size][/cell]'
	str += '[cell ratio=0.25][font_size=14]Date[/font_size][/cell]'
	str += '[/font_size]'
	str += '[cell][color=gold]1st[/color][/cell]'
	str += '[cell]username[/cell]'
	str += '[cell][color=gray]00:0[/color]3.26[/cell]'
	str += '[cell]2024/03/04[/cell]'
	str += '[/table][/center]'
	text = str
