###Handles the logic behind switching the Bunraku as well as initiating jumpscares
class_name BunrakuManager

extends Node3D

enum {YONO, YOROI}

@export var bunraku: Bunraku
@export var can_jumpscare_command: bool

func _ready() -> void:
	bunraku.deactivate(false)
	visible = false
	
func activate_bunraku():
	bunraku.activate()
	visible = true

func deactivate_bunraku():
	bunraku.deactivate(true)
	visible = false
	
func _process(_delta: float) -> void:
	if can_jumpscare_command:
		if Input.is_key_pressed(KEY_0):
			jumpscare()

func jumpscare():
	
	InspectionManager.exit_inspect()
	await get_tree().process_frame
	
	visible = true
	bunraku.visible = true
	bunraku.anger_level = 1
	var lights: Array = get_tree().get_nodes_in_group("Light")
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	$"../../../../../WorldLighting/UnderLight".light_energy = 1.5
	Player.instance.active = false
	Player.instance.get_node("CanvasLayer").visible = false
	$JumpscareSFX.volume_linear = 2
	$JumpscareSFX.play()
	$JumpscareSFX.pitch_scale = 1.4
	Player.instance.look_at( global_position, Vector3.UP, true)
	Player.instance.rotate_y(PI)
	Player.instance.rotation.x = 0
	Player.instance.get_node("Camera3D").rotation_degrees = Vector3(0.2, 0, 0)
	global_position = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.4
	global_position.y = 0.355
	Player.instance.get_node("Camera3D").fov = 100
	Player.instance.get_node("Camera3D").start_shaking()
	get_tree().create_tween().tween_property(Player.instance.get_node("Camera3D"), "fov", 120, 1.4)
	
	print("HELLO")
	var _to = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.2
	@warning_ignore("standalone_expression")
	get_tree().create_tween().tween_property(self, "global_position", Vector3(_to.x, 0.35, _to.z) , 0.2).finished
	await get_tree().create_timer(0.2).timeout
	
	_to = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.1
	@warning_ignore("standalone_expression")
	get_tree().create_tween().tween_property(self, "global_position", Vector3(_to.x, 0.35, _to.z) , 1.5).finished
	await get_tree().create_timer(2).timeout
	
	print("WHAT")
	get_tree().change_scene_to_file("res://Maps/MeltdownCutscene.tscn")
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
