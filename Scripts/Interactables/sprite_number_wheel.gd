extends StaticBody3D

# A clickable number wheel that uses an animated sprite
# The LockWheel.png sprite should have 30 vertical frames (3 frames per number 0-9)

@export var wheel_index: int = 1  # Which wheel (1-4)

var current_number: int = 0
var is_animating: bool = false

@onready var sprite: Sprite3D = $WheelSprite

func _ready():
	add_to_group("Interactable")
	
	# Set up sprite to use frame 0
	if sprite:
		sprite.vframes = 30  # 30 vertical frames (3 frames per number 0-9)
		sprite.frame = 0

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.INSPECT and not is_animating

func on_interact() -> void:
	print("on interact")
	if can_interact():
		print("can interact")
		increment_wheel()
		get_viewport().set_input_as_handled()

func on_inspect_click() -> void:
	# Called by InspectionManager when clicked in INSPECT mode
	if not is_animating:
		increment_wheel()

func increment_wheel() -> void:
	if is_animating:
		return
	
	is_animating = true
	
	# Increment number (0-9, wraps around)
	current_number = (current_number + 1) % 10
	
	# Animate sprite through frames with a spin effect
	# Each number uses 3 frames: number N uses frames (N*3), (N*3+1), and (N*3+2) for smooth transition
	if sprite:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		# Animate to the target number (N*3) which shows the complete digit
		var target_frame = current_number * 3
		tween.tween_property(sprite, "frame", target_frame, 0.2)
		await tween.finished
	
	is_animating = false
	
	# Notify parent lock
	if get_parent() and get_parent().has_method("on_wheel_changed"):
		get_parent().on_wheel_changed(wheel_index)

func get_current_number() -> int:
	return current_number

func reset() -> void:
	current_number = 0
	if sprite:
		sprite.frame = 0
