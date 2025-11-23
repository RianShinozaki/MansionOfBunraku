extends Node3D
class_name ChoshiPitcher

@export var tilt_angle: float = 45.0  # Degrees to tilt when pouring
@export var tilt_speed: float = 2.0  # Speed of tilt animation
@export var pour_rate: float = 0.15  # How fast sake fills cup per second
@export var drag_min_x: float = -0.4  # Minimum X position for dragging
@export var drag_max_x: float = 0.4  # Maximum X position for dragging
@export var spill_threshold: float = 0.055  # Maximum distance from cup before spilling

var is_pouring: bool = false
var is_clickable: bool = true
var is_being_dragged: bool = false
var target_cup: SakazukiCup = null
var drag_start_mouse_pos: Vector2 = Vector2.ZERO  # Mouse position at drag start
var drag_start_pitcher_x: float = 0.0  # Pitcher X position at drag start
var screen_to_world_scale: float = 1.0  # Scale factor for screen-to-world conversion
var screen_x_direction: Vector2 = Vector2.ZERO  # Direction of X-axis in screen space
var previous_lifetime: float = 0.0  # Track previous lifetime to detect changes
var restart_counter: int = 0  # Counter for periodic particle restarts

# Sprite visibility for mode switching
var inspection_manager: Node = null
var is_in_inspection_mode: bool = false

signal pour_started
signal pour_stopped
signal clicked
signal drag_started
signal drag_ended
signal hovering_cup(cup: SakazukiCup)
signal spill_detected

@onready var regular_view_sprite: Sprite3D = $RegularViewSprite
@onready var model: Node3D = $Model
@onready var pour_stream: GPUParticles3D = $Model/PourPoint/PourStream  # Optional visual effect
@onready var collision_area: Area3D = $CollisionArea
@onready var pour_sound: AudioStreamPlayer3D = $PourSound
@onready var pour_point: Node3D = $Model/PourPoint

func _ready():
	# Get InspectionManager
	inspection_manager = get_node_or_null("/root/InspectionManager")
	
	# Set up collision layer for inspection mode raycasting (layer 6)
	if collision_area:
		collision_area.collision_layer = 0
		collision_area.collision_mask = 0
		collision_area.set_collision_layer_value(6, true)
	
	# Hide pour stream initially
	if pour_stream:
		pour_stream.emitting = false
	
	# Set initial visibility based on mode
	_update_visibility_for_mode(false)

func _process(delta):
	# Check for inspection mode changes
	check_inspection_mode()
	
	# Animate tilt based on pouring state
	if model:
		var target_rotation = 0.0
		if is_pouring:
			target_rotation = deg_to_rad(tilt_angle)
		
		model.rotation.z = lerp_angle(model.rotation.z, target_rotation, tilt_speed * delta)
		
		# Counter-rotate PourPoint so particles always go straight down
		if pour_point:
			pour_point.rotation.z = -model.rotation.z
		
		# Update particle lifetime continuously while pouring to account for pitcher angle changes
		if is_pouring:
			update_particle_lifetime()

func set_target_cup(cup: SakazukiCup):
	"""Set which cup this pitcher will pour into"""
	target_cup = cup
	# Update particle lifetime based on distance to cup
	update_particle_lifetime()

func start_pour():
	"""Begin pouring"""
	if not is_clickable:
		return
	
	is_pouring = true
	
	# Start pour visual effect
	if pour_stream:
		pour_stream.emitting = true
		pour_stream.restart()
	
	# Start pour sound
	if pour_sound:
		pour_sound.play()
	
	emit_signal("pour_started")

func stop_pour():
	"""Stop pouring"""
	if not is_pouring:
		return
	
	is_pouring = false
	
	# Stop pour visual effect
	if pour_stream:
		pour_stream.emitting = false
	
	# Stop pour sound
	if pour_sound:
		pour_sound.stop()
	
	emit_signal("pour_stopped")

func _physics_process(delta):
	# Add liquid to target cup while pouring
	if is_pouring and target_cup:
		# Check alignment before adding liquid
		if is_pour_aligned_with_cup():
			target_cup.add_liquid(pour_rate * delta)
		else:
			# Pourpoint has moved too far from target - emit spill signal
			emit_signal("spill_detected")
			print("spill detected")
			target_cup = null  # Clear target to prevent further liquid addition
			is_pouring = false
			
			# Stop visual effects
			if pour_stream:
				pour_stream.emitting = false
			if pour_sound:
				pour_sound.stop()

func set_clickable(clickable: bool):
	"""Enable/disable clicking on pitcher"""
	is_clickable = clickable

func on_inspect_click():
	"""Called when clicked in inspection mode"""
	if is_clickable:
		emit_signal("clicked")

