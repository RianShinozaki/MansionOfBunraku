extends Camera3D

var shaking: bool

func _physics_process(_delta: float) -> void:
	if shaking:
		position.x = randf_range(-0.01, 0.01)
		position.y = randf_range(-0.01, 0.01)
		
func start_shaking():
	shaking = true
