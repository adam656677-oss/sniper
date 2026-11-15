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
