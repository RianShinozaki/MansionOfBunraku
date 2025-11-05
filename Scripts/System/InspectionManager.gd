extends Node

# Simple 2-state inspection system: PLAY <-> INSPECT
enum Mode { PLAY, INSPECT }

var current_mode: Mode = Mode.PLAY
var inspect_camera: Camera3D
var player_camera: Camera3D
var player: Player
var inspect_collision_mask: int = 1 << 5  # Layer 6 for inspectable details

func _ready():
	await get_tree().process_frame
	player = Player.instance
	if player:
		player_camera = player.get_node_or_null("Camera3D")

func _ensure_cameras() -> bool:
	# Lazily find cameras when first needed to ensure game scene is ready
	if not inspect_camera:
		inspect_camera = get_tree().root.find_child("InspectCamera", true, false) as Camera3D
		if not inspect_camera:
			push_error("InspectCamera not found in scene. Add a Camera3D named 'InspectCamera' to enable inspection mode.")
			return false
		print("InspectionManager: Found InspectCamera")
	
	if not player:
		player = Player.instance
	if player and not player_camera:
		player_camera = player.get_node_or_null("Camera3D")
	
	return inspect_camera != null and player != null and player_camera != null

func enter_inspect(target: Node3D, focus_marker: Node3D, fov: float = 50.0):
	if current_mode == Mode.INSPECT:
		return
	
	if not _ensure_cameras():
		push_error("InspectionManager not properly initialized")
		return
	
	# Ensure player is active first (in case of interrupted previous inspect)
	if not player.active:
		player.active = true
	
	# Store camera setup for deferred execution
	var camera_transform = focus_marker.global_transform
	var camera_fov = fov
	
	# Set mode first so input handlers see it
	current_mode = Mode.INSPECT
	
	# Defer ALL state changes to happen after input event completes
	call_deferred("_finalize_inspect_mode", camera_transform, camera_fov)

func _finalize_inspect_mode(camera_transform: Transform3D, camera_fov: float):
	# Position and activate inspect camera
	inspect_camera.global_transform = camera_transform
	inspect_camera.fov = camera_fov
	
	# Switch cameras
	player_camera.current = false
	inspect_camera.current = true
	
	# Disable player and confine cursor to window (hide OS cursor)
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	
	# Keep UI cursor visible - it will be updated in _process

func exit_inspect():
	if current_mode != Mode.INSPECT:
		return
	
	# Re-enable player
	player.active = true
	
	# Switch back to player camera
	player_camera.current = true
	
	# Capture cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_mode = Mode.PLAY

func _process(_delta):
	# Update UI cursor in inspect mode
	if current_mode != Mode.INSPECT:
		return
	
	if not player:
		return
	
	var ui_cursor = player.get_node_or_null("CanvasLayer/TextureRect")
	if not ui_cursor:
		return
	
	# Position UI cursor at mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	ui_cursor.position = mouse_pos - ui_cursor.size / 2  # Center on cursor
	
	# Raycast to check what we're hovering over
	var hit = raycast_from_mouse(mouse_pos)
	
	# Update cursor texture based on what we're hovering over
	if hit and hit.collider:
		# Hovering over something interactable - show circle
		ui_cursor.texture = player.circleUI
	else:
		# Hovering over nothing - show cross
		ui_cursor.texture = player.crossUI

func _unhandled_input(event):
	if current_mode != Mode.INSPECT:
		return
	
	# Handle ESC to exit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_inspect()
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse clicks
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var hit = raycast_from_mouse(get_viewport().get_mouse_position())
			if hit:
				# Hit something - let it handle the interaction
				var collider = hit.collider
				if collider and collider.has_method("on_inspect_click"):
					collider.on_inspect_click()
				get_viewport().set_input_as_handled()
			else:
				# Clicked empty space - exit inspect
				exit_inspect()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right click to exit
			exit_inspect()
			get_viewport().set_input_as_handled()

func raycast_from_mouse(mouse_pos: Vector2) -> Dictionary:
	if not inspect_camera:
		return {}
	
	# Cast ray from inspect camera through mouse position
	var from = inspect_camera.project_ray_origin(mouse_pos)
	var to = from + inspect_camera.project_ray_normal(mouse_pos) * 100.0
	
	# Get the 3D world from the viewport
	var space = get_tree().root.world_3d.direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.collision_mask = inspect_collision_mask
	
	return space.intersect_ray(params)
