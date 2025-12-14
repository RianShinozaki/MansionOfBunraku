extends BunrakuManager

@export var body_offset: Vector3
@export var time_between_turns: float
@export var looking_forward: bool

@export var normal_light_color: Color
@export var evil_light_color: Color

var turn_time_counter: float
var physics_delta: float
var orig_y: float
var active: bool = false
var jumpscaring: bool = false

signal movement_ready

func _ready() -> void:
	orig_y = global_position.y
	active = true
	
	looking_forward = false
	$Yoroi.visible = false
	$Yoroi.active = false
	$YoroiBackside.visible = true
	$"../../Objects/Chandelier/OmniLight3D".light_color = normal_light_color
	

func _physics_process(_delta):
	
	if not active: return
	$Yoroi.position = Vector3(0,0,0)
	
	turn_time_counter += _delta
	if turn_time_counter >= time_between_turns:
		turn_time_counter = 0
		light_flicker()
		await movement_ready
		if looking_forward:
			looking_forward = false
			$Yoroi.visible = false
			$Yoroi.active = false
			$YoroiBackside.visible = true
			$"../../Objects/Chandelier/OmniLight3D".light_color = normal_light_color
			
		else:
			looking_forward = true
			$Yoroi.visible = true
			$Yoroi.active = true
			$YoroiBackside.visible = false
			$"../../Objects/Chandelier/OmniLight3D".light_color = evil_light_color
			
	
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
	$Yoroi.top_level = false
	$Yoroi.global_transform.origin = global_transform.origin + body_offset
	super.jumpscare()
