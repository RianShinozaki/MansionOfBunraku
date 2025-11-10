extends CanvasLayer

# Text overlay that requires click to dismiss

@onready var panel = $Panel
@onready var rich_text_label = $Panel/BorderContainer/VBoxContainer/RichTextLabel
@onready var background = $ColorRect
@onready var paper_sound: AudioStreamPlayer = $PaperSound

signal hiding_message

var target_top: float = -350.0
var target_bottom: float = 350.0
var start_top: float = 1080.0
var start_bottom: float = 1780.0

func _ready():
	hide()
	# Set initial position off-screen
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom

func show_message(message: String) -> void:
	rich_text_label.text = message
	
	# Reset panel position to off-screen before showing
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom
	
	# Show the overlay first
	show()
	
	# Play paper sound
	if paper_sound:
		paper_sound.play()
	
	# Animate slide-up using tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "offset_top", target_top, 0.5)
	tween.parallel().tween_property(panel, "offset_bottom", target_bottom, 0.5)
	
	# Capture mouse to prevent clicking through
	get_viewport().set_input_as_handled()

func _input(event):
	if visible:
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				hide_message()
				emit_signal("hiding_message")

func hide_message() -> void:
	hide()
	# Reset panel position for next time
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom
	
	# Reset letter animation if it exists
	var letter = get_tree().root.find_child("Letter", true, false)
	if letter and letter.has_method("reset_animation"):
		letter.reset_animation()
