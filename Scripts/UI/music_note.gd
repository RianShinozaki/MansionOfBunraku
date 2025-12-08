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
	
	# Position centered in front of camera with slight random variation
	position = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), -0.3)  
	rotation_degrees = Vector3(0, 0, 35)
	scale = Vector3(0.25, 0.25, 1)

func _process(delta: float) -> void:
	time -= delta
	
	if time <= 0:
		queue_free()

func spawn_note(note: int):
	self.texture = notes[note][0]
	notes[note][1].play()
