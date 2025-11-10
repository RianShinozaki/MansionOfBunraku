class_name GameManager

extends Node3D

static var instance: GameManager 

@export var cycle_time: float
@export var meltdown_time: float

var timer: float

var meltdown_begun: bool


func _enter_tree():
	instance = self

func _process(delta: float) -> void:
	timer += delta
	if timer >= cycle_time and not meltdown_begun:
		meltdown_begun = true
		var _fire_nodes = get_tree().get_nodes_in_group("FireFX")
		for _node in _fire_nodes:
			_node.begin_meltdown()
	if timer >= cycle_time + meltdown_time:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://Maps/MeltdownCutscene.tscn")
