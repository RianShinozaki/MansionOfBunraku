extends StaticBody3D

@export var dialogue_id: String
@export var environmental_dialogues: DialogueData

var first_viewing: bool = true
@export var inspect_fov: float = 20.0
@onready var focus_marker: Node3D = $FocusMarker

@export var left_table: FruitTable
@export var right_table: FruitTable

#func check_offerings():
	#if not left_table.has_fruit or not right_table.has_fruit:
		#return false  # One or both tables empty
#
	#if left_table.fruit_type == "apple" and right_table.fruit_type == "peach":
		#print("Both offerings are correct")
		#return true
	#else:
		#print("Offerings incorrect. Left:", left_table.fruit_type, "Right:", right_table.fruit_type)
		#return false

func can_interact() -> bool:
	return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact():
	# Enter inspection mode using InspectionManager
	if focus_marker and InspectionManager:
		InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
		get_viewport().set_input_as_handled()
		
		#dialogue_id = "left_submission" if randf() > 0.5 else "right_submission"
		if left_table.has_fruit and right_table.has_fruit:
			if  left_table.fruit_type == "apple" and right_table.fruit_type == "peach":
				dialogue_id = "success"
			else: 
				dialogue_id = "failure"
			
		await get_tree().create_timer(0.1).timeout
		if dialogue_id != "" and first_viewing:
			#first_viewing = false
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
			
		return  # Exit after switching texture
