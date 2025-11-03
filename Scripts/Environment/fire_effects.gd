extends Node3D

@export var meltdown_length: float = 5
@export var fire_material: ShaderMaterial
@export var fire_individual_material: ShaderMaterial

var counter = 0
var meltdown_in_progress: bool = false
func _ready() -> void:
	meltdown_in_progress = true

func _process(delta: float) -> void:
	if meltdown_in_progress:
		counter = move_toward(counter, meltdown_length, delta)
		set_fire_progress(counter/meltdown_length)
	
func begin_meltdown():
	create_tween().tween_method(set_fire_progress, 0, 1, meltdown_length)

func set_fire_progress(t: float):
	fire_material.set_shader_parameter("fire_alpha", t / 2)
	fire_material.set_shader_parameter("fire_aperture", 1.2 - t)
	fire_individual_material.set_shader_parameter("fire_alpha", t / 2)
	$Firelight1.light_energy = t*1.5
	$Firelight2.light_energy = t*16
