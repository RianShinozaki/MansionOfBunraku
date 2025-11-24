extends CanvasLayer

@onready var panel: Control = $Panel
@onready var texture_rect: TextureRect = $Panel/TextureRect
@onready var background: ColorRect = $ColorRect
@onready var paper_sound: AudioStreamPlayer = $PaperSound

signal hiding_message

var target_top: float = -350.0
var target_bottom: float = 350.0
var start_top: float = 1080.0
var start_bottom: float = 1780.0

func _ready():
	hide()
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom

func show_image(texture: Texture2D) -> void:
	InspectionManager.current_mode = InspectionManager.Mode.INSPECT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	texture_rect.texture = texture
	
	# Slide the panel up
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom
		
	show()
	
	if paper_sound:
		paper_sound.play()
		
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "offset_top", target_top, 0.5)
	tween.parallel().tween_property(panel, "offset_bottom", target_bottom, 0.5)
	
	
		
	get_viewport().set_input_as_handled()

func _input(event):
	if visible:
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				hide_image()
				emit_signal("hiding_message")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			hide_image()

func hide_image() -> void:
	hide()
	
	if panel:
		panel.offset_top = start_top
		panel.offset_bottom = start_bottom
		
	# Reset letter animation if it exists
	var letter = get_tree().root.find_child("Letter", true, false)
	if letter and letter.has_method("reset_animation"):
		letter.reset_animation()
	
	var viewport_size = get_viewport().get_visible_rect().size
	var center_pos = viewport_size / 2
	
	# Center the UI cursor sprite before switching modes
	var ui_cursor = Player.instance.get_node_or_null("CanvasLayer/TextureRect")
	if ui_cursor:
		ui_cursor.position = center_pos - ui_cursor.size / 2
	
	# Switch to captured mode first
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	
	# Now warp the mouse to center while in captured mode
	get_viewport().warp_mouse(center_pos)
	await get_tree().process_frame
