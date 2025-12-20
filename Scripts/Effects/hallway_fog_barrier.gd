extends StaticBody3D

# Hallway Fog Barrier - Blocks hallways when time traveling to the past
# Appears only in past timeline after clock activation

@export var fade_duration: float = 1.5
@export var active_in_past: bool = true
@export var active_in_present: bool = false
@export var requires_clock_activation: bool = true

var current_alpha: float = 0.0
var target_alpha: float = 0.0
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Start invisible and disabled
	current_alpha = 0.0
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("fog_color", Color(0, 0, 0, 0))
	
	# Disable collision until activated
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

func _process(delta: float) -> void:
	# Check if GameManager is ready
	if not GameManager.instance:
		return
	
	# Determine if barrier should be active based on time state
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
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("fog_color", Color(0, 0, 0, alpha))

func set_collision_enabled(enabled: bool) -> void:
	if enabled:
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
	else:
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
