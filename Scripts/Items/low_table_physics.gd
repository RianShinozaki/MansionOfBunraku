extends RigidBody3D

# Physics-enabled low table that can fall and be pushed by the player
# Used in ceremonial_room_past.tscn
# Can be interacted with to tip onto its side

@export var lock_xz_rotation: bool = false  # Lock X and Z rotation (for tables on their side)
@export var interactable: bool = true  # Can the table be tipped by interaction?
@export var tip_duration: float = 0.8  # Duration of the tipping animation
@export var tip_y_offset: float = 0.3  # How much to raise the table's Y position when tipping (tune this value)

# Interaction state
var is_animating: bool = false
var original_position: Vector3

# Collision Sound Settings
@export var collision_sound_enabled: bool = true  # Toggle collision sounds on/off
@export var min_collision_velocity: float = 0.5  # Minimum velocity to trigger sound
@export var collision_cooldown: float = 0.2  # Time between collision sounds (prevents spam)
@export var volume_velocity_multiplier: float = 2.0  # Scale volume with impact strength
@export var max_volume_db: float = 0.0  # Maximum volume in decibels

# Internal variables for collision sound system
var can_play_sound: bool = true
var table_collision_player: AudioStreamPlayer3D
var floor_collision_player: AudioStreamPlayer3D

func _ready():
	# Store original position
	original_position = global_position
	
	# Set physics properties
	mass = 3.0  # Realistic table weight in kg?? ehhh.
	linear_damp = 0.4  # Reduced from 1.5 - allows tables to slide away from collisions without getting stuck
	angular_damp = 1.8  # Rotational resistance - prevents endless spinning. See above. Note to self: Fun future scene set on ice?
	
	gravity_scale = 2.5  
	# can_sleep = true  # Allow physics to sleep when stationary (default)
	
	# Let Godot calculate center of mass from collision shapes
	# We'll use the RotationCenter marker node to compensate for rotation offset
	
	# Add to interactable group if enabled
	if interactable:
		add_to_group("Interactable")
	
	# Create and apply physics material for better collision behavior
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.15  # Slight bounce helps objects separate on collision
	physics_material.friction = 0.7  # Moderate friction prevents ice-skating while allowing movement
	physics_material_override = physics_material
	
	# Rotation locking configuration
	if lock_xz_rotation:
		# For tables that should stay at a fixed angle (e.g., on their side)
		# Allow Y rotation (horizontal spinning) but lock X and Z (no tipping)
		axis_lock_angular_x = true
		axis_lock_angular_z = true
		# Y axis remains unlocked (default)
	# Otherwise, all rotation is free (default RigidBody3D behavior)
	
	# Set up collision sound system
	if collision_sound_enabled:
		# Get references to the AudioStreamPlayer3D nodes (created in the scene)
		table_collision_player = get_node_or_null("TableCollisionSound")
		floor_collision_player = get_node_or_null("FloorCollisionSound")
		
		# Connect collision signal
		body_entered.connect(_on_body_entered)


# Interactable functions
func is_flipped() -> bool:
	"""Calculate if the table is flipped based on its rotation.
	Returns true if x or z rotation is at approximately 90 degrees (±90 degrees)"""
	# Normalize rotations to the range -PI to PI
	var x_rot = fmod(rotation.x + PI, TAU) - PI
	var z_rot = fmod(rotation.z + PI, TAU) - PI
	
	# Check if either x or z rotation is close to 90 degrees (PI/2) or -90 degrees (-PI/2)
	var ninety_deg = PI / 2.0
	var tolerance = deg_to_rad(30)  # 30 degree tolerance
	
	var x_is_90 = abs(abs(x_rot) - ninety_deg) < tolerance
	var z_is_90 = abs(abs(z_rot) - ninety_deg) < tolerance
	
	return x_is_90 or z_is_90


func can_interact() -> bool:
	"""Check if the table can be interacted with"""
	print("can interact check")
	if is_animating:
		print("is animating")
		return false
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY


