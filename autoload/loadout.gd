extends Node

# Installed gunsmith parts per weapon family, persisted to user://loadout.cfg,
# and applied to WeaponProfile resources when a mission builds its rig.

const Gunsmith = preload("res://gunsmith.gd")
const PATH := "user://loadout.cfg"
const SLOTS := ["optic", "spring", "stock"]

signal changed(family: String)

var installed: Dictionary = {}

func _ready() -> void:
	load_loadout()

func parts_for(family: String) -> Dictionary:
	return installed.get(family, {}).duplicate()

func compatible_parts(family: String, slot: String) -> Array[String]:
	var result: Array[String] = []
	for part_id in Gunsmith.PARTS:
		if Gunsmith.compatible(family, slot, part_id):
			result.append(part_id)
	return result

func install(family: String, slot: String, part_id: String) -> bool:
	if family not in Gunsmith.FAMILIES or slot not in SLOTS:
		return false
	var parts := parts_for(family)
	if part_id.is_empty():
		parts.erase(slot)
	elif Gunsmith.compatible(family, slot, part_id):
		parts[slot] = part_id
	else:
		return false
	installed[family] = parts
	changed.emit(family)
	return true

func clear(family: String) -> void:
	installed.erase(family)
	changed.emit(family)

# A new profile with the installed parts applied. Base resources are never modified.
func apply_to(base: WeaponProfile) -> WeaponProfile:
	var profile: WeaponProfile = base.duplicate()
	var stats: Dictionary = Gunsmith.calculate(base.to_stats(), base.family, parts_for(base.family))
	if stats.is_empty():
		return profile
	profile.capacity = int(stats.capacity)
	profile.reserve = int(stats.reserve)
	profile.reload_seconds = float(stats.reload)
	profile.shot_interval = float(stats.interval)
	profile.pellets = int(stats.pellets)
	profile.spread = float(stats.spread)
	profile.max_range = float(stats.range)
	profile.aim_fov = float(stats.fov)
	return profile

func save_loadout() -> bool:
	var config := ConfigFile.new()
	for family in installed:
		for slot in installed[family]:
			config.set_value(family, slot, installed[family][slot])
	return config.save(PATH) == OK

func load_loadout() -> bool:
	installed = {}
	var config := ConfigFile.new()
	if not FileAccess.file_exists(PATH) or config.load(PATH) != OK:
		return false
	for family in config.get_sections():
		if family not in Gunsmith.FAMILIES:
			continue
		for slot in config.get_section_keys(family):
			var part_id := String(config.get_value(family, slot))
			if slot in SLOTS and Gunsmith.compatible(family, slot, part_id):
				if not installed.has(family):
					installed[family] = {}
				installed[family][slot] = part_id
	return true
