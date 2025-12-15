extends Node3D
@export var dialogue_data: DialogueData

func _ready() -> void:
	$DoorOpenTrigger.body_entered.connect(on_body_entered)
	$VaultEnterTrigger.body_entered.connect(on_vault_entered)
	
func on_body_entered(_body: Node3D):
	var _dialogue_box: DialogueBox = DialogueBox.instance
	_dialogue_box.data = dialogue_data
	_dialogue_box.start("yoroi")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
	await _dialogue_box.dialogue_ended
	
	Player.instance.fade_from_white()
	visible = true
	$AudioStreamPlayer.play()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InspectionManager.current_mode = InspectionManager.Mode.PLAY
	
	$DoorOpenTrigger/CollisionShape3D.disabled = true
	$StaticBody3D2/CollisionShape3D.disabled = false
	
	$"../FreedomDoors".visible = true
	$"../FreedomDoors/Area3D/CollisionShape3D".disabled = false

func on_vault_entered(_body: Node3D):
	Player.instance.fade_to_white()
	await Player.instance.fade_complete
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Maps/Ending.tscn")
