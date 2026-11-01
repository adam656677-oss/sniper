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
	check(game.ammo == 5, "Starting magazine has five rounds")
	check(game.reserve_ammo == 20, "Starting reserve has twenty rounds")
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
	check(not game.begin_reload(), "Full magazine rejects reload")
	game.ammo = 0
	press(game, KEY_R)
	check(game.ammo == 0 and game.reload_remaining > 0.0, "Reload is not instantaneous")
	check(not game.can_fire(), "Reload blocks firing")
	check(not game.begin_reload(), "Duplicate reload is rejected")
	game.advance_weapon(1.0)
	check(game.ammo == 0, "Incomplete reload transfers no ammunition")
	press(game, KEY_ESCAPE)
	check(game.paused, "Escape pauses game")
	var remaining: float = game.reload_remaining
	var location: Vector3 = game.player.position
	game.advance_weapon(10.0)
	game._physics_process(1.0)
	check(game.reload_remaining == remaining, "Pause freezes reload timer")
	check(game.player.position == location, "Pause freezes player simulation")
	check(game.hud.text.contains("PAUSED"), "Pause is displayed")
	press(game, KEY_ESCAPE)
	check(not game.paused, "Escape resumes game")
	game.advance_weapon(3.0)
	check(game.ammo == 5 and game.reserve_ammo == 15, "Reload consumes reserve ammunition")
	check(game.can_fire(), "Loaded rifle can fire")
	game.shot_remaining = 0.9
	check(not game.can_fire(), "Bolt cycle blocks firing")
	game.advance_weapon(1.0)
	check(game.can_fire(), "Bolt cycle expires")
	game.ammo = 4
	game.reserve_ammo = 1
	check(game.begin_reload(), "Partial reload starts")
	game.advance_weapon(3.0)
	check(game.ammo == 5 and game.reserve_ammo == 0, "Partial reload conserves ammunition")
	game.ammo = 0
	check(not game.begin_reload(), "Empty reserve prevents reload")
	check(not game.can_fire(), "Empty magazine prevents firing")
	game.player.position = Vector3(0, -20, 0)
	game._physics_process(0.0)
	check(game.player.position == Vector3(0, 1, 3), "Falling off map recovers player")
	press(game, KEY_E)
	check(game.finished, "Returning with intel completes mission")
	check(not game.can_fire(), "Completed mission prevents firing")
	await physics_frame
	await process_frame
	check(game.hud.text.contains("MISSION COMPLETE"), "HUD reports mission completion")
	game.queue_free()
	await process_frame
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("SMOKE TESTS PASSED")
	quit(0 if failures == 0 else 1)
