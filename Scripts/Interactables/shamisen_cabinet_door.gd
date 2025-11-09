extends StaticBody3D

# Glass cabinet door that swings open/closed

var anim_lock: bool = false
var open: bool = false
var is_locked: bool = true  # Door starts locked
var has_opened: bool = false  # Track if door has ever been opened
var pending_open: bool = false  # Set when unlock is called during inspection mode
var shamisen: Node3D = null  # Reference to the shamisen
@export var dir: int = 1  # 1 for right pivot (clockwise), -1 for left pivot (counterclockwise)

func _ready():
	# Remove door from Interactable group since it opens automatically
	remove_from_group("Interactable")
	
	# Find shamisen (it's a sibling - both are children of shamisenLocked)
	# Path: DoorBody -> Door -> DoorPivot -> ShamisenCabinet -> ShamisenLocked
	var shamisen_locked = get_parent().get_parent().get_parent().get_parent()
	if shamisen_locked:
		for child in shamisen_locked.get_children():
			if child.is_in_group("Shamisen") or child.name == "Shamisen":
				shamisen = child
				# Disable shamisen collision so it can't be picked up through the door
				shamisen.collision_layer = 0
				print("Shamisen found and collision disabled")
				break
		if not shamisen:
			push_warning("ShamisenCabinetDoor: Could not find Shamisen node")



func unlock() -> void:
	is_locked = false
	
	# Check if we're in PLAY mode
	if InspectionManager.current_mode == InspectionManager.Mode.PLAY:
		# Open immediately
		_open_door()
	else:
		# Defer opening until we exit inspection mode
		pending_open = true

func _process(_delta):
	# Check if we need to open the door after exiting inspection mode
	if pending_open and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
		pending_open = false
		_open_door()

func _open_door():
	if anim_lock or has_opened:
		return
	
	anim_lock = true
	var pivot = get_parent().get_parent()  # DoorPivot node
	
	# Open door
	if has_node("../../../OpenSFX"):
		$"../../../OpenSFX".play()
	await get_tree().create_tween().tween_property(pivot, "rotation_degrees", Vector3(0, dir * 100, 0), 0.25).finished
	open = true
	has_opened = true
	
	# Enable shamisen collision so it can be picked up
	if shamisen:
		shamisen.collision_layer = 4  # Layer 3
	
	anim_lock = false
