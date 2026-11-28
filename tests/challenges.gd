extends SceneTree

# Long-shot challenges on the 1000 m range: the catalog, each challenge's setup
# (plates, conditions, rounds, clock), pass and fail rules, the score formula,
# the local leaderboard and its achievements, the mission select briefing,
# results and Records screens, and the plain range mission left as it was.

const Ballistics = preload("res://ballistics.gd")
const Catalog = preload("res://scenes/challenges/challenge_catalog.gd")
const Atmosphere = preload("res://scenes/levels/atmosphere.gd")

var failures := 0
var state: Node
var progression: Node
var saves: Node
var requested: Array = []

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func open(id: String) -> Node:
	var game = load(String(Catalog.find(id).scene)).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	return game

func close(game: Node) -> void:
	game.queue_free()
	await process_frame

# Let the mission root run until it notices the outcome and shows the results.
func finish(game: Node) -> void:
	game.set_physics_process(true)
	await physics_frame
	await physics_frame

func reload_if_empty(weapon) -> void:
	if weapon.ammo == 0:
		weapon.begin_reload()
		weapon.advance_weapon(10.0)
	weapon.shot_remaining = 0.0

# Fire one round into the sky and let it run out of life.
func waste_round(game: Node) -> void:
	var weapon = game.weapon
	reload_if_empty(weapon)
	game.camera.global_position = Vector3(0, 1.4, 3)
	game.camera.look_at(Vector3(0, 600, -100), Vector3.UP)
	weapon.fire_weapon()
	weapon.advance_projectiles(3.0)

# Aim from straight behind a plate at its range, raised by holdover and, when
# correct_wind is set, offset by the drift the wind blowing now gives, then
# fire. The round flies only when fly is set. Mirrors tests/range.gd.
func aim_and_fire(game: Node, plate: Node, correct_wind := true, fly := true) -> void:
	var weapon = game.weapon
	weapon.wind = game.level.current_wind()
	game.camera.global_position = plate.global_position + Vector3(0, 0, plate.range_metres)
	var hold: float = weapon.holdover_at(plate.range_metres)
	var drift := 0.0
	if correct_wind:
		var params: Dictionary = weapon.ballistic_params()
		var elevation: float = Ballistics.zero_angle(weapon.profile().muzzle_velocity, weapon.zero_range(), params)
		var shot_frame_wind := Vector3(-weapon.wind.z, weapon.wind.y, weapon.wind.x)
		var flight: Dictionary = Ballistics.simulate_flat(weapon.profile().muzzle_velocity, elevation, plate.range_metres, Ballistics.make_params(params.gravity, params.drag, shot_frame_wind))
		drift = float(flight.drift)
	game.camera.look_at(plate.global_position + Vector3(-drift, hold, 0), Vector3.UP)
	reload_if_empty(weapon)
	weapon.fire_weapon()
	if fly:
		weapon.advance_projectiles(3.0)

func distances(level: Node) -> Array:
	var result := []
	for plate in level.plates:
		result.append(plate.range_metres)
	return result

# Equal challenge records, allowing for the precision a config file keeps for floats.
func same_records(a: Dictionary, b: Dictionary) -> bool:
	if a.keys() != b.keys():
		return false
	for id in a:
		if a[id].keys() != b[id].keys():
			return false
		for key in a[id]:
			if typeof(a[id][key]) != typeof(b[id][key]) or absf(float(a[id][key]) - float(b[id][key])) > 0.0001:
				return false
	return true

func direct_buttons(container: Node) -> Array:
	var result := []
	for child in container.get_children():
		if child is Button:
			result.append(child)
	return result

