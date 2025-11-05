###Handles the logic behind switching the Bunraku as well as initiating jumpscares

extends Node3D

enum {YONO, YOROI}

@export var bunraku: Bunraku

func activate_bunraku():
	bunraku.activate()

func jumpscare():
	$"../Environment/DirectionalLight3D".light_energy = 0.2
	var lights: Array = get_tree().get_nodes_in_group("Light")
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	Player.instance.active = false
	Player.instance.get_node("CanvasLayer").visible = false
	$JumpscareSFX.play()
	Player.instance.look_at( global_position, Vector3.UP, true)
	Player.instance.rotate_y(PI)
	Player.instance.get_node("Camera3D").rotation_degrees = Vector3(0.2, 0, 0)
	global_position = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.3
	global_position.y = -0.2
	var _to = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.15
	await get_tree().create_tween().tween_property(self, "global_position", Vector3(_to.x, -0.2, _to.z) , 1.4).finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Maps/Menu/GameOverScreen.tscn")
