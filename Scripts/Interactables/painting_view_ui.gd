extends CanvasLayer

# Manages the close-up painting view UI using a 3D SubViewport
# This whole thing is kind of a placeholder for now. Actually, it will transport you to the hallway (or open the door)

signal view_closed

@onready var viewport = $SubViewportContainer/SubViewport
@onready var camera = $SubViewportContainer/SubViewport/Camera3D
@onready var light = $SubViewportContainer/SubViewport/DirectionalLight3D

var painting_instance: Node3D = null
var original_painting: Node3D = null
var hint_timer: Timer = null
var pulse_tween: Tween = null

func _ready():
	hide()
	
	# Set up hint timer
	hint_timer = Timer.new()
	add_child(hint_timer)
	hint_timer.wait_time = 20.0
	hint_timer.one_shot = false
	hint_timer.timeout.connect(_on_hint_timer_timeout)

func show_painting(painting_node: Node3D) -> void:
	if not painting_node:
		return
	
	# Store reference to original painting for swing animation
	original_painting = painting_node
	
	# Duplicate the painting node to show in the viewport
	painting_instance = painting_node.duplicate()
	viewport.add_child(painting_instance)
	
	# Keep painting at its actual position in the scene
	painting_instance.global_transform = painting_node.global_transform
	
	# Ensure clean numbers are shown in close-up (not blurred)
	if painting_instance.has_node("VisualPivot/PlaqueNumbersSprite"):
		painting_instance.get_node("VisualPivot/PlaqueNumbersSprite").visible = true
	if painting_instance.has_node("VisualPivot/PlaqueNumbersSpriteBlur"):
		painting_instance.get_node("VisualPivot/PlaqueNumbersSpriteBlur").visible = false
	
	# Position camera close to painting, facing it from the front
	var painting_pos = painting_node.global_position
	var painting_forward = -painting_node.global_transform.basis.z  # Forward direction of painting
	var camera_distance = 2.0  # distance from painting (increase for less zoom)
	
	# Place camera in front of painting (opposite side from where painting faces)
	camera.global_position = painting_pos - painting_forward * camera_distance
	
	# Make camera look at the painting
	camera.look_at(painting_pos, Vector3.UP)
	
	# Copy camera settings from main scene
	_copy_camera_settings()
	
	# Copy lighting from main scene if available
	_copy_scene_lighting()
	
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Start hint timer and show initial pulse after a short delay
	await get_tree().create_timer(0.5).timeout
	_pulse_plaque_emission()
	hint_timer.start()

func _copy_camera_settings() -> void:
	# Find the player's camera to copy exposure and other settings
	var player = get_tree().root.get_node_or_null("Game/Player")
	if not player:
		return
	
	var player_camera = player.get_node_or_null("Head/Camera3D")
	if not player_camera:
		return
	
	# Copy ALL camera properties that affect rendering
	camera.attributes = player_camera.attributes
	camera.environment = player_camera.environment
	camera.cull_mask = player_camera.cull_mask
	camera.fov = player_camera.fov
	camera.near = player_camera.near
	camera.far = player_camera.far

func _copy_scene_lighting() -> void:
	# Try to match the main scene's lighting
	var main_scene = get_tree().root.get_node_or_null("Game")
	if not main_scene:
		return
	
	# Remove the default light since we'll copy from scene
	if light:
		light.queue_free()
		light = null
	
	# Copy ALL lights from the main scene
	var all_lights = []
	_find_nodes_of_type(main_scene, Light3D, all_lights)
	
	for scene_light in all_lights:
		var light_copy = scene_light.duplicate()
		viewport.add_child(light_copy)
		# Preserve global transform
		light_copy.global_transform = scene_light.global_transform

func _find_nodes_of_type(node: Node, type, result_array: Array) -> void:
	if is_instance_of(node, type):
		result_array.append(node)
	
	for child in node.get_children():
		_find_nodes_of_type(child, type, result_array)

func _find_node_of_type(node: Node, type):
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

func close_view() -> void:
	# Stop hint timer
	if hint_timer:
		hint_timer.stop()
	
	# Stop any ongoing pulse animation
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	
	# Clean up painting instance
	if painting_instance:
		painting_instance.queue_free()
		painting_instance = null
	
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	view_closed.emit()

func _input(event):
	if visible:
		if event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE:
				close_view()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				# Check if click is on the plaque
				if _is_click_on_plaque(event.position):
					# Reset hint timer on plaque click (since they found it)
					if hint_timer and not hint_timer.is_stopped():
						hint_timer.start()
					
					# Store reference before closing
					var painting_ref = original_painting
					# Close view first
					close_view()
					# Then dissolve the artwork after view is fully closed (deferred to next frame)
					if painting_ref and painting_ref.has_method("swing_painting"):
						painting_ref.call_deferred("swing_painting")
				else:
					# Click anywhere else to close immediately
					close_view()
				get_viewport().set_input_as_handled()

func _is_click_on_plaque(screen_pos: Vector2) -> bool:
	# Simple approach: The plaque is in the upper portion of the painting view
	# Check if click is in the top third of the screen and centered horizontally
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Plaque should be roughly in upper-middle area of view
	# Check if Y is in upper portion (top 40% of screen)
	# and X is in middle portion (30%-70% of screen width)
	var is_in_upper_portion = screen_pos.y < viewport_size.y * 0.4
	var is_in_middle_horizontally = screen_pos.x > viewport_size.x * 0.3 and screen_pos.x < viewport_size.x * 0.7
	
	return is_in_upper_portion and is_in_middle_horizontally

func _on_hint_timer_timeout() -> void:
	# Pulse the plaque emission every 20 seconds
	_pulse_plaque_emission()

func _pulse_plaque_emission() -> void:
	if not painting_instance:
		return
	
	# Find the plaque sprite
	var plaque_sprite = painting_instance.get_node_or_null("VisualPivot/PlaqueSprite")
	if not plaque_sprite:
		return
	
	# Get the material (it should already have emission enabled)
	var material = plaque_sprite.material_override
	if not material:
		return
	
	# Kill any existing pulse animation
	if pulse_tween:
		pulse_tween.kill()
	
	# Create a new tween for the pulse effect
	pulse_tween = create_tween()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	
	# Pulse the emission energy from normal (0.07) to bright (3.0) and back
	material.emission_energy_multiplier = 1.5
	pulse_tween.tween_property(material, "emission_energy_multiplier", 0.07, 0.8)
