extends Node3D

@export var move_speed: float
@export var target: Node3D

@onready var nav: NavigationAgent3D = $NavigationAgent3D

var direction_vector: Vector2 = Vector2(0, 1)

@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
var physics_delta: float
var orig_y: float

func _ready() -> void:
	target = Player.instance
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	orig_y = global_position.y

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

func _physics_process(delta):
	set_movement_target(target.global_position)
	# Save the delta for use in _on_velocity_computed.
	physics_delta = delta
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if navigation_agent.is_navigation_finished():
		return

	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * move_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	
	global_position = global_position.move_toward(global_position + safe_velocity, physics_delta * move_speed)
	
