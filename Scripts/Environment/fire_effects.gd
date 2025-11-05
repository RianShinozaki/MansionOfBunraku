extends Node3D

@export var fire_material: ShaderMaterial
@export var fire_individual_material: ShaderMaterial
@export var environment: WorldEnvironment

var counter = 0
var meltdown_in_progress: bool = false
var meltdown_length: float = 5

func _ready() -> void:
	meltdown_length = GameManager.instance.meltdown_time
	
func _process(delta: float) -> void:
	if meltdown_in_progress:
		counter = move_toward(counter, meltdown_length, delta)
		set_fire_progress(counter/meltdown_length)
	
func begin_meltdown():
	meltdown_in_progress = true
	$AudioStreamPlayer.play()
	$AudioStreamPlayer.volume_linear = 0
	create_tween().tween_property($AudioStreamPlayer, "volume_linear", 1.5, meltdown_length)

func set_fire_progress(t: float):
	fire_material.set_shader_parameter("fire_alpha", t / 2)
	fire_material.set_shader_parameter("fire_aperture", 1.2 - t)
	fire_individual_material.set_shader_parameter("fire_alpha", t / 2)
	$Firelight1.light_energy = t*1.5
	$Firelight2.light_energy = t*16
	environment.environment.fog_density = t/2
	environment.environment.fog_light_color.r = t/5
