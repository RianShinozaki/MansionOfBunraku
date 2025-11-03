extends RigidBody3D

var NoteScene = preload("res://Objects/Items/music_note.tscn")
var note_sequence = []

var appeasement_sequence = [1,3,1,2]
var last_played: float = 0.0

func _process(delta: float) -> void:
	last_played += delta
	
func _physics_process(_delta: float) -> void:
	position = Vector3(0.2, -0.07, -0.2)  
	rotation_degrees = Vector3(0, 0, -35)
	scale = Vector3(0.5, 0.5, 1)

func append_note(note):
	note_sequence.append(note)
	last_played = 0.0
	
	var note_instance = NoteScene.instantiate()
	add_child(note_instance)
	note_instance.spawn_note(note)
	
	if note_sequence.size() > 4:
		note_sequence.pop_front()
	
	print(note_sequence)
	
	# if near a password puzzle:
		# if puzzle has get_password():
			# if note_sequence == puzzle.get_password():
				# PUZZLE.unlock()

func is_appeased() -> bool:
	return note_sequence == appeasement_sequence and last_played <= 3.0
