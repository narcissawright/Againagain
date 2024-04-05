extends MarginContainer

const MAX_MSG_LENGTH = 200

func start() -> void:
	disable_line_edit()
	
	# not using _ready() because this script is autoloaded,
	# and on the Server, Network doesn't have a signal called connection_status_changed
	# realistically none of the UI nodes should exist on the server, yet they may be called sometimes from various places
	# I'm realizing having a UI autoload is a bit silly when most of this stuff is context sensitive.
	Network.connection_status_changed.connect(self.connection_status_changed)
	
	# this is actually the exact length necessary for the current $ChatBox size
	$ChatBox.text = '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'

	Events.chat_message_received.connect(new_chat_msg)
	Events.server_message.connect(server_msg)
	connection_status_changed(Network.get_connection_status())

func disable_line_edit() -> void:
	$LineEdit.editable = false
	$LineEdit.hide()
func enable_line_edit() -> void:
	$LineEdit.editable = true
	$LineEdit.show()

func connection_status_changed(status:MultiplayerPeer.ConnectionStatus) -> void:
	clear_old_chat_msg()
	var msg:String = '\n[color=#666]'
	match status:
		Network.DISCONNECTED: # MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
			msg += "Disconnected."
			disable_line_edit()
		Network.CONNECTING: # MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
			msg += "Connecting..."
		Network.CONNECTED: # MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
			msg += "Connected!"
			enable_line_edit()
	msg += '[/color]'
	$ChatBox.text += msg

func clear_old_chat_msg() -> void:
	# don't let text grow infinitely
	var first_newline_position:int = $ChatBox.text.find('\n')
	$ChatBox.text = $ChatBox.text.substr(first_newline_position + 1)

func server_msg(msg:String) -> void:
	clear_old_chat_msg()
	$ChatBox.text += '\n[color=#666]' + msg + '[/color]'

func new_chat_msg(sender:String, msg:String) -> void:
	clear_old_chat_msg()
	$ChatBox.text += '\n[color=#66c]'+sender+'[/color][color=#555]:[/color] '+msg

func _on_line_edit_text_changed(msg:String) -> void:
	# TODO exploit where you can paste many spaces between words, won't strip it properly.
	var stored_caret = min($LineEdit.caret_column, MAX_MSG_LENGTH)
	msg = msg.strip_escapes()
	msg = msg.strip_edges(true, false) # Strip Left
	var ends_with_space:bool = msg.ends_with(' ')
	msg = msg.strip_edges(false, true) # Strip Right
	if ends_with_space: msg += ' '
	if msg.length() > MAX_MSG_LENGTH:
		msg = msg.substr(0, MAX_MSG_LENGTH)
	$LineEdit.text = msg
	$LineEdit.caret_column = stored_caret

func _on_line_edit_text_submitted(msg:String) -> void:
	msg = msg.strip_escapes()
	msg = msg.strip_edges(true, true)
	if msg.length() == 0:
		return
	Network.send_chat_message(msg)
	$LineEdit.text = ''

func _input(event:InputEvent):
	# release focus when clicking outside of line edit
	if $LineEdit.has_focus() and event is InputEventMouseButton and not $LineEdit.get_global_rect().has_point(event.position):
		$LineEdit.release_focus()
