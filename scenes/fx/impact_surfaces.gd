extends RefCounted

# What a bullet struck: metal, wood, earth, stone or flesh. Shared by the weapon
# rig (only hard surfaces deflect a grazing round) and the impact effects.
# Explicit `impact_surface` metadata wins, then surface_* groups, then hostiles
# and target dummies (flesh), then common environment names; anything else is stone.

const HARD := ["metal", "stone"]
# Matched by script class name, not `is`, so this helper (preloaded by the weapon
# rig) never pulls the enemy script and its autoload references into a compile.
const FLESH_CLASSES := ["Enemy", "TargetDummy"]

static func surface_for(body: Object) -> String:
	if body == null:
		return "earth"
	if body.has_meta("impact_surface"):
		return String(body.get_meta("impact_surface")).to_lower()
	if body is Node:
		for surface in ["metal", "wood", "earth", "flesh"]:
			if body.is_in_group("surface_" + surface):
				return surface
	if has_script_class(body, FLESH_CLASSES):
		return "flesh"
	var label := String(body.get("name")).to_lower()
	if label.contains("fuel") or label.contains("truck") or label.contains("metal"):
		return "metal"
	if label.contains("wood") or label.contains("crate") or label.contains("door"):
		return "wood"
	if label.contains("ground") or label.contains("terrain") or label.contains("road"):
		return "earth"
	return "stone"

static func is_hard(surface: String) -> bool:
	return surface in HARD

# True when the body's script, or a script it extends, has one of these class names.
static func has_script_class(body: Object, class_names: Array) -> bool:
	var script: Script = body.get_script() as Script
	while script != null:
		if String(script.get_global_name()) in class_names:
			return true
		script = script.get_base_script()
	return false
