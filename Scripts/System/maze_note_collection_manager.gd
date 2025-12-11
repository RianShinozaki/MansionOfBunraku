extends Node

## Manages the collection of music notes in the maze
## Tracks when all 4 notes are collected and triggers the song display

signal all_notes_collected

var collected_notes: Dictionary = {}  # Stores which note numbers have been collected
var total_notes_needed: int = 4
var kitsune_spawned: bool = false

var KitsuneScene = preload("res://Objects/Entities/kitsune.tscn")
var MazeCompletionDialogue = preload("res://Dialogue/maze_completion.tres")

func _ready():
	# Wait a frame for all nodes to be ready
	await get_tree().process_frame
	
	# Find all MazeNote nodes in the scene
	var maze_notes = get_tree().get_nodes_in_group("MazeNote")
	
	if maze_notes.size() == 0:
		push_warning("MazeNoteCollectionManager: No MazeNote nodes found in scene!")
		return
	
	# Connect to each note's signal
	for note in maze_notes:
		if note.has_signal("note_played"):
			note.note_played.connect(_on_note_played)

func _on_note_played(note_number: int, node_name: String):
	# Track that this note has been collected
	collected_notes[node_name] = note_number
	
	print("Note collected: %s (Note #%d). Total collected: %d/%d" % [node_name, note_number, collected_notes.size(), total_notes_needed])
	
	# Check if all notes have been collected
	if collected_notes.size() >= total_notes_needed:
		print("All notes collected! Displaying song...")
		emit_signal("all_notes_collected")
		
		# Spawn kitsune in front of player
		if not kitsune_spawned:
			print("Starting kitsune spawn...")
			kitsune_spawned = true
			spawn_kitsune_in_front_of_player()

func reset_collection():
	"""Resets the collection state (useful for testing or replay)"""
	collected_notes.clear()
	kitsune_spawned = false

func spawn_kitsune_in_front_of_player():
	"""Spawns the kitsune directly in front of the player"""
	
	# Get player reference
	var player = Player.instance
	if not player:
		push_error("Cannot spawn kitsune: Player not found!")
		return
	
	# Get player's camera to determine facing direction
	var camera = player.get_node_or_null("Camera3D")
	if not camera:
		push_error("Cannot spawn kitsune: Player camera not found!")
		return
	
	# Calculate spawn position in front of player
	var camera_pos = camera.global_position
	var player_pos = player.global_position
	var camera_forward = -camera.global_transform.basis.z  # Camera's forward direction
	var desired_spawn_distance = 1.2  # Desired distance in front of player
	var min_spawn_distance = 0.5  # Minimum distance to keep kitsune visible
	var spawn_buffer = 0.15  # Buffer to keep kitsune in front of obstacles
	
	# Perform raycast to check for obstacles
	var space_state = player.get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera_pos,
		camera_pos + camera_forward * desired_spawn_distance
	)
	
	var raycast_result = space_state.intersect_ray(ray_query)
	
	var spawn_distance = desired_spawn_distance
	
	# If we hit something, adjust spawn distance
	if not raycast_result.is_empty():
		var hit_distance = camera_pos.distance_to(raycast_result.position)
		print("Raycast hit obstacle at distance: ", hit_distance)
		
		# Spawn at 70% of the distance to the obstacle, but respect minimum distance
		var adjusted_distance = max(hit_distance * 0.7 - spawn_buffer, min_spawn_distance)
		spawn_distance = min(adjusted_distance, desired_spawn_distance)
		print("Adjusted spawn distance to: ", spawn_distance)
	
	# Calculate final spawn position
	var spawn_position = player_pos + camera_forward * spawn_distance
	spawn_position.y = 0.3  # Fixed height for kitsune
	
	print("Player pos: ", player_pos)
	print("Camera pos: ", camera_pos)
	print("Spawn pos: ", spawn_position)
	print("Spawn distance used: ", spawn_distance)
	
	# Freeze player movement to prevent them from moving away
	if player:
		player.active = false
	
	# Instantiate kitsune
	var kitsune_instance = KitsuneScene.instantiate()
	
	# Set the maze completion dialogue
	kitsune_instance.dialogue_data = MazeCompletionDialogue
	
	# Add to scene (add as sibling to this manager, which is child of the maze level)
	get_parent().add_child(kitsune_instance)
	
	print("Kitsune added to scene tree")
	
	# Position the kitsune
	kitsune_instance.global_position = spawn_position
	kitsune_instance.visible = true
	
	print("Kitsune positioned and made visible")
	print("Kitsune visible: ", kitsune_instance.visible)
	print("Kitsune position: ", kitsune_instance.global_position)
	
	# Wait a frame for the kitsune to be fully integrated into the scene tree
	await get_tree().process_frame
	
	# Start the dialogue sequence immediately
	kitsune_instance.start_maze_completion_sequence()
