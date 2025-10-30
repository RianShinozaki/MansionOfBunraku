extends StaticBody3D

var anim_lock: bool = false
var open: bool = false
@export var dir: int = 1

func can_interact():
	return true
	
func on_interact():
	if anim_lock: return
	anim_lock = true
	if not open:
		var _par = get_parent().get_parent()
		$"../../../OpenSFX".play()
		await get_tree().create_tween().tween_property(_par, "rotation_degrees", Vector3(0, dir * 100, 0), 0.25).finished
		open = true
	else:
		var _par = get_parent().get_parent()
		$"../../../CloseSFX".play()
		
		await get_tree().create_tween().tween_property(_par, "rotation_degrees", Vector3(0, 0, 0), 0.25).finished
		open = false
		
	anim_lock = false
