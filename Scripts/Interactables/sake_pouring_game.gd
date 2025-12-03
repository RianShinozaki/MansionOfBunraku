extends StaticBody3D

enum GameState {
	INTRO,
	WAITING_FOR_POUR,
	POURING,
	EVALUATING,
	CUP_COMPLETE,
	RITUAL_COMPLETE,
	FAILED
}

# Timing parameters (adjustable for difficulty)
@export var min_pour_duration: float = 0.3  # Too fast = disrespectful (very lenient)
@export var max_pour_duration: float = 10.0  # Too slow = sake cools (very lenient)
@export var perfect_duration_min: float = 1.0
@export var perfect_duration_max: float = 3.0
@export var inspect_fov: float = 20.0
@export var disable_bunraku_on_inspect: bool = true

# Audio
@export var success_sound: AudioStream  # Ceremonial bell
@export var failure_sound: AudioStream  # Wrong pour
@export var cup_complete_sound: AudioStream  # Soft chime
@export var ritual_complete_sound: AudioStream  # Victory chime
@export var pouring_sound: AudioStream  # Liquid pouring sound (looping)
@export var spill_sound: AudioStream  # Sake spilling sound

# Dialogue
@export var intro_dialogue: DialogueData

var current_state: GameState = GameState.INTRO
var current_cup_index: int = 0
var pour_start_time: float = 0.0
var total_pours_completed: int = 0

signal ritual_completed
signal pour_failed

@onready var pitcher: ChoshiPitcher = $ChoshiPitcher
@onready var cup_small: SakazukiCup = $CupSmall
@onready var cup_medium: SakazukiCup = $CupMedium
@onready var cup_large: SakazukiCup = $CupLarge
@onready var focus_marker: Marker3D = $FocusMarker
@onready var success_audio: AudioStreamPlayer3D = $SuccessSound
@onready var failure_audio: AudioStreamPlayer3D = $FailureSound
@onready var cup_complete_audio: AudioStreamPlayer3D = $CupCompleteSound
@onready var ritual_complete_audio: AudioStreamPlayer3D = $RitualCompleteSound
@onready var pouring_audio: AudioStreamPlayer3D = $PouringSound
@onready var spill_audio: AudioStreamPlayer3D = $SpillSound
@onready var instruction_label: Label = $InstructionLabel
@onready var low_table_3d: Node3D = $LowTable3D

var cups: Array[SakazukiCup] = []
var pitcher_ever_dragged: bool = false
var spacebar_ever_pressed: bool = false
var previous_mode: int = -1  # Track previous inspection mode

func _ready():
	# Force correct collision layer for PLAY mode only (exclude layer 6 for inspection)
	# Layer 5 = binary 00101 = layers 1 and 3 only (not layer 6)
	collision_layer = 5
	collision_mask = 0
	
	add_to_group("Interactable")
	
	# Ensure instruction label starts hidden
	if instruction_label:
		instruction_label.visible = false
	
	# Set up audio
	if success_sound and success_audio:
		success_audio.stream = success_sound
	if failure_sound and failure_audio:
		failure_audio.stream = failure_sound
	if cup_complete_sound and cup_complete_audio:
		cup_complete_audio.stream = cup_complete_sound
	if ritual_complete_sound and ritual_complete_audio:
		ritual_complete_audio.stream = ritual_complete_sound
	if pouring_sound and pouring_audio:
		pouring_audio.stream = pouring_sound
	if spill_sound and spill_audio:
		spill_audio.stream = spill_sound
	
	# Collect cups in order
	cups = [cup_small, cup_medium, cup_large]
	
	# Connect pitcher signals
	if pitcher:
		pitcher.clicked.connect(_on_pitcher_clicked)
		pitcher.spill_detected.connect(_on_spill_detected)
	
	# Connect cup signals
	for cup in cups:
		if cup:
			cup.cup_completed.connect(_on_cup_completed)

