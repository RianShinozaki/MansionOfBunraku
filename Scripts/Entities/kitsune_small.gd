extends Node3D

@onready var play_sprite: Sprite3D = $PlaySprite
@onready var dialogue_sprite: Sprite3D = $DialogueSprite

@export var dialogue_id: String
@export var environmental_dialogues: DialogueData

var first_viewing: bool = true
@export var inspect_fov: float = 40.0
@onready var focus_marker: Node3D = $FocusMarker

func _ready():
	set_play_mode()

func set_play_mode():
	if play_sprite and dialogue_sprite:
		play_sprite.visible = true
		dialogue_sprite.visible = false

func set_dialogue_mode():
	if play_sprite and dialogue_sprite:
		play_sprite.visible = false
		dialogue_sprite.visible = true

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
	# Called when artwork is clicked during inspection mode
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	set_dialogue_mode()
	
	if dialogue_id != "":
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = environmental_dialogues
		_dialogue_box.start(dialogue_id)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.INSPECT
	
		
		# Exit inspect mode after switching
		if InspectionManager:
			InspectionManager.exit_inspect()
			set_play_mode()
		return  # Exit after switching texture
