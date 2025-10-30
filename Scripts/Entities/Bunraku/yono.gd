class_name Yono

extends Bunraku

##How close is too close?
@export var too_close_distance: float
##How quickly Yono's anger ramps up when getting closer
@export var too_close_curve: Curve
##Simple flat multiplier on anger
@export var too_close_factor: float

##How closely your gaze can align with Yono for her to be angry
@export var look_anger_range: float
##How quickly Yono's anger ramps up when looking closer at her
@export var look_anger_curve: Curve
##Flat multiplier on angee
@export var look_anger_factor: float

var has_cat : bool = false

func _ready() -> void:
	super._ready()
	
func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	
	if not active: return
	
	#Allow's Yono to grab the cat if the cat exists and is close to her
	if get_tree().get_nodes_in_group("Cat").size() > 0 and not has_cat:
		var _cat = get_tree().get_nodes_in_group("Cat")[0]
		var _vec_to_cat = _cat.global_position - global_position
		var _dist_to_cat = _vec_to_cat.length()
		if _dist_to_cat < 0.6:
			_cat.adopted()
			_cat.get_parent().remove_child(_cat)
			$Body.add_child(_cat)
			has_cat = true
			anger_level = 0
			appearance_update()
			var _key = $Body/BlueKey
			_key.freeze = false
			_key.get_parent().remove_child(_key)
			get_parent().add_child(_key)
	
	#All anger is completely canceled if she has a cat. She just like me fr
	if has_cat or Player.instance.held_object is Cat: return
	
	#Handles Yono's anger increasing when you're close to her or staring at her
	var _vec_to_player = (Player.instance.global_position - (global_position + Vector3.UP * 0.2))
	var _dist_to_player = _vec_to_player.length()
	if _dist_to_player < too_close_distance:
		var _samp = too_close_curve.sample(1-(_dist_to_player/too_close_distance))
		anger_level += _delta * _samp * too_close_factor
		anger_decrease_delta = 0
	var _player_forward = Player.instance.get_node("Camera3D").global_basis * Vector3.FORWARD
	var _angle = _player_forward.angle_to(-_vec_to_player)
	if _angle < look_anger_range:
		var _samp = look_anger_curve.sample(1-(_angle/look_anger_range))
		anger_level += _delta * _samp * look_anger_factor
		anger_decrease_delta = 0
	if get_tree().get_nodes_in_group("Meat").size() > 0:
		anger_level += _delta * 0.08
		anger_decrease_delta = 0
	
	