func _process(_delta):
	"""Continuously check if we should hide the instruction label and detect mode changes"""
	# Check for mode transitions to detect when leaving inspect mode
	var current_mode = InspectionManager.current_mode
	
	# Detect transition from INSPECT or DIALOGUE mode to PLAY mode
	if previous_mode != -1:  # Skip first frame
		var was_in_inspect_or_dialogue = (previous_mode == InspectionManager.Mode.INSPECT or previous_mode == InspectionManager.Mode.DIALOGUE)
		var now_in_play = (current_mode == InspectionManager.Mode.PLAY)
		
		if was_in_inspect_or_dialogue and now_in_play:
			# Player has left inspect mode - reset the game completely
			reset_game()
	
	previous_mode = current_mode
	
	# Always hide label when not in INSPECT mode
	if instruction_label and instruction_label.visible:
		if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
			instruction_label.visible = false
	
	# Hide label if both actions have been performed
	if instruction_label and instruction_label.visible:
		if pitcher_ever_dragged and spacebar_ever_pressed:
			instruction_label.visible = false

func can_interact() -> bool:
	var result = InspectionManager.current_mode == InspectionManager.Mode.PLAY
	return result

func on_interact() -> void:
	# Enter inspection mode to start the ceremony
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		get_viewport().set_input_as_handled()
		
		# Start the game after a brief intro
		await get_tree().create_timer(0.5).timeout
		start_game()

func start_game():
	"""Initialize the ceremonial pouring game"""
	current_state = GameState.INTRO
	current_cup_index = 0
	total_pours_completed = 0
	spacebar_ever_pressed = false
	
	# Reset all cups
	for cup in cups:
		cup.reset_cup()
	
	# Play intro sequence
	await play_intro_sequence()
	
	# Activate first cup
	activate_current_cup()
	current_state = GameState.WAITING_FOR_POUR

func play_intro_sequence():
	"""Play the intro dialogue sequence with cup flashes"""
	if not intro_dialogue:
		return
	
	var dialogue_box: DialogueBox = DialogueBox.instance
	if not dialogue_box:
		return
	
	dialogue_box.data = intro_dialogue
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
	
	# Line 1: "heaven" (no flash)
	dialogue_box.start("heaven")
	await dialogue_box.dialogue_ended
	await get_tree().create_timer(0.3).timeout
	
	# Line 2: "earth" (no flash)
	dialogue_box.start("earth")
	await dialogue_box.dialogue_ended
	await get_tree().create_timer(0.3).timeout
	
	# Line 3: "humanity" (no flash)
	dialogue_box.start("humanity")
	await dialogue_box.dialogue_ended
	await get_tree().create_timer(0.3).timeout
	
	# Line 4: instructions (no flash)
	dialogue_box.start("instruction1")
	await dialogue_box.dialogue_ended
	await get_tree().create_timer(0.3).timeout
	
	# Line 5: final instructions (no flash)
	dialogue_box.start("instruction2")
	await dialogue_box.dialogue_ended
	
	# Clear dialogue data to prevent accidental re-triggering
	dialogue_box.data = null
	dialogue_box.stop()
	
	# Restore inspection mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	InspectionManager.current_mode = InspectionManager.Mode.INSPECT
	
	await get_tree().create_timer(0.5).timeout
	
	# Flash choshi first
	if pitcher:
		pitcher.pulse_emission(3)
		await get_tree().create_timer(2.0).timeout  # Wait for 3 pulses to complete
	
	# Then flash smallest sakazuki (just visual pulse, don't activate yet)
	if cup_small:
		if not cup_small.original_material and cup_small.cup_model and cup_small.cup_model.material_override:
			cup_small.original_material = cup_small.cup_model.material_override.duplicate()
		cup_small.pulse_emission(3)
		await get_tree().create_timer(2.0).timeout  # Wait for 3 pulses to complete
		cup_small.stop_pulse_sequence()
	
	# Show instruction label after flashing completes
	if instruction_label:
		instruction_label.visible = true

func activate_current_cup():
	"""Activate the current cup for pouring"""
	if current_cup_index < cups.size():
		var cup = cups[current_cup_index]
		cup.activate()
		pitcher.set_target_cup(cup)
		pitcher.set_clickable(true)

