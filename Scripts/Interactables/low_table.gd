extends Node3D
class_name LowTable

# Sprite visibility for mode switching
var inspection_manager: Node = null
var is_in_inspection_mode: bool = false

@onready var regular_view_3d_model: Node3D = $RegularView3DModel
@onready var tray_model: Node3D = $TrayModel

func _ready():
	# Get InspectionManager
	inspection_manager = get_node_or_null("/root/InspectionManager")
	
	# Set initial visibility based on current mode
	if inspection_manager:
		var current_mode = inspection_manager.current_mode
		var is_inspect_or_dialogue = (current_mode == inspection_manager.Mode.INSPECT or current_mode == inspection_manager.Mode.DIALOGUE)
		is_in_inspection_mode = is_inspect_or_dialogue
		_update_visibility_for_mode(is_inspect_or_dialogue)
	else:
		_update_visibility_for_mode(false)
	
	# Also check again on next frame in case mode changes during initialization
	call_deferred("check_inspection_mode")

func _process(_delta):
	# Re-acquire InspectionManager if we don't have it yet
	if not inspection_manager:
		inspection_manager = get_node_or_null("/root/InspectionManager")
	
	# Check for inspection mode changes
	check_inspection_mode()

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
	"""Toggle visibility between regular 3D model and inspection sprite"""
	if regular_view_3d_model:
		regular_view_3d_model.visible = not is_inspect_mode
	if tray_model:
		tray_model.visible = is_inspect_mode
