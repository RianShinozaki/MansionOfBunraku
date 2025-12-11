extends StaticBody3D

enum GameState {
	HIDDEN,           # Sake hidden, in play mode
	WAITING_FOR_POUR, # In inspect mode, waiting for player to pour
	POURING,          # Actively pouring
	WARNING,          # Near full, warning flashes triggered
	OVERFLOW          # Overflowed, game ends
}

@export var max_pour_time: float = 8.0  # Maximum time to fill cup (in seconds)
@export var inspect_fov: float = 45.0

var current_state: GameState = GameState.HIDDEN
var pour_start_time: float = 0.0
var warning_triggered: bool = false
var previous_mode: int = -1

@onready var sake_pitcher: ShrineSakePitcher = $ShrineSake
@onready var cup: ShrineCupGame = $ShrineCup
@onready var focus_marker: Marker3D = $FocusMarker if has_node("FocusMarker") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready():
	# Set collision layers for both play mode (5) and inspection (6)
	# Layers 1 and 3 for play mode interaction, layer 6 for inspection raycasting
	collision_layer = 5 | (1 << 5)  # Layers 1, 3, and 6 = 37
	collision_mask = 0
	
	add_to_group("Interactable")

func _process(delta):
	# Check for mode transitions
	var current_mode = InspectionManager.current_mode
	
	# Detect transition from INSPECT/DIALOGUE to PLAY
	if previous_mode != -1:
		var was_in_inspect_or_dialogue = (previous_mode == InspectionManager.Mode.INSPECT or previous_mode == InspectionManager.Mode.DIALOGUE)
		var now_in_play = (current_mode == InspectionManager.Mode.PLAY)
		
		if was_in_inspect_or_dialogue and now_in_play:
			# Exited inspect mode - re-enable collision
			if collision_shape:
				collision_shape.disabled = false
			reset_sake_position()
			current_state = GameState.HIDDEN
	
	previous_mode = current_mode
	
	# Handle pouring logic
	if current_state == GameState.POURING:
		var pour_duration = (Time.get_ticks_msec() / 1000.0) - pour_start_time
		var fill_rate = delta / max_pour_time
		
		cup.add_fill(fill_rate)
		
		# Check for warning threshold
		if cup.should_flash_warning() and not warning_triggered:
			warning_triggered = true
			current_state = GameState.WARNING
			cup.flash_warning()
			await cup.get_tree().create_timer(0.9).timeout  # Duration of 3 flashes
			if current_state == GameState.WARNING:  # Check if still warning (not stopped)
				current_state = GameState.POURING
		
		# Check for overflow
		if cup.get_fill_level() >= 1.0:
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
	warning_triggered = false
	
	# Sake becomes visible in inspect mode
	if sake_pitcher:
		sake_pitcher.set_clickable(true)

func start_pouring():
	if current_state != GameState.WAITING_FOR_POUR and current_state != GameState.WARNING:
		return
	
	current_state = GameState.POURING
	pour_start_time = Time.get_ticks_msec() / 1000.0
	
	if sake_pitcher:
		sake_pitcher.start_pour()
	
	# Check if pouring outside cup - if so, trigger failure after brief moment
	if sake_pitcher and cup:
		if not sake_pitcher.check_cup_hover(cup):
			# Wait a brief moment then trigger spill
			await get_tree().create_timer(0.3).timeout
			if current_state == GameState.POURING:  # Still pouring
				handle_spill()

func stop_pouring():
	if current_state != GameState.POURING and current_state != GameState.WARNING:
		return
	
	current_state = GameState.WAITING_FOR_POUR
	
	if sake_pitcher:
		sake_pitcher.stop_pour()

func handle_overflow():
	current_state = GameState.OVERFLOW
	
	if sake_pitcher:
		sake_pitcher.stop_pour()
	
	# Cup shake and empty
	if cup:
		cup.shake_spill()
		await cup.get_tree().create_timer(0.8).timeout  # Wait for shake animation
		cup.empty_cup()
	
	# Exit inspect mode
	await get_tree().create_timer(0.3).timeout
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
	
	# Re-enable collision when exiting
	if collision_shape:
		collision_shape.disabled = false
	
	# Reset state
	reset_sake_position()
	current_state = GameState.HIDDEN
	warning_triggered = false

func handle_spill():
	"""Handle pouring outside the cup - same result as overflow"""
	current_state = GameState.OVERFLOW
	
	if sake_pitcher:
		sake_pitcher.stop_pour()
	
	# Cup shake and empty
	if cup:
		cup.shake_spill()
		await cup.get_tree().create_timer(0.8).timeout  # Wait for shake animation
		cup.empty_cup()
	
	# Exit inspect mode
	await get_tree().create_timer(0.3).timeout
	if InspectionManager.current_mode == InspectionManager.Mode.INSPECT:
		InspectionManager.exit_inspect()
	
	# Re-enable collision when exiting
	if collision_shape:
		collision_shape.disabled = false
	
	# Reset state
	reset_sake_position()
	current_state = GameState.HIDDEN
	warning_triggered = false

func reset_sake_position():
	if sake_pitcher:
		sake_pitcher.reset_position()
		sake_pitcher.stop_pour()
		sake_pitcher.set_clickable(false)

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
				# The collider could be the Area3D itself or have the sake pitcher as an ancestor
				var node = hit.collider
				var found_sake = false
				
				# Walk up the tree to see if we hit the sake pitcher
				while node != null:
					if node == sake_pitcher:
						found_sake = true
						break
					node = node.get_parent()
				
				if found_sake and not sake_pitcher.is_being_dragged:
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