func _on_pitcher_clicked():
	"""Handle pitcher being clicked - start/stop pouring"""
	match current_state:
		GameState.WAITING_FOR_POUR:
			# Start pouring
			start_pouring()
		GameState.POURING:
			# Stop pouring
			stop_pouring()

func start_pouring():
	"""Begin the pour"""
	if current_state != GameState.WAITING_FOR_POUR:
		return
	
	# Detect which cup (if any) is underneath the pitcher
	var cup_under_pitcher = pitcher.check_cup_hover(cups)
	
	# Set this as the target for this pour
	if cup_under_pitcher:
		pitcher.set_target_cup(cup_under_pitcher)
	else:
		pitcher.set_target_cup(null)  # Pouring into nothing
	
	current_state = GameState.POURING
	pour_start_time = Time.get_ticks_msec() / 1000.0
	pitcher.start_pour()
	
	# Play pouring sound
	if pouring_audio and pouring_audio.stream:
		pouring_audio.play()

func stop_pouring():
	"""End the pour and evaluate"""
	if current_state != GameState.POURING:
		return
	
	var pour_duration = (Time.get_ticks_msec() / 1000.0) - pour_start_time
	var poured_cup = pitcher.target_cup
	pitcher.stop_pour()
	
	# Stop pouring sound
	if pouring_audio:
		pouring_audio.stop()
	
	current_state = GameState.EVALUATING
	pitcher.set_clickable(false)
	
	# Evaluate the pour - use the actual cup that was poured into
	evaluate_pour(pour_duration, poured_cup)

func evaluate_pour(duration: float, poured_cup: SakazukiCup):
	"""Check if the pour was successful"""
	# Check if they poured into the correct cup
	if not poured_cup:
		handle_failure("You must pour into a cup!")
		return
	
	var expected_cup = cups[current_cup_index]
	if poured_cup != expected_cup:
		handle_failure("You poured into the wrong cup! Pour into the highlighted cup.")
		poured_cup.empty_cup()  # Empty the wrong cup
		return
	
	var cup = poured_cup
	
	# Check timing first
	if duration < min_pour_duration:
		# Too fast - disrespectful
		handle_failure("Pour was too hasty. Take your time with the ceremony.")
		return
	
	if duration > max_pour_duration:
		# Too slow - sake has cooled
		handle_failure("Pour took too long. The sake has cooled.")
		return
	
	# Check fill level
	var result = cup.evaluate_pour(duration)
	
	if result.overflow:
		# Overfilled
		handle_failure("You poured too much. The cup overflows.")
		return
	
	if result.success:
		# Successful pour!
		handle_success(result.perfect)
	else:
		# Fill level was incorrect
		handle_failure("The fill level is incorrect. Try again.")

func handle_success(_perfect: bool):
	"""Handle a successful pour"""
	var cup = cups[current_cup_index]
	
	# Visual feedback
	cup.show_success_animation()
	
	# Audio feedback
	if success_audio and success_audio.stream:
		success_audio.play()
	
	total_pours_completed += 1
	
	# Check if cup is complete (3 pours)
	if cup.is_complete:
		await get_tree().create_timer(1.0).timeout
		# Don't call advance_to_next_cup here, it's handled by cup_completed signal
	else:
		# Same cup, next pour - liquid should stay in cup!
		await get_tree().create_timer(0.5).timeout
		current_state = GameState.WAITING_FOR_POUR
		pitcher.set_clickable(true)

func _on_cup_completed():
	"""Called when a cup has received all 3 pours"""
	current_state = GameState.CUP_COMPLETE
	
	# Play cup complete sound
	if cup_complete_audio and cup_complete_audio.stream:
		cup_complete_audio.play()
	
	# Check if all cups are done
	if current_cup_index >= cups.size() - 1:
		# Ritual complete!
		complete_ritual()
	else:
		# Move to next cup
		await get_tree().create_timer(1.5).timeout
		advance_to_next_cup()

func advance_to_next_cup():
	"""Move to the next cup in the sequence"""
	cups[current_cup_index].deactivate()
	current_cup_index += 1
	
	if current_cup_index < cups.size():
		activate_current_cup()
		current_state = GameState.WAITING_FOR_POUR

