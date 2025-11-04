extends Node3D

@export var correct_combination: Array[int] = [4, 9, 7, 8]
@export var unlock_sound: AudioStream
@export var click_sound: AudioStream
@export var slide_distance: float = 0.04  # How far the assembly slides out
@export var slide_direction: Vector3 = Vector3(0, -1, 0)  # Direction to slide
@export var inspect_fov: float = 40.0  # FOV for inspect camera

var is_unlocked: bool = false

signal unlocked

@onready var moving_assembly_pivot: Node3D = $MovingAssemblyPivot/MovingAssembly
@onready var click_audio: AudioStreamPlayer3D = $ClickSound
@onready var unlock_audio: AudioStreamPlayer3D = $UnlockSound
@onready var focus_marker: Node3D = $FocusMarker  # Will be added in editor

func _ready():
	add_to_group("Interactable")
	
	# Set up audio if provided
	if click_sound and click_audio:
		click_audio.stream = click_sound
	if unlock_sound and unlock_audio:
		unlock_audio.stream = unlock_sound
	
	$"../Shamisen".remove_from_group("Item")

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact() -> void:
	# Enter inspection mode
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		# Mark this input event as handled so InspectionManager doesn't process the same click
		get_viewport().set_input_as_handled()

func on_wheel_changed(wheel_index: int) -> void:
	# Play click sound
	if click_audio and click_audio.stream:
		click_audio.play()
	
	# Check if combination is correct after any wheel change
	if not is_unlocked:
		check_combination()

func check_combination() -> void:
	if is_unlocked:
		return
	
	# Get current combination from all wheels
	var current_combo: Array[int] = []
	for i in range(4):
		var wheel_num = str(i + 1).pad_zeros(2)  # Formats as "01", "02", "03", "04"
		var wheel = get_node_or_null("Wheel" + wheel_num + "Pivot")
		if wheel:
			current_combo.append(wheel.get_current_number())
	
	# Check if it matches
	if current_combo.size() == 4 and arrays_equal(current_combo, correct_combination):
		unlock()

func arrays_equal(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		return false
	for i in range(arr1.size()):
		if arr1[i] != arr2[i]:
			return false
	return true


func unlock() -> void:
	if is_unlocked:
		return
	
	is_unlocked = true
	
	# Play unlock sound
	if unlock_audio and unlock_audio.stream:
		unlock_audio.play()
	
	# Animate moving assembly sliding out
	if moving_assembly_pivot:
		var target_position = moving_assembly_pivot.position + (slide_direction.normalized() * slide_distance)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(moving_assembly_pivot, "position", target_position, 1.0)
		
		# Wait for animation to finish, then wait 2 more seconds, then remove the object
		tween.finished.connect(_on_unlock_animation_finished)
	
	# Emit signal for other systems
	emit_signal("unlocked")
	
	#CHANGE THIS LATER
	$"../Shamisen".add_to_group("Item")

func _on_unlock_animation_finished() -> void:
	# Wait 2 seconds after animation completes
	await get_tree().create_timer(1.0).timeout
	
	# Dissolve effect: fade out all mesh materials over 1 second
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, mesh_instances)
	
	# Store original materials and create transparent duplicates
	var material_data: Array[Dictionary] = []
	for mesh_instance in mesh_instances:
		for i in range(mesh_instance.get_surface_override_material_count()):
			var original_mat = mesh_instance.get_surface_override_material(i)
			if original_mat:
				var mat_copy = original_mat.duplicate()
				mat_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.set_surface_override_material(i, mat_copy)
				material_data.append({
					"mesh": mesh_instance,
					"surface": i,
					"material": mat_copy
				})
	
	# Create tween to fade out
	var dissolve_tween = create_tween()
	dissolve_tween.set_parallel(true)
	
	for data in material_data:
		dissolve_tween.tween_property(data.material, "albedo_color:a", 0.0, 1.0)
	
	# Wait for dissolve to complete, then remove the object
	await dissolve_tween.finished
	queue_free()

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		_collect_mesh_instances(child, result)

func reset_lock() -> void:
	is_unlocked = false
	
	# Reset all wheels
	for i in range(4):
		var wheel_num = str(i + 1).pad_zeros(2)  # Formats as "01", "02", "03", "04"
		var wheel = get_node_or_null("Wheel" + wheel_num + "Pivot")
		if wheel:
			wheel.reset()
	
	# Reset moving assembly position
	if moving_assembly_pivot:
		var original_position = moving_assembly_pivot.position - (slide_direction.normalized() * slide_distance)
		moving_assembly_pivot.position = original_position
