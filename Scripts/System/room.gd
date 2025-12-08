class_name Room

extends Node3D

@export var world_offset: Vector3
@export var world_rotation: Vector3

func _ready() -> void:
	global_position = world_offset
	global_rotation_degrees = world_rotation
