extends CanvasLayer

## Time Vortex Effect Controller
## Creates a swirling vortex that distorts the screen and transitions to a new scene

var shader_material: ShaderMaterial
var color_rect: ColorRect
var current_progress: float = 0.0
var clock_hand_pivot: Node3D = null
var clock_hand_continuing: bool = false
var clock_hand_direction: float = 1.0

func _ready():
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
	vortex_col: Color = Color(0.1, 0.05, 0.15, 1.0),
	center_col: Color = Color(0.3, 0.3, 0.35, 1.0),
	max_progress: float = 0.85,
	clock_object: Node3D = null,
	camera_focus_duration: float = 1.5,
	inner_col: Color = Color(0.25, 0.2, 0.3, 1.0),
	mid_col: Color = Color(0.2, 0.1, 0.25, 1.0),
	edge_col: Color = Color(0.05, 0.0, 0.1, 1.0)
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
	
	# Phase 2: Swirl in (reveal new scene)
	var tween_in = create_tween()
	tween_in.set_ease(Tween.EASE_OUT)
	tween_in.set_trans(Tween.TRANS_CUBIC)
	
	tween_in.tween_method(
		func(value: float):
			shader_material.set_shader_parameter("progress", value)
			current_progress = value,
		max_progress,
		0.0,
		phase_duration
	)
	
	# Wait for swirl in to complete
	await tween_in.finished
	
	# Clean up
	queue_free()

## Plays the vortex effect without transitioning scenes
## Useful for visual feedback or other effects
func play_effect_only(
	duration: float = 2.5,
	clockwise_rotation: bool = true,
	center_col: Color = Color(0.3, 0.3, 0.35, 1.0),
	inner_col: Color = Color(0.25, 0.2, 0.3, 1.0),
	mid_col: Color = Color(0.2, 0.1, 0.25, 1.0),
	vortex_col: Color = Color(0.1, 0.05, 0.15, 1.0),
	edge_col: Color = Color(0.05, 0.0, 0.1, 1.0),
	reverse: bool = false
) -> void:
	# Set all 5 color shader parameters
	shader_material.set_shader_parameter("clockwise", clockwise_rotation)
	shader_material.set_shader_parameter("center_color", center_col)
	shader_material.set_shader_parameter("inner_color", inner_col)
	shader_material.set_shader_parameter("mid_color", mid_col)
	shader_material.set_shader_parameter("vortex_color", vortex_col)
	shader_material.set_shader_parameter("edge_color", edge_col)
	
	# Animate the vortex effect
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if reverse:
		# Reverse: from full vortex back to normal
		shader_material.set_shader_parameter("progress", 1.0)
		current_progress = 1.0
		tween.tween_method(
			func(value: float):
				shader_material.set_shader_parameter("progress", value)
				current_progress = value,
			1.0,
			0.0,
			duration
		)
	else:
		# Forward: from normal to full vortex
		tween.tween_method(
			func(value: float):
				shader_material.set_shader_parameter("progress", value)
				current_progress = value,
			0.0,
			1.0,
			duration
		)
	
	# Wait for animation to complete
	await tween.finished
	
	# Clean up
	queue_free()
