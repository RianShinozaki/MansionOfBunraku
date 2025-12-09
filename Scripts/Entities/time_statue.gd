class_name TimeStatue

extends AnimatableBody3D

@export var dialogue_data: DialogueData
@export var auto_trigger_dialogue: bool = false  # Set to true to auto-trigger like kitsune
@export var dialogue_id: String = "time_statue_intro"
@export var inspect_fov: float = 50.0  # Increased from 20.0 to see the statue better
@export var song_sequence: Array[int] = [3, 3, 3, 1]  # Song of Stillness

@onready var body_sprite: Sprite3D = $Body
@onready var focus_marker: Node3D = $FocusMarker

var NoteScene = preload("res://Objects/Items/music_note.tscn")

var has_interacted: bool = false
var dialogue_triggered: bool = false
var song_given: bool = false

func _get_dialogue_box() -> DialogueBox:
	"""Helper function to get DialogueBox instance with fallbacks"""
	print("TimeStatue: _get_dialogue_box() called")
	var dialogue_box: DialogueBox = DialogueBox.instance
	print("TimeStatue: DialogueBox.instance = ", dialogue_box)
	if dialogue_box:
		print("TimeStatue: Using DialogueBox.instance")
		return dialogue_box
	
	# Fallback 1: Try to find in scene tree by traversing up to Game node
	print("TimeStatue: Trying to find DialogueBox in scene tree...")
	var current = self
	var path_to_root = []
	while current:
		path_to_root.append(current.name)
		if current.name == "Game":
			var db = current.get_node_or_null("CanvasLayer/DialogueBox") as DialogueBox
			if db:
				print("TimeStatue: Found DialogueBox via Game node traversal")
				return db
		current = current.get_parent()
	print("TimeStatue: Path to root: ", path_to_root)
	
	# Fallback 2: Try absolute path from root
	print("TimeStatue: Trying absolute path from root...")
	var root = get_tree().root
	print("TimeStatue: Root node name: ", root.name if root else "null")
	
	# Try different possible paths
	var possible_paths = [
		"/root/Game/CanvasLayer/DialogueBox",
		"Game/CanvasLayer/DialogueBox",
		"../CanvasLayer/DialogueBox",
		"../../CanvasLayer/DialogueBox",
		"../../../CanvasLayer/DialogueBox"
	]
	
	for path in possible_paths:
		dialogue_box = get_node_or_null(path) as DialogueBox
		if dialogue_box:
			print("TimeStatue: Found DialogueBox via path: ", path)
			return dialogue_box
	
	# Fallback 3: Search entire tree recursively
	print("TimeStatue: Searching entire tree recursively...")
	var found = _find_dialogue_box_recursive(get_tree().root)
	if found:
		print("TimeStatue: Found DialogueBox via recursive search")
		return found
	
	# Fallback 4: Try to find Game node first, then DialogueBox
	print("TimeStatue: Looking for Game node...")
	var game_node = _find_node_by_name_recursive(get_tree().root, "Game")
	if game_node:
		print("TimeStatue: Found Game node, looking for DialogueBox...")
		var db = game_node.get_node_or_null("CanvasLayer/DialogueBox") as DialogueBox
		if db:
			print("TimeStatue: Found DialogueBox in Game/CanvasLayer/DialogueBox")
			return db
	
	push_error("DialogueBox instance not found! Make sure DialogueBox exists in the scene.")
	return null

func _find_node_by_name_recursive(node: Node, name_to_find: String) -> Node:
	"""Recursively search for a node by name"""
	if node.name == name_to_find:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name_recursive(child, name_to_find)
		if result:
			return result
	
	return null

func _find_dialogue_box_recursive(node: Node) -> DialogueBox:
	"""Recursively search for DialogueBox in the scene tree"""
	if node is DialogueBox:
		print("TimeStatue: Found DialogueBox at path: ", node.get_path())
		return node as DialogueBox
	
	for child in node.get_children():
		var result = _find_dialogue_box_recursive(child)
		if result:
			return result
	
	return null

func _ready() -> void:
	# Add to Interactable group for player interaction
	add_to_group("Interactable")
	print("TimeStatue _ready() called - added to Interactable group")
	
	# Auto-trigger dialogue if enabled
	if auto_trigger_dialogue:
		# Lock the player in place until dialogue starts
		if Player.instance:
			Player.instance.active = false
		
		await get_tree().create_timer(0.5).timeout
		_trigger_intro_dialogue()



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
		var _dialogue_box: DialogueBox = _get_dialogue_box()
		if _dialogue_box:
			_dialogue_box.data = dialogue_data
			_dialogue_box.start("kitsune_intro")  # TODO: Change to statue-specific dialogue ID
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
			await _dialogue_box.dialogue_ended
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			InspectionManager.current_mode = InspectionManager.Mode.PLAY

func can_interact() -> bool:
	"""Only allow interaction when in PLAY mode"""
	var can = InspectionManager.current_mode == InspectionManager.Mode.PLAY
	print("TimeStatue can_interact: ", can, " (current_mode: ", InspectionManager.current_mode, ")")
	return can

