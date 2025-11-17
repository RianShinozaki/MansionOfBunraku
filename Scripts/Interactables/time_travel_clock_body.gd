extends StaticBody3D

# Delegator script for the clock's StaticBody3D
# Forwards interaction calls to the parent Clock node

func can_interact() -> bool:
	return get_parent().can_interact()

func on_interact():
	get_parent().on_interact()
