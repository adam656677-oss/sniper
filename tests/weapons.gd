extends SceneTree

var failures := 0

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.select_weapon(1), "Origin can be selected")
	check(game.ammo == 8 and game.reserve_ammo == 32, "Origin starts with its own ammo")
	check(not game.select_weapon(-1) and not game.select_weapon(3), "Invalid slots are rejected")
	game.ammo = 2
	check(game.begin_reload(), "Origin reload starts")
	check(not game.select_weapon(2), "Switch during reload is rejected")
	game.advance_weapon(3.0)
	check(game.ammo == 8 and game.reserve_ammo == 26, "Origin reload conserves ammunition")
	game.shot_remaining = 0.2
	game.select_weapon(2)
	check(game.ammo == 14 and game.reserve_ammo == 28, "KSG has independent ammunition")
	game.select_weapon(1)
	check(game.ammo == 8 and game.reserve_ammo == 26, "Switching preserves ammunition")
	check(is_equal_approx(game.shot_remaining, 0.2), "Switching does not bypass cooldown")
	game.set_paused(true)
	check(not game.select_weapon(0), "Pause blocks switching")
	check(not game.fire_weapon(), "Pause blocks firing")
	game.set_paused(false)
	game.select_weapon(2)
	game.ammo = 13
	game.reserve_ammo = 1
	check(game.begin_reload(), "KSG reload starts")
	game.advance_weapon(6.0)
	check(game.ammo == 14 and game.reserve_ammo == 0, "KSG reload conserves shells")
	game.finished = true
	check(not game.select_weapon(0) and not game.fire_weapon(), "Completion blocks switching and firing")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("WEAPON TESTS PASSED")
	quit(0 if failures == 0 else 1)
