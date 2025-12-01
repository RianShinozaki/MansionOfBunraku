extends StaticBody3D

# Small collision area over the apple in the painting
# Only this area is clickable in inspect mode

func _ready():
	# Set collision layer to 6 (InspectableDetails) so InspectionManager can raycast it
	# Layer 6 = 1 << 5
	collision_layer = 1 << 5

func on_inspect_click() -> void:
	# Called by InspectionManager when clicked in INSPECT mode
	# Forward the click to the parent painting
	var painting = get_parent()
	if painting and painting.has_method("on_apple_area_clicked"):
		painting.on_apple_area_clicked()

