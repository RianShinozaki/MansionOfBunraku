extends Node3D

# Time Sensitive Object - Base script for objects that toggle based on time travel state
# Can be used for fog barriers, furniture, decorations, etc.

@export_group("Time State Configuration")
@export var active_in_past: bool = true
@export var active_in_present: bool = false
@export var requires_clock_activation: bool = true

@export_group("Visual Settings")
@export var fade_duration: float = 1.5
@export var toggle_collision: bool = true

@export_group("Node References")
@export var visual_nodes: Array[Node3D] = []  # Nodes to toggle visibility (MeshInstances, etc.)
@export var collision_nodes: Array[CollisionShape3D] = []  # Collision shapes to toggle

var current_alpha: float = 0.0
var target_alpha: float = 0.0
var is_initialized: bool = false

func _ready() -> void:
	# Auto-detect child nodes if none are specified
	if visual_nodes.is_empty():
		for child in get_children():
			if child is MeshInstance3D or child is Sprite3D:
				visual_nodes.append(child)
	
	if collision_nodes.is_empty() and toggle_collision:
		for child in get_children():
			if child is CollisionShape3D:
				collision_nodes.append(child)
	
	# Start invisible and disabled
	current_alpha = 0.0
	apply_alpha(0.0)
	set_collision_enabled(false)
	is_initialized = true

func _process(delta: float) -> void:
	if not GameManager.instance:
		return
	
	# Determine if object should be active based on time state
	var should_be_active = calculate_should_be_active()
	
	# Set target alpha
	target_alpha = 1.0 if should_be_active else 0.0
	
	# Smoothly interpolate to target alpha
	if current_alpha != target_alpha:
		var alpha_change = delta / fade_duration
		if current_alpha < target_alpha:
			current_alpha = min(target_alpha, current_alpha + alpha_change)
		else:
			current_alpha = max(target_alpha, current_alpha - alpha_change)
		
		apply_alpha(current_alpha)
		
		# Enable collision when mostly visible, disable when mostly invisible
		if toggle_collision:
			set_collision_enabled(current_alpha > 0.5)

func calculate_should_be_active() -> bool:
	# Check if clock activation is required but hasn't happened yet
	if requires_clock_activation and not GameManager.instance.clock_activated_once:
		return false
	
	# Check time state
	if GameManager.instance.is_past_time:
		return active_in_past
	else:
		return active_in_present

func apply_alpha(alpha: float) -> void:
	for node in visual_nodes:
		if node is MeshInstance3D:
			apply_alpha_to_mesh(node, alpha)
		elif node is Sprite3D:
			node.modulate.a = alpha

func apply_alpha_to_mesh(mesh_instance: MeshInstance3D, alpha: float) -> void:
	if not mesh_instance:
		return
	
	# Handle shader materials (like fog barrier)
	if mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is ShaderMaterial:
			# Try common shader parameter names for opacity
			if mat.shader.get_shader_uniform_list().any(func(u): return u.name == "fog_color"):
				var current_color = mat.get_shader_parameter("fog_color")
				if current_color is Color:
					mat.set_shader_parameter("fog_color", Color(current_color.r, current_color.g, current_color.b, alpha))
			elif mat.shader.get_shader_uniform_list().any(func(u): return u.name == "opacity"):
				mat.set_shader_parameter("opacity", alpha)
	
	# Handle standard materials
	elif mesh_instance.get_active_material(0):
		var mat = mesh_instance.get_active_material(0)
		if mat is StandardMaterial3D:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = alpha

func set_collision_enabled(enabled: bool) -> void:
	# Toggle collision layers/masks
	if self is CollisionObject3D:
		if enabled:
			set_collision_layer_value(1, true)
			set_collision_mask_value(1, true)
		else:
			set_collision_layer_value(1, false)
			set_collision_mask_value(1, false)
	
	# Toggle collision shapes
	for collision_node in collision_nodes:
		if collision_node:
			collision_node.disabled = not enabled
