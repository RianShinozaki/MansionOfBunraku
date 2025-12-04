extends StaticBody3D

var anim_lock: bool = false
var open: bool = false
@export var dir: int = -1
@export var locked: bool = false
var timer: SceneTreeTimer
var orig_position: Vector3

func _ready() -> void:
	orig_position = position
	
func unlock():
	locked = false

func can_interact():
	return not locked
	
func on_interact():
	if anim_lock: return
	anim_lock = true
	if not open:
		$"OpenSFX".play()
		await get_tree().create_tween().tween_property(self, "position", orig_position + Vector3(dir*1, 0, 0), 0.25).finished
		open = true
		anim_lock = false
		
		timer = get_tree().create_timer(3)
		var _timer = timer
		await timer.timeout
		print("closing?")
		if _timer == timer and open:
			on_interact()
	else:
		$"CloseSFX".play()
		await get_tree().create_tween().tween_property(self, "position", orig_position, 0.25).finished
		open = false
		anim_lock = false

func force_open():
	anim_lock = true
	$"OpenSFX".play()
	await get_tree().create_tween().tween_property(self, "position", orig_position + Vector3(dir*1, 0, 0), 0.25).finished
	open = true
