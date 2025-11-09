extends Node3D

# Cabinet controller that manages the relationship between the lock and door
# Listens for the lock's unlock signal and enables door interaction

var lock: Node3D = null
var door = null

func _ready():
	# Find the door (it's a child of this node)
	door = get_node_or_null("DoorPivot/Door/DoorBody")
	
	# Find the lock (it's a sibling - child of our parent)
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "CombinationLock" or child.is_in_group("Lock"):
				lock = child
				break
	
	# Connect to the lock's unlocked signal
	if lock and lock.has_signal("unlocked"):
		lock.unlocked.connect(_on_lock_unlocked)
	else:
		push_warning("ShamisenCabinet: Lock node not found or doesn't have 'unlocked' signal")
	
	# Verify door reference
	if not door:
		push_warning("ShamisenCabinet: Door node not found")

func _on_lock_unlocked():
	# When the lock is unlocked, unlock the door
	if door and door.has_method("unlock"):
		door.unlock()
