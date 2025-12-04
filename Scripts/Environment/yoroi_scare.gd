extends Node3D

func _ready() -> void:
	$DoorOpenTrigger.body_entered.connect(on_body_entered)
	
func on_body_entered(_body: Node3D):
	visible = true
	
	$"../Doors".force_open()
	$"../Doors2".force_open()
	GameManager.instance.timer = -1000
	$DoorOpenTrigger/CollisionShape3D.set_deferred("disabled", true)
	GameManager.instance.get_node("WorldEnvironment").environment.ambient_light_energy = 0.4
	$Rattle.play()
	$Breathe.play()
	$Feedback.play()
	create_tween().tween_property(GameManager.instance.get_node("WorldEnvironment").environment, "fog_density", 0.5, 2)
	
	await get_tree().create_timer(2).timeout
	
	var lights: Array = get_tree().get_nodes_in_group("Light")
	for _light in lights:
		get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	$"../../../../../WorldLighting/UnderLight".light_energy = 1.5
	Player.instance.active = false
	Player.instance.get_node("CanvasLayer").visible = false
	$Jumpscare.volume_linear = 2
	$Jumpscare.pitch_scale = 1.4
	$Jumpscare.play()
	$Body/Head.frame = 3
	Player.instance.look_at( global_position, Vector3.UP, true)
	Player.instance.rotate_y(PI)
	Player.instance.rotation.x = 0
	Player.instance.get_node("Camera3D").rotation_degrees = Vector3(0.2, 0, 0)
	$Body.global_position = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.4
	$Body.global_position.y = 0.355
	Player.instance.get_node("Camera3D").fov = 100
	Player.instance.get_node("Camera3D").start_shaking()
	get_tree().create_tween().tween_property(Player.instance.get_node("Camera3D"), "fov", 120, 1.4)
	
	print("HELLO")
	var _to = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.2
	@warning_ignore("standalone_expression")
	get_tree().create_tween().tween_property($Body, "global_position", Vector3(_to.x, 0.35, _to.z) , 0.2).finished
	await get_tree().create_timer(0.2).timeout
	
	_to = Player.instance.global_position + Player.instance.global_basis * Vector3.FORWARD * 0.07
	@warning_ignore("standalone_expression")
	get_tree().create_tween().tween_property($Body, "global_position", Vector3(_to.x, 0.35, _to.z) , 2).finished
	await get_tree().create_timer(2).timeout
	
	print("WHAT")
	get_tree().change_scene_to_file("res://Maps/MeltdownCutscene.tscn")
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
