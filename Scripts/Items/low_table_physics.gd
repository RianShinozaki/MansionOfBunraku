extends RigidBody3D

# Physics-enabled low table that can fall and be pushed by the player
# Used in ceremonial_room_past.tscn

func _ready():
	# Set physics properties
	mass = 8.0  # Realistic table weight in kg?? Who tf knows I googled it.
	linear_damp = 1.5  # Air resistance - prevents endless sliding. This is not an ice skating rink.
	angular_damp = 2.0  # Rotational resistance - prevents endless spinning. See above. Note to self: Fun future scene set on ice?
	
	# gravity_scale = 1.0  # boring default gravity
	# can_sleep = true  # Allow physics to sleep when stationary (default)
