extends CanvasLayer

## Time Vortex Effect Controller
## Creates a swirling vortex that distorts the screen and transitions to a new scene

signal effect_completed

var shader_material: ShaderMaterial
var color_rect: ColorRect
var current_progress: float = 0.0
var clock_hand_pivot: Node3D = null
var clock_hand_continuing: bool = false
var clock_hand_direction: float = 1.0

# Web platform focus management
var is_web_platform: bool = false

func _ready():
	# Detect web platform
	is_web_platform = OS.has_feature("web")
	
	# Create a full-screen ColorRect
	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	add_child(color_rect)
	
	# Create and assign shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://Shaders/TimeVortex.gdshader")
	color_rect.material = shader_material
	
	# Start with no effect
	shader_material.set_shader_parameter("progress", 0.0)
	shader_material.set_shader_parameter("vortex_opacity", 1.0)  # Full opacity by default

## Force canvas focus and release pointer lock on web platform to prevent freezing
func _ensure_canvas_focus() -> void:
	if not is_web_platform:
		return
	
	# Release pointer lock and re-acquire to prevent itch.io freezing
	JavaScriptBridge.eval("""
		(function() {
			try {
				// Release any pointer lock
				if (document.pointerLockElement) {
					document.exitPointerLock();
				}
				
				const canvas = document.getElementById('canvas');
				if (canvas) {
					// Ensure canvas is focused
					canvas.focus();
					canvas.setAttribute('tabindex', '0');
					
					// Small delay before re-requesting pointer lock
					setTimeout(function() {
						canvas.requestPointerLock();
					}, 10);
					
					return true;
				}
			} catch(e) {
				console.error('Canvas focus/pointer lock error:', e);
			}
			return false;
		})();
	""", true)
	print("TimeVortex: Canvas focus ensured and pointer lock cycled")

## Manual animation with frame yielding to prevent browser freezing
## Animates a value over time while yielding frames periodically
func _animate_with_yielding(
	from_value: float,
	to_value: float,
	duration: float,
	ease_type: Tween.EaseType,
	trans_type: Tween.TransitionType,
	update_callback: Callable
) -> void:
	var elapsed: float = 0.0
	var frames_since_yield: int = 0
	var yield_every_n_frames: int = 3  # Yield every 3 frames for smooth 60fps while staying responsive
	
	while elapsed < duration:
		var delta = get_process_delta_time()
		elapsed += delta
		
		# Calculate progress (0.0 to 1.0)
		var progress = min(elapsed / duration, 1.0)
		
		# Apply easing/transition
		var eased_progress = _apply_easing(progress, ease_type, trans_type)
		
		# Interpolate value
		var current_value = lerp(from_value, to_value, eased_progress)
		
		# Call the update function
		update_callback.call(current_value)
		
		# Yield frame periodically to keep browser responsive
		frames_since_yield += 1
		if frames_since_yield >= yield_every_n_frames:
			await get_tree().process_frame
			frames_since_yield = 0
		else:
			await get_tree().process_frame
	
	# Ensure we end at exact target value
	update_callback.call(to_value)

## Apply easing function (simplified version of Tween easing)
func _apply_easing(t: float, ease_type: Tween.EaseType, trans_type: Tween.TransitionType) -> float:
	# Apply transition type first
	match trans_type:
		Tween.TRANS_CUBIC:
			if ease_type == Tween.EASE_IN:
				t = t * t * t
			elif ease_type == Tween.EASE_OUT:
				t = 1.0 - pow(1.0 - t, 3.0)
			elif ease_type == Tween.EASE_IN_OUT:
				if t < 0.5:
					t = 4.0 * t * t * t
				else:
					t = 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
		Tween.TRANS_QUAD:
			if ease_type == Tween.EASE_IN:
				t = t * t
			elif ease_type == Tween.EASE_OUT:
				t = 1.0 - (1.0 - t) * (1.0 - t)
			elif ease_type == Tween.EASE_IN_OUT:
				if t < 0.5:
					t = 2.0 * t * t
				else:
					t = 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
		_:  # LINEAR or others default to linear
			pass
	
	return t

func _process(delta: float):
	# Continue rotating clock hand during vortex, gradually slowing down
	if clock_hand_continuing and clock_hand_pivot and is_instance_valid(clock_hand_pivot):
		# Start at max speed, gradually decelerate as vortex intensifies
		# Hand slows to a stop by 50% progress
		var decel_factor = max(0.0, 1.0 - (current_progress / 0.5))
		var rotation_speed = (2 * PI) / 60.0 * 4 * 200.0 * decel_factor  # Start at 200x speed
		clock_hand_pivot.rotation.z += rotation_speed * clock_hand_direction * delta
		
		# Stop rotating completely at 50% progress
		if current_progress >= 0.5:
			clock_hand_continuing = false