func on_interact():
	"""Handle interaction - tip the table onto its side"""
	if is_animating or not can_interact():
		return
	
	# Get player position to determine rotation direction
	var player = Player.instance
	if not player:
		return

	
	is_animating = true
	
	# Freeze physics during animation
	#freeze = true
	
	# Get the camera's forward direction (where player is looking)
	var camera = player.get_node("Camera3D")
	var camera_forward = -camera.global_transform.basis.z  # Camera looks down -Z
	camera_forward.y = 0  # Only horizontal component
	camera_forward = camera_forward.normalized()
	
	# Also calculate position-based direction for determining which edge to flip
	var to_player = (player.global_position - global_position).normalized()
	to_player.y = 0
	
	# Transform player direction into table's local space for edge detection
	var local_to_player = global_transform.basis.inverse() * to_player
	local_to_player = local_to_player.normalized()
	
	# Get current rotation
	var start_rotation = rotation
	var target_rotation = start_rotation
	
	if not is_flipped():
		# STEP 1: Y-rotation to face camera FIRST

		# Use RotationCenter marker to determine true rotation point
		var rotation_center = get_node_or_null("RotationCenter")
		var center_world_pos = rotation_center.global_position if rotation_center else global_position
		
		var camera_angle = atan2(camera_forward.x, camera_forward.z)
		
		# Store current state
		var before_pos = center_world_pos
		
		# Set Y rotation
		rotation.y = camera_angle
		
		# Check if the rotation center moved and compensate
		if rotation_center:
			var after_pos = rotation_center.global_position
			var drift = after_pos - before_pos
			drift.y = 0  # Only care about X-Z drift
			global_position -= drift  # Move table back to keep center in place
		
		
		# STEP 2: NOW determine edge and flip direction based on NEW orientation
		# Table dimensions
		var table_half_width = 0.23  # Half the table width (from center to edge)
		var table_leg_bottom = -0.15  # Distance from center to bottom of legs
		
		# Recalculate player direction in table's NEW local space (after Y-rotation)
		var new_local_to_player = global_transform.basis.inverse() * to_player
		new_local_to_player = new_local_to_player.normalized()
				
		# Determine which edge is closest to player and which axis to flip on
		var bottom_edge_offset: Vector3
		var target_x_rotation = 0.0
		var target_z_rotation = 0.0
		
		if abs(new_local_to_player.x) > abs(new_local_to_player.z):
			# Player on left/right - flip on Z axis
			if new_local_to_player.x > 0:
				target_z_rotation = deg_to_rad(-90)  # FLIPPED
				bottom_edge_offset = Vector3(table_half_width, table_leg_bottom, 0)
			else:
				target_z_rotation = deg_to_rad(90)  # FLIPPED
				bottom_edge_offset = Vector3(-table_half_width, table_leg_bottom, 0)
		else:
			# Player on front/back - flip on X axis
			if new_local_to_player.z > 0:
				target_x_rotation = deg_to_rad(90)  # FLIPPED
				bottom_edge_offset = Vector3(0, table_leg_bottom, table_half_width)
			else:
				target_x_rotation = deg_to_rad(-90)  # FLIPPED
				bottom_edge_offset = Vector3(0, table_leg_bottom, -table_half_width)
		
		# Store the Y rotation value to keep it constant during flip
		var locked_y_rotation = rotation.y
		
		# Store starting and target positions for the tween
		var start_pos = global_position
		var target_y = start_pos.y + tip_y_offset
		
		# Calculate horizontal shift toward player in world space
		# Use the to_player vector (already in world space) and scale by tip_y_offset
		var horizontal_offset = to_player * tip_y_offset
		var target_x = start_pos.x + horizontal_offset.x
		var target_z = start_pos.z + horizontal_offset.z
		
		
		# Animate the flip (rotation and position)
		var flip_tween = create_tween()
		flip_tween.set_ease(Tween.EASE_IN_OUT)
		flip_tween.set_trans(Tween.TRANS_CUBIC)
		
		flip_tween.tween_method(func(progress: float):
			# Interpolate X and Z rotation
			var current_x = lerp(0.0, target_x_rotation, progress)
			var current_z = lerp(0.0, target_z_rotation, progress)
			
			# Set rotation directly - Y stays constant, only X or Z changes
			rotation.x = current_x
			rotation.y = locked_y_rotation  # Keep Y constant!
			rotation.z = current_z
			
			# Animate position: Y always changes, and either X or Z shifts toward player
			global_position.x = lerp(start_pos.x, target_x, progress)
			global_position.y = lerp(start_pos.y, target_y, progress)
			global_position.z = lerp(start_pos.z, target_z, progress)
		, 0.0, 1.0, tip_duration)
		
		await flip_tween.finished
		
		# Lock rotation on X and Z after tipping
		#lock_xz_rotation = true
		#axis_lock_angular_x = true
		#axis_lock_angular_z = true
	
	# Re-enable physics
	#freeze = false
	is_animating = false


func _on_body_entered(body: Node):
	"""Handle collisions and play appropriate sound effects"""
	if not collision_sound_enabled or not can_play_sound:
		return
	
	# Calculate collision velocity (impact strength)
	var collision_velocity = linear_velocity.length()
	
	# Only play sound if velocity exceeds minimum threshold
	if collision_velocity < min_collision_velocity:
		return
	
	# Determine which sound to play based on what we collided with
	var sound_player: AudioStreamPlayer3D = null
	
	# Check if we hit the floor (StaticBody3D) or another table (RigidBody3D)
	if body is StaticBody3D:
		# Collided with floor/walls (static objects)
		sound_player = floor_collision_player
	elif body is RigidBody3D:
		# Collided with another table or dynamic object
		sound_player = table_collision_player
	
	# Play the sound if we have a valid player and it has a sound assigned
	if sound_player and sound_player.stream:
		# Calculate volume based on collision velocity
		var volume = clamp(collision_velocity * volume_velocity_multiplier - 20.0, -20.0, max_volume_db)
		sound_player.volume_db = volume
		
		# Play the sound
		sound_player.play()
		
		# Start cooldown to prevent sound spam
		can_play_sound = false
		await get_tree().create_timer(collision_cooldown).timeout
		can_play_sound = true
