extends Area3D

@export var room_path: String
@export var room_object: Room
@export var entered: bool
func _ready() -> void:
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

func _process(_delta: float) -> void:
	if GameManager.instance.debug_load_all: entered = true
	
	if entered and not is_instance_valid(room_object):
		if ResourceLoader.load_threaded_get_status(room_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			print("Beginning load of " + room_path)
			ResourceLoader.load_threaded_request(room_path)
		if ResourceLoader.load_threaded_get_status(room_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			var _res: PackedScene = ResourceLoader.load_threaded_get(room_path)
			room_object = _res.instantiate()
			add_child(room_object)
			room_object.global_position = room_object.world_offset
			print("Finished loading " + room_path)
	if !entered and is_instance_valid(room_object):
		room_object.call_deferred("queue_free")
		
func on_body_entered(_body: Node3D):
	print("Entered " + name)
	entered = true
	
func on_body_exited(_body: Node3D):
	print("Exited " + name)
	entered = false
	
