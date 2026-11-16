extends Node

# Versioned JSON saves under user://saves. capture() and apply() work on a live
# mission so tests can round-trip without changing scenes; request_load() stages
# data that the next mission applies in _ready after a scene reload.

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const CHECKPOINT_SLOT := "checkpoint"
const QUICK_SLOT := "quick"

signal saved(slot: String)
signal loaded(slot: String)

var pending: Dictionary = {}
var last_error := ""

func path_for(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot.validate_filename()]

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))

func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))

func capture(mission: Node) -> Dictionary:
	var player = mission.player
	var weapon = mission.weapon
	var level = mission.level
	weapon.stored[weapon.active] = {"ammo": weapon.ammo, "reserve": weapon.reserve_ammo, "cooldown": weapon.shot_remaining}
	var enemies: Array = []
	for enemy in level.enemies:
		enemies.append(enemy.capture())
	var dead_enemies: Array = []
	if level.has_node("Enemies"):
		for child in level.get_node("Enemies").get_children():
			if child.has_method("is_alive") and not child.is_alive():
				dead_enemies.append(child.name)
	var dead_targets: Array = []
	if level.has_node("Targets"):
		for child in level.get_node("Targets").get_children():
			if child not in level.targets:
				dead_targets.append(child.name)
	var plates: Dictionary = {}
	if level.get("plates") != null:
		for plate in level.plates:
			plates[plate.name] = plate.hit_count
	var tags: Array = []
	for enemy in mission.stealth.live_tags():
		tags.append(enemy.name)
	return {
		"version": SAVE_VERSION,
		"scene": mission.scene_file_path,
		"saved_at": Time.get_datetime_string_from_system(),
		"difficulty": GameState.difficulty,
		"intel": GameState.intel,
		"player": {
			"position": vec(player.global_position), "yaw": player.rotation.y, "pitch": player.head.rotation.x,
			"stance": player.stance, "health": player.health
		},
		"weapon": {
			"active": weapon.active, "stored": weapon.stored.duplicate(true),
			"zero_ranges": Array(weapon.zero_ranges), "fov": mission.camera.fov
		},
		"stealth": {"stones": mission.stealth.stones, "tags": tags},
		"objectives": level.mission_log.to_dict(),
		"stats": mission.stats.duplicate(),
		"enemies": enemies,
		"dead_enemies": dead_enemies,
		"dead_targets": dead_targets,
		"plates": plates,
		"coordinator": {"level": level.coordinator.level, "bodies": level.coordinator.bodies.size()}
	}

static func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func unvec(a) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

func write(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open %s for writing" % path_for(slot)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

# Returns {} for a missing, unreadable, malformed or wrong-version save.
func read(slot: String) -> Dictionary:
	last_error = ""
	if not has_save(slot):
		last_error = "No save in slot %s" % slot
		return {}
	var text := FileAccess.get_file_as_string(path_for(slot))
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		last_error = "Save %s is not valid JSON" % slot
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		last_error = "Save %s has version %s, expected %d" % [slot, str(parsed.get("version", "none")), SAVE_VERSION]
		return {}
	for key in ["scene", "player", "weapon", "objectives"]:
		if not parsed.has(key):
			last_error = "Save %s is missing %s" % [slot, key]
			return {}
	return parsed

func save_game(slot: String, mission: Node) -> bool:
	if not write(slot, capture(mission)):
		return false
	saved.emit(slot)
	return true

# Stage a save for the next mission load; returns false without touching the scene on a bad save.
func request_load(slot: String) -> bool:
	var data := read(slot)
	if data.is_empty():
		return false
	pending = data
	return true

func apply(mission: Node, data: Dictionary) -> void:
	var player = mission.player
	var weapon = mission.weapon
	var level = mission.level
	GameState.difficulty = int(data.get("difficulty", GameState.difficulty))
	GameState.intel = bool(data.get("intel", false))
	var p: Dictionary = data.player
	player.global_position = unvec(p.get("position"))
	player.rotation.y = float(p.get("yaw", 0.0))
	player.head.rotation.x = float(p.get("pitch", 0.0))
	player.velocity = Vector3.ZERO
	player.set_stance(int(p.get("stance", 0)))
	player.health = float(p.get("health", player.MAX_HEALTH))
	player.since_damage = 0.0
	var w: Dictionary = data.weapon
	for index in range(mini(weapon.stored.size(), w.get("stored", []).size())):
		var entry: Dictionary = w.stored[index]
		weapon.stored[index] = {"ammo": int(entry.get("ammo", 0)), "reserve": int(entry.get("reserve", 0)), "cooldown": float(entry.get("cooldown", 0.0))}
	for index in range(mini(weapon.zero_ranges.size(), w.get("zero_ranges", []).size())):
		weapon.zero_ranges[index] = float(w.zero_ranges[index])
	weapon.active = clampi(int(w.get("active", 0)), 0, weapon.profiles.size() - 1)
	weapon.ammo = int(weapon.stored[weapon.active].ammo)
	weapon.reserve_ammo = int(weapon.stored[weapon.active].reserve)
	weapon.shot_remaining = float(weapon.stored[weapon.active].cooldown)
	weapon.reload_remaining = 0.0
	weapon.projectiles.clear()
	mission.camera.fov = float(w.get("fov", 75.0))
	var st: Dictionary = data.get("stealth", {})
	mission.stealth.stones = int(st.get("stones", mission.stealth.STONE_COUNT))
	for name in data.get("dead_enemies", []):
		var enemy = level.find_enemy(String(name))
		if enemy:
			level.remove_enemy_silently(enemy)
	for saved in data.get("enemies", []):
		var enemy = level.find_enemy(String(saved.get("name", "")))
		if enemy:
			enemy.restore(saved)
	mission.stealth.tagged_enemies.clear()
	for name in st.get("tags", []):
		var enemy = level.find_enemy(String(name))
		if enemy:
			mission.stealth.tagged_enemies.append(enemy)
	for name in data.get("dead_targets", []):
		if level.has_node("Targets/" + String(name)):
			level.remove_target_silently(level.get_node("Targets/" + String(name)))
	if level.get("plates") != null:
		for plate in level.plates:
			if data.get("plates", {}).has(plate.name):
				plate.hit_count = int(data.plates[plate.name])
				if plate.hit_count > 0:
					level.rung_plates[plate] = true
	level.mission_log.from_dict(data.get("objectives", {}))
	for key in mission.stats.keys():
		if data.get("stats", {}).has(key):
			mission.stats[key] = data.stats[key]
	level.coordinator.level = int(data.get("coordinator", {}).get("level", 0))
	level.restore_triggers()
	mission.update_hud()
	loaded.emit(String(data.get("slot", "")))

# Called by a mission in _ready: applies and clears a pending load for its scene.
func apply_pending(mission: Node) -> bool:
	if pending.is_empty() or String(pending.get("scene", "")) != mission.scene_file_path:
		return false
	var data := pending
	pending = {}
	apply(mission, data)
	return true
