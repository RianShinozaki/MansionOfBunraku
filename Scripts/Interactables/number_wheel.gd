extends Node3D

@export var wheel_index: int = 0  # Which wheel (0-3)

var current_number: int = 0

@onready var number_label: Label3D = $NumberLabel

func _ready():
	# Initialize label to show 0
	if number_label:
		number_label.text = str(current_number)

func rotate_wheel() -> void:
	# Increment number (0-9, wraps around)
	current_number = (current_number + 1) % 10
	
	# Update label to show new number
	if number_label:
		number_label.text = str(current_number)
	
	# Notify parent lock
	get_parent().on_wheel_changed(wheel_index)

func get_current_number() -> int:
	return current_number

func reset() -> void:
	current_number = 0
	
	# Update label
	if number_label:
		number_label.text = str(current_number)
