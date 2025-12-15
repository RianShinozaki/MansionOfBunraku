

extends Node

@export var inside_environment: Environment
@export var outside_environment: Environment
@export var environment_node: WorldEnvironment
@onready var door_reference: Node3D = $"../Objects/GateArea/PaperDoors/PaperDoor"

func _ready() -> void:
	environment_node = GameManager.instance.get_node("WorldEnvironment")

func force_outside_environment():
	environment_node.environment = outside_environment

func force_inside_environment():
	environment_node.environment = inside_environment
	
func set_environment_conditional():
	if Player.instance.global_position.z > door_reference.global_position.z:
		environment_node.environment = outside_environment
	else:
		environment_node.environment = inside_environment
