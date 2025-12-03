class_name FruitTable

extends StaticBody3D

@export var has_fruit: bool = true
@export var fruit_texture: Texture2D
@export var fruit_type: String
var fruit_object: Fruit

@export var offering_table: bool = false
@export var left: bool = false
@export var required_offering: String = ""

@export var fruit_target_position: Vector3 = Vector3(0.0, 0.4, 0.0)  

func _ready():
	fruit_object = $Fruit if has_node("Fruit") else null
	
	if has_fruit and fruit_texture and fruit_type:
		$Fruit/Sprite3D.texture = fruit_texture
		fruit_object.set_fruit(fruit_type)
		fruit_object.remove_from_group("Item")
		for child in fruit_object.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		fruit_object.freeze = true
		fruit_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	
func can_interact() -> bool:
	return true

func on_interact():
	if Player.instance.held_object is Fruit:
		var fruit = Player.instance.held_object
		# Remove from player hand
		Player.instance.held_object = null
		fruit.get_parent().remove_child(fruit)
		add_child(fruit)
		fruit_type = fruit.get_fruit()
		
		#teleport to target coordinates 
		for child in fruit.get_children():
			if child is CollisionShape3D:
				child.disabled = true
				
		fruit.freeze = true
		fruit.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		fruit.position = fruit_target_position
		
		fruit.held = false
		
		print("placed ", fruit_type)

		has_fruit = true
		fruit_object = fruit
		fruit_object.remove_from_group("Item")
		
		if has_node("PlacementSound"):
			$PlacementSound.play()
		
		return
		
	if has_fruit:
		print("Trying to get", fruit_type)
		
		# Find the fruit
		fruit_object.freeze = false
		has_fruit = false
		fruit_type = ""
		
		# let player pick  up
		if fruit_object.can_pickup():
			fruit_object.add_to_group("Item")
			Player.instance.pick_up_object(fruit_object)
				
		
		fruit_object = null
		
		return
