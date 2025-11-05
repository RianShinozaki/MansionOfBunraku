extends Node3D



func _on_dialogue_box_dialogue_ended() -> void:
	$AnimationPlayer.play("end_cutscene")

func end_cutscene() -> void:
	get_tree().change_scene_to_file("res://Maps/Game.tscn")
	
