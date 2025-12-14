extends Node3D
class_name SakazukiCup

enum CupSize { SMALL, MEDIUM, LARGE }

@export var cup_size: CupSize = CupSize.SMALL
@export var target_fill_level: float = 0.4  # Target fill for perfect pour
@export var fill_tolerance: float = 0.1  # Acceptable variance
@export var overflow_threshold: float = 0.7  # Too full = failure
@export var filled_sprite_texture: Texture2D = null  # Sprite to show when filled >= 0.3

@export var current_fill_level: float = 0.0
var pours_completed: int = 0
var is_active: bool = false
var is_complete: bool = false
var is_in_target_range: bool = false
var original_material: Material = null
var pulse_timer: Timer = null
var is_pulsing: bool = false

# Sprite visibility for mode switching
var inspection_manager: Node = null
var is_in_inspection_mode: bool = false

signal pour_evaluated(success: bool, perfect: bool)
signal cup_completed

@onready var regular_view_sprite: Sprite3D = $RegularViewSprite
@onready var liquid_surface: MeshInstance3D = $LiquidSurface
@onready var cup_model: Node3D = $CupModel
@onready var collision_area: Area3D = $CollisionArea
@onready var target1: Sprite3D = $Target1 if has_node("Target1") else null
@onready var target2: Sprite3D = $Target2 if has_node("Target2") else null
@onready var target3: Sprite3D = $Target3 if has_node("Target3") else null

func _ready():
	# Get InspectionManager
	inspection_manager = get_node_or_null("/root/InspectionManager")
	
	# Store original sprite texture for switching
	if regular_view_sprite and regular_view_sprite.texture:
		set_meta("original_sprite", regular_view_sprite.texture)
	
	if liquid_surface:
		# LiquidSurface is a CHILD of the cup, so it moves with the cup automatically
		liquid_surface.visible = true
		
		# Match CupModel sprite EXACTLY - same position and size
		# CupModel is a Sprite3D, get its texture to determine actual pixel dimensions
		if cup_model is Sprite3D:
			var sprite = cup_model as Sprite3D
			# Position at same XY as sprite, but Z slightly in front
			liquid_surface.position = Vector3(0, 0, 0.001)  # Tiny offset forward
			liquid_surface.rotation = Vector3.ZERO
			
			# Match the sprite's pixel_size to get same scale
			var pixel_size = sprite.pixel_size if sprite.pixel_size > 0 else 0.0003
			
			# Get texture dimensions to calculate exact size
			var texture = sprite.texture
			if texture:
				var tex_size = texture.get_size()
				var mesh = liquid_surface.mesh as QuadMesh
				if mesh:
					# Set mesh size to exactly match sprite dimensions
					var world_width = tex_size.x * pixel_size
					var world_height = tex_size.y * pixel_size
					mesh.size = Vector2(world_width, world_height)

		
	
	# Set up collision layer for inspection mode raycasting (layer 6)
	if collision_area:
		collision_area.collision_layer = 0
		collision_area.collision_mask = 0
		#collision_area.set_collision_layer_value(6, true)
	
	# Ensure each cup instance has its own liquid material and initialize to empty
	if liquid_surface and liquid_surface.material_override:
		var base_material := liquid_surface.material_override
		var instance_material := base_material.duplicate()
		liquid_surface.material_override = instance_material
		if instance_material:
			instance_material.set_shader_parameter("fill_level", 0.0)
	
	# Set initial target fill levels - will update per pour
	update_target_fill_level()
	
	# Show the appropriate target for the current pour count
	update_target_visibility()
	
	# Set initial visibility based on mode
	_update_visibility_for_mode(false)

func _process(_delta):
	# Check for inspection mode changes
	check_inspection_mode()

func update_target_fill_level():
	"""Update target fill level based on cup size and pour count"""
	match cup_size:
		CupSize.SMALL:
			match pours_completed:
				0:
					target_fill_level = 0.7  # 70% for first pour
				1:
					target_fill_level = 0.85  # 85% for second pour
				2:
					target_fill_level = 1.0  # 100% for third pour
		CupSize.MEDIUM:
			match pours_completed:
				0:
					target_fill_level = 0.7  # 70% for first pour
				1:
					target_fill_level = 0.85  # 85% for second pour
				2:
					target_fill_level = 1.0  # 100% for third pour
		CupSize.LARGE:
			match pours_completed:
				0:
					target_fill_level = 0.7  # 70% for first pour
				1:
					target_fill_level = 0.85  # 85% for second pour
				2:
					target_fill_level = 1.0  # 100% for third pour

