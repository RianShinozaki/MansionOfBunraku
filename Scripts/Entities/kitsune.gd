class_name Kitsune

extends AnimatableBody3D

@export var dialogue_data: DialogueData

@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

var has_interacted: bool = false
var is_fading: bool = false
var is_sake_completion: bool = false
var is_maze_completion: bool = false
var note_parent: Node3D = null  # Parent node for spawning music notes
var dialogue_triggered: bool = false

var NoteScene = preload("res://Objects/Items/music_note.tscn")

signal kitsune_talk_over

func _ready() -> void:
	# Don't add to interactable group - we auto-trigger instead
	
	# Start in normal mode
	set_normal_mode()
	

func _process(_delta: float) -> void:
	
	if(Player.instance.active and Player.instance.global_position.z < -9.058):
		if not is_sake_completion and not is_maze_completion:
			_trigger_intro_dialogue()
	
	# Switch frames based on current inspection mode
	if InspectionManager.current_mode == InspectionManager.Mode.DIALOGUE:
		set_dialogue_mode()
	else:
		set_normal_mode()

func set_normal_mode() -> void:
	"""Display normal appearance (frames 0 and 1)"""
	if head_sprite:
		head_sprite.frame = 0
	if body_sprite:
		body_sprite.frame = 1

func set_dialogue_mode() -> void:
	"""Display dialogue appearance (frames 2 and 3)"""
	if head_sprite:
		head_sprite.frame = 2
	if body_sprite:
		body_sprite.frame = 3

func _trigger_intro_dialogue() -> void:
	"""Automatically start the intro dialogue"""
	if dialogue_triggered:
		return
		
	dialogue_triggered = true
	has_interacted = true
	
	# Unlock the player when dialogue starts
	if Player.instance:
		Player.instance.active = true
	
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("kitsune_intro")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		Player.instance.active = true
		emit_signal("kitsune_talk_over")
		# Disappear immediately after dialogue
		queue_free()

func start_sake_completion_sequence():
	"""Called when sake ritual is completed"""
	is_sake_completion = true
	has_interacted = false  # Allow automatic interaction
	
	# Start dialogue immediately
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("sake_completion")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
		# Give player 2 random music notes
		await give_music_notes()
		
		if is_in_group("Interactable"):
			remove_from_group("Interactable")
		# Disappear after giving notes
		# queue_free()

func start_maze_completion_sequence():
	"""Called when all maze notes are collected"""
	is_maze_completion = true
	dialogue_triggered = true
	has_interacted = true
	
	# Ensure sprites are visible and set to normal mode
	# Use get_node since @onready variables might not be ready yet
	visible = true
	var body = get_node_or_null("Body")
	if body:
		body.visible = true
		body.frame = 1
		print("Kitsune body sprite visible: ", body.visible, " frame: ", body.frame)
		
		var head = body.get_node_or_null("Head")
		if head:
			head.visible = true
			head.frame = 0
			print("Kitsune head sprite visible: ", head.visible, " frame: ", head.frame)
	else:
		print("ERROR: Could not find Body node!")
	
	print("Kitsune node visible: ", visible)
	print("Kitsune global position: ", global_position)
	
	# Wait just one frame to ensure kitsune is fully integrated before starting dialogue
	await get_tree().process_frame
	
	# Start dialogue immediately
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("maze_completion")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
		if Player.instance:
			Player.instance.active = true
		
		# Disappear after dialogue
		queue_free()

func give_music_notes():
	"""Spawn note-one then note-two as a reward"""
	# Wait a brief moment before spawning notes
	await get_tree().create_timer(0.3).timeout
	
	while(true):
		var note_instance = NoteScene.instantiate()
		add_child(note_instance)
		note_instance.spawn_note(1, false)
		note_instance.transform.origin.x -= 0.2
		# Slight delay between notes
		await get_tree().create_timer(0.25).timeout
		
		note_instance = NoteScene.instantiate()
		add_child(note_instance)
		note_instance.spawn_note(2, false)
		note_instance.transform.origin.x += 0.2
		note_instance.transform.origin.y += 0.1
		# Slight delay between notes
		await get_tree().create_timer(0.25).timeout
