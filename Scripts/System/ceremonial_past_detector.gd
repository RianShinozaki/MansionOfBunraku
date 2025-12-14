extends Area3D

# Detects when player enters the ceremonial room past and removes fog barriers

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if it's the player
	if body.is_in_group("Player") or body.name == "Player":
		if not GameManager.instance.entered_ceremonial_past:
			GameManager.instance.entered_ceremonial_past = true
			print("Player entered ceremonial room past - removing fog barriers")
