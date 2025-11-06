extends Node

var fullscreen: bool
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var _iek = event as InputEventKey
		if _iek.keycode == KEY_F4:
			if fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			fullscreen = not fullscreen
			
