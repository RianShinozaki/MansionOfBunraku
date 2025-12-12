class_name Yoroi

extends Bunraku

##How close is too close?
@export var too_close_distance: float
##How quickly Yono's anger ramps up when getting closer
@export var too_close_curve: Curve
##Simple flat multiplier on anger
@export var too_close_factor: float

@onready var raycast = $RayCast3D

var has_cat : bool = false

func _ready() -> void:
	super._ready()
	
func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	
	if not active: return
	if Player.instance.statue: return
	#Handles Yono's anger increasing when you're close to her or staring at her
	var _vec_to_player = (Player.instance.global_position - (global_position + Vector3.UP * 0.2))
	var _dist_to_player = _vec_to_player.length()
	
	raycast.target_position = _vec_to_player
	
	if not raycast.is_colliding() and InspectionManager.current_mode == InspectionManager.Mode.PLAY:
		if _dist_to_player < too_close_distance:
			$"..".target = Player.instance
			var _samp = too_close_curve.sample(1-(_dist_to_player/too_close_distance))
			anger_level += _delta * _samp * too_close_factor
			anger_decrease_delta = 0
		
	
