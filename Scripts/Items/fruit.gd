class_name Fruit

extends Item

@export var fruit_artwork: Texture2D = preload("res://Art Assets/Fruits/apple.png")
@export var fruit_type: String = "apple"

func _ready() -> void:
	$Sprite3D.texture = fruit_artwork
	

func get_fruit() -> String:
	return fruit_type

func set_fruit(fruit) -> void:
	fruit_type = fruit
