extends Node3D

@onready var play_sprite: Sprite3D = $PlaySprite
@onready var dialogue_sprite: Sprite3D = $DialogueSprite

func _ready():
	set_play_mode()

func set_play_mode():
	if play_sprite and dialogue_sprite:
		play_sprite.visible = true
		dialogue_sprite.visible = false

func set_dialogue_mode():
	if play_sprite and dialogue_sprite:
		play_sprite.visible = false
		dialogue_sprite.visible = true
