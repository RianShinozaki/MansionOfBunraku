extends StaticBody3D

# Simple combination lock using 2D sprites
# Emits "unlocked" signal when correct combination is entered

@export var correct_combination: Array[int] = [1, 7, 1, 1]
@export var unlock_sound: AudioStream
@export var click_sound: AudioStream
@export var inspect_fov: float = 40.0

var is_unlocked: bool = false
var wheels: Array[Node3D] = []
var was_in_inspect_mode: bool = false

signal unlocked

@onready var click_audio: AudioStreamPlayer3D = $ClickSound
@onready var unlock_audio: AudioStreamPlayer3D = $UnlockSound
@onready var focus_marker: Node3D = $FocusMarker
@onready var regular_view_sprite: Sprite3D = $RegularViewSprite
@onready var panel_sprite: Sprite3D = $PanelSprite

func _ready():
	add_to_group("Interactable")
	add_to_group("Lock")
	
	# Set up audio if provided
	if click_sound and click_audio:
		click_audio.stream = click_sound
	if unlock_sound and unlock_audio:
		unlock_audio.stream = unlock_sound
	
	# Collect wheel references
	for i in range(1, 5):
		var wheel = get_node_or_null("Wheel" + str(i))
		if wheel:
			wheels.append(wheel)
	
	# Ensure we start in regular view mode
	_update_visibility_for_mode(false)

func _process(_delta):
	# Check if we've transitioned out of inspect mode
	if was_in_inspect_mode and InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		was_in_inspect_mode = false
		_update_visibility_for_mode(false)

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact() -> void:
	# Enter inspection mode
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		was_in_inspect_mode = true
		_update_visibility_for_mode(true)
		get_viewport().set_input_as_handled()

func _update_visibility_for_mode(is_inspect_mode: bool):
	# In inspect mode: show detailed panel and wheels, hide regular view sprite
	# In regular mode: show regular view sprite, hide detailed panel and wheels
	if regular_view_sprite:
		regular_view_sprite.visible = not is_inspect_mode
	if panel_sprite:
		panel_sprite.visible = is_inspect_mode
	for wheel in wheels:
		if wheel:
			wheel.visible = is_inspect_mode

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
	for wheel in wheels:
		if wheel and wheel.has_method("get_current_number"):
			current_combo.append(wheel.get_current_number())
	
	# Check if it matches
	if current_combo.size() == correct_combination.size():
		var matches = true
		for i in range(current_combo.size()):
			if current_combo[i] != correct_combination[i]:
				matches = false
				break
		
		if matches:
			unlock()

func unlock() -> void:
	if is_unlocked:
		return
	
	is_unlocked = true
	
	# Play unlock sound
	if unlock_audio and unlock_audio.stream:
		unlock_audio.play()
	
	# Emit signal for other systems
	emit_signal("unlocked")
	
	# Wait a moment then exit inspection mode
	await get_tree().create_timer(1.0).timeout
	
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
