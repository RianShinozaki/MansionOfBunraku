@tool
extends StaticBody3D

## Interactive music note that can be placed in the maze
## Plays once when clicked or walked over, then becomes inactive

signal note_played(note_number: int, node_name: String)

@export_range(1, 3) var note_number: int = 1:
	set(value):
		note_number = value
		_update_note_visuals()

var note_textures = {}
var note_audio = {}
var has_been_played: bool = false
var is_on_cooldown: bool = false

@onready var sprite: Sprite3D = $NoteSprite
@onready var area: Area3D = $WalkOverArea
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func _update_note_visuals():
	# This function updates the sprite texture based on the note_number
	# It works both in the editor and at runtime
	
	# Load note textures if not already loaded
	if note_textures.is_empty():
		note_textures = {
			1: preload("res://Art Assets/note-one.png"),
			2: preload("res://Art Assets/note-two.png"),
			3: preload("res://Art Assets/note-three.png")
		}
	
	# Get sprite node - need to handle both editor and runtime contexts
	var sprite_node = get_node_or_null("NoteSprite")
	if not sprite_node:
		return
	
	# Update the sprite texture
	if note_number in note_textures:
		sprite_node.texture = note_textures[note_number]

func _ready():
	# Don't run gameplay logic in editor mode
	if Engine.is_editor_hint():
		return
	
	add_to_group("Interactable")
	add_to_group("MazeNote")
	
	# Load textures and audio resources
	note_textures = {
		1: preload("res://Art Assets/note-one.png"),
		2: preload("res://Art Assets/note-two.png"),
		3: preload("res://Art Assets/note-three.png")
	}
	
	note_audio = {
		1: preload("res://Audio/string-one.mp3"),
		2: preload("res://Audio/string-two.mp3"),
		3: preload("res://Audio/string-three.mp3")
	}
	
	# Set the correct texture based on note_number
	if sprite and note_number in note_textures:
		sprite.texture = note_textures[note_number]
	
	# Set the correct audio stream
	if audio_player and note_number in note_audio:
		audio_player.stream = note_audio[note_number]
	
	# Connect area signal for walkover detection
	if area:
		area.body_entered.connect(_on_body_entered)

func can_interact() -> bool:
	# Only interactable if not played yet and in PLAY mode
	return not has_been_played and InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact():
	# Called when player clicks on the note
	if not has_been_played and not is_on_cooldown:
		play_note()

func _on_body_entered(body: Node3D):
	# Called when player walks over the note
	if body is Player and not has_been_played and not is_on_cooldown:
		play_note()

func play_note():
	if has_been_played or is_on_cooldown:
		return
	
	has_been_played = true
	is_on_cooldown = true
	
	# Emit signal for note collection manager
	emit_signal("note_played", note_number, name)
	
	# Play the audio
	if audio_player:
		audio_player.play()
	
	# Spawn the visual note in front of camera
	spawn_visual_note()
	
	# Visual feedback: make the sprite completely disappear
	if sprite:
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
		# Optionally hide the sprite after the fade animation
		tween.tween_callback(func(): sprite.visible = false)
	
	# Brief cooldown to prevent double-triggering
	await get_tree().create_timer(0.5).timeout
	is_on_cooldown = false

func spawn_visual_note():
	# Get player's camera
	var player = Player.instance
	if not player:
		return
	
	var camera = player.get_node_or_null("Camera3D")
	if not camera:
		return
	
	# Instantiate the visual note scene
	var note_scene = preload("res://Objects/Items/music_note.tscn")
	var visual_note = note_scene.instantiate()
	
	# Add as child of camera so it appears in front of player
	camera.add_child(visual_note)
	
	# Tell it which note to display
	visual_note.spawn_note(note_number)
