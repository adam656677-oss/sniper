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
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var viewmodel: WeaponViewmodel = game.viewmodel
	check(viewmodel != null and viewmodel.visible, "First-person viewmodel is attached and enabled")
	check(viewmodel.active_profile == game.weapon.profile(), "Viewmodel starts on the active rifle")
	check(viewmodel.model_root != null and viewmodel.model_root.get_child_count() >= 3, "Viewmodel builds original weapon and arm geometry")
	check(viewmodel.muzzle_flash != null and viewmodel.flash_light != null, "Muzzle flash mesh and light are ready")
	game.weapon.fire_weapon()
	check(viewmodel.recoil > 0.0 and viewmodel.muzzle_flash.visible, "Firing triggers recoil and a brief muzzle flash")
	viewmodel.advance(0.08, false, 0.0, 0.0)
	check(not viewmodel.muzzle_flash.visible, "Muzzle flash fades after its short pulse")
	check(game.weapon.select_weapon(1), "A handgun can be selected")
	viewmodel.advance(0.05, false, 0.0, 0.0)
	check(viewmodel.active_profile == game.weapon.profile(), "Viewmodel changes model when weapon selection changes")
	check(viewmodel.magazine != null, "Handgun magazine is represented separately for reload presentation")
	game.weapon.ammo -= 1
	check(game.weapon.begin_reload(), "Handgun reload begins")
	game.weapon.advance_weapon(0.25)
	viewmodel.advance(0.25, false, game.weapon.reload_remaining, 0.0)
	check(viewmodel.magazine.position.y < -0.16, "Reload state animates the magazine and weapon position")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("VIEWMODEL TESTS PASSED")
	quit(0 if failures == 0 else 1)
