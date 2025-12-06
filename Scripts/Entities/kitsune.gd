class_name Kitsune

extends AnimatableBody3D

@export var dialogue_data: DialogueData

@onready var body_sprite: Sprite3D = $Body
@onready var head_sprite: Sprite3D = $Body/Head

var has_interacted: bool = false
var is_fading: bool = false
var is_sake_completion: bool = false
var note_parent: Node3D = null  # Parent node for spawning music notes
var dialogue_triggered: bool = false

var NoteScene = preload("res://Objects/Items/music_note.tscn")

func _ready() -> void:
	# Don't add to interactable group - we auto-trigger instead
	
	# Start in normal mode
	set_normal_mode()
	
	# Auto-trigger intro dialogue after a brief delay (to ensure everything is loaded)
	if not is_sake_completion:
		# Lock the player in place until dialogue starts
		if Player.instance:
			Player.instance.active = false
		
		await get_tree().create_timer(0.5).timeout
		_trigger_intro_dialogue()

func _process(_delta: float) -> void:
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
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
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
		
		# Disappear after giving notes
		queue_free()

func give_music_notes():
	"""Spawn note-one then note-two as a reward"""
	# Wait a brief moment before spawning notes
	await get_tree().create_timer(0.3).timeout
	
	# Get reference to player's camera for spawning notes (ensures they're always visible)
	var player = Player.instance
	if not player:
		push_warning("Player instance not found, cannot spawn music notes")
		return
	
	var camera = player.get_node("Camera3D")
	if not camera:
		push_warning("Player camera not found, cannot spawn music notes")
		return
	
	# Spawn note-one (1) then note-two (2) as children of camera
	var note_values = [1, 2]
	for note_value in note_values:
		var note_instance = NoteScene.instantiate()
		camera.add_child(note_instance)
		note_instance.spawn_note(note_value)
		
		# Slight delay between notes
		await get_tree().create_timer(0.25).timeout
