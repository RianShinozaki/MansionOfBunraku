extends Node3D

@export var wheel_index: int = 1  # Which wheel (1-4)

var current_number: int = 0


@onready var ring_mesh: Node3D = get_node_or_null("Ring")

func _ready():
	if not ring_mesh:
		push_error("Ring mesh not found for wheel " + str(wheel_index))
		print("Looking for: Ring_0" + str(wheel_index))
	else:
		print("Ring mesh found successfully for wheel " + str(wheel_index))

func rotate_wheel() -> void:
	# Increment number (0-9, wraps around)
	current_number = (current_number + 1) % 10
	
	# Only create tween if we have something to animate
	if ring_mesh and ring_mesh.is_inside_tree():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		
		var ring_current = ring_mesh.rotation_degrees
		var ring_target = ring_current + Vector3(0, -36, 0)
		tween.tween_property(ring_mesh, "rotation_degrees", ring_target, 0.3)
	
	# Notify parent lock
	get_parent().on_wheel_changed(wheel_index)

func get_current_number() -> int:
	return current_number

func reset() -> void:
	current_number = 0
	
	
	if ring_mesh:
		ring_mesh.rotation_degrees = Vector3.ZERO
