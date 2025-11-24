extends Node

@onready var object: Node3D = get_parent() as Node3D
func _physics_process(_delta: float) -> void:
	turn_to_cam()
	
func turn_to_cam() -> void:
	# Only turn to camera if camera is available (for testing scenes directly)
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	# var _pos: Vector3 = get_viewport().get_camera_3d().global_position
	var _pos: Vector3 = camera.global_position
	object.look_at( Vector3(_pos.x, object.global_position.y, _pos.z), Vector3.UP, true)
