extends Area3D

var note_sequence: Array[int]
var player_entered: bool
var locked: bool = true

signal unlock

func _ready() -> void:
	body_entered.connect(_on_area_3d_body_entered)
	body_exited.connect(_on_area_3d_body_exited)
	
func append_note(note):
	note_sequence.append(note)
	if note_sequence.size() > 4:
		note_sequence.pop_front()
	print("Clock listener note sequence: ", note_sequence)
	if locked and note_sequence == Player.SONG_OF_TIME_TRAVEL:
		locked = false
		emit_signal("unlock")
		# Hide the symbol
		$Symbol.visible = false
		
		# Mark song as acquired (persists across room reloads)
		Player.song_of_time_travel_acquired = true
		
		# Update music memory UI: show Song of Time Travel
		var player = Player.instance
		if player:
			var time_travel_ui = player.get_node_or_null("CanvasLayer/Music Memory/SongOfTimeTravel")
			if time_travel_ui:
				time_travel_ui.visible = true
				time_travel_ui.modulate.a = 1.0
				print("Clock: Showing SongOfTimeTravel UI")
			else:
				push_warning("Clock: SongOfTimeTravel UI node not found in Player scene!")
		
		# Trigger the clock's time vortex effect
		var clock = get_parent()
		if clock and clock.has_method("trigger_time_vortex"):
			clock.trigger_time_vortex()
		
func _on_area_3d_body_entered(_body: Node3D) -> void:
	player_entered = true
	Player.instance.played_note_signal.connect(append_note)
	
func _on_area_3d_body_exited(_body: Node3D) -> void:
	player_entered = false
	Player.instance.played_note_signal.disconnect(append_note)
	note_sequence.clear()
