extends Node3D
class_name ShrineCupGame

var cup_full_level: float = 0.0  # 0.0 to 1.0, persists in instance
var is_flashing: bool = false

signal overflow

@onready var regular_view_sprite: Sprite3D = $RegularViewSprite

func _ready():
	pass

func add_fill(amount: float):
	"""Add to the cup fill level (called during pouring)"""
	cup_full_level = clamp(cup_full_level + amount, 0.0, 1.0)

func get_fill_level() -> float:
	return cup_full_level

func should_flash_warning() -> bool:
	"""Check if we should start flashing (around 90-95% full)"""
	return cup_full_level >= 0.90 and cup_full_level < 1.0

func flash_warning():
	"""Flash the cup 3 times to warn player"""
	if is_flashing:
		return
	
	is_flashing = true
	
	for i in range(3):
		# Flash to bright
		var tween = create_tween()
		tween.tween_property(regular_view_sprite, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.15)
		await tween.finished
		
		# Flash back to normal
		tween = create_tween()
		tween.tween_property(regular_view_sprite, "modulate", Color.WHITE, 0.15)
		await tween.finished
	
	is_flashing = false

func shake_spill():
	"""Shake animation when cup overflows"""
	# Disable billboard so rotation is visible
	if regular_view_sprite:
		regular_view_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	var original_rotation = rotation
	
	for i in range(5):
		var tween = create_tween()
		tween.tween_property(self, "rotation:z", deg_to_rad(10), 0.08)
		await tween.finished
		
		tween = create_tween()
		tween.tween_property(self, "rotation:z", deg_to_rad(-10), 0.08)
		await tween.finished
	
	# Reset rotation
	var tween = create_tween()
	tween.tween_property(self, "rotation", original_rotation, 0.1)
	await tween.finished
	
	# Re-enable billboard
	if regular_view_sprite:
		regular_view_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func empty_cup():
	"""Empty the cup (on overflow)"""
	cup_full_level = 0.0

func reset():
	"""Reset cup to initial state"""
	cup_full_level = 0.0
	is_flashing = false
	if regular_view_sprite:
		regular_view_sprite.modulate = Color.WHITE