func show_hint_animation():
	"""Subtle animation to indicate pitcher is clickable"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y + 0.02, 1.0)
	tween.tween_property(self, "position:y", position.y, 1.0)

func stop_hint_animation():
	"""Stop the hint animation"""
	var tweens = get_tree().get_nodes_in_group("tweens")
	for tween in tweens:
		if tween is Tween:
			tween.kill()

func start_drag(mouse_screen_pos: Vector2):
	"""Begin dragging the pitcher"""
	if not is_clickable or is_pouring:
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var parent_node = get_parent()
	if not parent_node:
		return
	
	# Store initial state
	drag_start_mouse_pos = mouse_screen_pos
	drag_start_pitcher_x = position.x
	
	# Calculate screen-space mapping for the X-axis
	# Project two points along the X-axis to see how they map to screen space
	var world_x_axis = parent_node.global_transform.basis.x
	var current_world_pos = global_position
	var offset_world_pos = current_world_pos + world_x_axis * 0.1  # 0.1 units along X
	
	var screen_pos_1 = camera.unproject_position(current_world_pos)
	var screen_pos_2 = camera.unproject_position(offset_world_pos)
	
	# Calculate screen space direction and scale
	screen_x_direction = (screen_pos_2 - screen_pos_1).normalized()
	var screen_distance = screen_pos_1.distance_to(screen_pos_2)
	
	# Scale factor: screen pixels per world unit
	if screen_distance > 0.001:
		screen_to_world_scale = 0.1 / screen_distance  # 0.1 world units = screen_distance pixels
	else:
		screen_to_world_scale = 1.0
	
	is_being_dragged = true
	emit_signal("drag_started")

func update_drag(mouse_screen_pos: Vector2):
	"""Update pitcher position while dragging"""
	if not is_being_dragged:
		return
	
	# Calculate mouse movement in screen space
	var mouse_delta = mouse_screen_pos - drag_start_mouse_pos
	
	# Project mouse delta onto the screen X-axis direction
	var movement_along_axis = mouse_delta.dot(screen_x_direction)
	
	# Convert screen space movement to world space movement
	var world_movement = movement_along_axis * screen_to_world_scale
	
	# Apply movement to pitcher X position
	var new_x = drag_start_pitcher_x + world_movement
	position.x = clamp(new_x, drag_min_x, drag_max_x)

func end_drag():
	"""Stop dragging the pitcher"""
	if not is_being_dragged:
		return
	
	is_being_dragged = false
	emit_signal("drag_ended")

func check_cup_hover(cups: Array) -> SakazukiCup:
	"""Check if pitcher is hovering over any cup"""
	# Use PourPoint position (where liquid pours from) in local coordinates
	# PourPoint has an offset from pitcher base, need to account for that
	var pour_point_local_offset = pour_point.position if pour_point else Vector3.ZERO
	var check_position = position + pour_point_local_offset
	var closest_cup: SakazukiCup = null
	var closest_distance = 0.1  # Maximum distance to consider "hovering"
	
	for cup in cups:
		if cup is SakazukiCup:
			var cup_local_pos = cup.position
			var distance = abs(check_position.x - cup_local_pos.x)
			if distance < closest_distance:
				closest_distance = distance
				closest_cup = cup
	
	return closest_cup

func is_pour_aligned_with_cup() -> bool:
	"""Check if pourpoint is still aligned with target cup within spill threshold"""
	if not target_cup or not pour_point:
		return false
	
	# Get global position of pourpoint (where liquid actually pours from)
	var pour_pos = pour_point.global_position
	var cup_pos = target_cup.global_position
	
	# Calculate horizontal distance (X-axis)
	var horizontal_distance = abs(pour_pos.x - cup_pos.x)
	
	# Check if within acceptable threshold
	return horizontal_distance <= spill_threshold

func update_particle_lifetime():
	"""Calculate and set particle lifetime based on distance to target cup"""
	if not pour_stream or not target_cup or not pour_point:
		return
	
	# Get global positions
	var pour_pos = pour_point.global_position
	var cup_pos = target_cup.global_position
	
	# Calculate vertical distance (Y-axis)
	# Account for cup collider offset (0.005 units above cup origin)
	var fall_distance = abs(pour_pos.y - (cup_pos.y + 0.005))
	
	# Get particle properties from ParticleProcessMaterial
	var process_mat = pour_stream.process_material as ParticleProcessMaterial
	if not process_mat:
		return
	
	# Physics: distance = v0*t + 0.5*g*t^2
	# We know: initial velocity (avg ~0.75), gravity (-2.0), distance
	# Solve quadratic equation: 0.5*g*t^2 + v0*t - distance = 0
	var v0 = (process_mat.initial_velocity_min + process_mat.initial_velocity_max) / 2.0
	var g = abs(process_mat.gravity.y)
	
	# Quadratic formula: t = (-v0 + sqrt(v0^2 + 2*g*distance)) / g
	var discriminant = v0 * v0 + 2.0 * g * fall_distance
	if discriminant < 0:
		# Shouldn't happen, but safety check
		pour_stream.lifetime = 0.3
		return
	
	var time_to_cup = (-v0 + sqrt(discriminant)) / g
	
	# Reduce lifetime to stop particles at cup rim
	# Cup origin is at center, so we want to stop particles earlier
	var lifetime = max(0.1, time_to_cup * 1.0)  # reduce to end earlier
	
	# Always update the lifetime
	pour_stream.lifetime = lifetime
	
	# During tilt animation, lifetime changes gradually (less than 0.01s per frame)
	# so we restart particles periodically to clear old particles with incorrect lifetimes
	restart_counter += 1
	if restart_counter >= 3 and pour_stream.emitting:
		pour_stream.restart()
		restart_counter = 0
	
	previous_lifetime = lifetime

func check_inspection_mode():
	"""Check if inspection mode has changed and update visibility accordingly"""
	if not inspection_manager:
		return
	
	var current_mode = inspection_manager.current_mode
	# Show high-res sprite in both INSPECT and DIALOGUE modes
	var new_inspection_state = (current_mode == inspection_manager.Mode.INSPECT or current_mode == inspection_manager.Mode.DIALOGUE)
	
	if new_inspection_state != is_in_inspection_mode:
		is_in_inspection_mode = new_inspection_state
		_update_visibility_for_mode(new_inspection_state)

func _update_visibility_for_mode(is_inspect_mode: bool):
	"""Toggle visibility between regular and inspection sprites"""
	if regular_view_sprite:
		regular_view_sprite.visible = not is_inspect_mode
	if model:
		model.visible = is_inspect_mode