## Helper function to smoothly move camera to focus on clock face
## Can use a focus_marker child node for precise camera positioning
func _focus_camera_on_clock(clock: Node3D, focus_duration: float) -> void:
	# Get the player camera
	var player = Player.instance
	if not player:
		return
	
	var player_camera = player.get_node_or_null("Camera3D")
	if not player_camera:
		return
	
	# Store original camera transform
	var original_transform = player_camera.global_transform
	
	# Look for a "CameraFocus" marker node - check as child first, then as sibling
	var focus_marker = clock.get_node_or_null("CameraFocus")
	if not focus_marker and clock.get_parent():
		# CameraFocus might be a sibling (child of parent) if clock is a sub-node
		focus_marker = clock.get_parent().get_node_or_null("CameraFocus")
	
	var target_transform: Transform3D
	
	if focus_marker:
		# Use the focus marker's transform directly
		target_transform = focus_marker.global_transform
		print("TimeVortex: Using CameraFocus marker at position: ", target_transform.origin)
		print("TimeVortex: CameraFocus rotation (basis forward): ", -target_transform.basis.z)
	else:
		print("TimeVortex: CameraFocus not found, using fallback calculation")
		# Fallback: Calculate target position from clock position
		var clock_position = clock.global_position
		var offset_distance = 2.0  # Distance from clock
		
		# If clock has a rotation, use it; otherwise face forward
		var clock_forward = -clock.global_transform.basis.z
		var target_position = clock_position + (clock_forward * offset_distance)
		
		# Create target transform looking at clock
		target_transform = Transform3D()
		target_transform.origin = target_position
		target_transform = target_transform.looking_at(clock_position, Vector3.UP)
	
	# Disable player control during camera movement
	player.active = false
	
	# Smoothly tween camera to target
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Tween position and rotation separately for smoother result
	tween.tween_property(player_camera, "global_position", target_transform.origin, focus_duration)
	tween.parallel().tween_method(
		func(t: float):
			var current_basis = original_transform.basis.slerp(target_transform.basis, t)
			player_camera.global_transform.basis = current_basis,
		0.0,
		1.0,
		focus_duration
	)
	
	await tween.finished
	
	# Keep player disabled - will re-enable after scene transition

## Accelerate the 3D clock hand while focusing camera (both happen simultaneously)
func _focus_camera_and_spin_clock(clock: Node3D, focus_duration: float, clockwise_dir: bool) -> void:
	# Get the player camera
	var player = Player.instance
	if not player:
		return
	
	var player_camera = player.get_node_or_null("Camera3D")
	if not player_camera:
		return
	
	# Store original camera transform
	var original_transform = player_camera.global_transform
	
	# Look for a "CameraFocus" marker node - check as child first, then as sibling
	var focus_marker = clock.get_node_or_null("CameraFocus")
	if not focus_marker and clock.get_parent():
		focus_marker = clock.get_parent().get_node_or_null("CameraFocus")
	
	var target_transform: Transform3D
	
	if focus_marker:
		target_transform = focus_marker.global_transform
		print("TimeVortex: Using CameraFocus marker")
	else:
		print("TimeVortex: CameraFocus not found, using fallback")
		var clock_position = clock.global_position
		var offset_distance = 2.0
		var clock_forward = -clock.global_transform.basis.z
		var target_position = clock_position + (clock_forward * offset_distance)
		target_transform = Transform3D()
		target_transform.origin = target_position
		target_transform = target_transform.looking_at(clock_position, Vector3.UP)
	
	# Disable player
	player.active = false
	
	# Find the ClockHandPivot
	clock_hand_pivot = null
	if clock.get_parent():
		clock_hand_pivot = clock.get_parent().get_node_or_null("ClockHandPivot")
	
	# Start camera tween
	var cam_tween = create_tween()
	cam_tween.set_ease(Tween.EASE_IN_OUT)
	cam_tween.set_trans(Tween.TRANS_CUBIC)
	cam_tween.tween_property(player_camera, "global_position", target_transform.origin, focus_duration)
	cam_tween.parallel().tween_method(
		func(t: float):
			var current_basis = original_transform.basis.slerp(target_transform.basis, t)
			player_camera.global_transform.basis = current_basis,
		0.0,
		1.0,
		focus_duration
	)
	
	# Accelerate clock hand in parallel
	if clock_hand_pivot:
		# Match vortex direction
		var direction = 1.0 if clockwise_dir else -1.0
		var time_elapsed = 0.0
		
		while time_elapsed < focus_duration:
			var delta = get_process_delta_time()
			time_elapsed += delta
			
			# Exponential acceleration - much more dramatic!
			var accel_progress = time_elapsed / focus_duration
			# Use cubic curve for extreme acceleration at the end
			var speed_multiplier = 1.0 + (pow(accel_progress, 3.0) * 200.0)  # 1x to 201x speed!
			
			# Rotate the hand
			var rotation_speed = (2 * PI) / 60.0 * 4 * speed_multiplier
			clock_hand_pivot.rotation.z += rotation_speed * direction * delta
			
			await get_tree().process_frame
		
		# Store reference to continue rotating during vortex
		self.clock_hand_pivot = clock_hand_pivot
		self.clock_hand_direction = direction
		self.clock_hand_continuing = true
	else:
		# Just wait for camera if no clock hand
		await cam_tween.finished

