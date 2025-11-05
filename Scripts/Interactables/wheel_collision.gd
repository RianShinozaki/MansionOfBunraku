extends StaticBody3D

func _ready():
	add_to_group("Interactable")
	# Set collision layers to 3 (Interactables) AND 6 (InspectableDetails)
	# Layer 3: Player can click in PLAY mode
	# Layer 6: InspectionManager can raycast in INSPECT mode
	collision_layer = (1 << 2) | (1 << 5)  # Layers 3 and 6

func can_interact() -> bool:
	# Only allow normal interaction in PLAY mode
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact() -> void:
	# In PLAY mode, clicking any wheel enters inspect mode on the lock
	var lock = get_parent().get_parent()
	if lock and lock.has_method("on_interact"):
		lock.on_interact()

func on_inspect_click() -> void:
	# Called by InspectionManager when clicked in INSPECT mode
	# Rotate the wheel
	var wheel_pivot = get_parent()
	if wheel_pivot and wheel_pivot.has_method("rotate_wheel"):
		wheel_pivot.rotate_wheel()
