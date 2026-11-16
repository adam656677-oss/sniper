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

func aim_at(game: Node, point: Vector3, distance: float) -> void:
	game.camera.global_position = Vector3(point.x, 1.6, point.z + distance)
	var hold: float = game.weapon.holdover_at(distance)
	game.camera.look_at(point + Vector3(0, hold, 0), Vector3.UP)
	game.weapon.shot_remaining = 0.0
	game.weapon.ammo = 5

func run_tests() -> void:
	root.get_node("Settings").reset()
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	game.weapon.wind = Vector3.ZERO
	game.level.wind = Vector3.ZERO
	var dummy = load("res://scenes/targets/target_dummy.tscn").instantiate()
	game.level.add_child(dummy)
	dummy.global_position = Vector3(-30, 1, -300)
	game.level.register_target(dummy)
	await physics_frame
	await physics_frame
	var head: Vector3 = dummy.global_position + Vector3(0, 0.85, 0)
	# Prediction.
	aim_at(game, head, 300.0)
	game.camera.global_position.z = head.z + 300.0
	var probe := {"position": game.camera.global_position, "velocity": -game.camera.global_basis.z * 820.0, "age": 0.0, "distance": 0.0, "profile": game.weapon.profile()}
	var params = load("res://ballistics.gd").make_params(9.81, game.weapon.profile().drag_coefficient, Vector3.ZERO)
	var elevation: float = load("res://ballistics.gd").zero_angle(820.0, 100.0, params)
	probe.velocity = (-game.camera.global_basis.z).rotated(game.camera.global_basis.x, elevation) * 820.0
	var predicted: Dictionary = game.weapon.predict_hit(probe)
	check(not predicted.is_empty() and predicted.collider == dummy and absf(predicted.distance - 300.0) < 2.0, "Prediction finds the dummy at 300 m")
	check(game.weapon.would_kill(dummy, predicted.shape, 90.0), "A head hit with the rifle is predicted lethal")
	check(not game.weapon.would_kill(game.level.plate_at(300.0), -1, 90.0), "Steel plates never count as kills")
	check(dummy.health == 100.0 and probe.distance == 0.0, "Prediction changes nothing")
	# Bullet camera.
	var player_camera: Camera3D = game.camera
	game.weapon.fire_weapon()
	check(game.killcam.following and is_equal_approx(Engine.time_scale, game.killcam.FOLLOW_SCALE), "A predicted long kill starts the bullet camera in slow motion")
	check(game.killcam.camera.current and not player_camera.current, "The bullet camera takes over the view")
	game.weapon.advance_projectiles(0.1)
	game.killcam.advance_follow(0.1, game.weapon.projectiles.has(game.killcam.followed))
	var bullet: Vector3 = game.killcam.followed.position
	check(game.killcam.camera.global_position.distance_to(bullet) < 2.5 and game.killcam.camera.global_position.z > bullet.z, "The camera rides just behind the bullet")
	check(game.killcam.bullet_mesh.visible and game.killcam.bullet_mesh.global_position.is_equal_approx(bullet), "A visible round rides with the projectile")
	game._physics_process(0.0)
	check(not game.get_node("HUDLayer").visible, "The HUD hides during the bullet camera")
	game.weapon.advance_projectiles(1.0)
	check(not dummy.is_alive() and game.weapon.projectiles.is_empty(), "The round lands and kills")
	check(game.killcam.following and not game.killcam.active(), "The post-kill slow motion does not stack on the bullet camera")
	await process_frame
	check(not is_instance_valid(dummy), "The dead dummy is removed")
	game.killcam.advance_follow(0.05, false)
	check(game.killcam.following, "The camera holds on the impact")
	game.killcam.advance_follow(1.0, false)
	check(not game.killcam.following and Engine.time_scale == 1.0 and player_camera.current and not game.killcam.bullet_mesh.visible, "After the hold the view and time return to normal")
	Engine.time_scale = 1.0
	game.killcam.remaining = 0.0
	# A short kill and a plate do not trigger.
	var near = load("res://scenes/targets/target_dummy.tscn").instantiate()
	game.level.add_child(near)
	near.global_position = Vector3(-40, 1, -60)
	await physics_frame
	await physics_frame
	aim_at(game, near.global_position + Vector3(0, 0.85, 0), 60.0)
	game.weapon.fire_weapon()
	check(not game.killcam.following, "A 60 m kill does not start the bullet camera")
	game.weapon.projectiles.clear()
	var plate = game.level.plate_at(500.0)
	aim_at(game, plate.global_position, 500.0)
	game.weapon.fire_weapon()
	check(not game.killcam.following, "A plate shot does not start the bullet camera")
	game.weapon.projectiles.clear()
	# Skip and disabled.
	var far = load("res://scenes/targets/target_dummy.tscn").instantiate()
	game.level.add_child(far)
	far.global_position = Vector3(-50, 1, -400)
	await physics_frame
	await physics_frame
	aim_at(game, far.global_position + Vector3(0, 0.85, 0), 400.0)
	game.weapon.fire_weapon()
	check(game.killcam.following, "A 400 m kill starts the bullet camera")
	game.killcam.skip()
	check(not game.killcam.following and Engine.time_scale == 1.0 and player_camera.current, "Skipping returns control at once")
	game.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Leaving the mission restores time")
	if failures == 0:
		print("BULLETCAM TESTS PASSED")
	quit(0 if failures == 0 else 1)
