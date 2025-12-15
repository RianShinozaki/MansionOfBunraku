extends BunrakuManagerCBody

@export var body_offset: Vector3
@export var time_between_turns: float
@export var looking_forward: bool

@export var normal_light_color: Color
@export var evil_light_color: Color

@export var sake_games: Array[DrunkYoroiGame] 
@export var drunkness: float
@export var max_drunkenness: float

@export var dialogue_data: DialogueData
var NoteScene = preload("res://Objects/Items/music_note.tscn")

var song_sequence: Array[int]
var turn_time_counter: float
var physics_delta: float
var orig_y: float
var active: bool = false
var jumpscaring: bool = false

signal movement_ready

func _ready() -> void:
	orig_y = global_position.y
	active = true
	song_sequence = Player.SONG_OF_FATE
	looking_forward = false
	$Yoroi.visible = false
	$Yoroi.active = false
	$YoroiBackside.visible = true
	$"../../Objects/Chandelier/OmniLight3D".light_color = normal_light_color
	

func _physics_process(_delta):
	
	
	
	if not active: return
	$Yoroi.position = Vector3(0,0,0)
	
	turn_time_counter += _delta
	if turn_time_counter >= time_between_turns:
		turn_time_counter = 0
		light_flicker()
		await movement_ready
		if looking_forward:
			looking_forward = false
			$Yoroi.visible = false
			$Yoroi.active = false
			$YoroiBackside.visible = true
			$"../../Objects/Chandelier/OmniLight3D".light_color = normal_light_color
			$Yoroi/Feedback2.stop()
			
			var _sake_games_filled: Array[DrunkYoroiGame]
			for game in sake_games:
				if game.get_node("SakazukiCup").current_fill_level > 0:
					_sake_games_filled.append(game)
			
			if _sake_games_filled.is_empty():
				position.z = randf_range(-1.4, -6.4)
				position.x = randf_range(1, 5)	
				$YoroiBackside/Body.frame = 0
			else:
				_sake_games_filled.shuffle()
				var _the_game: DrunkYoroiGame = _sake_games_filled[0]
				global_position.z = _the_game.global_position.z
				global_position.x = _the_game.global_position.x
				position = position.move_toward( Vector3(3.193, 0.373, -4.598), 0.6 )
				drunkness += _the_game.get_node("SakazukiCup").current_fill_level
				$Slurp.play()
				_the_game.get_node("SakazukiCup").empty_cup()
				Player.instance.set_drunken_level_tweened(drunkness/20)
				$YoroiBackside/Body.frame = 1
				_the_game.visible = false
				_the_game.remove_from_group("Interactable")
				if _the_game.current_state != DrunkYoroiGame.GameState.HIDDEN:
					print("force exit inspect")
					InspectionManager.exit_inspect()
		else:
			if drunkness < max_drunkenness:
				looking_forward = true
				$Yoroi.visible = true
				$Yoroi.active = true
				$YoroiBackside.visible = false
				$"../../Objects/Chandelier/OmniLight3D".light_color = evil_light_color
				$Yoroi/Feedback2.play()
				for game in sake_games:
					game.visible = true
					game.add_to_group("Interactable")
			else:
				active = false
				$YoroiBackside.visible = false
				for game in sake_games:
					game.visible = true
					game.add_to_group("Interactable")
				$YoroiFloored.visible = true
				Player.instance.set_drunken_level_tweened(0)
				Player.instance.get_node("Camera3D").shaking = true
				$Collapse.play()
				await get_tree().create_timer(0.2).timeout
				Player.instance.get_node("Camera3D").shaking = false
				
				await get_tree().create_timer(4).timeout
				$Yoroi.appearance_update()
				$"../../Objects/Yono".visible = true
				$"../../Objects/Yono/CollisionShape3D".disabled = false
				$"../../Objects/YonoPainting".switch_to_alt_tex()
				
				await get_tree().create_timer(4).timeout
				var _dialogue_box: DialogueBox = DialogueBox.instance
				_dialogue_box.data = dialogue_data
				_dialogue_box.start("thankyou")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
				await _dialogue_box.dialogue_ended
				
				give_song_of_fate()
				
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				InspectionManager.current_mode = InspectionManager.Mode.PLAY
				
	#Drunken shuffling
	velocity.z += randf_range(-drunkness * 0.01, drunkness * 0.01)
	velocity.x += randf_range(-drunkness * 0.01, drunkness * 0.01)
	
	velocity.z = clamp(velocity.z, -drunkness*0.4, drunkness*0.4)
	velocity.x = clamp(velocity.x, -drunkness*0.4, drunkness*0.4)
	
	move_and_slide()
					
func light_flicker():
	var _distance_to_player = global_position.distance_to(Player.instance.global_position)
	var _do_light_flicker: bool = false
	if _distance_to_player < 4.5:
		_do_light_flicker = true
		
	if _do_light_flicker:
		var lights: Array = get_tree().get_nodes_in_group("Light")
		for _light in lights:
			get_tree().create_tween().tween_property(_light, "energy_median", 0, 0.1)
	get_tree().create_tween().tween_property($Yoroi/Body/BlackFade, "modulate", Color.BLACK, 0.05)
	
	await get_tree().create_timer(0.15).timeout
	emit_signal("movement_ready")
	
	if _do_light_flicker:
		var lights: Array = get_tree().get_nodes_in_group("Light")
		for _light in lights:
			get_tree().create_tween().tween_property(_light, "energy_median", 1.5, 0.2)
	
	#if _distance_to_player < 3:
	get_tree().create_tween().tween_property($Yoroi/Body/BlackFade, "modulate", Color(0, 0, 0, 0), 0.2)
		
func jumpscare():
	jumpscaring = true
	$Yoroi.top_level = false
	$Yoroi.global_transform.origin = global_transform.origin + body_offset
	super.jumpscare()

func give_song_of_fate():
	
	# Get reference to player's camera for spawning notes
	var player = Player.instance
	if not player:
		push_warning("Player instance not found, cannot spawn music notes")
		return
	
	var camera = player.get_node("Camera3D")
	if not camera:
		push_warning("Player camera not found, cannot spawn music notes")
		return
	
	# Spawn all notes in the song sequence [3, 3, 3, 1]
	var note_index = 0
	for note_value in song_sequence:
		var note_instance = NoteScene.instantiate()
		
		# Hide note initially to prevent flash at wrong position
		note_instance.visible = false
		
		camera.add_child(note_instance)
		
		# Wait for _ready() to complete
		await get_tree().process_frame
		
		# Now set the correct position, scale, and rotation (overriding values from _ready())
		note_instance.position = Vector3((note_index - 1.5) * 0.15, 0, -0.3)
		note_instance.scale = Vector3(0.1, 0.1, 1)  # Smaller scale
		note_instance.rotation_degrees = Vector3(0, 0, 0)  # Make notes straight, not rotated
		
		# Make visible now that position is correct
		note_instance.visible = true
		# Show note visuals with playing audio)
		note_instance.spawn_note(note_value, true)
		note_index += 1
		
		# Half second delay between notes
		await get_tree().create_timer(0.5).timeout
	
	# Add song to Music Memory UI
	var song_ui = player.get_node_or_null("CanvasLayer/Music Memory/SongOfFate")
	if song_ui:
		song_ui.visible = true
		song_ui.modulate.a = 1.0  # Set to fully visible immediately
		
	# Mark the song as acquired so it can be played
	Player.song_of_fate_acquired = true
