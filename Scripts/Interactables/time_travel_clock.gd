extends StaticBody3D

# Time Travel Clock - Interactive clock that triggers time vortex effect

@export_group("Time Vortex Settings")
@export var time_travel_target: String = "res://Maps/TimeTravelScene.tscn"
@export var vortex_duration: float = 2.5
@export var vortex_clockwise: bool = true
@export var vortex_color: Color = Color(0.1, 0.05, 0.15, 1.0)  # Void/Shadow: Very Dark Purple
@export var vortex_center_color: Color = Color(0.3, 0.3, 0.35, 1.0)  # Void/Shadow: Dark Gray

var anim_lock: bool = false

func _ready():
	# Add to Interactable group
	add_to_group("Interactable")

func can_interact() -> bool:
	# Can only interact when in normal play mode
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY and not anim_lock

func on_interact():
	if anim_lock:
		return
	
	# Trigger the time vortex effect
	trigger_time_vortex()

func trigger_time_vortex():
	if anim_lock:
		return
	
	anim_lock = true
	
	# Create and add the time vortex effect
	var vortex_scene = preload("res://Objects/Effects/TimeVortex.tscn")
	var vortex = vortex_scene.instantiate()
	get_tree().root.add_child(vortex)
	
	# Trigger the transition with configured parameters, passing clock reference
	vortex.trigger_transition(
		time_travel_target,
		vortex_duration,
		vortex_clockwise,
		vortex_color,
		vortex_center_color,
		0.85,  # max_progress
		self,  # clock_object - pass this clock as the focus target
		3.0    # camera_focus_duration - 2x longer for more dramatic buildup
	)
	
	# Note: No need to reset anim_lock since the scene will change
