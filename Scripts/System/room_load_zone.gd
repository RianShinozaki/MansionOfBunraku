extends Area3D

@export var room_path: String
@export var room_path_present: String  # Path for present timeline
@export var room_path_past: String     # Path for past timeline
@export var room_object: Room
@export var entered: bool
func _ready() -> void:
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

func _process(_delta: float) -> void:
	if GameManager.instance.debug_load_all: entered = true
	
	# Determine which room path to use based on time state
	var active_room_path = get_active_room_path()
	
	if entered and not is_instance_valid(room_object):
		if ResourceLoader.load_threaded_get_status(active_room_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			print("Beginning load of " + active_room_path)
			ResourceLoader.load_threaded_request(active_room_path)
		if ResourceLoader.load_threaded_get_status(active_room_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			var _res: PackedScene = ResourceLoader.load_threaded_get(active_room_path)
			room_object = _res.instantiate()
			add_child(room_object)
			room_object.global_position = room_object.world_offset
			print("Finished loading " + active_room_path)
	if !entered and is_instance_valid(room_object):
		room_object.call_deferred("queue_free")

## Get the active room path based on time state (if dual paths are configured)
func get_active_room_path() -> String:
	# If dual paths are configured, use them based on time state
	if room_path_present != "" and room_path_past != "":
		if GameManager.instance.is_past_time:
			return room_path_past
		else:
			return room_path_present
	# Otherwise, use the default single room_path
	return room_path

## Force reload the room (useful for time travel toggle)
func reload_room() -> void:
	# Unload current room if it exists
	if is_instance_valid(room_object):
		room_object.queue_free()
		room_object = null
	
	# The next _process call will load the correct room based on time state
	print("Room reload triggered for " + name)
		
func on_body_entered(_body: Node3D):
	print("Entered " + name)
	entered = true
	
func on_body_exited(_body: Node3D):
	print("Exited " + name)
	entered = false
