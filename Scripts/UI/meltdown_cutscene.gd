extends Node3D

var tween: Tween

func _ready() -> void:
	$"CanvasLayer2/Left click to skip".visible = false

func _on_dialogue_box_dialogue_ended() -> void:
	$AnimationPlayer.play("end_cutscene")

func end_cutscene() -> void:
	get_tree().change_scene_to_file("res://Maps/Game.tscn")
	
func _unhandled_input(event: InputEvent) -> void:
	if $AnimationPlayer.is_playing() and $AnimationPlayer.current_animation == "cutscene" and $AnimationPlayer.current_animation_position < 20:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Mark input as handled immediately to prevent re-processing on Mac
			get_viewport().set_input_as_handled()
			
			if $"CanvasLayer2/Left click to skip".visible == false:
				$"CanvasLayer2/Left click to skip".visible = true
				var timer: SceneTreeTimer = get_tree().create_timer(2)
				var lambda = func():
					# Safety check to prevent accessing invalid nodes
					if is_instance_valid(self) and has_node("CanvasLayer2/Left click to skip"):
						$"CanvasLayer2/Left click to skip".visible = false
				timer.timeout.connect( lambda )
			else:
				$AnimationPlayer.play("cutscene_skip")
