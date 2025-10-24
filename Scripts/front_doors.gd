extends Node3D

var remaining_locks = 2

func on_lock_removed():
	remaining_locks -= 1
	if remaining_locks == 0:
		get_tree().change_scene_to_file("res://Maps/GameWnScreen.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
