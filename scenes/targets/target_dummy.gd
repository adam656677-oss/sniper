class_name TargetDummy
extends StaticBody3D

# Shootable dummy with hit zones. Emits died once.

const HitZones = preload("res://scenes/targets/hit_zones.gd")

signal died(target: TargetDummy)

const ZONE_MULTIPLIER := HitZones.ZONE_MULTIPLIER

@export var max_health := 100.0
var health := 100.0

func _ready() -> void:
	health = max_health

func is_alive() -> bool:
	return health > 0.0

func zone_for_shape(shape_index: int) -> String:
	return HitZones.zone_for_shape(self, shape_index)

func take_hit(shape_index: int, damage: float) -> float:
	if not is_alive():
		return 0.0
	var dealt: float = maxf(damage, 0.0) * HitZones.multiplier(zone_for_shape(shape_index))
	health = maxf(0.0, health - dealt)
	if health == 0.0:
		died.emit(self)
	return dealt
