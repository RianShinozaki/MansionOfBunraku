class_name Cat

extends CharacterBody3D

var door_is_open: bool = false

var move_angle = 0
var held := false
var held_by_yono := false

@export var gravity: float
@export var move_speed: float

func can_pickup() -> bool:
	if held or held_by_yono:
		return false
	return true
	
func on_pickup(_bypass: bool = false):
	if not can_pickup() and not _bypass: return
	held = true
	# Disable all collisions
	$CollisionShape3D.disabled = true
	# POSITION IN FRONT OF CAMERA 
	position = Vector3(0.3, -0.2, -0.5)  
	rotation_degrees = Vector3(0, 0, 0)
	scale = Vector3(1, 1, 1) 
	$Sprite3D.flip_h = false
	$Sprite3D/AnimationPlayer.play("hold")

func on_dropped():
	$CollisionShape3D.disabled = false
	held = false
	rotation_degrees = Vector3(0, 0, 0)
	$Sprite3D/AnimationPlayer.play("run")

func _physics_process(_delta: float) -> void:
	if held and not held_by_yono:
		position = Vector3(0.2, -0.07, -0.2)  
		rotation_degrees = Vector3(0, 0, 0)
		scale = Vector3(1, 1, 1)
	if held_by_yono:
		position = Vector3(0, -0.1, 0.1)  
		rotation_degrees = Vector3(0, 0, 0)
		scale = Vector3(1, 1, 1)
	if not held:
		if is_on_floor():
			var _dir = Vector2.from_angle(move_angle)
			velocity.x = _dir.x * move_speed
			velocity.z = _dir.y * move_speed
			velocity.y = 0
			var _player_forward = Player.instance.get_node("Camera3D").global_basis * Vector3.FORWARD
			var _ang = velocity.signed_angle_to(_player_forward, Vector3.UP)
			$Sprite3D.flip_h = _ang < 0
			if is_on_wall():
				velocity = velocity.bounce(get_wall_normal())
				move_angle = Vector2(velocity.x, velocity.z).angle()
				move_angle += randf_range(-PI/4, PI/4)
		else:
			velocity.x = 0
			velocity.z = 0
			velocity.y += _delta * gravity
			
		move_and_slide()

func adopted() -> void:
	held = true
	held_by_yono = true
	$Sprite3D/AnimationPlayer.play("sleep")
	$CollisionShape3D.disabled = true
	position = Vector3(0.3, -0.2, -0.5)  
	rotation_degrees = Vector3(0, 0, 0)
	scale = Vector3(1, 1, 1) 
	if Player.instance.held_object is Cat:
		Player.instance.held_object = null
	remove_from_group("Cat")
