class_name Kitsune

extends AnimatableBody3D

@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

func _ready() -> void:
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
