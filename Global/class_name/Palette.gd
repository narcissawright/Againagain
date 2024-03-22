extends Node
class_name Palette

# Common colors used in the project.
const p:Dictionary = {
	"yellow": Color('d8bf37'),
	"blue_energy": Color(0.45, 0.5, 1.0),
	"grey": Color(0.5, 0.5, 0.5),
	"disabled_grey": Color(0.35, 0.3, 0.3),
	"eigengrau": Color('16161D'),
	"black": Color(0,0,0),
	"white": Color(1,1,1)
}

# Returns a Color from the Palette
# Palette.c('color_name')
static func c(color_name:String) -> Color:
	if p.has(color_name):
		return p[color_name]
	return p['grey']

# For use in RichTextLabel
# Palette.bb('color_name')
static func bb(color_name:String) -> String:
	return '[color=#' + c(color_name).to_html(false) + ']'

# Close color tag, for RichTextLabel
# Palette.bb_end
const bb_end:String = '[/color]'
