extends StaticBody3D

# Hallway Fog Barrier - Blocks hallways after clock activation

@export var fade_in_duration: float = 1.5

var activated: bool = false
var current_alpha: float = 0.0
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Start invisible
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("fog_color", Color(0, 0, 0, 0))
		current_alpha = 0.0
	
	# Disable collision until activated
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

func _process(delta: float) -> void:
	# Check if GameManager is ready
	if not GameManager.instance:
		return
	
	# Check if we should remove the barrier
	if GameManager.instance.entered_ceremonial_past:
		queue_free()
		return
	
	# Check if clock has been activated
	if GameManager.instance.clock_activated_once and not activated:
		activated = true
		# Enable collision when activating
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		print("Fog barrier activating at: ", global_position)
	
	# Fade in when activated
	if activated and current_alpha < 1.0:
		current_alpha = min(1.0, current_alpha + (delta / fade_in_duration))
		
		if mesh_instance and mesh_instance.get_surface_override_material(0):
			var mat = mesh_instance.get_surface_override_material(0)
			if mat is ShaderMaterial:
				mat.set_shader_parameter("fog_color", Color(0, 0, 0, current_alpha))
