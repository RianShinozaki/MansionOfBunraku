extends StaticBody3D

enum GameState {
	HIDDEN,           # Sake hidden, in play mode
	WAITING_FOR_POUR, # In inspect mode, waiting for player to pour
	POURING,          # Actively pouring
	COMPLETE,         # Successfully filled
	OVERFLOW          # Overflowed, game ends
}

@export var max_pour_time: float = 8.0  # Maximum time to fill cup (in seconds)
@export var inspect_fov: float = 45.0

var current_state: GameState = GameState.HIDDEN
var pour_start_time: float = 0.0
var previous_mode: int = -1

@onready var sake_pitcher: ChoshiPitcher = $ChoshiPitcher
@onready var cup: SakazukiCup = $SakazukiCup
@onready var focus_marker: Marker3D = $FocusMarker if has_node("FocusMarker") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready():
	# Set collision layers for both play mode (5) and inspection (6)
	# Layers 1 and 3 for play mode interaction, layer 6 for inspection raycasting
	collision_layer = 5 | (1 << 5)  # Layers 1, 3, and 6 = 37
	collision_mask = 0
	
	add_to_group("Interactable")
	
	# Set cup to only show the top target (Target3) for single fill level
	if cup:
		# Set the target fill level to 100%
		cup.target_fill_level = 1.0
		cup.pours_completed = 2  # This will show Target3
		# Hide Target1 and Target2 permanently
		if cup.has_node("Target1"):
			cup.get_node("Target1").queue_free()
		if cup.has_node("Target2"):
			cup.get_node("Target2").queue_free()

func _process(delta):
	# Check for mode transitions
	var current_mode = InspectionManager.current_mode
	
	# Detect transition from INSPECT/DIALOGUE to PLAY
	if previous_mode != -1:
		var was_in_inspect_or_dialogue = (previous_mode == InspectionManager.Mode.INSPECT or previous_mode == InspectionManager.Mode.DIALOGUE)
		var now_in_play = (current_mode == InspectionManager.Mode.PLAY)
		
		if was_in_inspect_or_dialogue and now_in_play:
			# Exited inspect mode - re-enable collision and reset pitcher only
			if collision_shape:
				collision_shape.disabled = false
			reset_pitcher_only()  # Don't empty cup - preserve fill level
			current_state = GameState.HIDDEN
	
	previous_mode = current_mode
	
	# Handle pouring logic
	if current_state == GameState.POURING:
		var pour_duration = (Time.get_ticks_msec() / 1000.0) - pour_start_time
		var fill_rate = delta / max_pour_time
		
		# Check if at target before adding more liquid
		var was_at_target = cup.current_fill_level >= 0.98
		
		# Use add_liquid instead of add_fill
		cup.add_liquid(fill_rate)
		
		# Check for completion - exactly at 100% with small tolerance
		if cup.current_fill_level >= 0.98:
			# If we just reached 98%, this is success
			if not was_at_target:
				# First time reaching target - success!
				stop_pouring()
				handle_complete()
			else:
				# Continued pouring after reaching target - overflow!
				# Player held spacebar too long
				handle_overflow()

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact() -> void:
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		# Disable game collision so sake pitcher can be clicked
		if collision_shape:
			collision_shape.disabled = true
		get_viewport().set_input_as_handled()
		
		await get_tree().create_timer(0.5).timeout
		start_game()

func start_game():
	current_state = GameState.WAITING_FOR_POUR
	
	# Sake becomes visible and clickable in inspect mode
	if sake_pitcher:
		sake_pitcher.set_clickable(true)
	
	# Activate cup to show Target3
	if cup:
		cup.is_active = true
		cup.update_target_visibility()

func start_pouring():
	if current_state != GameState.WAITING_FOR_POUR:
		return
	
	current_state = GameState.POURING
	pour_start_time = Time.get_ticks_msec() / 1000.0
	
	if sake_pitcher:
		sake_pitcher.start_pour()
	
	# Check if pouring outside cup - if so, trigger failure after brief moment
	if sake_pitcher and cup:
		# Use check_cup_hover with array for compatibility with ChoshiPitcher
		var cup_under_pitcher = sake_pitcher.check_cup_hover([cup])
		if not cup_under_pitcher:
			# Wait a brief moment then trigger spill
			await get_tree().create_timer(0.3).timeout
			if current_state == GameState.POURING:  # Still pouring
				handle_spill()

func stop_pouring():
	if current_state != GameState.POURING:
		return
	
	current_state = GameState.WAITING_FOR_POUR
	
	if sake_pitcher:
		sake_pitcher.stop_pour()

