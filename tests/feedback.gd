extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	root.get_node("Settings").reset()
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var fx = game.feedback
	var weapon = game.weapon
	# Recoil.
	game.camera.global_position = Vector3(0, 1.6, 0)
	game.camera.global_rotation = Vector3.ZERO
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	check(is_equal_approx(fx.recoil_degrees, 3.0), "A rifle shot kicks the view 3 degrees")
	game.advance_sway(0.0)
	check(game.camera.rotation_degrees.x >= 2.9, "Recoil lifts the camera")
	fx.advance(0.25, 0.0, false, false)
	check(fx.recoil_degrees < 0.5 and fx.recoil_degrees > 0.0, "Recoil recovers within a quarter second")
	fx.advance(2.0, 0.0, false, false)
	check(fx.recoil_degrees == 0.0, "Recoil settles fully")
	weapon.select_weapon(1)
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	check(is_equal_approx(fx.recoil_degrees, 1.2), "The sidearm kicks less")
	weapon.select_weapon(0)
	fx.recoil_degrees = 0.0
	# Head bob.
	fx.advance(0.1, 5.0, false, false)
	check(fx.bob_offset() != 0.0, "Walking bobs the head")
	fx.advance(0.1, 5.0, true, false)
	check(fx.bob_offset() == 0.0, "Aiming stops the bob")
	fx.advance(0.1, 5.0, false, true)
	check(fx.bob_offset() == 0.0, "Reduced motion stops the bob")
	# Tracers.
	weapon.projectiles.clear()
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	fx.draw_tracers(weapon.projectiles)
	check(fx.tracer_count() == 0, "No tracer right at the muzzle")
	weapon.advance_projectiles(0.1)
	fx.draw_tracers(weapon.projectiles)
	check(weapon.projectiles.size() == 1 and fx.tracer_count() == 1, "A round in flight draws a tracer")
	weapon.projectiles.clear()
	fx.draw_tracers(weapon.projectiles)
	check(fx.tracer_count() == 0, "Tracers clear when the round is gone")
	# Impacts and holes.
	var wall: StaticBody3D = game.level.spawn_box(Vector3(30, 1.6, -20), Vector3(4, 4, 1), Color.GRAY)
	await physics_frame
	await physics_frame
	var children_before: int = fx.get_child_count()
	game.camera.global_position = Vector3(30, 1.6, 0)
	game.camera.global_rotation = Vector3.ZERO
	weapon.shot_remaining = 0.0
	weapon.fire_weapon()
	weapon.advance_projectiles(0.2)
	check(fx.holes.size() == 1 and fx.get_child_count() >= children_before + 2, "A wall hit leaves a dust puff and a hole")
	check(fx.holes[0].global_position.z > -19.5 - 0.05 and fx.holes[0].global_position.z < -19.4, "The hole sits on the wall face")
	for i in range(70):
		fx.add_hole(Vector3(i, 0, 0), Vector3.UP)
	check(fx.holes.size() == fx.MAX_HOLES, "Bullet holes are capped")
	# Hit marker.
	var plate = game.level.plate_at(100.0)
	game.on_body_hit(plate, -1, 90.0, 100.0)
	game.update_crosshair()
	check(fx.hit_marker_time > 0.0 and game.crosshair.text == "X", "A hit shows a hit marker")
	fx.advance(0.5, 0.0, false, false)
	game.update_crosshair()
	check(game.crosshair.text == "+", "The hit marker fades")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("FEEDBACK TESTS PASSED")
	quit(0 if failures == 0 else 1)
