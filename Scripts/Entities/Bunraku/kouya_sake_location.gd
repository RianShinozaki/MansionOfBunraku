extends Node3D
@onready var kouya_object = $"../../Bunraku/Kouya"

func handle_failed_game() -> void:
	$"../../Bunraku".switch_to_yono()
	if kouya_object.global_position != global_position:
		kouya_object.global_position = global_position
	else:
		$"../../Bunraku/Kouya/Kouya".anger_level += 0.35
