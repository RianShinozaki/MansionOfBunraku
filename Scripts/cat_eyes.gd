extends Sprite3D

var meow_time = 0

func _process(delta: float) -> void:
	var _vec_to_player = (Player.instance.global_position - (global_position + Vector3.UP * 0.2))
	var _dist_to_player = _vec_to_player.length()
	meow_time = move_toward(meow_time, 0, delta)
	if _dist_to_player < 3 and Player.instance.held_object is Meatball and meow_time == 0:
		$AudioStreamPlayer3D.pitch_scale = randf_range(0.8, 1.2)
		$AudioStreamPlayer3D.play()
		meow_time = 4
