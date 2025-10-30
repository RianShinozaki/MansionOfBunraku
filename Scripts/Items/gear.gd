class_name Gear

extends Item

var is_in_socket: bool = false

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
func on_dropped():
	super.on_dropped()
	# Only freeze if in socket, otherwise stay pickupable
	if not is_in_socket:
		freeze = false
