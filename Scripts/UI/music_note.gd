extends Sprite3D

var notes = {}
var note_one = preload("res://Art Assets/note-one.png")
var note_two = preload("res://Art Assets/note-two.png")
var note_three = preload("res://Art Assets/note-three.png")

var time: float = 0.5

func _ready():
	notes = {
		1: [note_one, $string_one],
		2: [note_two, $string_two],
		3: [note_three, $string_three]
	}
	
	transform.origin = Vector3(randf_range(-0.5,0.5), randf_range(-0.5,0.5), 0.0)  
	scale = Vector3(0.25, 0.25, 1)

func _process(delta: float) -> void:
	time -= delta
	
	if time <= 0:
		queue_free()

func spawn_note(note: int, play_note: bool):
	self.texture = notes[note][0]
	if play_note: notes[note][1].play()

func set_spawn_time(spawn_time: int):
	time = spawn_time