func update_target_visibility():
	"""Show the correct target sprite based on pour count and active status"""
	# Only show targets in inspection mode
	if target1:
		target1.visible = (pours_completed == 0) and is_active and is_in_inspection_mode
	if target2:
		target2.visible = (pours_completed == 1) and is_active and is_in_inspection_mode
	if target3:
		target3.visible = (pours_completed == 2) and is_active and is_in_inspection_mode
	
	# Update target fill level for current pour
	update_target_fill_level()

func activate():
	"""Make this cup the active target for pouring"""
	is_active = true
	update_target_visibility()
	
	# Store original material if not already stored
	if cup_model and cup_model is Sprite3D:
		var sprite = cup_model as Sprite3D
		if sprite.material_override and not original_material:
			original_material = sprite.material_override.duplicate()
	
	# Start the initial 3-pulse sequence
	start_pulse_sequence()

func deactivate():
	"""Remove active status"""
	is_active = false
	update_target_visibility()
	
	# Stop any pulsing and timers
	stop_pulse_sequence()
	
	# Remove emission glow and restore original material
	if cup_model and cup_model is Sprite3D and original_material:
		var sprite = cup_model as Sprite3D
		sprite.material_override = original_material

func add_liquid(amount: float):
	"""Add liquid during pouring (called continuously)"""
	current_fill_level = clamp(current_fill_level + amount, 0.0, 1.0)
	update_liquid_visual()
	check_target_range()
	

func update_liquid_visual():
	"""Update shader parameter to show fill level"""
	if liquid_surface and liquid_surface.material_override:
		var material = liquid_surface.material_override
		if material:
			material.set_shader_parameter("fill_level", current_fill_level)

	
func check_target_range():
	"""Check if current fill is within acceptable range and provide visual feedback"""
	var fill_error = abs(current_fill_level - target_fill_level)
	var was_in_range = is_in_target_range
	is_in_target_range = fill_error <= fill_tolerance
	
	# Start flashing when entering target range
	if is_in_target_range and not was_in_range:
		start_target_range_flash()
	# Stop flashing when leaving target range
	elif not is_in_target_range and was_in_range:
		stop_target_range_flash()

func start_target_range_flash():
	"""Visual feedback when fill level is in acceptable range"""
	if cup_model and cup_model is Sprite3D:
		var sprite = cup_model as Sprite3D
		# Create bright pulsing effect - more visible
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 2.0, 1.0), 0.25)  # Bright cyan flash
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	
	# Make active target pulse brightly
	var active_target = null
	match pours_completed:
		0:
			active_target = target1
		1:
			active_target = target2
		2:
			active_target = target3
	
	if active_target:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(active_target, "modulate", Color(0.5, 1.0, 1.5, 1.0), 0.3)
		tween.tween_property(active_target, "modulate", Color(0.3, 0.7, 1.0, 0.8), 0.3)

func stop_target_range_flash():
	"""Stop visual feedback when leaving acceptable range"""
	# Kill all tweens created by this node
	var tree = get_tree()
	if tree:
		for node in [self, cup_model, target1, target2, target3]:
			if node:
				var tweens = node.get_tree().get_processed_tweens()
				for tween in tweens:
					if tween.is_valid():
						tween.kill()
	
	# Reset cup color
	if cup_model and cup_model is Sprite3D:
		var sprite = cup_model as Sprite3D
		sprite.modulate = Color.WHITE
	
	# Reset target colors
	if target1:
		target1.modulate = Color(0.3, 0.7, 1.0, 0.8)
	if target2:
		target2.modulate = Color(0.3, 0.7, 1.0, 0.8)
	if target3:
		target3.modulate = Color(0.3, 0.7, 1.0, 0.8)

func evaluate_pour(_pour_duration: float) -> Dictionary:
	"""
	Evaluate if the pour was successful
	Returns: { success: bool, perfect: bool, overflow: bool }
	"""
	var result = {
		"success": false,
		"perfect": false,
		"overflow": false
	}
	
	# Check for overflow - use dynamic threshold based on target + margin
	var dynamic_overflow = target_fill_level + 0.15
	if current_fill_level >= dynamic_overflow:
		result.overflow = true
		return result
	
	# Check if fill level is within tolerance
	var fill_error = abs(current_fill_level - target_fill_level)
	if fill_error <= fill_tolerance:
		result.success = true
		# Perfect pour if very close to target
		if fill_error <= fill_tolerance * 0.5:
			result.perfect = true
		
		pours_completed += 1
		update_target_visibility()  # Show next target
		
		# Check if cup is complete (3 pours)
		if pours_completed >= 3:
			is_complete = true
			emit_signal("cup_completed")
	
	emit_signal("pour_evaluated", result.success, result.perfect)
	return result

func empty_cup():
	"""Empty the cup for retry"""
	current_fill_level = 0.0
	pours_completed = 0  # Reset pour counter to show target1
	is_in_target_range = false
	stop_target_range_flash()
	stop_pulse_sequence()  # Stop any ongoing pulse and timer
	update_liquid_visual()
	update_target_visibility()  # Refresh target line after emptying

