extends ColorRect

@export var fire_material: ShaderMaterial

var counter = 0
var meltdown_in_progress: bool = false
var meltdown_length: float = 5

func _ready() -> void:
	meltdown_length = GameManager.instance.meltdown_time/2
	
func _process(delta: float) -> void:
	if meltdown_in_progress:
		counter = move_toward(counter, meltdown_length, delta)
		fire_material.set_shader_parameter("fire_alpha", 1)
		set_fire_progress(counter/meltdown_length)
	
func begin_meltdown():
	await get_tree().create_timer(meltdown_length).timeout
	meltdown_in_progress = true

func set_fire_progress(t: float):
	fire_material.set_shader_parameter("fire_aperture", 3 - t*3)
	fire_material.set_shader_parameter("tip_color", Color.LIGHT_PINK.lerp(Color.WHITE, t))
