extends SceneTree

var failures := 0
var state: Node

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var weapon = game.weapon
	check(weapon.profiles.size() == 3, "Three weapon profiles load")
	for profile in weapon.profiles:
		check(not profile.display_name.to_lower().contains("fostech") and not profile.display_name.to_lower().contains("kel-tec"), "Fictional name: " + profile.display_name)
	check(weapon.select_weapon(1), "Auto shotgun can be selected")
	check(weapon.ammo == 8 and weapon.reserve_ammo == 32, "Auto shotgun starts with its own ammo")
	check(not weapon.select_weapon(-1) and not weapon.select_weapon(3), "Invalid slots are rejected")
	weapon.ammo = 2
	check(weapon.begin_reload(), "Auto shotgun reload starts")
	check(not weapon.select_weapon(2), "Switch during reload is rejected")
	weapon.advance_weapon(3.0)
	check(weapon.ammo == 8 and weapon.reserve_ammo == 26, "Auto shotgun reload conserves ammunition")
	weapon.shot_remaining = 0.2
	weapon.select_weapon(2)
	check(weapon.ammo == 14 and weapon.reserve_ammo == 28, "Pump shotgun has independent ammunition")
	weapon.select_weapon(1)
	check(weapon.ammo == 8 and weapon.reserve_ammo == 26, "Switching preserves ammunition")
	check(is_equal_approx(weapon.shot_remaining, 0.2), "Switching does not bypass cooldown")
	state.set_paused(true)
	check(not weapon.select_weapon(0), "Pause blocks switching")
	check(not weapon.fire_weapon(), "Pause blocks firing")
	state.set_paused(false)
	weapon.select_weapon(2)
	weapon.ammo = 13
	weapon.reserve_ammo = 1
	check(weapon.begin_reload(), "Pump shotgun reload starts")
	weapon.advance_weapon(6.0)
	check(weapon.ammo == 14 and weapon.reserve_ammo == 0, "Pump shotgun reload conserves shells")
	state.finish_mission()
	check(not weapon.select_weapon(0) and not weapon.fire_weapon(), "Completion blocks switching and firing")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("WEAPON TESTS PASSED")
	quit(0 if failures == 0 else 1)
