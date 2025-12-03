extends Area3D

@export var active_fog_level: float
@export var inactive_fog_level: float
@export var environment: WorldEnvironment

var entered: bool


func _ready() -> void:
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

func _process(_delta: float) -> void:
	if GameManager.instance.meltdown_begun: return
	
	var _density = environment.environment.fog_density
	if entered:
		environment.environment.fog_density = move_toward(_density, active_fog_level, _delta * 0.1)
	else:
		environment.environment.fog_density = move_toward(_density, inactive_fog_level, _delta * 0.1)

func on_body_entered(_body: Node3D):
	print("Entered " + name)
	entered = true
	
func on_body_exited(_body: Node3D):
	print("Exited " + name)
	entered = false
	
