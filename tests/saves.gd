extends SceneTree

var failures := 0
var state: Node
var saves: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func fresh(path: String) -> Node:
	var game = load(path).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run_tests() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveSystem")
	saves.delete_save("test")
	saves.delete_save(saves.CHECKPOINT_SLOT)
	check(not saves.has_save("test") and saves.read("test").is_empty() and not saves.request_load("test"), "Missing save reads as empty and cannot be loaded")
	var game = fresh("res://compound_mission.tscn")
	await physics_frame
	await physics_frame
	var level = game.level
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	# Build a distinctive state.
	game.player.global_position = Vector3(12, 1, -33)
	game.player.rotation.y = 0.7
	game.player.set_stance(game.player.Stance.CROUCH)
	game.player.take_damage(35.0)
	game.weapon.ammo = 2
	game.weapon.reserve_ammo = 11
	game.weapon.zero_ranges[0] = 400.0
	game.camera.fov = 25.0
	game.stealth.stones = 1
	game.stealth.tagged_enemies.append(level.enemies[1])
	var victim = level.enemies[3]
	var victim_name: String = victim.name
	level.on_body_hit(victim, -1, 1000.0, 210.0)
	var guard = level.enemies[0]
	var guard_name: String = guard.name
	guard.change_state(guard.State.SEARCH)
	guard.perception.awareness = 0.8
	guard.last_known = Vector3(1, 1, -2)
	guard.has_last_known = true
	guard.health = 60.0
	guard.global_position = Vector3(-20, 1, -40)
	game.stats.shots = 7
	game.stats.hits = 3
	state.difficulty = state.Difficulty.HARD
	check(saves.has_save(saves.CHECKPOINT_SLOT) == false, "No checkpoint before an objective completes")
	level.mission_log.complete("silent")
	check(saves.has_save(saves.CHECKPOINT_SLOT), "Completing an objective writes a checkpoint")
	check(saves.save_game("test", game) and saves.has_save("test"), "Quick save writes a file")
	var data: Dictionary = saves.read("test")
	check(data.version == 1 and data.scene == "res://compound_mission.tscn" and data.enemies.size() == 3 and data.dead_enemies == [victim_name], "Save records scene, living and dead hostiles")
	game.queue_free()
	await process_frame
	# Restore into a fresh mission.
	state.difficulty = state.Difficulty.NORMAL
	game = fresh("res://compound_mission.tscn")
	await physics_frame
	await physics_frame
	level = game.level
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	check(level.enemies.size() == 4 and game.player.health == 100.0, "Fresh mission starts clean")
	saves.apply(game, data)
	check(game.player.global_position.is_equal_approx(Vector3(12, 1, -33)) and is_equal_approx(game.player.rotation.y, 0.7), "Player position and facing restore")
	check(game.player.stance == game.player.Stance.CROUCH and game.player.health == 65.0, "Player stance and health restore")
	check(game.weapon.ammo == 2 and game.weapon.reserve_ammo == 11 and game.weapon.zero_range() == 400.0 and game.camera.fov == 25.0, "Weapon ammunition, zero and aim restore")
	check(game.stealth.stones == 1 and game.stealth.live_tags().size() == 1 and game.stealth.live_tags()[0].name == level.enemies[1].name, "Stealth kit and tags restore")
	await process_frame
	check(level.enemies.size() == 3 and level.find_enemy(victim_name) == null, "Dead hostiles stay dead")
	var restored = level.find_enemy(guard_name)
	check(restored.state == restored.State.SEARCH and restored.health == 60.0 and is_equal_approx(restored.perception.awareness, 0.8) and restored.last_known == Vector3(1, 1, -2) and restored.global_position.is_equal_approx(Vector3(-20, 1, -40)), "Hostile state, health, awareness and position restore")
	check(level.mission_log.find("eliminate").progress == 1 and level.mission_log.status("silent") == level.mission_log.Status.COMPLETE, "Objective progress restores without double counting")
	check(game.stats.shots == 7 and game.stats.hits == 3 and game.stats.kills == 1 and game.stats.longest_kill == 210.0, "Statistics restore")
	check(state.difficulty == state.Difficulty.HARD, "Difficulty restores")
	game.queue_free()
	await process_frame
	# A save made with the recon rifle loads safely after the workbench swaps in
	# a rifle with a smaller magazine and reserve.
	var loadout = root.get_node("Loadout")
	var chosen_rifle: String = loadout.rifle
	var full_rifle: Dictionary = data.duplicate(true)
	full_rifle.weapon.active = 0
	full_rifle.weapon.stored[0] = {"ammo": 5, "reserve": 20, "cooldown": 0.0}
	check(loadout.select_rifle("heavy_rifle"), "The workbench can switch the primary rifle")
	game = fresh("res://compound_mission.tscn")
	await physics_frame
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)
	saves.apply(game, full_rifle)
	var heavy: WeaponProfile = game.weapon.profiles[0]
	check(heavy.capacity < 5 and game.weapon.ammo == heavy.capacity and game.weapon.reserve_ammo <= heavy.reserve, "A checkpoint from another rifle never overfills the magazine or reserve")
	loadout.select_rifle(chosen_rifle)
	game.queue_free()
	await process_frame
	# Pending load applies on the next mission for the matching scene only.
	check(saves.request_load("test") and not saves.pending.is_empty(), "Requesting a load stages the data")
	game = fresh("res://main.tscn")
	await process_frame
	check(not saves.pending.is_empty() and game.player.health == 100.0, "A different scene leaves the staged load alone")
	game.queue_free()
	await process_frame
	game = fresh("res://compound_mission.tscn")
	await process_frame
	check(saves.pending.is_empty() and game.player.health == 65.0 and game.level.enemies.size() == 3, "The matching scene applies the staged load in _ready")
	game.queue_free()
	await process_frame
	# Test range: intel survives a save.
	game = fresh("res://main.tscn")
	await process_frame
	game.player.position = Vector3(0, 1, -58)
	game.interact()
	check(saves.has_save(saves.CHECKPOINT_SLOT) and saves.read(saves.CHECKPOINT_SLOT).scene == "res://main.tscn", "Collecting intel checkpoints the test range")
	game.queue_free()
	await process_frame
	game = fresh("res://main.tscn")
	await process_frame
	saves.apply(game, saves.read(saves.CHECKPOINT_SLOT))
	check(state.intel and game.level.mission_log.status("extract") == game.level.mission_log.Status.ACTIVE, "Intel and the extraction objective restore")
	game.queue_free()
	await process_frame
	# Corruption and version handling.
	var file := FileAccess.open(saves.path_for("test"), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	check(saves.read("test").is_empty() and saves.last_error.contains("JSON"), "Corrupt save is rejected with a reason")
	saves.write("test", {"version": 99, "scene": "x", "player": {}, "weapon": {}, "objectives": {}})
	check(saves.read("test").is_empty() and saves.last_error.contains("version"), "Wrong save version is rejected")
	saves.write("test", {"version": 1, "scene": "x"})
	check(saves.read("test").is_empty() and saves.last_error.contains("missing"), "Incomplete save is rejected")
	check(not saves.request_load("test") and saves.pending.is_empty(), "A bad save never stages a load")
	saves.delete_save("test")
	saves.delete_save(saves.CHECKPOINT_SLOT)
	check(not saves.has_save("test"), "Deleting a save removes the file")
	if failures == 0:
		print("SAVE TESTS PASSED")
	quit(0 if failures == 0 else 1)