func handle_complete():
	"""Successfully filled the cup to 100%"""
	current_state = GameState.COMPLETE
	
	if sake_pitcher:
		sake_pitcher.stop_pour()
	
	# Success animation
	if cup:
		cup.show_success_animation()
	
	# Exit inspect mode
	await get_tree().create_timer(1.0).timeout
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
	
	# Re-enable collision when exiting
	if collision_shape:
		collision_shape.disabled = false
	
	# Reset pitcher only - keep cup filled for bunraku to check
	reset_pitcher_only()
	current_state = GameState.HIDDEN

func handle_overflow():
	"""Handle overflow - too much sake poured"""
	# Immediately change state to prevent more liquid from being added
	current_state = GameState.OVERFLOW
	
	if sake_pitcher:
		sake_pitcher.stop_pour()
	
	# Empty cup immediately to stop visual overflow, then do failure animation
	if cup:
		# Set to exactly 0 before animation
		cup.current_fill_level = 0.0
		cup.update_liquid_visual()
		
		cup.show_failure_animation()
		await cup.get_tree().create_timer(0.8).timeout
		
		# Ensure everything is reset properly
		cup.empty_cup()
		cup.pours_completed = 2
		cup.update_target_visibility()
		cup.update_liquid_visual()
	
	# Exit inspect mode
	await get_tree().create_timer(0.3).timeout
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
	
	# Re-enable collision when exiting
	if collision_shape:
		collision_shape.disabled = false
	
	# Reset pitcher only
	reset_pitcher_only()
	current_state = GameState.HIDDEN

func handle_spill():
	"""Handle pouring outside the cup - spill failure"""
	current_state = GameState.OVERFLOW
	
	if sake_pitcher:
		sake_pitcher.stop_pour()
	
	# Cup shake and empty
	if cup:
		cup.show_failure_animation()
		await cup.get_tree().create_timer(0.8).timeout
		cup.empty_cup()
		# After emptying, restore pours_completed to 2 for Target3 visibility
		cup.pours_completed = 2
		cup.update_target_visibility()
		# Explicitly update shader to ensure visual is at 0
		cup.update_liquid_visual()
	
	# Exit inspect mode
	await get_tree().create_timer(0.3).timeout
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
	
	# Re-enable collision when exiting
	if collision_shape:
		collision_shape.disabled = false
	
	# Reset pitcher only
	reset_pitcher_only()
	current_state = GameState.HIDDEN

func reset_pitcher_only():
	"""Reset pitcher position without emptying cup - preserves fill level"""
	if sake_pitcher:
		sake_pitcher.reset_position()
		sake_pitcher.stop_pour()
		sake_pitcher.set_clickable(false)
	
	if cup:
		cup.is_active = false
		cup.pours_completed = 2  # Keep it set to show Target3
		cup.update_target_visibility()

## Public API for bunraku entities
func get_fill_level() -> float:
	"""Returns the current fill level (0.0 to 1.0) for bunraku entities to check"""
	if cup:
		return cup.current_fill_level
	return 0.0

func empty_cup() -> void:
	"""Empties the cup - callable by bunraku entities"""
	if cup:
		cup.empty_cup()

func _unhandled_input(event):
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	if not is_inside_tree():
		return
	
	# Handle SPACE key for pouring
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.is_echo():
			start_pouring()
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			stop_pouring()
			get_viewport().set_input_as_handled()
	
	# Handle mouse for dragging sake
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if clicking sake
			var hit = InspectionManager.raycast_from_mouse(get_viewport().get_mouse_position())
			if hit and hit.collider and sake_pitcher:
				# Check if the hit collider is part of the sake pitcher
				var node = hit.collider
				var found_sake = false
				
				# Walk up the tree to see if we hit the sake pitcher
				while node != null:
					if node == sake_pitcher or node.get_parent() == sake_pitcher:
						found_sake = true
						break
					node = node.get_parent()
				
				if found_sake and not sake_pitcher.is_being_dragged:
					sake_pitcher.set_target_cup(cup)
					sake_pitcher.start_drag(get_viewport().get_mouse_position())
					get_viewport().set_input_as_handled()
		else:
			# Mouse released
			if sake_pitcher and sake_pitcher.is_being_dragged:
				sake_pitcher.end_drag()
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if sake_pitcher and sake_pitcher.is_being_dragged:
			sake_pitcher.update_drag(event.position)
			get_viewport().set_input_as_handled()
