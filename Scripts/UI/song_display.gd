extends CanvasLayer

## Displays the song notes in the upper-left corner when all notes are collected
## Shows the background image with the note sequence "1221" overlaid

@onready var background: TextureRect = $Control/Background
@onready var note1: TextureRect = $Control/Background/Note1
@onready var note2: TextureRect = $Control/Background/Note2
@onready var note3: TextureRect = $Control/Background/Note3
@onready var note4: TextureRect = $Control/Background/Note4

var note_textures = {
	1: preload("res://Art Assets/note-one.png"),
	2: preload("res://Art Assets/note-two.png"),
	3: preload("res://Art Assets/note-three.png")
}

func _ready():
	# Initially hide the display
	hide_display()

func show_song_display():
	"""Shows the complete song display with notes in the pattern 1221"""
	# Set the note textures according to the pattern 1-2-2-1
	if note1 and note2 and note3 and note4:
		note1.texture = note_textures[1]
		note2.texture = note_textures[2]
		note3.texture = note_textures[2]
		note4.texture = note_textures[1]
	
	# Fade in the display
	background.modulate.a = 0.0
	background.visible = true
	
	var tween = get_tree().create_tween()
	tween.tween_property(background, "modulate:a", 1.0, 0.5)

func hide_display():
	"""Hides the display"""
	if background:
		background.visible = false
