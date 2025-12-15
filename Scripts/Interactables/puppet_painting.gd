extends StaticBody3D

# Painting interactable for puppet painting

@export var painting_artwork: Texture2D
@export var painting_artwork_alt: Texture2D
@export var inspect_fov: float = 40.0
@export var can_be_opened: bool
@export var switch_texture_on_click: bool = false  # If true, switches to alt texture when clicked in inspect mode
@export var bunraku_appeasement: bool = true
@export var dialogue_id: String
@export var environmental_dialogues: DialogueData

@export_group("Time Vortex Settings")
@export var use_time_vortex: bool = false
@export var time_travel_target: String = ""
@export var vortex_duration: float = 2.5
@export var vortex_clockwise: bool = true
@export var vortex_color: Color = Color(0.1, 0.05, 0.15, 1.0)
@export var vortex_center_color: Color = Color(0.3, 0.3, 0.35, 1.0)

@export_group("Apple Spawn Settings")
@export var spawn_apple_on_click: bool = false  # If true, spawns an apple item when clicked

@export_group("Puppet Painting Textures")
@export var texture_missing: Texture2D  # Baseline (puppet_mountain-painting)
@export var texture_kouya_only: Texture2D  # Just Kouya filled (kouya_puppet_mountain-painting)
@export var texture_yono_only: Texture2D  # Just Yono filled (yono_puppet_mountain-painting)
@export var texture_both: Texture2D  # Both filled (yono_kouya_puppet_mountain-painting)

var anim_lock: bool = false
var open: bool = false
var dir: int = -1  # -1 for left pivot (counterclockwise rotation)
var first_viewing: bool = true
var texture_switched: bool = false  # Track if texture has been switched

# Track puppet placement state
var kouya_placed: bool = false
var yono_placed: bool = false

@onready var focus_marker: Node3D = $FocusMarker

signal door_opened

func _ready():
	add_to_group("Interactable")
	_apply_textures()
	_update_painting_texture()

func _apply_textures():
	# Apply initial artwork texture (will be overridden by _update_painting_texture if textures are set)
	var initial_texture = texture_missing if texture_missing else painting_artwork
	if initial_texture and has_node("VisualPivot/ArtworkSprite"):
		$VisualPivot/ArtworkSprite.texture = initial_texture
		if $VisualPivot/ArtworkSprite.material_override:
			var material = $VisualPivot/ArtworkSprite.material_override.duplicate() as StandardMaterial3D
			if material:
				material.albedo_texture = initial_texture
				$VisualPivot/ArtworkSprite.material_override = material
	
func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact():
	# Enter inspection mode using InspectionManager
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		get_viewport().set_input_as_handled()
		
		await get_tree().create_timer(0.1).timeout
		if dialogue_id != "" and first_viewing:
			first_viewing = false
			var _dialogue_box: DialogueBox = DialogueBox.instance
			_dialogue_box.data = environmental_dialogues
			_dialogue_box.start(dialogue_id)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
			await _dialogue_box.dialogue_ended
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			InspectionManager.current_mode = InspectionManager.Mode.INSPECT

func on_inspect_click():
	# Called when main painting is clicked during inspection mode
	# Handle puppet placement when clicking anywhere on the painting
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	var player = Player.instance
	if not player or not player.held_object:
		return
	
	var held_item = player.held_object
	
	# Check if holding Kouya or Yono puppet
	var is_kouya = held_item is KouyaPuppet
	var is_yono = held_item is YonoPuppet
	
	if not is_kouya and not is_yono:
		return  # Not holding a valid puppet
	
	# Place the puppet based on what's held
	if is_kouya and not kouya_placed:
		kouya_placed = true
	elif is_yono and not yono_placed:
		yono_placed = true
	else:
		return  # Puppet already placed
	
	# Remove puppet from player's hand
	player.drop_held_object()
	# Delete the puppet object
	held_item.queue_free()
	
	# Update the painting texture
	_update_painting_texture()
	
	# Exit inspect mode after placing
	if InspectionManager:
		InspectionManager.exit_inspect()

func on_apple_area_clicked():
	# Called when the apple area is clicked during inspection mode
	# This contains the original on_inspect_click logic
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	if dialogue_id != "":
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = environmental_dialogues
		_dialogue_box.start(dialogue_id)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.INSPECT
	
	# Check if texture should be switched on click (prioritize this)
	if switch_texture_on_click and painting_artwork_alt and not texture_switched:
		switch_to_alt_tex()
		texture_switched = true
		
		# Spawn apple if enabled
		if spawn_apple_on_click:
			spawn_apple_for_player()
		
		# Exit inspect mode after switching
		if InspectionManager:
			InspectionManager.exit_inspect()
		return  # Exit after switching texture
	# Check if time vortex should be triggered
	if use_time_vortex and time_travel_target != "":
		trigger_time_vortex()
	elif can_be_opened:
		dissolve_painting()
	

