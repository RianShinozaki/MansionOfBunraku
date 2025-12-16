extends Node3D

@export var dialogue_data: DialogueData
@export var dialogue_id: String

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact():
	var _dialogue_box: DialogueBox = DialogueBox.instance
	_dialogue_box.data = dialogue_data
	_dialogue_box.start(dialogue_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
	await _dialogue_box.dialogue_ended
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InspectionManager.current_mode = InspectionManager.Mode.PLAY