func reset_cup():
	"""Reset cup to initial state"""
	current_fill_level = 0.0
	pours_completed = 0
	is_active = false
	is_complete = false
	is_in_target_range = false
	stop_target_range_flash()
	stop_pulse_sequence()  # Stop any ongoing pulse and timer
	
	# Remove emission glow and restore original material
	if cup_model and cup_model is Sprite3D and original_material:
		var sprite = cup_model as Sprite3D
		sprite.material_override = original_material
	
	update_liquid_visual()
	update_target_visibility()

func show_success_animation():
	"""Visual feedback for successful pour"""
	if liquid_surface:
		var tween = create_tween()
		tween.set_parallel(true)
		# Gentle glow pulse
		var material = liquid_surface.material_override
		if material:
			# Could add emission or color change here
			pass
		
		# Scale pulse
		tween.tween_property(self, "scale", Vector3.ONE * 1.05, 0.3)
		tween.tween_property(self, "scale", Vector3.ONE, 0.3).set_delay(0.3)

func show_failure_animation():
	"""Visual feedback for failed pour"""
	# Red flash effect could be added
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(5), 0.1)
	tween.tween_property(self, "rotation:z", deg_to_rad(-5), 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)

func get_fill_percentage() -> float:
	"""Get current fill as percentage for UI display"""
	return current_fill_level * 100.0

func start_pulse_sequence():
	"""Start a sequence of 3 emission pulses"""
	if is_pulsing:
		return
	
	is_pulsing = true
	pulse_emission(3)

func pulse_emission(pulses_remaining: int):
	"""Pulse the emission on and off"""
	if not is_active or pulses_remaining <= 0:
		is_pulsing = false
		return
	
	if cup_model and cup_model is Sprite3D:
		var sprite = cup_model as Sprite3D
		if sprite.material_override:
			# Create glowing material
			var glow_material = sprite.material_override.duplicate() as StandardMaterial3D
			if glow_material:
				glow_material.emission_enabled = true
				glow_material.emission = Color(0.98, 0.98, 0.8	)  
				glow_material.emission_energy_multiplier = 0.1
				
				# Pulse on
				var tween = create_tween()
				sprite.material_override = glow_material
				tween.tween_property(glow_material, "emission_energy_multiplier", 0.4, 0.1)
				tween.tween_property(glow_material, "emission_energy_multiplier", 0.1, 0.4)
				
				# After pulse completes, either do next pulse or finish
				await tween.finished
				
				# Restore original material
				if original_material:
					sprite.material_override = original_material
				
				# Brief pause between pulses
				await get_tree().create_timer(0.2).timeout
				
				# Continue with remaining pulses
				pulse_emission(pulses_remaining - 1)

func stop_pulse_sequence():
	"""Stop any ongoing pulse sequences"""
	is_pulsing = false

func on_inspect_click():
	"""Called when clicked in inspection mode - not used for cups"""
	pass  # Cups are not directly clickable, pitcher handles pouring

func check_inspection_mode():
	"""Check if inspection mode has changed and update visibility accordingly"""
	if not inspection_manager:
		return
	
	var current_mode = inspection_manager.current_mode
	# Show high-res sprite in both INSPECT and DIALOGUE modes
	var new_inspection_state = (current_mode == inspection_manager.Mode.INSPECT or current_mode == inspection_manager.Mode.DIALOGUE)
	
	if new_inspection_state != is_in_inspection_mode:
		is_in_inspection_mode = new_inspection_state
		_update_visibility_for_mode(new_inspection_state)

func _update_visibility_for_mode(is_inspect_mode: bool):
	"""Toggle visibility between regular and inspection sprites"""
	if regular_view_sprite:
		regular_view_sprite.visible = not is_inspect_mode
		
		# Update PLAY mode sprite based on fill level
		if not is_inspect_mode and filled_sprite_texture:
			if current_fill_level >= 0.3:
				regular_view_sprite.texture = filled_sprite_texture
			else:
				# Restore original empty sprite - need to get it from the scene
				# The original texture should be set in the scene, so we store it
				if not has_meta("original_sprite"):
					set_meta("original_sprite", regular_view_sprite.texture)
				else:
					regular_view_sprite.texture = get_meta("original_sprite")
	
	if cup_model:
		cup_model.visible = is_inspect_mode
	
	# Hide liquid surface and targets in PLAY mode
	if liquid_surface:
		liquid_surface.visible = is_inspect_mode
	if target1:
		target1.visible = is_inspect_mode and (pours_completed == 0) and is_active
	if target2:
		target2.visible = is_inspect_mode and (pours_completed == 1) and is_active
	if target3:
		target3.visible = is_inspect_mode and (pours_completed == 2) and is_active
