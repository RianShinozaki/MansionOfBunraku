extends Area3D

# Detects when player enters the ceremonial room past
# NOTE: This detector is no longer used for barrier removal. Barriers now toggle
# automatically based on time state. Keeping this for potential future use.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if it's the player
	if body.is_in_group("Player") or body.name == "Player":
		if not GameManager.instance.entered_ceremonial_past:
			GameManager.instance.entered_ceremonial_past = true
			print("Player entered ceremonial room past")
			# NOTE: Fog barriers now toggle based on is_past_time instead of this flag
