extends SceneTree

var failures := 0
var progression: Node
var state: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	progression = root.get_node("Progression")
	state = root.get_node("GameState")
	progression.reset()
	progression.save_progress()
	check(progression.achievements.is_empty() and progression.records.is_empty(), "Progress starts empty")
	check(progression.mission_id_for("res://compound_mission.tscn") == "compound" and progression.mission_id_for("res://range_mission.tscn") == "range", "Scenes map to mission ids")
	# A loud, sloppy compound run.
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var log = game.level.mission_log
	log.fail("undetected")
	log.fail("silent")
	var stats := {"shots": 10, "hits": 3, "kills": 2, "longest_kill": 520.0, "elapsed": 300.0, "detections": 2}
	var first: Dictionary = progression.record("compound", stats, log, false)
	check(first.unlocked.has("first_blood") and first.unlocked.has("long_shot_500") and not first.unlocked.has("marksman"), "Kills and a 520 m shot unlock their achievements")
	check(not first.unlocked.has("ghost") and not first.unlocked.has("silent"), "A loud run earns no stealth achievements")
	check(first.new_best and progression.records.compound.completions == 1, "The first completion sets a record")
	var second: Dictionary = progression.record("compound", stats, log, false)
	check(second.unlocked.is_empty() and not second.new_best and progression.records.compound.completions == 2, "Repeating a run unlocks nothing new")
	game.queue_free()
	await process_frame
	# A clean compound run.
	game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	log = game.level.mission_log
	for id in ["eliminate", "exfil", "undetected", "silent"]:
		log.activate(id)
		log.complete(id)
	var clean := {"shots": 5, "hits": 5, "kills": 4, "longest_kill": 1010.0, "elapsed": 200.0, "detections": 0}
	var third: Dictionary = progression.record("compound", clean, log, false)
	check(third.unlocked.has("ghost") and third.unlocked.has("silent") and third.unlocked.has("marksman") and third.unlocked.has("long_shot_1000"), "A clean run unlocks ghost, silent, marksman and one kilometre")
	check(third.new_best and progression.records.compound.best_time == 200.0 and progression.records.compound.longest_shot == 1010.0, "Records keep the best score, fastest time and longest shot")
	game.queue_free()
	await process_frame
	# Failure records nothing but can still unlock kill achievements.
	progression.reset()
	game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var failed: Dictionary = progression.record("range", {"shots": 1, "hits": 1, "kills": 1, "longest_kill": 50.0, "elapsed": 10.0, "detections": 0}, game.level.mission_log, true)
	check(failed.unlocked == ["first_blood"] and not progression.records.has("range"), "A failed mission stores no record")
	# Tutorial and range master.
	for step in game.level.TUTORIAL:
		game.level.mission_log.activate(step[0])
		game.level.mission_log.complete(step[0])
	game.level.mission_log.complete("plates")
	var range_result: Dictionary = progression.record("range", {"shots": 10, "hits": 10, "kills": 0, "longest_kill": 0.0, "elapsed": 400.0, "detections": 0}, game.level.mission_log, false)
	check(range_result.unlocked.has("graduate") and range_result.unlocked.has("range_master"), "Finishing the tutorial and every plate unlock their achievements")
	game.queue_free()
	await process_frame
	# Persistence.
	progression.save_progress()
	var count: int = progression.achievements.size()
	progression.reset()
	check(progression.load_progress() and progression.achievements.size() == count and progression.records.range.completions == 1, "Progress survives a reload")
	# Screens.
	game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.results.show_results({"new_best": true, "unlocked": ["long_shot_1000"]})
	check(game.results.text.text.contains("New best score") and game.results.text.text.contains("One kilometre"), "Results announce records and achievements")
	game.queue_free()
	await process_frame
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_screen(menu.Screen.RECORDS)
	check(menu.records.visible and menu.records_text.text.contains("Shooting range: best") and menu.records_text.text.contains("[x] Graduate"), "The Records screen lists bests and achievements")
	menu.queue_free()
	await process_frame
	progression.reset()
	progression.save_progress()
	if failures == 0:
		print("PROGRESSION TESTS PASSED")
	quit(0 if failures == 0 else 1)
