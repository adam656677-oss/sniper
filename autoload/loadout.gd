extends Node

# Installed gunsmith parts per weapon family and the rifle chassis chosen for
# the primary slot, persisted to user://loadout.cfg, and applied to
# WeaponProfile resources when a mission builds its rig.

const Gunsmith = preload("res://gunsmith.gd")
const PATH := "user://loadout.cfg"
const SLOTS := ["optic", "spring", "stock"]
# Rifle chassis for the primary slot, keyed by gunsmith family. Fictional weapons.
const RIFLES := {
	"recon": "res://scenes/weapons/profiles/ridgeline_recon.tres",
	"heavy_rifle": "res://scenes/weapons/profiles/talus_heavy.tres"
}
const DEFAULT_RIFLE := "recon"
# Config section for choices that are not per-family parts. Configs written
# before the rifle choice existed have no such section and load the default.
const SELECTION := "selection"

signal changed(family: String)
signal rifle_changed(rifle_id: String)

var installed: Dictionary = {}
var rifle := DEFAULT_RIFLE

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

func rifle_ids() -> Array:
	return RIFLES.keys()

func select_rifle(rifle_id: String) -> bool:
	if not RIFLES.has(rifle_id):
		return false
	rifle = rifle_id
	rifle_changed.emit(rifle)
	return true

# Resource path of a rifle chassis; the chosen one when rifle_id is empty.
func rifle_path(rifle_id := "") -> String:
	return String(RIFLES.get(rifle if rifle_id.is_empty() else rifle_id, RIFLES[DEFAULT_RIFLE]))

# The unmodified base profile of a rifle chassis; the chosen one when rifle_id is empty.
func rifle_base(rifle_id := "") -> WeaponProfile:
	return load(rifle_path(rifle_id)) as WeaponProfile

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
	profile.zoom_min = float(stats.zoom_min)
	profile.zoom_max = float(stats.zoom_max)
	profile.zoom_step = float(stats.zoom_step)
	profile.reticle_step = float(stats.reticle_step)
	profile.reticle_max = float(stats.reticle_max)
	return profile

func save_loadout() -> bool:
	var config := ConfigFile.new()
	config.set_value(SELECTION, "rifle", rifle)
	for family in installed:
		for slot in installed[family]:
			config.set_value(family, slot, installed[family][slot])
	return config.save(PATH) == OK

func load_loadout() -> bool:
	installed = {}
	rifle = DEFAULT_RIFLE
	var config := ConfigFile.new()
	if not FileAccess.file_exists(PATH) or config.load(PATH) != OK:
		return false
	var stored_rifle = config.get_value(SELECTION, "rifle", DEFAULT_RIFLE)
	if stored_rifle is String and RIFLES.has(stored_rifle):
		rifle = stored_rifle
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