## Triggers a time vortex transition to a new scene
## @param target_scene: Path to the scene to load (e.g., "res://Maps/Game.tscn")
## @param duration: How long the transition takes in seconds (total for both phases)
## @param clockwise: True for clockwise rotation (forward in time), false for counter-clockwise (backward)
## @param vortex_col: Main vortex area color (backward compatible)
## @param center_col: The bright center color (backward compatible)
## @param max_progress: Maximum vortex intensity before switching scenes (backward compatible position!)
## @param clock_object: Optional - the clock Node3D to focus camera on before transition
## @param camera_focus_duration: How long to spend moving camera to clock (default 1.5s)
## @param inner_col: Color just outside the center (NEW - optional)
## @param mid_col: Middle zone color (NEW - optional)
## @param edge_col: Outermost edge color (NEW - optional)
func trigger_transition(
	target_scene: String,
	duration: float = 5.5,
	clockwise_rotation: bool = true,
	vortex_col: Color = Color(0.2, 0.3, 0.7, 1.0),
	center_col: Color = Color(0.95, 1.0, 1.0, 1.0),
	max_progress: float = 0.85,
	clock_object: Node3D = null,
	camera_focus_duration: float = 1.5,
	inner_col: Color = Color(0.4, 0.8, 1.0, 1.0),
	mid_col: Color = Color(0.7, 0.3, 0.9, 1.0),
	edge_col: Color = Color(0.05, 0.05, 0.3, 1.0)
) -> void:
	# Set all 5 color shader parameters
	shader_material.set_shader_parameter("clockwise", clockwise_rotation)
	shader_material.set_shader_parameter("center_color", center_col)
	shader_material.set_shader_parameter("inner_color", inner_col)
	shader_material.set_shader_parameter("mid_color", mid_col)
	shader_material.set_shader_parameter("vortex_color", vortex_col)
	shader_material.set_shader_parameter("edge_color", edge_col)
	
	# Optional: Move camera to focus on clock before transition starts
	# During this time, accelerate the 3D clock hand in the scene
	if clock_object:
		await _focus_camera_and_spin_clock(clock_object, camera_focus_duration, clockwise_rotation)
	
	# Phase 1: Swirl out (distort old scene)
	var phase_duration = duration / 2.0
	var tween_out = create_tween()
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.set_trans(Tween.TRANS_CUBIC)
	
	tween_out.tween_method(
		func(value: float):
			shader_material.set_shader_parameter("progress", value)
			current_progress = value,  # Track for clock hand updates
		0.0,
		max_progress,
		phase_duration
	)
	
	# Wait for swirl out to complete
	await tween_out.finished
	
	# Load the target scene at peak distortion
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
		# Give the scene one frame to load
		await get_tree().process_frame
	
	# Phase 2: Two-stage swirl in (Option 2 - Fade Through Vortex Colors)
	# Stage 1: Fade out vortex colors while keeping distortion high
	# This makes the scene visible but still heavily distorted
	var fade_duration = phase_duration * 0.4  # First 40% of phase
	var unswirl_duration = phase_duration * 0.6  # Last 60% of phase
	
	var tween_fade = create_tween()
	tween_fade.set_ease(Tween.EASE_OUT)
	tween_fade.set_trans(Tween.TRANS_CUBIC)
	
	# Fade vortex colors from full opacity to transparent
	tween_fade.tween_method(
		func(value: float):
			shader_material.set_shader_parameter("vortex_opacity", value),
		1.0,
		0.0,
		fade_duration
	)
	
	await tween_fade.finished
	
	# Stage 2: Reduce distortion while vortex colors are already faded
	# This reveals the new scene gradually without the abrupt color change
	var tween_unswirl = create_tween()
	tween_unswirl.set_ease(Tween.EASE_OUT)
	tween_unswirl.set_trans(Tween.TRANS_CUBIC)
	
	tween_unswirl.tween_method(
		func(value: float):
			shader_material.set_shader_parameter("progress", value)
			current_progress = value,
		max_progress,
		0.0,
		unswirl_duration
	)
	
	# Wait for unswirl to complete
	await tween_unswirl.finished
	
	# Clean up
	queue_free()

