extends SceneTree

var failures := 0
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
	var packed = load("res://main.tscn")
	check(packed is PackedScene, "Main scene loads")
	if not packed is PackedScene:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	check(is_instance_valid(game.player), "Player exists")
	check(is_instance_valid(game.camera), "Camera exists")
	check(game.camera.current, "Camera is active")
	check(game.targets.size() == 3, "Three test targets spawn")
	check(game.ammo == 5 and game.reserve == 20, "Starting ammunition is finite")
	check(not game.intel and not game.finished, "Mission starts incomplete")
	for i in range(90):
		await physics_frame
	check(game.player.is_on_floor(), "Player settles on floor")
	check(game.player.position.y > 0.5, "Player does not fall through floor")
	press(game, KEY_E)
	check(not game.finished, "Extraction without intel is rejected")
	game.player.position = Vector3(0, 1, -50)
	press(game, KEY_E)
	check(not game.intel, "Intel cannot be collected from a distance")
	game.player.position = Vector3(0, 1, -58)
	press(game, KEY_E)
	check(game.intel, "Nearby terminal grants intel")
	check(not game.finished, "Intel collection does not immediately extract")
	game.ammo = 0
	press(game, KEY_R)
	check(game.reload_remaining > 0 and game.ammo == 0, "Reload is timed, not instant")
	check(not game.can_fire(), "Cannot fire during reload")
	game.advance_weapon(1.0)
	check(game.ammo == 0, "Partial reload does not grant ammunition")
	press(game, KEY_ESCAPE)
	check(game.paused, "Escape pauses simulation")
	var remaining: float = game.reload_remaining
	game.advance_weapon(5.0)
	check(game.reload_remaining == remaining, "Reload freezes while paused")
	var before: Vector3 = game.player.position
	game._physics_process(1.0)
	check(game.player.position == before, "Player physics freezes while paused")
	press(game, KEY_ESCAPE)
	check(not game.paused, "Escape resumes simulation")
	game.advance_weapon(2.1)
	check(game.ammo == 5 and game.reserve == 15, "Completed reload consumes reserve")
	game.cooldown = 1.0
	check(not game.can_fire(), "Cooldown blocks firing")
	game.advance_weapon(1.1)
	check(game.can_fire(), "Weapon becomes ready after cooldown")
	game.ammo = 4
	game.reserve = 1
	game.start_reload()
	game.advance_weapon(2.1)
	check(game.ammo == 5 and game.reserve == 0, "Partial magazine uses exact reserve")
	game.ammo = 0
	game.start_reload()
	check(game.reload_remaining == 0 and not game.can_fire(), "Empty reserve cannot reload or fire")
	game.player.position = Vector3(0, 1, 3)
	press(game, KEY_E)
	check(game.finished, "Returning with intel completes mission")
	check(not game.can_fire(), "Completed mission blocks firing")
	await physics_frame
	await process_frame
	check(game.hud.text.contains("MISSION COMPLETE"), "HUD reports mission completion")
	game.queue_free()
	await process_frame
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("SMOKE TESTS PASSED")
	quit(0 if failures == 0 else 1)
