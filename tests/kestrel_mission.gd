extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var packed = load("res://kestrel_mission.tscn")
	check(packed is PackedScene, "Kestrel Pass mission scene loads")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var level = game.level
	check(level.enemies.size() == 9 and level.find_enemy("Commander") != null, "Eight guards and a named commander are registered")
	check(level.spawn_point == Vector3(0, 1, 170), "Insertion begins in the south gully")
	check(level.mission_log.status("commander") == MissionLog.Status.ACTIVE, "Commander is the first primary objective")
	check(level.mission_log.status("ledger") == MissionLog.Status.HIDDEN and level.mission_log.status("exfil") == MissionLog.Status.HIDDEN, "Ledger and exfil unlock in campaign order")
	check(level.exfil_zone != null and not level.exfil_zone.enabled, "North saddle extraction stays locked until the ledger is recovered")
	check(MissionCatalog.index_for_scene("res://kestrel_mission.tscn") >= 0, "Kestrel Pass appears in the mission catalog")
	level.interact(level.ledger_point)
	check(level.mission_log.status("ledger") == MissionLog.Status.HIDDEN, "Ledger cannot be recovered before the commander objective")
	level.interact(level.radio_point)
	check(level.mission_log.status("radio") == MissionLog.Status.COMPLETE, "Radio mast can be disabled through close interaction")
	level.find_enemy("Commander").die()
	check(level.mission_log.status("commander") == MissionLog.Status.COMPLETE and level.mission_log.status("ledger") == MissionLog.Status.ACTIVE, "Commander death unlocks ledger recovery")
	level.interact(level.ledger_point)
	check(level.mission_log.status("ledger") == MissionLog.Status.COMPLETE and level.exfil_zone.enabled, "Recovering the ledger activates north saddle extraction")
	level.exfil_zone.check(level.gate_point)
	check(level.mission_log.status("exfil") == MissionLog.Status.COMPLETE, "Entering the north saddle completes the final objective")
	game.check_outcome()
	check(GameState.finished and not GameState.failed, "Completing the campaign objectives finishes the mission")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("KESTREL MISSION TESTS PASSED")
	quit(0 if failures == 0 else 1)
