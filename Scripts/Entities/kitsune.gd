class_name Kitsune

extends AnimatableBody3D

@export var dialogue_data: DialogueData

@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

var has_interacted: bool = false
var is_fading: bool = false

func _ready() -> void:
	# Add to interactable group so player can click on it
	add_to_group("Interactable")
	
	# Start in normal mode
	set_normal_mode()

func _process(_delta: float) -> void:
	# Switch frames based on current inspection mode
	if InspectionManager.current_mode == InspectionManager.Mode.DIALOGUE:
		set_dialogue_mode()
	else:
		set_normal_mode()

func set_normal_mode() -> void:
	"""Display normal appearance (frames 0 and 1)"""
	if head_sprite:
		head_sprite.frame = 0
	if body_sprite:
		body_sprite.frame = 1

func set_dialogue_mode() -> void:
	"""Display dialogue appearance (frames 2 and 3)"""
	if head_sprite:
		head_sprite.frame = 2
	if body_sprite:
		body_sprite.frame = 3

func can_interact() -> bool:
	"""Check if kitsune can be interacted with"""
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY and not has_interacted and not is_fading

func on_interact():
	"""Called when player clicks on the kitsune"""
	if has_interacted:
		return
	
	has_interacted = true
	
	# Start dialogue
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("kitsune_intro")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
		# Disappear immediately after dialogue
		queue_free()
