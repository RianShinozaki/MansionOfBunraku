extends Node3D

@export var move_speed: float
@export var target: Node3D
@onready var raycasters: Node3D = $Raycasters

@onready var f_cast: RayCast3D = $Raycasters/ForwardCast
@onready var r_cast: RayCast3D = $Raycasters/RightCast
@onready var l_cast: RayCast3D = $Raycasters/LeftCast
@onready var nav: NavigationAgent3D = $NavigationAgent3D

var direction_vector: Vector2 = Vector2(0, 1)

@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
var physics_delta: float
var orig_y: float

func _ready() -> void:
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
	
func make_turning_decision():
	var _move_vector: Vector2 = move_speed * direction_vector
	
	if r_cast.is_colliding() and l_cast.is_colliding():
		direction_vector = -direction_vector
	else:
		var _direction_vector_1: Vector2 = direction_vector.rotated( deg_to_rad( 90 ))
		var _direction_vector_2: Vector2 = direction_vector.rotated( deg_to_rad(-90))
		var _vec3_to_target: Vector3 = target.global_position - global_position
		var _vec2_to_target: Vector2 = Vector2(_vec3_to_target.x, _vec3_to_target.z)
		var _try_dir_1 = abs(_direction_vector_1.angle_to(_vec2_to_target))
		var _try_dir_2 = abs(_direction_vector_2.angle_to(_vec2_to_target))
		if _try_dir_1 < _try_dir_2:
			direction_vector = _direction_vector_1
		else:
			direction_vector = _direction_vector_2
	
	raycasters.global_rotation.y = -direction_vector.angle()
	
