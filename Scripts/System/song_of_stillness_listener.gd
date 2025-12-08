extends Node

## Listens for the Song of Stillness sequence [3, 3, 3, 1] and triggers the black/white effect
## This is a global listener that works anywhere in the game

var note_sequence: Array[int] = []
var song_sequence: Array[int] = [3, 3, 3, 1]
var connected: bool = false

func _ready() -> void:
	# Wait a frame for Player.instance to be set
	await get_tree().process_frame
	_connect_to_player()

func _connect_to_player() -> void:
	if connected:
		return
		
	if Player.instance:
		Player.instance.played_note_signal.connect(_on_note_played)
		connected = true
	else:
		# Try again next frame if player isn't ready yet
		await get_tree().process_frame
		_connect_to_player()

func _on_note_played(note: int) -> void:
	# Only listen for the song if it has been acquired from the statue
	if not Player.song_of_stillness_acquired:
		return
	
	note_sequence.append(note)
	if note_sequence.size() > 4:
		note_sequence.pop_front()
	
	# Check if sequence matches Song of Stillness
	if note_sequence == song_sequence:
		# Trigger the black/white effect on the player
		if Player.instance:
			Player.instance.apply_black_white_effect(3.0)

