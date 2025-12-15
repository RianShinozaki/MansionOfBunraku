extends Node3D
var dialogue_data: DialogueData

func _ready() -> void:
	$DoorOpenTrigger.body_entered.connect(on_body_entered)
	
func on_body_entered(_body: Node3D):
	var _dialogue_box: DialogueBox = DialogueBox.instance
	_dialogue_box.data = dialogue_data
	_dialogue_box.start("yoroi")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
	await _dialogue_box.dialogue_ended
	
	Player.instance.fade_from_white()
	visible = true
	$Rattle.play()
	$Breathe.play()
	$Feedback.play()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InspectionManager.current_mode = InspectionManager.Mode.PLAY
