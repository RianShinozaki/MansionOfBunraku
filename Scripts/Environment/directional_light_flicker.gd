extends DirectionalLight3D

@export var energy_median: float
@export var energy_range: float
var energy_change: float
@export var energy_delta_range: float

func _process(_delta: float) -> void:
	energy_change += randf_range(-energy_delta_range, energy_delta_range)
	light_energy += energy_change
	if light_energy < energy_median - energy_range or light_energy > energy_median + energy_range:
		energy_change = 0
	light_energy = clampf(light_energy, energy_median - energy_range, energy_median + energy_range)
