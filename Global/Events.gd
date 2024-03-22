extends Node

signal is_editor_server # this game instance is a makeshift server run via the editor!

signal ladder_camera(ladder_forwards:Vector3, midpoint:Vector3)
signal normal_camera()

signal ladder_touched(position:Vector3, y_rot:float, height:int)
signal player_reached_goal()





# Game State
#signal start_game
#signal pause_game
#signal unpause_game
#signal change_level(scene_name : String, entrance_idx_next : int)

# CRTs
#signal controller_monitor_finished
#signal server_monitor_finished

# level actor signals
#signal update_player_saved_transform_last(transform)
#signal player_entered_void()
#signal player_entered_exit(scene_name : String, entrance_idx_next : int)
