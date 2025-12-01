class_name BunrakuCoordinator

extends Node3D

## Does this class do exactly what BunrakuManager was supposed to do?
## Making a completely redundant layer? 
## Yes. 
## Do I feel like doing anything about it?
## no

@export var time_before_initiation: float
@export var bunraku_switch_time: float

@onready var yono_manager: BunrakuManager = $Yono
@onready var kouya_manager: BunrakuManager = $Kouya
var bunraku_counter: float
var initiated: bool = false
var active_bunraku: BunrakuManager = null

func _ready() -> void:
	initiated = false
	
func _process(delta: float) -> void:
	bunraku_counter += delta
	if !initiated and bunraku_counter > time_before_initiation:
		initiated = true
		bunraku_counter = 0
		switch_bunraku()
		
	if initiated and bunraku_counter > bunraku_switch_time:
		switch_bunraku()
		bunraku_counter = 0

func switch_bunraku() -> void:
	if active_bunraku == null:
		yono_manager.activate_bunraku()
		active_bunraku = yono_manager
	elif active_bunraku == yono_manager:
		yono_manager.deactivate_bunraku()
		kouya_manager.activate_bunraku()
		active_bunraku = kouya_manager
	else:
		kouya_manager.deactivate_bunraku()
		yono_manager.activate_bunraku()
		active_bunraku = yono_manager
		
