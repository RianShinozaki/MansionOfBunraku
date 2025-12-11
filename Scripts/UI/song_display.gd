extends CanvasLayer

## Displays the song notes in the upper-left corner when all notes are collected
## Now matches the Music Memory format with all 4 songs

@onready var song_of_freedom: Control = $Control/SongOfFreedom
@onready var song_of_matrimony: Control = $Control/SongOfMatrimony
@onready var song_of_stillness: Control = $Control/SongOfStillness
@onready var song_of_time_travel: Control = $Control/SongOfTimeTravel

func _ready():
	# Initially hide all displays
	hide_display()

func show_song_display():
	"""Shows the Song of Time Travel display in the upper-left corner"""
	# Mark song as acquired and update player's Music Memory
	Player.song_of_time_travel_acquired = true
	
	var player = Player.instance
	if player:
		var player_time_travel_ui = player.get_node_or_null("CanvasLayer/Music Memory/SongOfTimeTravel")
		if player_time_travel_ui:
			player_time_travel_ui.visible = true
			player_time_travel_ui.modulate.a = 1.0
			print("SongDisplay: Set player Music Memory SongOfTimeTravel visible")
	
	# Show only Song of Time Travel in this display
	if song_of_time_travel:
		song_of_time_travel.modulate.a = 0.0
		song_of_time_travel.visible = true
		
		var tween = get_tree().create_tween()
		tween.tween_property(song_of_time_travel, "modulate:a", 1.0, 0.5)

func hide_display():
	"""Hides all song displays"""
	if song_of_freedom:
		song_of_freedom.visible = false
	if song_of_matrimony:
		song_of_matrimony.visible = false
	if song_of_stillness:
		song_of_stillness.visible = false
	if song_of_time_travel:
		song_of_time_travel.visible = false
