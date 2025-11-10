class_name Yoroi

extends Bunraku

##How closely the player must be looking at Yoroi to curb his anger
@export var look_anger_range: float
##How quickly Yoroi's anger ramps up when ignored
@export var look_anger_curve: Curve
##Simple flat multiplier on Yoroi's anger
@export var look_anger_factor: float
##How long Yoroi can be ignored before he gets angry
@export var no_look_max_time: float

var no_look_time: float = 0
var has_been_fed: bool = false 
var has_gear := true

func _ready() -> void:
	super._ready()
func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	
	if not active: return
	
	#Handles Yoroi's anger when not looked at for long enough
	var _vec_to_player = (Player.instance.global_position - (global_position + Vector3.UP * 0.2))
	var _player_forward = Player.instance.get_node("Camera3D").global_basis * Vector3.FORWARD
	var _angle = _player_forward.angle_to(-_vec_to_player)
	if _angle > look_anger_range:
		no_look_time += _delta
		if no_look_time > no_look_max_time:
			var _samp = look_anger_curve.sample(1-(_angle/360))
			anger_level += _delta * _samp * look_anger_factor
			anger_decrease_delta = 0
	else:
		no_look_time = 0