func dissolve_painting():
	if anim_lock: return
	anim_lock = true
	
	# Get the artwork sprite
	var artwork_sprite = get_node_or_null("VisualPivot/ArtworkSprite")
	if not artwork_sprite:
		anim_lock = false
		return
	
	# Get the collision shape
	var collision = get_node_or_null("CollisionShape3D")
	
	if not open:
		emit_signal("door_opened")
		if has_node("OpenSFX"):
			$OpenSFX.play()
		
		# Ensure the material has transparency enabled
		if artwork_sprite.material_override:
			artwork_sprite.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		# Dissolve the artwork by fading its alpha to 0
		var tween = get_tree().create_tween()
		tween.tween_property(artwork_sprite.material_override, "albedo_color:a", 0.0, 0.5)
		await tween.finished
		
		# Disable collision so player can pass through
		if collision:
			collision.disabled = true
		
		open = true
	else:
		if has_node("CloseSFX"):
			$CloseSFX.play()
		
		# Re-enable collision
		if collision:
			collision.disabled = false
		
		# Restore the artwork by fading its alpha back to 1
		var tween = get_tree().create_tween()
		tween.tween_property(artwork_sprite.material_override, "albedo_color:a", 1.0, 0.5)
		await tween.finished
		
		open = false
	anim_lock = false

func trigger_time_vortex():
	if anim_lock: return
	anim_lock = true
	
	# Exit inspection mode first
	if InspectionManager:
		InspectionManager.exit_inspect()
	
	# Create and add the time vortex effect
	var vortex_scene = preload("res://Objects/Effects/TimeVortex.tscn")
	var vortex = vortex_scene.instantiate()
	get_tree().root.add_child(vortex)
	
	# Trigger the transition with configured parameters
	vortex.trigger_transition(
		time_travel_target,
		vortex_duration,
		vortex_clockwise,
		vortex_color,
		vortex_center_color
	)
	
	# Note: No need to reset anim_lock since the scene will change

func switch_to_alt_tex():
	if painting_artwork_alt and has_node("VisualPivot/ArtworkSprite"):
		$VisualPivot/ArtworkSprite.texture = painting_artwork_alt
		if $VisualPivot/ArtworkSprite.material_override:
			var material = $VisualPivot/ArtworkSprite.material_override.duplicate() as StandardMaterial3D
			if material:
				material.albedo_texture = painting_artwork_alt
				$VisualPivot/ArtworkSprite.material_override = material
	# Hide the frame if it exists
	if has_node("VisualPivot/FrameSprite"):
		$VisualPivot/FrameSprite.visible = false

func switch_to_main_tex():
	if painting_artwork and has_node("VisualPivot/ArtworkSprite"):
		$VisualPivot/ArtworkSprite.texture = painting_artwork
		if $VisualPivot/ArtworkSprite.material_override:
			var material = $VisualPivot/ArtworkSprite.material_override.duplicate() as StandardMaterial3D
			if material:
				material.albedo_texture = painting_artwork
				$VisualPivot/ArtworkSprite.material_override = material

func _update_painting_texture():
	# Update the painting texture based on current state
	var target_texture: Texture2D
	
	if kouya_placed and yono_placed:
		# Both puppets placed
		target_texture = texture_both
	elif kouya_placed:
		# Only Kouya placed
		target_texture = texture_kouya_only
	elif yono_placed:
		# Only Yono placed
		target_texture = texture_yono_only
	else:
		# Neither placed (base state)
		target_texture = texture_missing
	
	if target_texture and has_node("VisualPivot/ArtworkSprite"):
		$VisualPivot/ArtworkSprite.texture = target_texture
		if $VisualPivot/ArtworkSprite.material_override:
			var material = $VisualPivot/ArtworkSprite.material_override.duplicate() as StandardMaterial3D
			if material:
				material.albedo_texture = target_texture
				$VisualPivot/ArtworkSprite.material_override = material

func spawn_apple_for_player():
	# Spawn an apple item and give it directly to the player
	var apple_scene = preload("res://Objects/Items/fruit.tscn")
	if not apple_scene:
		push_error("Apple scene not found!")
		return
	
	var player = Player.instance
	if not player:
		push_error("Player instance not found!")
		return
	
	# Don't spawn if player already has something held
	if player.held_object:
		return
	
	# Instantiate the apple
	var apple = apple_scene.instantiate()
	if not apple:
		push_error("Failed to instantiate apple!")
		return
	
	# Add to scene tree first (required for proper setup)
	get_tree().root.add_child(apple)
	
	# Use the player's pick_up_object method to properly handle the pickup
	# This ensures it's set up correctly like other items
	player.pick_up_object(apple)
