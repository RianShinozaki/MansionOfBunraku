class_name Bunraku

extends AnimatableBody3D

@export var anger_headshake_factor: float
@export var anger_bodyshake_factor: float
@export var anger_decrease_delta: float
@export var anger_decrease_max: float

@export_range(0,1) var anger_level: float
@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

var active: bool
var mat: StandardMaterial3D
var update_lock = false

signal appearance_update_end

func _ready() -> void:
	mat = head_sprite.material_override as StandardMaterial3D
	mat.emission_energy_multiplier = 0
	
	
func _physics_process(_delta: float) -> void:
	
	#anger_level = 0
	
	body_sprite.offset = Vector2.ZERO
	head_sprite.rotation.z = 0
	if anger_level > 0:
		var _x = randf_range(-anger_level, anger_level)
		head_sprite.rotation.z = -_x * anger_headshake_factor
		body_sprite.offset = Vector2(_x, 0) * anger_bodyshake_factor
	
	anger_decrease_delta += _delta
	anger_decrease_delta = clamp(anger_decrease_delta, -_delta*2, anger_decrease_max)
	anger_level -= anger_decrease_delta * _delta
	anger_level = clamp(anger_level, 0, 1)
	
	mat.emission_energy_multiplier = 0
	
	if anger_level > 0:
		if not $Rattle.playing:
			$Rattle.playing = true
			$Breathe.playing = true
			$Feedback.playing = true
		$Rattle.volume_db = -(1-anger_level)*30 + 10
		$Breathe.volume_db = -(1-anger_level)*30 + 10
		$Feedback.volume_db = -(1-anger_level)*40
		$Rattle.pitch_scale = 1+anger_level*2
		
		if not update_lock:
			mat.emission_energy_multiplier = anger_level
	else:
		$Rattle.playing = false
		$Breathe.playing = false
		$Feedback.playing = false
	
	if not active: return
	
	if anger_level == 1:
		active = false
		get_parent().jumpscare()
	
	if anger_level <= 0.33  and $Body/Head.frame != 0:
		appearance_update()
		await appearance_update_end
		$Body/NegativeLight.energy_median = 0
		$Body/Head.frame = 0
	if anger_level > 0.33 and anger_level <= 0.66 and $Body/Head.frame != 2:
		appearance_update()
		await appearance_update_end
		$Body/NegativeLight.energy_median = 4
		$Body/Head.frame = 2
	if anger_level > 0.66 and $Body/Head.frame != 3:
		appearance_update()
		await appearance_update_end
		$Body/NegativeLight.energy_median = 12
		$Body/Head.frame = 3

func appearance_update():
	if update_lock: return
	update_lock = true
	var lights: Array = get_tree().get_nodes_in_group("Light")
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	await get_tree().create_timer(0.2).timeout
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 1.5, 0.2)

	await get_tree().create_timer(0.1).timeout
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	await get_tree().create_timer(0.3).timeout
	emit_signal("appearance_update_end")
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 1.5, 0.2)
	update_lock = false

func deactivate():
	appearance_update()
	active = false
	visible = false

func activate():
	active = true
	visible = true
