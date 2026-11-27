extends RefCounted

# Fictional balancing only. No real firearm modification specifications.
const FAMILIES := ["recon", "sidearm", "auto_shotgun", "pump_shotgun", "carbine", "heavy_rifle"]
const RIFLE_FAMILIES := ["recon", "carbine", "heavy_rifle"]
# Optic stats: fov is the aimed camera view, zoom_* the scope magnification range
# and steps, reticle_* the holdover mark spacing and reach in metres.
const PARTS := {
	"precision_scope": {"name": "Precision scope", "slot": "optic", "families": RIFLE_FAMILIES, "multiply": {}, "set": {"fov": 18.0}},
	"reflex": {"name": "Reflex sight", "slot": "optic", "families": FAMILIES, "multiply": {}, "set": {"fov": 60.0}},
	"light_spring": {"name": "Light spring", "slot": "spring", "families": ["sidearm", "auto_shotgun", "carbine"], "multiply": {"interval": 0.9, "spread": 1.1}, "set": {}},
	"match_barrel": {"name": "Match barrel", "slot": "spring", "families": ["recon", "heavy_rifle"], "multiply": {"spread": 0.8, "range": 1.1}, "set": {}},
	"light_stock": {"name": "Light stock", "slot": "stock", "families": FAMILIES, "multiply": {"reload": 0.95, "spread": 1.1}, "set": {}},
	"stable_stock": {"name": "Stable stock", "slot": "stock", "families": FAMILIES, "multiply": {"reload": 1.05, "spread": 0.9}, "set": {}},
	# Low power, wide view and fine 50 m holds for close and middle distance; tops out at 8x and 600 m.
	"close_scope": {"name": "Thicket close-range scope", "slot": "optic", "families": RIFLE_FAMILIES, "multiply": {},
		"set": {"fov": 32.0, "zoom_min": 2.0, "zoom_max": 8.0, "zoom_step": 2.0, "reticle_step": 50.0, "reticle_max": 600.0}},
	# High power and holds out to 1500 m; a narrow aimed view and no wider than 6x.
	"long_scope": {"name": "Farwatch long-range scope", "slot": "optic", "families": RIFLE_FAMILIES, "multiply": {},
		"set": {"fov": 14.0, "zoom_min": 6.0, "zoom_max": 24.0, "zoom_step": 3.0, "reticle_step": 100.0, "reticle_max": 1500.0}}
}

# English display name (a translation key), or "" for an unknown part.
static func part_name(part_id: String) -> String:
	return String(PARTS[part_id].name) if PARTS.has(part_id) else ""

static func compatible(family: String, slot: String, part_id: String) -> bool:
	if not PARTS.has(part_id):
		return false
	var part: Dictionary = PARTS[part_id]
	return part.slot == slot and family in part.families

static func calculate(base: Dictionary, family: String, installed: Dictionary) -> Dictionary:
	if family not in FAMILIES:
		return {}
	if installed.is_empty():
		return base.duplicate(true)
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
	result["optic"] = "precision_scope" if family in ["recon", "heavy_rifle"] else "reflex"
	return result
