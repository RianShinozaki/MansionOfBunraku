class_name Key

extends Grabbable

var door_is_open: bool = false

func _ready():
	# Keep the key frozen in place until picked up
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

func can_pickup() -> bool:
	if not door_is_open:
		return false
	if held or freeze:
		return false
	return true

func unlock_key():
	door_is_open = true
	freeze = false

func on_pickup(_bypass: bool = false):
	if not can_pickup(): 
		return
	freeze = false
	super.on_pickup()
