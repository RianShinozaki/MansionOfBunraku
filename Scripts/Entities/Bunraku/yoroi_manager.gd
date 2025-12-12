extends BunrakuManager

@export var move_speed: float
@export var target: Node3D
@export var body_update_delay: float
@export var body_offset: Vector3

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var target_nodes: Node3D = $"../YoroiTargetNodes"

var direction_vector: Vector2 = Vector2(0, 1)

var physics_delta: float
var orig_y: float
var navigating: bool = false
var active: bool = false
var body_update_timer: float = 0
var jumpscaring: bool = false

signal movement_ready

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	orig_y = global_position.y
	get_random_target()
	$Yoroi.deactivate(false)
	$"../../Area3D".body_entered.connect(on_body_entered)
	$"../../Area3D".body_exited.connect(on_body_exited)
	
func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

const VALID_NODE_DISTANCE = 5
func get_random_target(_delay: float = 0):
	var _target_options: Array[Node3D]
	_target_options.append(Player.instance)
	
	for _node: Node3D in target_nodes.get_children():
		if _node != target and _node.global_position.distance_to(Player.instance.global_position) < VALID_NODE_DISTANCE:
			_target_options.append(_node)
	if not _delay == 0:
		await get_tree().create_timer(_delay).timeout
	
	if not jumpscaring:
		var _rand = randi_range(0, _target_options.size()-1)
		target = _target_options[_rand]
		navigating = true
	
func _physics_process(delta):
	if not navigating or not active: return
	
	body_update_timer += delta
	if body_update_timer >= body_update_delay:
		body_update_timer = 0
		light_flicker()
		await movement_ready
		$Yoroi.global_position = global_position + body_offset
	
	set_movement_target(target.global_position)
	# Save the delta for use in _on_velocity_computed.
	physics_delta = delta
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if navigation_agent.is_navigation_finished():
		get_random_target(2)
		navigating = false

	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * move_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)
	
func light_flicker():
	var _distance_to_player = global_position.distance_to(Player.instance.global_position)
	var _do_light_flicker: bool = false
	if _distance_to_player < 4.5:
		_do_light_flicker = true
		
	if _do_light_flicker:
		var lights: Array = get_tree().get_nodes_in_group("Light")
		for _light in lights:
			get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	get_tree().create_tween().tween_property($Yoroi/Body/BlackFade, "modulate", Color.BLACK, 0.05)
	
	await get_tree().create_timer(0.15).timeout
	emit_signal("movement_ready")
	
	if _do_light_flicker:
		var lights: Array = get_tree().get_nodes_in_group("Light")
		for _light in lights:
			get_tree().create_tween().tween_property(_light, "energy_median", 1.5, 0.2)
	
	#if _distance_to_player < 3:
	get_tree().create_tween().tween_property($Yoroi/Body/BlackFade, "modulate", Color(0, 0, 0, 0), 0.2)
		
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	global_position = global_position.move_toward(global_position + safe_velocity, physics_delta * move_speed)

func jumpscare():
	jumpscaring = true
	navigating = false
	$Yoroi.top_level = false
	$Yoroi.global_transform.origin = global_transform.origin + body_offset
	super.jumpscare()

func on_body_entered(_node: Node3D):
	print("player entered")
	navigating = true
	active = true
	$Yoroi.activate()
	
func on_body_exited(_node: Node3D):
	navigating = false
	active = false
	$Yoroi.deactivate(false)
