extends CanvasLayer

# Text overlay that requires click to dismiss

@onready var panel = $Panel
@onready var label = $Panel/MarginContainer/Label
@onready var background = $ColorRect

func _ready():
	hide()

func show_message(message: String) -> void:
	label.text = message
	show()
	# Capture mouse to prevent clicking through
	get_viewport().set_input_as_handled()

func _input(event):
	if visible and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_message()
			get_viewport().set_input_as_handled()

func hide_message() -> void:
	hide()
