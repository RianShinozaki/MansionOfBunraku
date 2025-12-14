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

@export var player_dialogues: DialogueData

@export var circleUI: Texture2D
@export var crossUI: Texture2D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@export var do_intro: bool = false

var walk_velocity: Vector3
var air_velocity: float
var held_object: Node3D = null
var walk_sample_pos: float = 0
var active: bool = true
var statue: bool = false
var statue_hp: int = 0
var statue_shaking: bool = false
var push_direction: bool = false

# Push cooldown tracking to prevent sticky collisions
var push_cooldowns: Dictionary = {}  # Maps RigidBody3D to cooldown timer
const PUSH_COOLDOWN_TIME: float = 0.3  # Increased from 0.2 - gives tables time to move away

@export var holding_shamisen: bool = false
var toggle_shamisen: bool = false
var shamisen_wait_time: float
@export var shamisen_wait_memory_time: float # 3.0

signal played_note_signal(note: int)
signal fade_complete

static var instance: Player
static var song_of_stillness_acquired: bool = false
static var song_of_time_travel_acquired: bool = false

# Song Sequences - centralized definitions
const SONG_OF_TIME_TRAVEL: Array[int] = [1, 2, 2, 1]
const SONG_OF_MATRIMONY: Array[int] = [1, 1, 2, 1]
const SONG_OF_STILLNESS: Array[int] = [3, 3, 3, 1]

func _ready() -> void:
	# RAYCAST SETUP 
	#Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	raycast.target_position = Vector3(0, 0, -interaction_range)
	instance = self
	fade_from_white()
	
	# Restore song visibility if previously acquired
	if song_of_time_travel_acquired:
		var time_travel_ui = get_node_or_null("CanvasLayer/Music Memory/SongOfTimeTravel")
		if time_travel_ui:
			time_travel_ui.visible = true
			time_travel_ui.modulate.a = 1.0
			print("Player: Restored SongOfTimeTravel UI visibility")
	
	if song_of_stillness_acquired:
		var stillness_ui = get_node_or_null("CanvasLayer/Music Memory/SongOfStillness")
		if stillness_ui:
			stillness_ui.visible = true
			stillness_ui.modulate.a = 1.0
			print("Player: Restored SongOfStillness UI visibility")
	
	if do_intro:
		await get_tree().create_timer(1).timeout
		run_dialogue("first_cycle_begin")
	else:
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		call_deferred("_deferred_mouse_capture")
	
	$"CanvasLayer/ThinkingBar/TextureProgressBar".max_value = shamisen_wait_memory_time

func _deferred_mouse_capture():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _physics_process(_delta: float) -> void:
	if statue:
		if statue_hp <= 0: un_statuefy()
		else:
			var _input_dir: Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
			if not statue_shaking:
				if _input_dir.length() > 0.5 and not push_direction:
					$Camera3D.shaking = true
					statue_shaking = true
					await get_tree().create_timer(0.1).timeout
					$Camera3D.shaking = false
					statue_shaking = false
					statue_hp -= 1
					push_direction = true
				elif _input_dir.length() <= 0.5:
					push_direction = false
		
	if not active: return
	
	# Get desired movement velocity
	var desired_velocity = get_walk_velocity(_delta) + Vector3.UP * get_air_velocity(_delta)
	
	# Check for RigidBody3D collisions BEFORE moving
	# This prevents the player from continuously pushing into dynamic objects
	var test_motion_params = PhysicsTestMotionParameters3D.new()
	test_motion_params.from = global_transform
	test_motion_params.motion = desired_velocity * _delta
	var test_motion_result = PhysicsTestMotionResult3D.new()
	
	if PhysicsServer3D.body_test_motion(get_rid(), test_motion_params, test_motion_result):
		# We're about to collide with something
		var collider = test_motion_result.get_collider()
		if collider is RigidBody3D:
			# Block movement in the direction of the RigidBody
			# Project velocity to slide along the surface instead of pushing into it
			var collision_normal = test_motion_result.get_collision_normal()
			desired_velocity = desired_velocity.slide(collision_normal)
	
	velocity = desired_velocity
	move_and_slide()
	
	# Push RigidBody3D objects when player collides with them
	# Apply impulse only on first contact, then let physics handle separation
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			# Check if this object is on cooldown
			var current_time = Time.get_ticks_msec() / 1000.0
			if push_cooldowns.has(collider):
				if current_time < push_cooldowns[collider]:
					continue  # Skip this object, still on cooldown
			
			# Calculate push direction (horizontal only)
			var push_direction = -collision.get_normal()
			push_direction.y = 0  # Remove vertical component for horizontal-only pushing
			push_direction = push_direction.normalized()  # Re-normalize after zeroing Y
			
			# Apply impulse on first contact
			var push_strength = 5.0  # Impulse strength
			collider.apply_central_impulse(push_direction * push_strength * collider.mass)
			
			# Set cooldown for this object
			push_cooldowns[collider] = current_time + PUSH_COOLDOWN_TIME
	
	# Clean up expired cooldowns to prevent dictionary from growing indefinitely
	var objects_to_remove = []
	for obj in push_cooldowns.keys():
		if not is_instance_valid(obj) or Time.get_ticks_msec() / 1000.0 > push_cooldowns[obj]:
			objects_to_remove.append(obj)
	for obj in objects_to_remove:
		push_cooldowns.erase(obj)
	
	if get_walk_velocity(_delta) == Vector3.ZERO and toggle_shamisen and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
		shamisen_wait_time += _delta
	else:
		shamisen_wait_time = 0
	
	# displays thinking bar to load music pattern memories
	$"CanvasLayer/ThinkingBar/TextureProgressBar".value = shamisen_wait_time

	if shamisen_wait_time <= 1.0 or shamisen_wait_time >= shamisen_wait_memory_time:
		if $"CanvasLayer/ThinkingBar".modulate.a > 0:
			$"CanvasLayer/ThinkingBar".modulate.a -= _delta*4
	elif shamisen_wait_time >= 1.0 and shamisen_wait_time <= shamisen_wait_memory_time and $"CanvasLayer/ThinkingBar".modulate.a < 1:
		$"CanvasLayer/ThinkingBar".modulate.a += _delta*2
		
	# displays music pattern memories
	if shamisen_wait_time <= shamisen_wait_memory_time:	
		if $"CanvasLayer/Music Memory".modulate.a > 0:
			$"CanvasLayer/Music Memory".modulate.a -= _delta*4
	elif shamisen_wait_time >= shamisen_wait_memory_time and $"CanvasLayer/Music Memory".modulate.a < 1:
		$"CanvasLayer/Music Memory".modulate.a += _delta*2
	
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
		if event.pressed and event.keycode == KEY_ESCAPE and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
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
				emit_signal("played_note_signal", 1)
			if event.pressed and event.keycode == KEY_2:
				$Camera3D/Shamisen.append_note(2)
				emit_signal("played_note_signal", 2)
			if event.pressed and event.keycode == KEY_3:
				$Camera3D/Shamisen.append_note(3)
				emit_signal("played_note_signal", 3)

			
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
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
		run_dialogue("pickup_shamisen")
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
	if object.can_interact():
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
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return Vector3.ZERO
		
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

