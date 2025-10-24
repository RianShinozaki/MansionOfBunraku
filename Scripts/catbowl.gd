extends StaticBody3D

var meated: bool = false
var cancel: bool = false

@onready var cat_object = preload("res://Objects/Cat.tscn")
@onready var meat_ball = preload("res://Objects/Meatball.tscn")

func _ready() -> void:
	$CatEating.finished.connect(on_finished)
	
func _process(_delta: float) -> void:
	if Player.instance.held_object is Meatball:
		if not is_in_group("Interactable"):
			add_to_group("Interactable")
	else:
		if is_in_group("Interactable") and not meated:
			remove_from_group("Interactable")
	
	if meated:
		var _vec_to_player = (Player.instance.global_position - (global_position + Vector3.UP * 0.2))

		var _player_forward = Player.instance.get_node("Camera3D").global_basis * Vector3.FORWARD
		var _angle = _player_forward.angle_to(-_vec_to_player)
		if _angle > PI/2:
			if not $CatEating.playing:
				$CatEating.play()
				cancel = false
				meated = false
				$"..".frame = 2
				remove_from_group("Meat")
				remove_from_group("Interactable")
				$"../../Cat".queue_free()
				

func can_interact():
	return (Player.instance.held_object is Meatball and not meated) or (Player.instance.held_object == null and meated)

func on_interact():
	if not meated:
		Player.instance.held_object.queue_free()
		Player.instance.held_object = null
		meated = true
		$"..".frame = 1
		add_to_group("Meat")
	else:
		meated = false
		$"..".frame = 0
		var _meat = meat_ball.instantiate()
		Player.instance.get_node("Camera3D").add_child(_meat)
		Player.instance.held_object = _meat
		_meat.on_pickup()
		$SFX.play()
		remove_from_group("Meat")

func on_finished():
	if not cancel:
		meated = false
		$"..".frame = 0
		$CatEating.volume_db = -80
		var _cat = cat_object.instantiate()
		$"../..".add_child(_cat)
		_cat.global_position = global_position
