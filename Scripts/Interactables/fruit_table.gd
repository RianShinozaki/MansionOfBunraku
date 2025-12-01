class_name FruitTable

extends StaticBody3D

@export var has_fruit: bool = true
var fruit_object: Fruit

@export var fruit_target_position: Vector3 = Vector3(0.0, 0., 0.0)  

func _ready():
	return

func can_interact() -> bool:
	return true
	#return Player.instance.held_object is Fruit or has_fruit

func on_interact():
	if Player.instance.held_object is Fruit:
		var fruit = Player.instance.held_object
		# Remove from player hand
		Player.instance.held_object = null
		fruit.get_parent().remove_child(fruit)
		add_child(fruit)
		
		#teleport to target coordinates 
		fruit.position = fruit_target_position
		for child in fruit.get_children():
			if child is CollisionShape3D:
				child.disabled = false
		fruit.held = false
		
		print("placed fruit")
		
		fruit.freeze = true
		fruit.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		
		has_fruit = true
		fruit_object = fruit
		
		if has_node("PlacementSound"):
			$PlacementSound.play()
		return
		
	if has_fruit:
		print("Trying to get fruit")
		
		# Find the fruit
		fruit_object.freeze = false
		has_fruit = false
		
		# let player pick  up
		if fruit_object.can_pickup():
			Player.instance.pick_up_object(fruit_object)
		
		fruit_object = null
		
		return
	
