class_name KitsuneCompletion

extends AnimatableBody3D

@export var dialogue_data: DialogueData
@export var appear_delay: float = 1.0

@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

var has_appeared: bool = false

func _ready() -> void:
	# Start hidden - hide parent and children explicitly
	visible = false
	if body_sprite:
		body_sprite.visible = false
	if head_sprite:
		head_sprite.visible = false
	
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

func trigger_appearance() -> void:
	"""Called externally to trigger the kitsune's appearance and dialogue"""
	if has_appeared:
		return
	
	has_appeared = true
	
	# Wait 1 frame for inspect mode to fully exit
	await get_tree().process_frame
	
	# Make visible - use show() for more explicit visibility
	show()
	if body_sprite:
		body_sprite.show()
	if head_sprite:
		head_sprite.show()
	
	# Start dialogue automatically
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("sake_completion")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
		# Disappear after dialogue
		queue_free()
