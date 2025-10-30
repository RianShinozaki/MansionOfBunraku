class_name GearSocket

extends StaticBody3D

const SECONDS_TO_CHIME: int = 15

@export var gear_target_position: Vector3 = Vector3(-2.3, 0.015, -1.15)  
@export var gear_rotation: Vector3 = Vector3(0, 90, 0)  
@export var wait_time_total = 1

var has_gear: bool = false
var time_remaining: float = SECONDS_TO_CHIME
var gear_object: Gear
var tick_sfx_offset: float = 0
static var instance: GearSocket

func _ready():
	# Create timer for the countdown
	var timer = Timer.new()
	timer.name = "WaitTimer"
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_wait_complete)
	instance = self

func can_interact() -> bool:
	return Player.instance.held_object is Gear or has_gear

func on_interact():
	# When clicked with a gear held place it in the socket
	if Player.instance.held_object is Gear:
		var gear = Player.instance.held_object
		# Remove from player hand
		Player.instance.held_object = null
		gear.get_parent().remove_child(gear)
		add_child(gear)
		
		#teleport to target coordinates 
		gear.position = gear_target_position
		for child in gear.get_children():
			if child is CollisionShape3D:
				child.disabled = false
		gear.held = false
		gear.is_in_socket = true 
		
		# Set rotation BEFORE freezing
		gear.rotation_degrees = gear_rotation
		gear.global_rotation_degrees = gear_rotation
		gear.freeze = true
		gear.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		
		has_gear = true
		gear_object = gear
		
		if has_node("PlacementSound"):
			$PlacementSound.play()
		
		$"../TickSFX".play(tick_sfx_offset)
		# Resume timer from where it left off
		$WaitTimer.start(time_remaining)
		return
	if has_gear:
		print("Trying to get gear")
		# Find the gear
		gear_object.is_in_socket = false
		gear_object.freeze = false
		has_gear = false
		
		# save remaining time n stop timer
		if has_node("WaitTimer") and $WaitTimer.time_left > 0:
			time_remaining = $WaitTimer.time_left
			$WaitTimer.stop()
		
		# let player pick  up
		if gear_object.can_pickup():
			Player.instance.pick_up_object(gear_object)
		
		gear_object = null
		tick_sfx_offset = $"../TickSFX".get_playback_position()
		$"../TickSFX".stop()
		
		return

func _on_wait_complete():
	if has_gear:
		if has_node("ChimeSound"):
			$ChimeSound.play()
		
		# Open the glass door
		var glass_door = get_parent().get_node("GlassPivot")
		if glass_door and glass_door.has_method("open_door"):
			glass_door.open_door()
		
		# Unlock the key
		print("Looking for key...")
		var key = get_parent().get_node("Key")
		print("Key found: ", key != null)
		if key:
			print("Key has unlock_key method: ", key.has_method("unlock_key"))
			if key.has_method("unlock_key"):
				key.unlock_key()
		else:
			print("ERROR: Could not find BlueKey!")
		
		time_remaining = SECONDS_TO_CHIME
