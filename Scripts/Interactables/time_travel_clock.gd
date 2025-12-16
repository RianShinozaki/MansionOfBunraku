extends StaticBody3D

# Time Travel Clock - Interactive clock that triggers time vortex effect

@export_group("Time Vortex Settings")
@export var time_travel_target: String = "res://Maps/TimeTravelScene.tscn"
@export var vortex_duration: float = 4.0
@export var vortex_clockwise: bool = true
@export var vortex_color: Color = Color(0.1, 0.05, 0.15, 1.0)  # Void/Shadow: Very Dark Purple
@export var vortex_center_color: Color = Color(0.3, 0.3, 0.35, 1.0)  # Void/Shadow: Dark Gray

var anim_lock: bool = false

func trigger_time_vortex():
	if anim_lock:
		return
	
	anim_lock = true
	
	# On web, store current mouse mode and switch to visible to prevent input freeze
	var original_mouse_mode = Input.mouse_mode
	if OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("Clock: Mouse mode set to VISIBLE for web vortex")
		await get_tree().process_frame
	
	# Store whether this is the first activation (delay setting the flag until after vortex)
	var is_first_activation = not GameManager.instance.clock_activated_once
	
	# Toggle time state
	GameManager.instance.is_past_time = !GameManager.instance.is_past_time
	print("Time travel! Now in: " + ("PAST" if GameManager.instance.is_past_time else "PRESENT"))
	
	# Find the ceremonial load zone and trigger room reload
	var ceremonial_zone = get_tree().root.get_node_or_null("Game/LoadingZones/CeremonialLoadZone")
	if ceremonial_zone:
		ceremonial_zone.reload_room()
		# On web, give the room time to actually reload
		if OS.has_feature("web"):
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			print("Clock: Extra frames for room reload on web")
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
	
	# Wait for effect to complete using signal instead of tree_exited
	await vortex.effect_completed
	
	# On web, add extra delay before activating fog barriers to prevent shader overlap
	if OS.has_feature("web"):
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		print("Clock: Extra delay on web before fog barriers")
	
	# NOW mark that clock has been activated (after vortex completes)
	# This prevents fog barrier shader from loading while vortex is still active
	if is_first_activation:
		GameManager.instance.clock_activated_once = true
		print("Clock activated for the first time - fog barriers appearing NOW")
	
	# On web, restore mouse mode after everything completes
	if OS.has_feature("web"):
		await get_tree().process_frame
		Input.mouse_mode = original_mouse_mode
		print("Clock: Mouse mode restored to: ", original_mouse_mode)
		await get_tree().process_frame
	
	anim_lock = false