#I don't know why this is its own function but I think it's funny so it gets to stay
func play_eating_sfx():
	$EatingSFX.play()

func run_dialogue(dialogue_id: String):
	var _dialogue_box: DialogueBox = DialogueBox.instance
	_dialogue_box.data = player_dialogues
	_dialogue_box.start(dialogue_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
	await _dialogue_box.dialogue_ended
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InspectionManager.current_mode = InspectionManager.Mode.PLAY

func fade_to_white():
	$CanvasLayer/WhiteFade.modulate = Color(1, 1, 1, 0)
	await create_tween().tween_property($CanvasLayer/WhiteFade, "modulate", Color.WHITE, 2).finished
	emit_signal("fade_complete")

func fade_from_white(_duration: float = 2, _init_alpha: float = 1):
	$CanvasLayer/WhiteFade.modulate = Color(1, 1, 1, _init_alpha)
	await create_tween().tween_property($CanvasLayer/WhiteFade, "modulate", Color(1, 1, 1, 0), _duration).finished
	emit_signal("fade_complete")

func set_gray_scale(_value: float):
	var overlay = $CanvasLayer/BlackWhiteOverlay
	overlay.material.set_shader_parameter("grey_level", _value)
	
func apply_black_white_effect():
	"""Apply white overlay effect with low opacity"""
	# Disable player movement during the effect
	active = false
	statue = true
	statue_hp = 3
	if not has_node("CanvasLayer/BlackWhiteOverlay"):
		push_warning("Player: BlackWhiteOverlay node not found!")
		return
	
	var overlay = $CanvasLayer/BlackWhiteOverlay
	
	# Reset overlay state completely
	overlay.modulate = Color.WHITE  # Reset modulate
	overlay.color = Color(1, 1, 1, 1)  # Start transparent white
	overlay.visible = true
	set_gray_scale(1.0)
	
	# Wait a frame to ensure state is set
	await get_tree().process_frame
	
	fade_from_white(0.5, 0.5)
	
func un_statuefy():
	var overlay = $CanvasLayer/BlackWhiteOverlay
	active = true
	statue = false
	# Fade out the effect (0.3 seconds)
	await get_tree().create_tween().tween_method(set_gray_scale, 1.0, 0, 0.4).finished
	
	# Reset and hide overlay
	overlay.visible = false

var current_drunken_level: float = 0
func set_drunken_level(_value: float):
	$CanvasLayer/DrunkenOverlay.material.set_shader_parameter("wiggleMult", _value)

func set_drunken_level_tweened(_value: float):
	get_tree().create_tween().tween_method(set_drunken_level, current_drunken_level, _value, 2)
	current_drunken_level = _value
