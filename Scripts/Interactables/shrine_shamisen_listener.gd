extends Area3D

# Using centralized song sequence from Player class
var song_sequence: Array[int]:
	get:
		return Player.SONG_OF_MATRIMONY

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
	print(note_sequence)
	if locked and note_sequence == song_sequence:
		locked = false
		emit_signal("unlock")
		$"../../Bunraku".disable()
		$Symbol.visible = false
		Player.instance.active = false
		Player.instance.fade_to_white()
		await Player.instance.fade_complete
		Player.instance.global_position = $PlayerPos.global_position
		Player.instance.global_rotation_degrees = Vector3(0, 0, 0)
		$Bunraku.visible = true
		$Bunraku/Yono/CollisionShape3D.disabled = false
		$Bunraku/Kouya/CollisionShape3D.disabled = false
		if is_instance_valid($"../../Kitsune"):
			$"../../Kitsune".queue_free()
		
		Player.instance.fade_from_white()
		await Player.instance.fade_complete
		Player.instance.active = true
		$"../Yoroi/DoorOpenTrigger/CollisionShape3D".set_deferred("disabled", false)
		
func _on_area_3d_body_entered(_body: Node3D) -> void:
	player_entered = true
	Player.instance.played_note_signal.connect(append_note)
	
func _on_area_3d_body_exited(_body: Node3D) -> void:
	player_entered = false
	Player.instance.played_note_signal.disconnect(append_note)
	note_sequence.clear()