func run_tests() -> void:
	state = root.get_node("GameState")
	progression = root.get_node("Progression")
	saves = root.get_node("SaveSystem")
	progression.reset()
	progression.save_progress()
	saves.delete_save(saves.QUICK_SLOT)
	saves.delete_save(saves.CHECKPOINT_SLOT)

	# Catalog.
	var ids := []
	for i in range(Catalog.count()):
		ids.append(String(Catalog.get_challenge(i).id))
	check(ids == ["warmup", "crosswind", "kilometre", "sequence"], "Four long-shot challenges in menu order")
	var range_distances := [100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 700.0, 800.0, 900.0, 1000.0]
	var well_formed := true
	for challenge in Catalog.CHALLENGES:
		for plate in challenge.plates:
			well_formed = well_formed and range_distances.has(float(plate))
		well_formed = well_formed and not String(challenge.title).is_empty() and not String(challenge.brief).is_empty()
		well_formed = well_formed and int(challenge.rounds) > 0 and ResourceLoader.exists(String(challenge.scene))
		well_formed = well_formed and Catalog.find(String(challenge.id)) == challenge and Catalog.index_of(String(challenge.id)) == ids.find(challenge.id)
	check(well_formed, "Every challenge has a title, a brief, a scene, a round budget and plates the range has")
	check(Catalog.find("nonsense").is_empty() and Catalog.index_of("nonsense") == -1 and Catalog.get_challenge(99).is_empty(), "Unknown challenges are not found")
	var warmup: Dictionary = Catalog.find("warmup")
	var crosswind: Dictionary = Catalog.find("crosswind")
	var kilometre: Dictionary = Catalog.find("kilometre")
	var sequence: Dictionary = Catalog.find("sequence")
	check(warmup.plates == [200.0, 300.0, 400.0] and int(warmup.weather) == Atmosphere.Weather.CLEAR and warmup.wind.length() <= 1.0 and int(warmup.rounds) == 6 and float(warmup.time_limit) == 0.0 and not warmup.ordered, "Warm-up: 200, 300 and 400 m in calm clear air, six rounds, no clock")
	check(crosswind.plates == [700.0, 800.0] and int(crosswind.weather) == Atmosphere.Weather.WINDY and crosswind.wind.x > 0.0 and int(crosswind.rounds) == 6, "Crosswind: 700 and 800 m in gusting wind from the left, six rounds")
	check(kilometre.plates == [1000.0] and int(kilometre.rounds) == 3 and float(kilometre.time_limit) == 0.0, "Kilometre: one plate at 1000 m and three rounds")
	check(sequence.plates == [300.0, 500.0, 700.0, 900.0] and sequence.ordered and float(sequence.time_limit) == 180.0 and int(sequence.rounds) == 10, "Sequence: 300, 500, 700 and 900 m in order, ten rounds, three minutes")

	# Score formula: plate metres + 100 per unused round + 10 per whole second left.
	var parts: Dictionary = Catalog.score_parts(warmup, 900.0, 3, 40.0, true)
	check(parts.distance == 900 and parts.rounds == 300 and parts.time == 0 and parts.total == 1200 and Catalog.score_for(warmup, 900.0, 3, 40.0, true) == 1200, "Warm-up pass with three rounds spare scores 900 + 300 = 1200")
	parts = Catalog.score_parts(sequence, 2400.0, 6, 100.4, true)
	check(parts.distance == 2400 and parts.rounds == 400 and parts.time == 790 and parts.total == 3590, "Sequence pass with four rounds and 79 s spare scores 2400 + 400 + 790 = 3590")
	check(Catalog.score_for(kilometre, 1000.0, 1, 12.0, true) == 1200 and Catalog.score_for(kilometre, 1000.0, 3, 12.0, true) == 1000, "Kilometre scores 1200 on the first round and 1000 on the last")
	check(Catalog.score_for(sequence, 1500.0, 10, 180.0, false) == 0 and Catalog.score_parts(kilometre, 0.0, 3, 9.0, false).total == 0, "A failed challenge scores zero")
	check(Catalog.score_for(crosswind, 1500.0, 9, 10.0, true) == 1500 and Catalog.score_for(sequence, 2400.0, 10, 200.0, true) == 2400, "Round and time bonuses never go negative")

	# Setup of every challenge.
	for challenge in Catalog.CHALLENGES:
		var game = await open(String(challenge.id))
		var level = game.level
		var weapon = game.weapon
		var label := String(challenge.title)
		check(game.scene_file_path == challenge.scene and level.challenge_id == challenge.id, "%s: its scene loads its challenge" % label)
		check(distances(level) == challenge.plates and level.get_node("Plates").get_child_count() == 2 * challenge.plates.size(), "%s: only its plates and their markers stand" % label)
		check(level.time_of_day == int(challenge.time_of_day) and level.weather == int(challenge.weather) and level.wind == challenge.wind, "%s: time of day, weather and wind follow the challenge" % label)
		check(level.current_wind() == Atmosphere.wind_at(challenge.wind, int(challenge.weather), level.clock), "%s: the wind gusts through the shared weather model" % label)
		check(weapon.active == 0 and weapon.ammo + weapon.reserve_ammo == int(challenge.rounds) and weapon.ammo == mini(int(challenge.rounds), weapon.profile().capacity) and level.rounds_left() == int(challenge.rounds), "%s: the rifle carries exactly the round budget" % label)
		var others_empty := true
		for index in range(1, weapon.stored.size()):
			others_empty = others_empty and int(weapon.stored[index].ammo) + int(weapon.stored[index].reserve) == 0
		check(others_empty, "%s: the sidearms carry no rounds" % label)
		check(level.time_limit() == float(challenge.time_limit) and level.outcome == level.Outcome.RUNNING, "%s: its clock limit is set and it starts running" % label)
		check(level.mission_log.find("t_aim").is_empty() and level.mission_log.find("long_shot").is_empty() and level.mission_log.objectives.size() == 1, "%s: one objective and no tutorial steps" % label)
		check(not level.allows_saves() and not game.quick_save() and not saves.has_save(saves.QUICK_SLOT), "%s: quick saves are refused" % label)
		check(game.hud.text.contains("Rounds %d / %d" % [int(challenge.rounds), int(challenge.rounds)]) and game.hud.text.contains("Ring "), "%s: the HUD shows the rounds left and the objective" % label)
		await close(game)

	# Warm-up: ring the three plates with live rounds, one miss in between.
	var checkpoint := {"version": saves.SAVE_VERSION, "scene": "res://compound_mission.tscn", "player": {}, "weapon": {}, "objectives": {}}
	saves.write(saves.CHECKPOINT_SLOT, checkpoint)
	var game = await open("warmup")
	var level = game.level
	saves.write(saves.QUICK_SLOT, {"version": saves.SAVE_VERSION, "scene": warmup.scene, "player": {}, "weapon": {}, "objectives": {}})
	check(not game.load_slot(saves.QUICK_SLOT) and saves.pending.is_empty(), "Quick load is refused in a challenge")
	saves.delete_save(saves.QUICK_SLOT)
	aim_and_fire(game, level.plate_at(200.0))
	aim_and_fire(game, level.plate_at(300.0))
	check(level.mission_log.find("plates").progress == 2 and level.outcome == level.Outcome.RUNNING, "Warm-up counts each rung plate")
	check(game.level.conditions_text().contains("Rounds 4 / 6") and game.level.conditions_text().contains("Time 0:"), "The HUD counts down rounds and shows the time on an untimed challenge")
	waste_round(game)
	root.get_node("StoryCampaign").active = true
	aim_and_fire(game, level.plate_at(400.0))
	check(level.outcome == level.Outcome.PASSED and level.is_complete() and level.rounds_used() == 4, "Ringing every plate passes the warm-up with four rounds")
	var result: Dictionary = level.result()
	check(result.passed and result.score == 1100 and result.plates_rung == 3 and result.rounds_used == 4 and result.time > 0.0 and result.longest == 400.0, "The warm-up result carries the score, plates, rounds, time and longest plate")
	await finish(game)
	check(state.finished and not state.failed and game.results.visible, "A passed challenge finishes and shows the results")
	game.update_hud()
	check(game.hud.text.contains("CHALLENGE PASSED") and not game.hud.text.contains("MISSION COMPLETE"), "The HUD banner names a passed challenge, not a mission")
	check(level.end_banner(true).contains("CHALLENGE FAILED"), "A failed challenge has its own HUD banner")
	check(not game.controls_help().contains("quick save") and not game.controls_help().contains("quick load"), "Pause help leaves out quick save and quick load during a challenge")
	var text: String = game.results.text.text
	check(text.contains("CHALLENGE PASSED") and text.contains("Calm warm-up") and text.contains("Score: 1100") and text.contains("Plates 900 + rounds 200 + time 0"), "Results show the challenge, its score and the score breakdown")
	check(text.contains("Plates rung: 3 / 3") and text.contains("Rounds used: 4 / 6") and text.contains("New best score") and not text.contains("MISSION COMPLETE"), "Results show plates rung, rounds used and the new best")
	check(not game.results.continue_story_button.visible, "Results offer no story continuation after a challenge, even with a campaign running")
	root.get_node("StoryCampaign").active = false
	var entry: Dictionary = progression.challenge_records.get("warmup", {})
	check(int(entry.get("best_score", 0)) == 1100 and int(entry.get("fewest_rounds", 0)) == 4 and float(entry.get("best_time", 0.0)) > 0.0 and int(entry.get("passes", 0)) == 1 and int(entry.get("attempts", 0)) == 1, "The warm-up records its best score, fewest rounds, fastest time, passes and attempts")
	check(progression.records.is_empty(), "A challenge writes no mission record")
	check(saves.has_save(saves.CHECKPOINT_SLOT), "Finishing a challenge leaves another mission's checkpoint alone")
	saves.delete_save(saves.CHECKPOINT_SLOT)
	await close(game)
	# Later attempts: each record improves on its own.
	var slower: Dictionary = progression.record_challenge("warmup", {"passed": true, "score": 1200, "rounds_used": 3, "time": float(entry.best_time) + 30.0, "longest": 400.0})
	check(slower.new_best and slower.new_fewest_rounds and not slower.new_fastest and progression.challenge_records.warmup.best_score == 1200 and progression.challenge_records.warmup.best_time == entry.best_time, "A higher score with fewer rounds keeps the faster time")
	var quickest: float = float(entry.best_time) * 0.5
	var quicker: Dictionary = progression.record_challenge("warmup", {"passed": true, "score": 1000, "rounds_used": 5, "time": quickest, "longest": 400.0})
	check(not quicker.new_best and not quicker.new_fewest_rounds and quicker.new_fastest and progression.challenge_records.warmup.best_score == 1200 and progression.challenge_records.warmup.fewest_rounds == 3 and progression.challenge_records.warmup.best_time == quickest, "A quicker, lower-scoring pass only improves the fastest time")
	var miss: Dictionary = progression.record_challenge("warmup", {"passed": false, "score": 0, "rounds_used": 6, "time": 0.001, "longest": 200.0})
	check(not miss.new_best and not miss.new_fastest and progression.challenge_records.warmup.passes == 3 and progression.challenge_records.warmup.attempts == 4 and progression.challenge_records.warmup.best_time == quickest, "A failed attempt counts as an attempt and changes no best")

	# Kilometre: three rounds into the sky runs out of rounds.
	game = await open("kilometre")
	level = game.level
	for i in range(3):
		waste_round(game)
	level._physics_process(0.05)
	check(level.rounds_left() == 0 and level.outcome == level.Outcome.OUT_OF_ROUNDS and level.is_failed(), "Spending every round without ringing the plate fails the kilometre")
	await finish(game)
	text = game.results.text.text
	check(state.failed and text.contains("CHALLENGE FAILED") and text.contains("Out of rounds") and text.contains("Score: 0"), "Results report a challenge failed for want of rounds")
	check(int(progression.challenge_records.kilometre.attempts) == 1 and int(progression.challenge_records.kilometre.passes) == 0 and int(progression.challenge_records.kilometre.best_score) == 0, "A failed kilometre records an attempt and no best")
	await close(game)
	# Kilometre: the last round is still in the air when the budget hits zero.
	game = await open("kilometre")
	level = game.level
	game.weapon.zero_ranges[0] = 600.0
	waste_round(game)
	waste_round(game)
	aim_and_fire(game, level.plate_at(1000.0), true, false)
	level._physics_process(0.05)
	check(level.rounds_left() == 0 and game.weapon.projectiles.size() == 1 and level.outcome == level.Outcome.RUNNING, "The challenge waits for the last round in flight")
	game.weapon.advance_projectiles(3.0)
	check(level.plate_at(1000.0).hit_count == 1 and level.outcome == level.Outcome.PASSED and level.result().score == 1000, "The last round rings the 1000 m plate and passes on 1000 points")
	await finish(game)
	check(progression.has_achievement("long_shot_1000") and not progression.has_achievement("cold_bore") and int(progression.challenge_records.kilometre.fewest_rounds) == 3, "Ringing 1000 m unlocks One kilometre; three rounds is no cold bore")
	await close(game)
	# Kilometre: first round.
	game = await open("kilometre")
	level = game.level
	game.weapon.zero_ranges[0] = 600.0
	aim_and_fire(game, level.plate_at(1000.0))
	check(level.outcome == level.Outcome.PASSED and level.result().score == 1200, "A first-round kilometre scores 1200")
	await finish(game)
	text = game.results.text.text
	check(progression.has_achievement("cold_bore") and text.contains("Achievement unlocked: Cold bore") and text.contains("New best score") and text.contains("New fewest rounds"), "A first-round kilometre unlocks Cold bore and new bests")
	check(int(progression.challenge_records.kilometre.best_score) == 1200 and int(progression.challenge_records.kilometre.fewest_rounds) == 1 and int(progression.challenge_records.kilometre.passes) == 2 and int(progression.challenge_records.kilometre.attempts) == 3, "The kilometre keeps its best and counts every attempt")
	await close(game)

	# Crosswind: the gusting wind matters at 800 m.
	game = await open("crosswind")
	level = game.level
	var gusts := []
	for t in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]:
		gusts.append(Atmosphere.wind_at(crosswind.wind, Atmosphere.Weather.WINDY, t).x)
	check(gusts.max() - gusts.min() > 2.0 and gusts.min() > 0.0, "The crosswind gusts by several metres a second without changing direction")
	aim_and_fire(game, level.plate_at(800.0), false)
	check(level.plate_at(800.0).hit_count == 0, "An uncorrected shot in the crosswind misses at 800 m")
	aim_and_fire(game, level.plate_at(800.0))
	aim_and_fire(game, level.plate_at(700.0))
	check(level.outcome == level.Outcome.PASSED and level.result().score == 1800, "Drift-corrected shots ring 800 and 700 m and score 1500 + 300")
	await close(game)

	# Sequence: order and the clock.
	game = await open("sequence")
	level = game.level
	check(level.conditions_text().contains("Next 300 m") and level.conditions_text().contains("Time left 3:00"), "The HUD names the next plate and counts the time left down from 3:00")
	level.plate_at(500.0).take_hit(-1, 0.0)
	check(level.rung_plates.is_empty() and level.mission_log.find("plates").progress == 0, "A plate rung out of order does not count")
	level.plate_at(300.0).take_hit(-1, 0.0)
	level.plate_at(300.0).take_hit(-1, 0.0)
	check(level.mission_log.find("plates").progress == 1 and level.next_plate() == level.plate_at(500.0) and level.conditions_text().contains("Next 500 m"), "The nearest plate counts once and the next one is named")
	level.plate_at(500.0).take_hit(-1, 0.0)
	check(level.mission_log.find("plates").progress == 2, "The next plate in order counts")
	state.set_paused(true)
	var before: float = level.elapsed
	level._physics_process(1.0)
	check(level.elapsed == before, "The challenge clock stops while paused")
	state.set_paused(false)
	level.elapsed = 179.95
	level._physics_process(0.1)
	check(level.outcome == level.Outcome.OUT_OF_TIME and level.is_failed() and level.mission_log.status("plates") == level.mission_log.Status.FAILED, "The sequence fails when the clock runs out")
	level.plate_at(700.0).take_hit(-1, 0.0)
	check(level.mission_log.find("plates").progress == 2, "Plates rung after the clock runs out do not count")
	await finish(game)
	text = game.results.text.text
	check(state.failed and text.contains("CHALLENGE FAILED") and text.contains("Out of time") and text.contains("Timed sequence"), "Results report a challenge failed on time")
	await close(game)
	game = await open("sequence")
	level = game.level
	for metres in [300.0, 500.0, 700.0, 900.0]:
		level.plate_at(metres).take_hit(-1, 0.0)
	result = level.result()
	check(level.outcome == level.Outcome.PASSED and result.score == Catalog.score_for(sequence, 2400.0, 0, level.finish_time, true) and result.parts.time >= 1790, "A quick sequence pass earns the time bonus")
	await finish(game)
	text = game.results.text.text
	check(text.contains("CHALLENGE PASSED") and text.contains("Time: 0:00 of 3:00"), "Results show the time taken against the limit")
	await close(game)

	# Every challenge passed unlocks Challenger once.
	check(not progression.has_achievement("challenger"), "Challenger waits for every challenge")
	var last: Dictionary = progression.record_challenge("crosswind", {"passed": true, "score": 1800, "rounds_used": 3, "time": 60.0, "longest": 800.0})
	check(last.unlocked.has("challenger") and progression.has_achievement("challenger"), "Passing the last challenge unlocks Challenger")
	check(not progression.record_challenge("crosswind", {"passed": true, "score": 1800, "rounds_used": 3, "time": 60.0, "longest": 800.0}).unlocked.has("challenger"), "Challenger unlocks only once")

	# Persistence.
	var saved_records: Dictionary = progression.challenge_records.duplicate(true)
	progression.save_progress()
	progression.reset()
	check(progression.challenge_records.is_empty(), "Reset clears the challenge records")
	check(progression.load_progress() and same_records(progression.challenge_records, saved_records) and progression.has_achievement("cold_bore"), "Challenge records and achievements survive a reload")

	# Mission select, briefing and Records.
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.scene_changer = func(path): requested.append(path)
	menu.show_screen(menu.Screen.MISSIONS)
	var mission_buttons := direct_buttons(menu.missions)
	check(mission_buttons.size() == 5 and mission_buttons[0].text == "Shooting range" and mission_buttons[4].text == "Back", "The mission list keeps its missions and back button")
	check(menu.challenge_section.visible and menu.challenge_section.get_parent() == menu.missions and menu.challenge_buttons.size() == 4, "Mission select has a challenges section")
	check(menu.challenge_buttons.map(func(b): return b.text) == ["Calm warm-up", "Gusting crosswind", "Kilometre shot", "Timed sequence"], "Each challenge has a button")
	menu.challenge_buttons[2].pressed.emit()
	var info: String = menu.challenge_info.text
	check(menu.screen == menu.Screen.CHALLENGE and menu.challenge_panel.visible and not menu.missions.visible and menu.selected_challenge == 2, "Choosing a challenge opens its briefing")
	check(menu.challenge_title.text == "Kilometre shot" and info.contains("Three rounds to ring it") and info.contains("Plates: 1000 m") and info.contains("Dusk") and info.contains("from the right") and info.contains("Rounds: 3") and info.contains("No time limit"), "The briefing names the challenge and lists its plates, conditions, wind, rounds and clock")
	check(info.contains("Pass: ring every plate") and info.contains("Score: plate metres + 100 per unused round"), "The briefing states the pass rule and score formula")
	check(info.contains("best 1200") and info.contains("fewest rounds 1") and info.contains("passed 2 / 3"), "The briefing shows the player's best")
	menu.challenge_buttons[3].pressed.emit()
	check(menu.challenge_info.text.contains("Plates in order: 300 m, 500 m, 700 m, 900 m") and menu.challenge_info.text.contains("Time limit: 3:00") and menu.challenge_info.text.contains("10 per second left"), "Mission select reaches each challenge's briefing")
	menu.challenge_back_button.pressed.emit()
	check(menu.screen == menu.Screen.MISSIONS and menu.missions.visible and not menu.challenge_panel.visible, "Back returns to mission select")
	menu.challenge_buttons[1].pressed.emit()
	saves.pending = {"scene": "res://compound_mission.tscn"}
	menu.challenge_start_button.pressed.emit()
	check(requested == [crosswind.scene] and saves.pending.is_empty(), "Start launches the chosen challenge")
	check(menu.start_challenge(99) == "" and requested.size() == 1, "Unknown challenges are ignored")
	menu.show_screen(menu.Screen.RECORDS)
	var records: String = menu.records_text.text
	check(records.contains("Long-shot challenges") and records.contains("Kilometre shot: best 1200") and records.contains("fewest rounds 1") and records.contains("[x] Cold bore") and records.contains("[x] Challenger"), "The Records screen lists challenge bests and achievements")
	menu.queue_free()
	await process_frame
	progression.reset()
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_challenge(0)
	check(menu.challenge_info.text.contains("not passed"), "A briefing without a pass says so")
	menu.show_screen(menu.Screen.RECORDS)
	check(menu.records_text.text.contains("Calm warm-up: not passed"), "Records list unpassed challenges")
	menu.queue_free()
	await process_frame

	# The plain range mission is unchanged.
	game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	level = game.level
	check(level.plates.size() == 10 and level.get("challenge_id") == null and level.TUTORIAL.size() == 7 and level.mission_log.status("t_aim") == level.mission_log.Status.ACTIVE, "The plain range keeps every plate and its tutorial")
	check(level.allows_saves() and level.conditions_text() == "Noon, clear" and game.weapon.ammo == game.weapon.profile().capacity and game.weapon.reserve_ammo == game.weapon.profile().reserve, "The plain range keeps its conditions, saves and full ammunition")
	check(game.controls_help().contains("quick save") and level.end_banner(false).contains("MISSION COMPLETE"), "The plain range keeps quick save in the pause help and the mission banner")
	level.mission_log.complete("plates")
	var range_progress: Dictionary = level.record_progress("range", game.stats)
	check(progression.records.has("range") and progression.challenge_records.is_empty() and range_progress.has("new_best"), "The plain range records to the mission records")
	await close(game)

	progression.reset()
	progression.save_progress()
	saves.delete_save(saves.QUICK_SLOT)
	saves.delete_save(saves.CHECKPOINT_SLOT)
	if failures == 0:
		print("CHALLENGE TESTS PASSED")
	quit(0 if failures == 0 else 1)
