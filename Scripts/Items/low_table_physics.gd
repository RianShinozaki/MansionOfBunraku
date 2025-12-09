extends RigidBody3D

# Physics-enabled low table that can fall and be pushed by the player
# Used in ceremonial_room_past.tscn

@export var lock_xz_rotation: bool = false  # Lock X and Z rotation (for tables on their side)

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
	# Set physics properties
	mass = 3.0  # Realistic table weight in kg?? ehhh.
	linear_damp = 0.4  # Reduced from 1.5 - allows tables to slide away from collisions without getting stuck
	angular_damp = 1.8  # Rotational resistance - prevents endless spinning. See above. Note to self: Fun future scene set on ice?
	
	gravity_scale = 2.5  
	# can_sleep = true  # Allow physics to sleep when stationary (default)
	
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
