extends Node

var is_editor_server:bool = false
@onready var DebugLabel:RichTextLabel = UI.get_node('DebugLabel')

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	Utils.set_priority(self, 'debug')
	
	# Set main display as current display
	#DisplayServer.window_set_current_screen(0)
	Events.is_editor_server.connect(_is_editor_server)
	
func _is_editor_server() -> void:
	is_editor_server = true

func _physics_process(_delta:float) -> void:
	DebugLabel.text = ''

func write(msg) -> void:
	if OS.has_feature('editor'):
		msg = str(msg)
		var source:String = get_stack()[1].source
		source = source.get_slice('/', source.get_slice_count('/')-1)
		DebugLabel.text += '[color=88c]' + source + '  [/color]' + msg + '\n'
	else:
		# could write here without get_stack, if needed...
		pass

const server_color = '[bgcolor=322][color=fcc]'
const client_color = '[bgcolor=223][color=ccf]'
func printf(msg) -> void:
	if OS.has_feature('editor'):
		msg = str(msg)
		var source:String = get_stack()[1].source
		source = source.get_slice('/', source.get_slice_count('/')-1)
		if is_editor_server:
			print_rich(server_color + "[b] {s} [/b][/color][/bgcolor] ".format({"s": source}) + msg)
		else:
			print_rich(client_color + "[b] {s} [/b][/color][/bgcolor] ".format({"s": source}) + msg)
	else:
		print(msg)
