extends Node

## Manages the collection of music notes in the maze
## Tracks when all 4 notes are collected and triggers the song display

signal all_notes_collected

var collected_notes: Dictionary = {}  # Stores which note numbers have been collected
var total_notes_needed: int = 4

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

func reset_collection():
	"""Resets the collection state (useful for testing or replay)"""
	collected_notes.clear()
