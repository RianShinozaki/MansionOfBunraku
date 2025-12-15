extends StaticBody3D

# Collision area for puppet placement in the painting
# Can be either "male" or "female" side

@export var puppet_side: String = "male"  # "male" or "female"

func _ready():
	# Set collision layer to 6 (InspectableDetails) so InspectionManager can raycast it
	# Layer 6 = 1 << 5
	collision_layer = 1 << 5

func on_inspect_click() -> void:
	# Called by InspectionManager when clicked in INSPECT mode
	# Forward the click to the parent painting with the side information
	var painting = get_parent()
	if painting and painting.has_method("on_puppet_area_clicked"):
		painting.on_puppet_area_clicked(puppet_side)