func on_interact():
	"""Enter inspection mode when clicked in play mode"""
	print("TimeStatue on_interact() called!")
	if not focus_marker:
		push_error("TimeStatue: focus_marker is null!")
		return
	if not InspectionManager:
		push_error("TimeStatue: InspectionManager is null!")
		return
	
	InspectionManager.enter_inspect(self, focus_marker, inspect_fov)
	get_viewport().set_input_as_handled()
	
	await get_tree().create_timer(0.1).timeout
	print("TimeStatue: dialogue_id='", dialogue_id, "', dialogue_data=", dialogue_data)
	if dialogue_id != "" and dialogue_data:
		print("TimeStatue: Getting dialogue box...")
		var _dialogue_box: DialogueBox = _get_dialogue_box()
		if _dialogue_box:
			print("TimeStatue: DialogueBox found! Setting data and starting dialogue...")
			_dialogue_box.data = dialogue_data
			_dialogue_box.start(dialogue_id)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
			print("TimeStatue: Waiting for dialogue to end...")
			await _dialogue_box.dialogue_ended
			print("TimeStatue: Dialogue ended!")
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			
			# Set mode back to INSPECT so exit_inspect can work
			InspectionManager.current_mode = InspectionManager.Mode.INSPECT
			
			# Exit inspection mode immediately after dialogue ends
			if InspectionManager:
				InspectionManager.exit_inspect()
			
			# Give the song automatically after dialogue ends
			if not song_given:
				await give_song_of_stillness()
			
			# Disappear after giving the song
			queue_free()
		else:
			push_error("TimeStatue: DialogueBox not found!")
	else:
		print("TimeStatue: Skipping dialogue - dialogue_id='", dialogue_id, "', dialogue_data=", dialogue_data)
		# If no dialogue, still give the song and exit
		if not song_given:
			await give_song_of_stillness()
		if InspectionManager:
			InspectionManager.exit_inspect()
		queue_free()

func on_inspect_click():
	"""Called when statue is clicked during inspection mode - gives the song"""
	if InspectionManager.current_mode != InspectionManager.Mode.INSPECT:
		return
	
	if song_given:
		return  # Already gave the song
	
	# Give the song
	await give_song_of_stillness()
	
	# Exit inspection mode
	if InspectionManager:
		InspectionManager.exit_inspect()
	
	# Disappear after giving the song
	queue_free()

func give_song_of_stillness():
	"""Spawn all 4 music notes for Song of Stillness and add to Music Memory UI"""
	if song_given:
		return
	
	song_given = true
	
	# Wait a brief moment before spawning notes
	await get_tree().create_timer(0.3).timeout
	
	# Get reference to player's camera for spawning notes
	var player = Player.instance
	if not player:
		push_warning("Player instance not found, cannot spawn music notes")
		return
	
	var camera = player.get_node("Camera3D")
	if not camera:
		push_warning("Player camera not found, cannot spawn music notes")
		return
	
	# Spawn all notes in the song sequence [3, 3, 3, 1]
	var note_index = 0
	for note_value in song_sequence:
		var note_instance = NoteScene.instantiate()
		
		# Hide note initially to prevent flash at wrong position
		note_instance.visible = false
		
		camera.add_child(note_instance)
		
		# Wait for _ready() to complete
		await get_tree().process_frame
		
		# Now set the correct position, scale, and rotation (overriding values from _ready())
		note_instance.position = Vector3((note_index - 1.5) * 0.15, 0, -0.3)
		note_instance.scale = Vector3(0.1, 0.1, 1)  # Smaller scale
		note_instance.rotation_degrees = Vector3(0, 0, 0)  # Make notes straight, not rotated
		
		# Make visible now that position is correct
		note_instance.visible = true
		# Show note visuals with playing audio)
		note_instance.spawn_note(note_value, true)
		note_index += 1
		
		# Half second delay between notes
		await get_tree().create_timer(0.5).timeout
	
	# Add song to Music Memory UI
	var song_ui = player.get_node_or_null("CanvasLayer/Music Memory/SongOfStillness")
	if song_ui:
		print("TimeStatue: Found SongOfStillness UI, making it visible...")
		song_ui.visible = true
		song_ui.modulate.a = 1.0  # Set to fully visible immediately
		print("TimeStatue: SongOfStillness visible=", song_ui.visible, ", modulate.a=", song_ui.modulate.a)
	else:
		push_warning("TimeStatue: SongOfStillness UI node not found in Player scene!")
		print("TimeStatue: Tried to find path: CanvasLayer/Music Memory/SongOfStillness")
		if player:
			print("TimeStatue: Player node path: ", player.get_path())
		else:
			print("TimeStatue: Player is null")
	
	# Mark the song as acquired so it can be played
	Player.song_of_stillness_acquired = true
	print("TimeStatue: Song of Stillness marked as acquired!")
