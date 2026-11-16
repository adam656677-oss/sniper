extends SceneTree

var failures := 0
var state: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func press(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_input(event)

func run_tests() -> void:
	state = root.get_node("GameState")
	# Objective log on its own.
	var log = load("res://scenes/missions/mission_log.gd").new()
	root.add_child(log)
	log.add("a", "First", log.Kind.PRIMARY)
	log.add("b", "Second", log.Kind.PRIMARY, 3, true)
	log.add("c", "Bonus", log.Kind.OPTIONAL)
	check(log.lines().size() == 2 and not log.all_primary_complete(), "Hidden objectives stay off the list")
	log.progress("b")
	check(log.find("b").progress == 0, "Hidden objectives do not progress")
	log.complete("a")
	log.activate("b")
	log.progress("b", 2)
	check(log.lines()[1] == "[ ] Second (2/3)" and not log.all_primary_complete(), "Progress counts toward the goal")
	log.progress("b")
	check(log.status("b") == log.Status.COMPLETE and log.all_primary_complete(), "Reaching the goal completes the objective and the mission")
	log.fail("c")
	check(log.lines()[2].ends_with("FAILED") and not log.any_primary_failed(), "A failed optional does not fail the mission")
	log.activate("c")
	check(log.status("c") == log.Status.FAILED, "Finished objectives cannot be reopened")
	var snapshot: Dictionary = log.to_dict()
	var copy = load("res://scenes/missions/mission_log.gd").new()
	copy.add("a", "First")
	copy.add("b", "Second", log.Kind.PRIMARY, 3, true)
	copy.add("c", "Bonus", log.Kind.OPTIONAL)
	copy.from_dict(snapshot)
	check(copy.status("b") == log.Status.COMPLETE and copy.find("b").progress == 3 and copy.status("c") == log.Status.FAILED, "Objective state round-trips through a dictionary")
	log.queue_free()
	copy.free()
	# Test range: intel then extraction, optional targets.
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var level = game.level
	check(level.objective_text().contains("gold terminal") and level.mission_log.lines().size() == 2, "Intel objective is active and extraction hidden")
	game.player.position = Vector3(0, 1, -58)
	press(game, KEY_E)
	check(level.mission_log.status("intel") == level.mission_log.Status.COMPLETE and level.mission_log.status("extract") == level.mission_log.Status.ACTIVE, "Collecting intel reveals extraction")
	level.on_body_hit(level.targets[0], -1, 1000.0)
	check(level.mission_log.find("targets").progress == 1, "Dropping a practice target progresses the optional")
	game.player.position = Vector3(0, 1, 3)
	press(game, KEY_E)
	await physics_frame
	await physics_frame
	check(state.finished and not state.failed and game.hud.text.contains("[x] Return"), "Extraction completes the mission and the HUD lists objectives")
	game.queue_free()
	await process_frame
	# Shooting range: progress per plate and the long-shot secondary.
	game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	level = game.level
	level.plate_at(300.0).take_hit(-1, 0.0)
	level.plate_at(300.0).take_hit(-1, 0.0)
	check(level.mission_log.find("plates").progress == 1, "Ringing the same plate twice counts once")
	level.plate_at(1000.0).take_hit(-1, 0.0)
	check(level.mission_log.status("long_shot") == level.mission_log.Status.COMPLETE and level.mission_log.find("plates").progress == 2, "The 1000 m plate completes the secondary")
	game.queue_free()
	await process_frame
	# Compound: eliminate, exfil trigger, undetected and silent objectives, stats.
	game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	level = game.level
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	check(level.mission_log.find("eliminate").goal == 4 and level.mission_log.status("exfil") == level.mission_log.Status.HIDDEN, "Compound starts with four to eliminate and a hidden exfil")
	level.report_noise(Vector3(0, 0, -3000), 25.0, 1.0)
	check(level.mission_log.status("silent") == level.mission_log.Status.ACTIVE, "A suppressed shot keeps the silent objective")
	level.report_noise(Vector3(0, 0, -3000), 400.0, 1.0)
	check(level.mission_log.status("silent") == level.mission_log.Status.FAILED, "An unsuppressed shot fails the silent objective")
	level.coordinator.escalate(level.coordinator.Level.SUSPICIOUS)
	check(level.mission_log.status("undetected") == level.mission_log.Status.ACTIVE, "Suspicion alone keeps the undetected objective")
	level.coordinator.escalate(level.coordinator.Level.ALERT)
	check(level.mission_log.status("undetected") == level.mission_log.Status.FAILED and game.stats.detections == 1, "Alert fails the undetected objective and counts a detection")
	var zone = level.exfil_zone
	zone.check(level.gate_point)
	check(level.mission_log.status("exfil") == level.mission_log.Status.HIDDEN, "The gate does nothing before the hostiles are down")
	var remaining: Array = level.enemies.duplicate()
	for enemy in remaining:
		level.on_body_hit(enemy, -1, 1000.0, 120.0)
	check(level.mission_log.status("eliminate") == level.mission_log.Status.COMPLETE and level.mission_log.status("exfil") == level.mission_log.Status.ACTIVE and zone.enabled, "Eliminating every hostile activates the exfil")
	check(game.stats.kills == 4 and game.stats.hits == 0 and game.stats.longest_kill == 120.0, "Kill statistics are recorded")
	check(not state.finished, "Mission is not complete until the player exfiltrates")
	game.player.global_position = level.gate_point
	for i in range(4):
		await physics_frame
	check(state.finished and not state.failed, "Reaching the gate completes the mission")
	game.queue_free()
	await process_frame
	# Primary failure ends the mission.
	game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.level.mission_log.fail("eliminate")
	await physics_frame
	await physics_frame
	check(state.failed and game.hud.text.contains("MISSION FAILED"), "A failed primary objective fails the mission")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("MISSION TESTS PASSED")
	quit(0 if failures == 0 else 1)
