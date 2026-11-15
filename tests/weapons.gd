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
	check(weapon.profiles.size() == 2, "Default loadout is rifle and sidearm")
	check(weapon.profiles[0].simulated_projectile and not weapon.profiles[1].simulated_projectile, "Rifle is projectile, sidearm is hitscan")
	check(weapon.profiles[1].suppressed, "Sidearm is suppressed")
	for path in ["res://scenes/weapons/profiles/vanguard_auto.tres", "res://scenes/weapons/profiles/bulwark_pump.tres"]:
		var pickup = load(path)
		check(pickup != null and pickup.pellets == 8, "Shotgun pickup profile loads: " + path.get_file())
	for profile in weapon.profiles:
		var lower: String = profile.display_name.to_lower()
		check(not lower.contains("fostech") and not lower.contains("kel-tec"), "Fictional name: " + profile.display_name)
	check(weapon.select_weapon(1), "Sidearm can be selected")
	check(weapon.ammo == 15 and weapon.reserve_ammo == 45, "Sidearm starts with its own ammo")
	check(not weapon.select_weapon(-1) and not weapon.select_weapon(2), "Invalid slots are rejected")
	weapon.ammo = 2
	check(weapon.begin_reload(), "Sidearm reload starts")
	check(not weapon.select_weapon(0), "Switch during reload is rejected")
	weapon.advance_weapon(2.0)
	check(weapon.ammo == 15 and weapon.reserve_ammo == 32, "Sidearm reload conserves ammunition")
	weapon.shot_remaining = 0.2
	weapon.select_weapon(0)
	check(weapon.ammo == 5 and weapon.reserve_ammo == 20, "Rifle has independent ammunition")
	weapon.select_weapon(1)
	check(weapon.ammo == 15 and weapon.reserve_ammo == 32, "Switching preserves ammunition")
	check(is_equal_approx(weapon.shot_remaining, 0.2), "Switching does not bypass cooldown")
	state.set_paused(true)
	check(not weapon.select_weapon(0), "Pause blocks switching")
	check(not weapon.fire_weapon(), "Pause blocks firing")
	state.set_paused(false)
	weapon.ammo = 14
	weapon.reserve_ammo = 1
	check(weapon.begin_reload(), "Partial sidearm reload starts")
	weapon.advance_weapon(2.0)
	check(weapon.ammo == 15 and weapon.reserve_ammo == 0, "Partial sidearm reload conserves rounds")
	weapon.shot_remaining = 0.0
	game.camera.global_position = Vector3(30, 2, 0)
	game.camera.global_rotation = Vector3.ZERO
	check(weapon.fire_weapon() and weapon.projectiles.is_empty(), "Sidearm shot is hitscan")
	state.finish_mission()
	check(not weapon.select_weapon(0) and not weapon.fire_weapon(), "Completion blocks switching and firing")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("WEAPON TESTS PASSED")
	quit(0 if failures == 0 else 1)
