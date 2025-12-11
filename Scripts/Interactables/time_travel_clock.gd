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
	
	# Toggle time state
	GameManager.instance.is_past_time = !GameManager.instance.is_past_time
	print("Time travel! Now in: " + ("PAST" if GameManager.instance.is_past_time else "PRESENT"))
	
	# Find the ceremonial load zone and trigger room reload
	var ceremonial_zone = get_tree().root.get_node_or_null("Game/LoadingZones/CeremonialLoadZone")
	if ceremonial_zone:
		ceremonial_zone.reload_room()
	else:
		push_warning("CeremonialLoadZone not found!")
	
	# Create and add the time vortex effect for visual feedback (no scene change)
	var vortex_scene = preload("res://Objects/Effects/TimeVortex.tscn")
	var vortex = vortex_scene.instantiate()
	get_tree().root.add_child(vortex)
	
	# Use play_effect_only instead of trigger_transition since we're not changing scenes
	vortex.play_effect_only(
		vortex_duration,
		vortex_clockwise,
		vortex_center_color,  # center_color
		Color(0.25, 0.2, 0.3, 1.0),  # inner_color
		Color(0.2, 0.1, 0.25, 1.0),  # mid_color
		vortex_color,  # vortex_color
		Color(0.05, 0.0, 0.1, 1.0),  # edge_color
		false  # reverse
	)
	
	# Wait for effect to finish, then unlock
	await vortex.tree_exited
	anim_lock = false
