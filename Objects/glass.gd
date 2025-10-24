extends Node3D
signal door_opened  # Signal when door finishes opening
func open_door():
	# Animate the door opening
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", Vector3(0, -90, 0), 1.0)
	print("Glass door opening!")
