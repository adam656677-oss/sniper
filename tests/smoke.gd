extends SceneTree

var failures := 0
var state: Node
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func press(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_input(event)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var packed = load("res://main.tscn")
	check(packed is PackedScene, "Main scene loads")
	if not packed is PackedScene:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var weapon = game.weapon
	check(is_instance_valid(game.player), "Player exists")
	check(is_instance_valid(game.camera), "Camera exists")
	check(game.camera.current, "Camera is active")
	check(game.level.targets.size() == 3, "Three test targets spawn")
	check(weapon.ammo == 5 and weapon.reserve_ammo == 20, "Starting ammunition is finite")
	check(not state.intel and not state.finished, "Mission starts incomplete")
	for i in range(90):
		await physics_frame
	check(game.player.is_on_floor(), "Player settles on floor")
	check(game.player.position.y > 0.5, "Player does not fall through floor")
	press(game, KEY_E)
	check(not state.finished, "Extraction without intel is rejected")
	game.player.position = Vector3(0, 1, -50)
	press(game, KEY_E)
	check(not state.intel, "Intel cannot be collected from a distance")
	game.player.position = Vector3(0, 1, -58)
	press(game, KEY_E)
	check(state.intel, "Nearby terminal grants intel")
	check(not state.finished, "Intel collection does not immediately extract")
	check(not weapon.begin_reload(), "Full magazine rejects reload")
	weapon.ammo = 0
	press(game, KEY_R)
	check(weapon.reload_remaining > 0 and weapon.ammo == 0, "Reload is timed, not instant")
	check(not weapon.can_fire(), "Cannot fire during reload")
	check(not weapon.begin_reload(), "Duplicate reload is rejected")
	weapon.advance_weapon(1.0)
	check(weapon.ammo == 0, "Partial reload does not grant ammunition")
	press(game, KEY_ESCAPE)
	check(state.paused, "Escape pauses simulation")
	var remaining: float = weapon.reload_remaining
	weapon.advance_weapon(5.0)
	check(weapon.reload_remaining == remaining, "Reload freezes while paused")
	var before: Vector3 = game.player.position
	game.player.velocity = Vector3(5, 0, 0)
	game.player._physics_process(1.0)
	check(game.player.position == before, "Player physics freezes while paused")
	game.player.velocity = Vector3.ZERO
	game._physics_process(0.0)
	check(game.hud.text.contains("PAUSED"), "Pause is displayed")
	press(game, KEY_ESCAPE)
	check(not state.paused, "Escape resumes simulation")
	weapon.advance_weapon(2.1)
	check(weapon.ammo == 5 and weapon.reserve_ammo == 15, "Completed reload consumes reserve")
	check(weapon.can_fire(), "Loaded rifle can fire")
	weapon.shot_remaining = 1.0
	check(not weapon.can_fire(), "Cooldown blocks firing")
	weapon.advance_weapon(1.1)
	check(weapon.can_fire(), "Weapon becomes ready after cooldown")
	weapon.ammo = 4
	weapon.reserve_ammo = 1
	weapon.begin_reload()
	weapon.advance_weapon(2.3)
	check(weapon.ammo == 5 and weapon.reserve_ammo == 0, "Partial magazine uses exact reserve")
	weapon.ammo = 0
	weapon.begin_reload()
	check(weapon.reload_remaining == 0 and not weapon.can_fire(), "Empty reserve cannot reload or fire")
	game.player.position = Vector3(0, -20, 0)
	game.player._physics_process(0.0)
	check(game.player.position == Vector3(0, 1, 3), "Falling off map recovers player")
	press(game, KEY_E)
	check(state.finished, "Returning with intel completes mission")
	check(not weapon.can_fire(), "Completed mission blocks firing")
	await physics_frame
	await process_frame
	check(game.hud.text.contains("MISSION COMPLETE"), "HUD reports mission completion")
	press(game, KEY_ESCAPE)
	check(not state.paused, "Pause is ignored after completion")
	game.queue_free()
	await process_frame
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("SMOKE TESTS PASSED")
	quit(0 if failures == 0 else 1)
