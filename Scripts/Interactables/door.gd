extends StaticBody3D

var anim_lock: bool = false
var open: bool = false
@export var dir: int = -1

func can_interact():
	return true
	
func on_interact():
	if anim_lock: return
	anim_lock = true
	if not open:
		$"OpenSFX".play()
		await get_tree().create_tween().tween_property(self, "rotation_degrees", Vector3(0, dir * 75, 0), 0.25).finished
		open = true
	else:
		$"CloseSFX".play()
		await get_tree().create_tween().tween_property(self, "rotation_degrees", Vector3(0, 0, 0), 0.25).finished
		open = false
		
	anim_lock = false
