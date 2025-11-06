extends Node3D

var tween: Tween

func _ready() -> void:
	$"CanvasLayer2/Left click to skip".visible = false

func _on_dialogue_box_dialogue_ended() -> void:
	$AnimationPlayer.play("end_cutscene")

func end_cutscene() -> void:
	get_tree().change_scene_to_file("res://Maps/Game.tscn")
	
func _unhandled_input(event: InputEvent) -> void:
	if $AnimationPlayer.is_playing() and $AnimationPlayer.current_animation == "cutscene":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if $"CanvasLayer2/Left click to skip".visible == false:
				$"CanvasLayer2/Left click to skip".visible = true
				var timer: SceneTreeTimer = get_tree().create_timer(2)
				var lambda = func():
					$"CanvasLayer2/Left click to skip".visible = false
				timer.timeout.connect( lambda )
				return
			else:
				$AnimationPlayer.play("cutscene_skip")
