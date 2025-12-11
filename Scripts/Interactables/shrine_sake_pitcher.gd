extends Node3D
class_name ShrineSakePitcher

@export var drag_min_x: float = -0.2
@export var drag_max_x: float = 0.2
@export var drag_min_y: float = 0.0  # Set in _ready to original_y
@export var drag_max_y: float = 0.3
@export var hover_threshold: float = 0.08  # Distance to consider "over cup"
@export var tilt_angle: float = 45.0  # Degrees to tilt when pouring
@export var tilt_speed: float = 2.0  # Speed of tilt animation

var is_pouring: bool = false
var is_clickable: bool = true
var is_being_dragged: bool = false
var target_cup: Node3D = null
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_position: Vector3 = Vector3.ZERO
var screen_to_world_scale_x: float = 1.0
var screen_to_world_scale_y: float = 1.0
var screen_x_direction: Vector2 = Vector2.ZERO
var screen_y_direction: Vector2 = Vector2.ZERO
var original_position: Vector3 = Vector3.ZERO
var inspection_manager: Node = null
var is_in_inspection_mode: bool = false

signal clicked
signal drag_started
signal drag_ended

@onready var regular_view_sprite: Sprite3D = $RegularViewSprite
@onready var pour_stream: GPUParticles3D = $PourPoint/PourStream if has_node("PourPoint/PourStream") else null
@onready var collision_area: Area3D = $CollisionArea if has_node("CollisionArea") else null
@onready var pour_point: Node3D = $PourPoint if has_node("PourPoint") else null

func _ready():
	# Get InspectionManager
	inspection_manager = get_node_or_null("/root/InspectionManager")
	
	# Store original position
	original_position = position
	drag_min_y = original_position.y  # Can't go below starting Y
	
	# Set up collision layer for inspection mode raycasting (layer 6)
	if collision_area:
		collision_area.collision_layer = 0
		collision_area.collision_mask = 0
		collision_area.set_collision_layer_value(6, true)
	
	# Hide pour stream initially
	if pour_stream:
		pour_stream.emitting = false
	
	# Set initial visibility - hidden in play mode, visible in inspect mode
	_update_visibility_for_mode(false)

func _process(delta):
	check_inspection_mode()
	
	# Animate tilt based on pouring state
	# Rotate the entire node, not just the sprite (billboard sprites can't be rotated)
	var target_rotation = 0.0
	if is_pouring:
		target_rotation = deg_to_rad(tilt_angle)
	
	rotation.z = lerp_angle(rotation.z, target_rotation, tilt_speed * delta)
	
	# Counter-rotate PourPoint so particles always go straight down
	if pour_point:
		pour_point.rotation.z = -rotation.z
	
	# Disable billboard when pouring so tilt is visible
	if regular_view_sprite:
		if is_pouring and regular_view_sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			regular_view_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		elif not is_pouring and regular_view_sprite.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
			regular_view_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func set_target_cup(cup: Node3D):
	target_cup = cup

func start_pour():
	if not is_clickable:
		return
	
	is_pouring = true
	
	if pour_stream:
		pour_stream.emitting = true
		pour_stream.restart()
	else:
		print("ERROR: Pour stream not found!")

func stop_pour():
	if not is_pouring:
		return
	
	is_pouring = false
	
	if pour_stream:
		pour_stream.emitting = false

func set_clickable(clickable: bool):
	is_clickable = clickable

func start_drag(mouse_screen_pos: Vector2):
	if not is_clickable or is_pouring:
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var parent_node = get_parent()
	if not parent_node:
		return
	
	drag_start_mouse_pos = mouse_screen_pos
	drag_start_position = position
	
	# Calculate screen-space mapping for X and Y axes
	var world_x_axis = parent_node.global_transform.basis.x
	var world_y_axis = parent_node.global_transform.basis.y
	var current_world_pos = global_position
	
	# X-axis mapping
	var offset_x_pos = current_world_pos + world_x_axis * 0.1
	var screen_pos_1x = camera.unproject_position(current_world_pos)
	var screen_pos_2x = camera.unproject_position(offset_x_pos)
	screen_x_direction = (screen_pos_2x - screen_pos_1x).normalized()
	var screen_distance_x = screen_pos_1x.distance_to(screen_pos_2x)
	if screen_distance_x > 0.001:
		screen_to_world_scale_x = 0.1 / screen_distance_x
	else:
		screen_to_world_scale_x = 1.0
	
	# Y-axis mapping
	var offset_y_pos = current_world_pos + world_y_axis * 0.1
	var screen_pos_1y = camera.unproject_position(current_world_pos)
	var screen_pos_2y = camera.unproject_position(offset_y_pos)
	screen_y_direction = (screen_pos_2y - screen_pos_1y).normalized()
	var screen_distance_y = screen_pos_1y.distance_to(screen_pos_2y)
	if screen_distance_y > 0.001:
		screen_to_world_scale_y = 0.1 / screen_distance_y
	else:
		screen_to_world_scale_y = 1.0
	
	is_being_dragged = true
	emit_signal("drag_started")

func update_drag(mouse_screen_pos: Vector2):
	if not is_being_dragged:
		return
	
	var mouse_delta = mouse_screen_pos - drag_start_mouse_pos
	
	# Project onto X and Y axes
	var movement_x = mouse_delta.dot(screen_x_direction) * screen_to_world_scale_x
	var movement_y = mouse_delta.dot(screen_y_direction) * screen_to_world_scale_y
	
	# Apply movements with constraints
	var new_x = drag_start_position.x + movement_x
	var new_y = drag_start_position.y + movement_y
	
	position.x = clamp(new_x, drag_min_x, drag_max_x)
	position.y = clamp(new_y, drag_min_y, drag_max_y)

func end_drag():
	if not is_being_dragged:
		return
	
	is_being_dragged = false
	emit_signal("drag_ended")

func check_cup_hover(cup: Node3D) -> bool:
	if not cup or not pour_point:
		return false
	
	var pour_pos = pour_point.global_position
	var cup_pos = cup.global_position
	
	var horizontal_distance = Vector2(pour_pos.x, pour_pos.z).distance_to(Vector2(cup_pos.x, cup_pos.z))
	
	return horizontal_distance <= hover_threshold

func reset_position():
	position = original_position
	is_being_dragged = false

func check_inspection_mode():
	if not inspection_manager:
		return
	
	var current_mode = inspection_manager.current_mode
	var new_inspection_state = (current_mode == inspection_manager.Mode.INSPECT or current_mode == inspection_manager.Mode.DIALOGUE)
	
	if new_inspection_state != is_in_inspection_mode:
		is_in_inspection_mode = new_inspection_state
		_update_visibility_for_mode(new_inspection_state)

func _update_visibility_for_mode(is_inspect_mode: bool):
	# In play mode: hidden
	# In inspect mode: visible
	if regular_view_sprite:
		regular_view_sprite.visible = is_inspect_mode
