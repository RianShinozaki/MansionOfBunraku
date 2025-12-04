extends Node3D
@onready var kouya_object = $"../../Bunraku/Kouya"
var kouya_object_orig
var moved_kouya: bool = false

func _process(_delta: float) -> void:
	if Player.instance.active and moved_kouya and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
		kouya_object.global_position = kouya_object_orig
		moved_kouya = false
		
func handle_failed_game() -> void:
	if not moved_kouya:
		kouya_object_orig = kouya_object.global_position
		
	moved_kouya = true
	$"../../Bunraku".switch_to_yono()
	$"../../Bunraku/Kouya/Kouya".anger_decrease_delta = 0
	if kouya_object.global_position != global_position:
		kouya_object.global_position = global_position
	else:
		$"../../Bunraku/Kouya/Kouya".anger_level += 0.91