func handle_failure(_message: String):
	"""Handle a failed pour"""
	current_state = GameState.FAILED
	
	var cup = cups[current_cup_index]
	cup.show_failure_animation()
	
	# Play failure sound
	if failure_audio and failure_audio.stream:
		failure_audio.play()
	
	emit_signal("pour_failed")
	
	# Show message (could use your TextOverlay system)
	# Empty cup and allow retry
	await get_tree().create_timer(1.0).timeout
	cup.empty_cup()
	# Re-activate the correct cup (ensures is_active is true, target visibility is refreshed, and pulse sequence starts)
	cup.activate()
	# Reset pitcher target back to the correct cup after failure
	pitcher.set_target_cup(cup)
	current_state = GameState.WAITING_FOR_POUR
	pitcher.set_clickable(true)

func _on_spill_detected():
	"""Called when pitcher detects the pour is no longer aligned with target cup"""
	if current_state != GameState.POURING:
		return
	
	# Stop pouring sound
	if pouring_audio:
		pouring_audio.stop()
	
	# Play spill sound
	if spill_audio and spill_audio.stream:
		spill_audio.play()
	
	# Treat spill as an immediate failure
	current_state = GameState.EVALUATING
	pitcher.set_clickable(false)
	
	# Handle as failure with spill message
	handle_failure("The pour missed the cup! The sake spilled.")

func complete_ritual():
	"""All cups completed - ceremony successful!"""
	current_state = GameState.RITUAL_COMPLETE
	
	# Play completion sound
	if ritual_complete_audio and ritual_complete_audio.stream:
		ritual_complete_audio.play()
	
	# Victory animation
	for cup in cups:
		cup.show_success_animation()
	
	await get_tree().create_timer(2.0).timeout
	
	# Emit signal for external systems
	emit_signal("ritual_completed")
	
	# Exit inspection mode after brief pause
	await get_tree().create_timer(1.0).timeout
	
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()

func _unhandled_input(event):
	"""Handle mouse input for dragging and spacebar for pouring"""
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	# Only process if this game is active
	if not is_inside_tree():
		return
	
	# Handle SPACE key for pouring
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.is_echo():
			# Mark spacebar as pressed
			if not spacebar_ever_pressed:
				spacebar_ever_pressed = true
			
			# Start pouring when space is pressed
			if current_state == GameState.WAITING_FOR_POUR:
				start_pouring()
				get_viewport().set_input_as_handled()
		elif not event.pressed:
			# Stop pouring when space is released
			if current_state == GameState.POURING:
				stop_pouring()
				get_viewport().set_input_as_handled()
	
	# Handle mouse for dragging
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if clicking pitcher
			var hit = InspectionManager.raycast_from_mouse(get_viewport().get_mouse_position())
			if hit and hit.collider:
				var parent = hit.collider.get_parent()
				if parent == pitcher or parent.get_parent() == pitcher:
					# Clicked on pitcher - start dragging
					if current_state == GameState.WAITING_FOR_POUR and not pitcher.is_being_dragged:
						pitcher.start_drag(get_viewport().get_mouse_position())
						# Mark pitcher as dragged
						if not pitcher_ever_dragged:
							pitcher_ever_dragged = true
					get_viewport().set_input_as_handled()
		else:
			# Mouse released - just end drag, don't start pouring
			if pitcher.is_being_dragged:
				pitcher.end_drag()
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if pitcher and pitcher.is_being_dragged:
			# Update drag position with mouse screen position
			pitcher.update_drag(event.position)
			get_viewport().set_input_as_handled()


func reset_game():
	"""Reset the entire game"""
	current_state = GameState.INTRO
	current_cup_index = 0
	total_pours_completed = 0
	pour_start_time = 0.0
	pitcher_ever_dragged = false  # Reset flags so instruction can show again
	spacebar_ever_pressed = false
	
	for cup in cups:
		cup.reset_cup()
	
	pitcher.set_clickable(false)
	pitcher.stop_pour()
	pitcher.reset_position()  # Reset pitcher to original position
	
	# Reset instruction label
	if instruction_label:
		instruction_label.visible = false
