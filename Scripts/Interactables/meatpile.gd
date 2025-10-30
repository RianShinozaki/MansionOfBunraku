extends StaticBody3D

@onready var meat_ball = preload("res://Objects/Items/Meatball.tscn")

func can_interact():
	return Player.instance.held_object == null
	
func on_interact():
	var _meat = meat_ball.instantiate()
	Player.instance.get_node("Camera3D").add_child(_meat)
	Player.instance.held_object = _meat
	_meat.on_pickup()
	$SFX.play()

func _process(_delta: float) -> void:
	if $"../../DoorLPivot/DoorL/StaticBody3D".open or $"../../DoorLPivot2/DoorL/StaticBody3D".open:
		if not is_in_group("Meat"):
			add_to_group("Meat")
	else:
		if is_in_group("Meat"):
			remove_from_group("Meat")
