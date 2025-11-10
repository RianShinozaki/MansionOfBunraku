extends StaticBody3D

# Painting interactable that will open the door

@export var painting_frame_texture: Texture2D
@export var painting_frame_heightmap: Texture2D
@export var painting_artwork: Texture2D
@export var inspect_fov: float = 40.0
@export var can_be_opened: bool
@export var dialogue_id: String
@export var environmental_dialogues: DialogueData

var anim_lock: bool = false
var open: bool = false
var dir: int = -1  # -1 for left pivot (counterclockwise rotation)

@onready var focus_marker: Node3D = $FocusMarker

signal door_opened

func _ready():
	add_to_group("Interactable")
	_apply_textures()

func _apply_textures():
	# Apply artwork texture
	if painting_artwork and has_node("VisualPivot/ArtworkSprite"):
		$VisualPivot/ArtworkSprite.texture = painting_artwork
		if $VisualPivot/ArtworkSprite.material_override:
			var material = $VisualPivot/ArtworkSprite.material_override.duplicate() as StandardMaterial3D
			if material:
				material.albedo_texture = painting_artwork
				$VisualPivot/ArtworkSprite.material_override = material
	
	# Apply frame texture and heightmap
	if has_node("VisualPivot/FrameSprite"):
		var frame_material = null
		
		if $VisualPivot/FrameSprite.material_override:
			frame_material = $VisualPivot/FrameSprite.material_override.duplicate() as StandardMaterial3D
			
			if painting_frame_texture and frame_material:
				frame_material.albedo_texture = painting_frame_texture
			
			if painting_frame_heightmap and frame_material:
				frame_material.heightmap_texture = painting_frame_heightmap
			
			$VisualPivot/FrameSprite.material_override = frame_material
		
		if painting_frame_texture:
			$VisualPivot/FrameSprite.texture = painting_frame_texture

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact():
	# Enter inspection mode using InspectionManager
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		get_viewport().set_input_as_handled()

func on_inspect_click():
	# Called when artwork is clicked during inspection mode
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
		
	if can_be_opened:
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
