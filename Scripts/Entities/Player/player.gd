class_name Player

extends CharacterBody3D

##How fast the player can move
@export var move_speed: float
##How quickly the player turns
@export var mouse_sensitivity: float
##How quickly the player reachs top speed
@export var acceleration: float
##How quickly the player returns to stillness
@export var deceleration: float
##How quickly the player falls
@export var gravity: float
##How far the player can click on things
@export var interaction_range: float = 3.5

@export var circleUI: Texture2D
@export var crossUI: Texture2D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D

var walk_velocity: Vector3
var air_velocity: float
var held_object: Node3D = null
var walk_sample_pos: float = 0
var active: bool = true

var holding_shamisen: bool = false
var toggle_shamisen: bool = false

static var instance: Player

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# RAYCAST SETUP 
	raycast.target_position = Vector3(0, 0, -interaction_range)
	instance = self
	
func _physics_process(_delta: float) -> void:
	if not active: return
	
	#Sum up all movement vectors
	velocity = get_walk_velocity(_delta) + Vector3.UP * get_air_velocity(_delta)
	move_and_slide()
	
	#Set the crosshair sprite depending on whether or not the raycast is touching something
	$CanvasLayer/TextureRect.texture = crossUI
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and (collider.is_in_group("Interactable") or collider.is_in_group("Item")):
			$CanvasLayer/TextureRect.texture = circleUI
	
	# Adjust Shamisen Position
	if (toggle_shamisen):
		$Camera3D/Shamisen.global_transform.origin = $Camera3D.global_transform.origin + $Camera3D.global_transform.basis * Vector3.FORWARD * interaction_range

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	
	#Camera rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate(Vector3(0, -1, 0), mouse_sensitivity * event.screen_relative.x)
		$Camera3D.rotate(Vector3(-1, 0, 0), mouse_sensitivity * event.screen_relative.y)
		$Camera3D.rotation_degrees.x = clamp($Camera3D.rotation_degrees.x, -90, 90)
	
	if event is InputEventKey:
		#Allow the game to free the cursor when pressing escape
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
		# Drop held object
		if event.pressed and event.keycode == KEY_Q:
			drop_held_object()
			
		# Toggle Shamisen Visibility
		if event.pressed and event.keycode == KEY_E and holding_shamisen:
			toggle_shamisen = not toggle_shamisen
			$Camera3D/Shamisen.visible = toggle_shamisen
			if held_object:
				held_object.visible = not toggle_shamisen
		
		# Play Shamisen string audio
		if toggle_shamisen:
			if event.pressed and event.keycode == KEY_1:
				$Camera3D/Shamisen.append_note(1)
			if event.pressed and event.keycode == KEY_2:
				$Camera3D/Shamisen.append_note(2)
			if event.pressed and event.keycode == KEY_3:
				$Camera3D/Shamisen.append_note(3)
			
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			click_object()

func click_object():
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Check if object is pickupable
		if collider and collider.is_in_group("Interactable"):
			interact_object(collider)
			return  
		elif collider and collider.is_in_group("Item"):
			pick_up_object(collider)
			return  

	#raycast is not hitting anything
	if held_object:
		drop_held_object()
		return

func pick_up_object(object: Node3D):
	#Drop current object instead of picking up another
	if held_object:
		drop_held_object()
		return
	
	if object.is_in_group("Shamisen"):
		holding_shamisen = true
		toggle_shamisen = true
		$Camera3D/Shamisen.visible = toggle_shamisen
		object.queue_free()
		return
	
	#Check if the object can be picked up
	var success = object.can_pickup()
	if not success: return
	
	#Call object's specific on_pickup function
	object.on_pickup()
	
	# Attach to camera 
	var object_parent = object.get_parent()
	object_parent.remove_child(object)
	$Camera3D.add_child(object)
	held_object = object

func interact_object(object: Node3D):
	#Check if the object can be interacted with, and then interact
	if object.can_interact() and not toggle_shamisen:
		object.on_interact()
	
func drop_held_object():
	if not held_object:
		return
	
	# Remove from camera
	$Camera3D.remove_child(held_object)
	# Add back to scene
	get_tree().root.get_child(0).add_child(held_object)
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		# Move your object to the collision_point
		held_object.global_transform.origin = collision_point
		held_object.global_transform.origin = held_object.global_transform.origin.move_toward(global_transform.origin, 0.2)
	# Position in front of player
	else:
		held_object.global_transform.origin = $Camera3D.global_transform.origin + $Camera3D.global_transform.basis * Vector3.FORWARD * interaction_range
	held_object.on_dropped()
	held_object = null

func get_walk_velocity(_delta: float):
	#Do some matrix calculations to turn input into world movement
	walk_velocity = walk_velocity.move_toward(Vector3.ZERO, deceleration * _delta)
	var _input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	var _forward: Vector3 = global_transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)
	var _move_dir: Vector3 = _forward.normalized()
	walk_velocity = walk_velocity.move_toward(_move_dir * move_speed * _input_dir.length(), acceleration * _delta)
	
	#Play walking sfx when on the move
	if !$WalkingSFX.playing and _input_dir != Vector2.ZERO:
		$WalkingSFX.play(walk_sample_pos)
	if $WalkingSFX.playing and _input_dir == Vector2.ZERO:
		walk_sample_pos = $WalkingSFX.get_playback_position()
		$WalkingSFX.stop()
	return walk_velocity

func get_air_velocity(_delta: float):
	#Fall. This is like never used though. 
	if not is_on_floor():
		air_velocity += gravity * _delta
	return air_velocity

#I don't know why this is its own function but I think it's funny so it gets to live
func play_eating_sfx():
	$EatingSFX.play()
