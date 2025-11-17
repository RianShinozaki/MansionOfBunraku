class_name InspectionLetter
extends StaticBody3D

## The message text to display when the letter is clicked
@export_multiline  var message_text: String = "This is a test message. Replace this with your actual letter content."

## Whether to disable bunraku while reading the letter
@export var disable_bunraku_on_inspect: bool = false

## Reference to the text overlay (will be found in scene)
var text_overlay: CanvasLayer

@onready var sprite: Sprite3D = $Sprite3D
@onready var animation_player: AnimationPlayer = $Sprite3D/AnimationPlayer

signal started_reading
signal finished_reading

func _ready():
	# Add to Interactable group so the player can interact with it
	add_to_group("Interactable")
	# Start with closed animation
	if animation_player:
		animation_player.play("closed")

func can_interact() -> bool:
	# Only allow interaction when in PLAY mode
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_inspect_click():
	
	# Disable bunraku if flag is set
	if disable_bunraku_on_inspect:
		InspectionManager.disable_bunraku_external()
	
	# Find the text overlay in the scene
	text_overlay = get_tree().root.find_child("TextOverlay", true, false) as CanvasLayer
	if text_overlay and text_overlay.has_method("show_message"):
		text_overlay.show_message(message_text)
		text_overlay.hiding_message.connect(on_finished_reading)
		emit_signal("started_reading")
	
	# Mark input as handled to prevent double-processing
	get_viewport().set_input_as_handled()

func on_finished_reading():
	# Restore bunraku if they were disabled
	if disable_bunraku_on_inspect:
		InspectionManager.restore_bunraku_external()
	
	emit_signal("finished_reading")
	text_overlay.hiding_message.disconnect(on_finished_reading)
	
	await get_tree().create_timer(0.1).timeout
	InspectionManager.current_mode = InspectionManager.Mode.INSPECT
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func reset_animation() -> void:
	# Reset to closed animation so it can be opened again
	if animation_player:
		animation_player.play("closed")
