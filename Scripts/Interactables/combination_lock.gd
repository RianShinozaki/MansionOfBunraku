extends Node3D

@export var correct_combination: Array[int] = [4, 9, 7, 8]
@export var unlock_sound: AudioStream
@export var click_sound: AudioStream
@export var slide_distance: float = 0.04  # How far the assembly slides out
@export var slide_direction: Vector3 = Vector3(0, -1, 0)  # Direction to slide 

var is_unlocked: bool = false

signal unlocked

@onready var moving_assembly_pivot: Node3D = $MovingAssemblyPivot/MovingAssembly
@onready var click_audio: AudioStreamPlayer3D = $ClickSound
@onready var unlock_audio: AudioStreamPlayer3D = $UnlockSound

func _ready():
	add_to_group("Interactable")
	print("lock ready")
	
	# Set up audio if provided
	if click_sound and click_audio:
		click_audio.stream = click_sound
	if unlock_sound and unlock_audio:
		unlock_audio.stream = unlock_sound

func can_interact() -> bool:
	return not is_unlocked

func on_interact() -> void:
	# This will be called by the player when clicking on the lock
	# The actual wheel interaction is handled by wheel collision areas
	pass

func on_wheel_changed(wheel_index: int) -> void:
	# Play click sound
	if click_audio and click_audio.stream:
		click_audio.play()
	
	# Check if combination is correct after any wheel change
	if not is_unlocked:
		check_combination()

func check_combination() -> void:
	if is_unlocked:
		return
	
	# Get current combination from all wheels
	var current_combo: Array[int] = []
	for i in range(4):
		var wheel_num = str(i + 1).pad_zeros(2)  # Formats as "01", "02", "03", "04"
		var wheel = get_node_or_null("Wheel" + wheel_num + "Pivot")
		if wheel:
			current_combo.append(wheel.get_current_number())
	
	# Check if it matches
	if current_combo.size() == 4 and arrays_equal(current_combo, correct_combination):
		unlock()

func arrays_equal(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		return false
	for i in range(arr1.size()):
		if arr1[i] != arr2[i]:
			return false
	return true

func unlock() -> void:
	if is_unlocked:
		return
	
	is_unlocked = true
	
	# Play unlock sound
	if unlock_audio and unlock_audio.stream:
		unlock_audio.play()
	
	# Animate moving assembly sliding out
	if moving_assembly_pivot:
		var target_position = moving_assembly_pivot.position + (slide_direction.normalized() * slide_distance)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(moving_assembly_pivot, "position", target_position, 1.0)
	
	# Emit signal for other systems
	emit_signal("unlocked")

func reset_lock() -> void:
	is_unlocked = false
	
	# Reset all wheels
	for i in range(4):
		var wheel_num = str(i + 1).pad_zeros(2)  # Formats as "01", "02", "03", "04"
		var wheel = get_node_or_null("Wheel" + wheel_num + "Pivot")
		if wheel:
			wheel.reset()
	
	# Reset moving assembly position
	if moving_assembly_pivot:
		var original_position = moving_assembly_pivot.position - (slide_direction.normalized() * slide_distance)
		moving_assembly_pivot.position = original_position
