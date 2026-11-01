extends RefCounted

# Fictional balancing only. No real firearm modification specifications.
const FAMILIES := ["recon", "origin12", "ksg", "ar_style", "l115_style"]
const PARTS := {
	"precision_scope": {"slot": "optic", "families": ["recon", "ar_style", "l115_style"], "multiply": {}, "set": {"fov": 18.0}},
	"reflex": {"slot": "optic", "families": FAMILIES, "multiply": {}, "set": {"fov": 60.0}},
	"light_spring": {"slot": "spring", "families": ["origin12", "ar_style"], "multiply": {"interval": 0.9, "spread": 1.1}, "set": {}},
	"light_stock": {"slot": "stock", "families": FAMILIES, "multiply": {"reload": 0.95, "spread": 1.1}, "set": {}},
	"stable_stock": {"slot": "stock", "families": FAMILIES, "multiply": {"reload": 1.05, "spread": 0.9}, "set": {}}
}

static func compatible(family: String, slot: String, part_id: String) -> bool:
	if not PARTS.has(part_id):
		return false
	var part: Dictionary = PARTS[part_id]
	return part.slot == slot and family in part.families

static func calculate(base: Dictionary, family: String, installed: Dictionary) -> Dictionary:
	if family not in FAMILIES:
		return {}
	var slots := installed.keys()
	slots.sort()
	for slot in slots:
		if not (slot is String) or not (installed[slot] is String):
			return {}
		if not compatible(family, slot, installed[slot]):
			return {}
	var result := base.duplicate(true)
	for slot in slots:
		var part: Dictionary = PARTS[installed[slot]]
		for stat in part.multiply:
			if not result.has(stat) or not (result[stat] is float or result[stat] is int):
				return {}
			result[stat] = float(result[stat]) * float(part.multiply[stat])
		for stat in part.set:
			if not result.has(stat):
				return {}
			result[stat] = part.set[stat]
	return result

static func upgraded_preset(family: String) -> Dictionary:
	if family not in FAMILIES:
		return {}
	var result := {"stock": "stable_stock"}
	result["optic"] = "precision_scope" if family in ["recon", "l115_style"] else "reflex"
	return result