## Plays the vortex effect without transitioning scenes
## Useful for visual feedback or other effects
## Now includes smooth fade-through effect on return (Option 2 implementation)
func play_effect_only(
	duration: float = 2.5,
	clockwise_rotation: bool = true,
	center_col: Color = Color(0.95, 1.0, 1.0, 1.0),
	inner_col: Color = Color(0.4, 0.8, 1.0, 1.0),
	mid_col: Color = Color(0.7, 0.3, 0.9, 1.0),
	vortex_col: Color = Color(0.2, 0.3, 0.7, 1.0),
	edge_col: Color = Color(0.05, 0.05, 0.3, 1.0),
	reverse: bool = false
) -> void:
	# Ensure canvas has focus before starting effect (critical for web)
	_ensure_canvas_focus()
	
	# Give browser a frame to process focus
	await get_tree().process_frame
	
	# Set all 5 color shader parameters
	shader_material.set_shader_parameter("clockwise", clockwise_rotation)
	shader_material.set_shader_parameter("center_color", center_col)
	shader_material.set_shader_parameter("inner_color", inner_col)
	shader_material.set_shader_parameter("mid_color", mid_col)
	shader_material.set_shader_parameter("vortex_color", vortex_col)
	shader_material.set_shader_parameter("edge_color", edge_col)
	
	if reverse:
		# Reverse ONLY: from full vortex back to normal with fade-through effect
		shader_material.set_shader_parameter("progress", 1.0)
		current_progress = 1.0
		
		# Calculate phase durations
		var fade_duration = duration * 0.4  # First 40%: fade colors
		var unswirl_duration = duration * 0.6  # Last 60%: reduce distortion
		
		# Stage 1: Fade out vortex colors while keeping distortion high (with frame yielding)
		await _animate_with_yielding(
			1.0,
			0.0,
			fade_duration,
			Tween.EASE_OUT,
			Tween.TRANS_CUBIC,
			func(value: float): shader_material.set_shader_parameter("vortex_opacity", value)
		)
		
		# Stage 2: Reduce distortion while colors are faded (with frame yielding)
		await _animate_with_yielding(
			1.0,
			0.0,
			unswirl_duration,
			Tween.EASE_OUT,
			Tween.TRANS_CUBIC,
			func(value: float):
				shader_material.set_shader_parameter("progress", value)
				current_progress = value
		)
	else:
		# Forward: Complete cycle - swirl in, then swirl out with fade effect
		# This is used by time travel clock for visual feedback without scene change
		var phase_duration = duration / 2.0
		
		# Phase 1: Swirl IN (normal to full vortex) with frame yielding
		await _animate_with_yielding(
			0.0,
			1.0,
			phase_duration,
			Tween.EASE_IN_OUT,
			Tween.TRANS_CUBIC,
			func(value: float):
				shader_material.set_shader_parameter("progress", value)
				current_progress = value
		)
		
		# Re-ensure focus at the peak of the effect
		_ensure_canvas_focus()
		
		# Phase 2: Swirl OUT with fade-through effect
		var fade_duration = phase_duration * 0.4  # First 40%: fade colors
		var unswirl_duration = phase_duration * 0.6  # Last 60%: reduce distortion
		
		# Stage 1: Fade out vortex colors while keeping distortion high (with frame yielding)
		await _animate_with_yielding(
			1.0,
			0.0,
			fade_duration,
			Tween.EASE_OUT,
			Tween.TRANS_CUBIC,
			func(value: float): shader_material.set_shader_parameter("vortex_opacity", value)
		)
		
		# Stage 2: Reduce distortion while colors are faded (with frame yielding)
		await _animate_with_yielding(
			1.0,
			0.0,
			unswirl_duration,
			Tween.EASE_OUT,
			Tween.TRANS_CUBIC,
			func(value: float):
				shader_material.set_shader_parameter("progress", value)
				current_progress = value
		)
	
	# Final focus ensure before cleanup
	_ensure_canvas_focus()
	
	# On web, hide instead of destroy to prevent input freeze
	if is_web_platform:
		visible = false
		if color_rect:
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("TimeVortex: Hidden on web (not destroyed)")
		
		# Signal completion
		effect_completed.emit()
		
		# Schedule deferred cleanup much later to avoid memory leaks
		get_tree().create_timer(5.0).timeout.connect(
			func(): 
				if is_instance_valid(self):
					queue_free()
					print("TimeVortex: Deferred cleanup on web")
		)
	else:
		# Desktop: normal cleanup
		effect_completed.emit()
		queue_free()
