class_name TargetDummy
extends StaticBody3D

# Shootable dummy with hit zones. Each CollisionShape3D child carries a "zone"
# metadata string; damage is multiplied per zone. Emits died once.

signal died(target: TargetDummy)

const ZONE_MULTIPLIER := {"head": 10.0, "torso": 1.0, "limb": 0.4}

@export var max_health := 100.0
var health := 100.0

func _ready() -> void:
	health = max_health

func is_alive() -> bool:
	return health > 0.0

func zone_for_shape(shape_index: int) -> String:
	if shape_index < 0:
		return "torso"
	var owner_id := shape_find_owner(shape_index)
	var node := shape_owner_get_owner(owner_id)
	if node and node.has_meta("zone"):
		return String(node.get_meta("zone"))
	return "torso"

func take_hit(shape_index: int, damage: float) -> float:
	if not is_alive():
		return 0.0
	var zone := zone_for_shape(shape_index)
	var dealt: float = maxf(damage, 0.0) * float(ZONE_MULTIPLIER.get(zone, 1.0))
	health = maxf(0.0, health - dealt)
	if health == 0.0:
		died.emit(self)
	return dealt
