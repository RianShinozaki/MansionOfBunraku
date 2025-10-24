class_name KeySocket

extends StaticBody3D

var key_object = null

func _ready():
	add_to_group("Interactable")

func can_interact() -> bool:
	return Player.instance.held_object is Key or Player.instance.held_object is RegularKey

func on_interact():
	# When clicked with a key held, place it in the socket
	if Player.instance.held_object is Key or Player.instance.held_object is RegularKey:
		var key = Player.instance.held_object
		# Remove from player hand
		Player.instance.held_object = null
		key.get_parent().remove_child(key)
		
		$"../..".on_lock_removed()
		# Destroy the key sprite
		key.queue_free()
		$"../../AudioStreamPlayer3D".play()
		# Destroy the lock sprite
		get_parent().queue_free()
		return
		
