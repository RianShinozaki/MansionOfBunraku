###A script for controlling the title screen menu

extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_game()

func _on_start_button_pressed() -> void:
	_start_game()

func _start_game() -> void:
	# Skip cutscene for testing - go directly to game
	get_tree().change_scene_to_file("res://Maps/Game.tscn")
	# Original code (commented out for testing):
	# $StartGame.play("start")
	# await $StartGame.animation_finished
	# get_tree().change_scene_to_file("res://Maps/MeltdownCutscene.tscn")
