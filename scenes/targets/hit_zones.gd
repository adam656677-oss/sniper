extends RefCounted

# Shared hit-zone helpers for anything with zoned CollisionShape3D children.
# Each shape carries a "zone" metadata string: head, torso or limb.

const ZONE_MULTIPLIER := {"head": 10.0, "torso": 1.0, "limb": 0.4}

static func zone_for_shape(body: CollisionObject3D, shape_index: int) -> String:
	if shape_index < 0:
		return "torso"
	var owner_id := body.shape_find_owner(shape_index)
	var node := body.shape_owner_get_owner(owner_id)
	if node and node.has_meta("zone"):
		return String(node.get_meta("zone"))
	return "torso"

static func multiplier(zone: String) -> float:
	return float(ZONE_MULTIPLIER.get(zone, 1.0))
