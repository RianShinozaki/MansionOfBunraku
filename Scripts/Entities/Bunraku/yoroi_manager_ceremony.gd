extends BunrakuManager

@export var move_speed: float
@export var target: Node3D
@export var body_update_delay: float
@export var body_offset: Vector3

var direction_vector: Vector2 = Vector2(0, 1)

var physics_delta: float
var orig_y: float
var navigating: bool = false
var active: bool = false
var body_update_timer: float = 0
var jumpscaring: bool = false

signal movement_ready

var time_since_targeted_player: float = 0

func _ready() -> void:
	orig_y = global_position.y
	$Yoroi.activate()
	active = true

func _physics_process(_delta):
	
	if not active: return
	$Yoroi.position = Vector3(0,0,0)
	
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
		
func jumpscare():
	jumpscaring = true
	navigating = false
	$Yoroi.top_level = false
	$Yoroi.global_transform.origin = global_transform.origin + body_offset
	super.jumpscare()
