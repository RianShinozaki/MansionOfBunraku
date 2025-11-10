extends Node3D

@export var wheel_index: int = 1  # Which wheel (1-4)

var current_number: int = 0

@onready var number_labels: Node3D = $NumberLabels
@onready var ring_mesh: Node3D = get_node_or_null("Ring_0" + str(wheel_index))

func _ready():
	pass

func rotate_wheel() -> void:
	# Increment number (0-9, wraps around)
	current_number = (current_number + 1) % 10
	
	# Animate the wheel spinning
	var tween = create_tween()
	tween.set_parallel(true)  # Both animations run simultaneously
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	# Rotate NumberLabels (with safety check)
	if number_labels and number_labels.is_inside_tree():
		var current_rotation = number_labels.rotation_degrees
		var target_rotation = current_rotation + Vector3(0, -36, 0)
		tween.tween_property(number_labels, "rotation_degrees", target_rotation, 0.3)
	
	# Rotate Ring mesh (with safety check)
	if ring_mesh and ring_mesh.is_inside_tree():
		var ring_current = ring_mesh.rotation_degrees
		var ring_target = ring_current + Vector3(0, -36, 0)
		tween.tween_property(ring_mesh, "rotation_degrees", ring_target, 0.3)
	
	# Notify parent lock
	get_parent().on_wheel_changed(wheel_index)

func get_current_number() -> int:
	return current_number

func reset() -> void:
	current_number = 0
	
	# Reset rotations
	if number_labels:
		number_labels.rotation_degrees = Vector3.ZERO
	if ring_mesh:
		ring_mesh.rotation_degrees = Vector3.ZERO
