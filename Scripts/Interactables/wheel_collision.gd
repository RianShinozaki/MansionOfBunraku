extends StaticBody3D

func _ready():
	add_to_group("Interactable")

func can_interact() -> bool:
	var lock = get_parent().get_parent()
	if lock and lock.has_method("can_interact"):
		return lock.can_interact()
	return true

func on_interact() -> void:
	var wheel_pivot = get_parent()
	if wheel_pivot and wheel_pivot.has_method("rotate_wheel"):
		wheel_pivot.rotate_wheel()
