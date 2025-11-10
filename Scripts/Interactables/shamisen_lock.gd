extends Node3D

@export var song_sequence: Array[int]
var note_sequence: Array[int]
var player_entered: bool
var locked: bool = true

signal unlock

func append_note(note):
	note_sequence.append(note)
	if note_sequence.size() > 4:
		note_sequence.pop_front()
	print(note_sequence)
	if locked and note_sequence == song_sequence:
		locked = false
		emit_signal("unlock")
		$FreedomSymbol.visible = false

func _on_area_3d_body_entered(_body: Node3D) -> void:
	player_entered = true
	Player.instance.played_note_signal.connect(append_note)
	
func _on_area_3d_body_exited(_body: Node3D) -> void:
	player_entered = false
	Player.instance.played_note_signal.disconnect(append_note)
	note_sequence.clear()
