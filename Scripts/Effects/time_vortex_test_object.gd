extends StaticBody3D

## Simple test object for triggering the time vortex effect
## Click on this object to see the vortex and restart the scene

@export var time_travel_target: String = "res://Maps/Game.tscn"
@export var vortex_duration: float = 2.5
@export var vortex_clockwise: bool = true
@export var vortex_color: Color = Color(0.0, 0.38, 0.482, 1.0)
@export var vortex_center_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	add_to_group("Interactable")

func can_interact() -> bool:
	return true

func on_interact():
	print("Time Vortex Test Object clicked! Triggering vortex...")
	trigger_time_vortex()

func trigger_time_vortex():
	# Create and add the time vortex effect
	var vortex_scene = preload("res://Objects/Effects/TimeVortex.tscn")
	var vortex = vortex_scene.instantiate()
	get_tree().root.add_child(vortex)
	
	# Trigger the transition with configured parameters
	vortex.trigger_transition(
		time_travel_target,
		vortex_duration,
		vortex_clockwise,
		vortex_color,
		vortex_center_color
	)
