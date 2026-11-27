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

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var weapon = game.weapon
	# Zero adjustment.
	check(weapon.zero_range() == 100.0, "Rifle starts zeroed at 100 m")
	check(weapon.adjust_zero(1) and weapon.zero_range() == 200.0, "Turret step raises zero by 100 m")
	check(weapon.adjust_zero(-3) and weapon.zero_range() == 100.0, "Turret clamps at the minimum zero")
	check(not weapon.adjust_zero(-1), "Cannot go below the minimum zero")
	check(weapon.adjust_zero(20) and weapon.zero_range() == 1000.0, "Turret clamps at the maximum zero")
	weapon.zero_ranges[0] = 100.0
	check(absf(weapon.holdover_at(100.0)) < 0.01, "Holdover is zero at the zero range")
	check(weapon.holdover_at(600.0) > weapon.holdover_at(300.0) and weapon.holdover_at(300.0) > 0.0, "Holdover grows beyond the zero")
	weapon.select_weapon(1)
	check(not weapon.adjust_zero(1) and weapon.holdover_at(300.0) == 0.0, "Hitscan sidearm has no turret or holdover")
	weapon.select_weapon(0)
	# Zero changes the launch elevation.
	game.camera.global_position = Vector3(30, 2, 0)
	game.camera.global_rotation = Vector3.ZERO
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	var low_zero_lift: float = weapon.projectiles[0].velocity.y
	weapon.projectiles.clear()
	weapon.zero_ranges[0] = 600.0
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	check(weapon.projectiles[0].velocity.y > low_zero_lift and low_zero_lift > 0.0, "Longer zero launches the bullet higher")
	weapon.projectiles.clear()
	weapon.zero_ranges[0] = 100.0
	# Rendered scope view.
	var scope = game.scope_view
	check(scope.source == game.camera and scope.zoom == 4.0, "Scope view follows the player camera at 4x")
	game.camera.global_position = Vector3(5, 3, -7)
	game.camera.global_rotation = Vector3(0.1, 0.4, 0)
	scope.follow()
	check(scope.camera.global_transform.is_equal_approx(game.camera.global_transform), "Scope camera copies the player camera transform")
	check(scope.camera.near >= 2.0 and game.viewmodel.position.length() < 1.0, "Scope camera clips the first-person viewmodel out of the picture")
	var fov_4x: float = scope.current_fov()
	check(fov_4x < 25.0 and fov_4x > 15.0, "4x magnification narrows the scope view")
	check(scope.zoom_in() and scope.zoom == 6.0 and scope.current_fov() < fov_4x, "Wheel up magnifies")
	scope.set_zoom(100.0)
	check(scope.zoom == 12.0 and not scope.zoom_in(), "Magnification clamps at 12x")
	scope.set_zoom(1.0)
	check(scope.zoom == 4.0 and not scope.zoom_out(), "Magnification clamps at 4x")
	check(absf(scope.fov_for_zoom(1.0, 75.0) - 75.0) < 0.001, "1x magnification is the hip field of view")
	# The installed optic sets the magnification range (checklist 5.3).
	check(scope.zoom_min == 4.0 and scope.zoom_max == 12.0 and scope.zoom_step == 2.0, "The stock rifle optic magnifies 4x to 12x")
	var high_power := WeaponProfile.new()
	high_power.simulated_projectile = true
	high_power.zoom_min = 6.0
	high_power.zoom_max = 24.0
	high_power.zoom_step = 3.0
	scope.configure(high_power)
	check(scope.zoom == 6.0 and scope.zoom_min == 6.0 and scope.zoom_max == 24.0, "An optic with a higher minimum pulls the zoom up to it")
	check(scope.zoom_in() and scope.zoom == 9.0, "Zoom steps follow the optic")
	scope.set_zoom(12.0)
	var fov_12x: float = scope.current_fov()
	scope.set_zoom(100.0)
	check(scope.zoom == 24.0 and not scope.zoom_in(), "Magnification clamps at the optic's maximum")
	check(scope.current_fov() < fov_12x * 0.6, "24x narrows the scope picture well beyond 12x")
	scope.configure(weapon.profile())
	check(scope.zoom == 12.0 and scope.zoom_max == 12.0, "Returning to the stock optic clamps the zoom back into range")
	scope.set_zoom(4.0)
	game.camera.global_position = Vector3(30, 2, 0)
	game.camera.global_rotation = Vector3.ZERO
	# Reticle marks.
	var overlay = game.get_node("ScopeLayer/ScopeOverlay")
	game.camera.fov = 25.0
	var marks: Array = overlay.holdover_marks()
	check(marks.size() == 9 and marks[0].range == 200.0 and marks[-1].range == 1000.0, "Reticle shows a mark per 100 m beyond the zero")
	var monotonic := true
	for i in range(1, marks.size()):
		if marks[i].pixels <= marks[i - 1].pixels:
			monotonic = false
	check(monotonic and marks[0].pixels > 0.0, "Holdover marks descend monotonically below centre")
	scope.set_zoom(12.0)
	check(overlay.holdover_marks()[0].pixels > marks[0].pixels * 2.0, "Marks spread out at higher magnification")
	scope.set_zoom(4.0)
	var rifle: WeaponProfile = weapon.profile()
	rifle.reticle_step = 50.0
	rifle.reticle_max = 600.0
	var fine: Array = overlay.holdover_marks()
	check(fine.size() == 10 and fine[0].range == 150.0 and fine[-1].range == 600.0, "Reticle marks follow the optic's spacing and reach")
	rifle.reticle_step = 100.0
	rifle.reticle_max = 1500.0
	var far: Array = overlay.holdover_marks()
	check(far.size() == 11 and far[-1].range == 1200.0, "Reticle marks stop at the rifle's maximum range")
	rifle.reticle_max = 1000.0
	# Rangefinder.
	var wall: StaticBody3D = game.level.spawn_box(Vector3(30, 2, -40), Vector3(4, 4, 1), Color.GRAY)
	await physics_frame
	await physics_frame
	var measured: float = game.measure_range()
	check(absf(measured - 39.5) < 0.1, "Rangefinder measures the distance to the wall face")
	game.camera.global_rotation = Vector3(0, PI, 0)
	check(game.measure_range() < 0.0 or game.measure_range() > 100.0, "Rangefinder reports no nearby surface behind")
	game.camera.global_rotation = Vector3.ZERO
	wall.queue_free()
	# Wind readout.
	weapon.wind = Vector3(3.0, 0.0, 0.0)
	var relative: Vector3 = game.wind_relative()
	check(relative.x > 0.0 and absf(relative.z) < 0.001, "Wind from the left reads as left-to-right crosswind")
	game.camera.global_rotation = Vector3(0, PI, 0)
	check(game.wind_relative().x < 0.0, "Turning around flips the crosswind")
	game.camera.global_rotation = Vector3(0, PI * 0.5, 0)
	check(game.wind_relative().z > 0.0, "Facing into the wind reads as headwind")
	game.camera.global_rotation = Vector3.ZERO
	check(game.wind_text().contains("L>R"), "HUD wind text names the crosswind direction")
	weapon.wind = game.level.wind
	# Kill cam trigger.
	var killcam = game.killcam
	check(not killcam.consider(80.0) and Engine.time_scale == 1.0, "Short kills do not trigger slow motion")
	check(killcam.consider(320.0) and Engine.time_scale < 1.0 and killcam.active(), "Long kills trigger slow motion")
	check(not killcam.consider(400.0), "Slow motion does not restart while active")
	killcam.advance(0.25)
	check(killcam.active(), "Slow motion lasts beyond one scaled second")
	killcam.advance(10.0)
	check(not killcam.active() and Engine.time_scale == 1.0, "Slow motion ends and restores time")
	killcam.consider(300.0)
	killcam.skip()
	check(not killcam.active() and Engine.time_scale == 1.0, "Skip restores time immediately")
	killcam.enabled = false
	check(not killcam.consider(500.0), "Disabled kill cam never triggers")
	killcam.enabled = true
	game.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Leaving the mission restores time scale")
	if failures == 0:
		print("SCOPE TESTS PASSED")
	quit(0 if failures == 0 else 1)
