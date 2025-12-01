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
