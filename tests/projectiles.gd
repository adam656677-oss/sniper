extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	game.set_paused(false)
	game.camera.global_position = Vector3(30, 2, 0)
	game.camera.global_rotation = Vector3.ZERO
	var ammo_before: int = game.ammo
	check(game.fire_weapon(), "Rifle fires")
	check(game.ammo == ammo_before - 1, "One round consumed")
	check(game.projectiles.size() == 1, "One projectile created")
	check(not game.fire_weapon(), "Cooldown blocks duplicate shot")
	var initial: Vector3 = game.projectiles[0].position
	game.set_paused(true)
	game.advance_projectiles(0.1)
	check(game.projectiles[0].position == initial, "Pause freezes flight")
	game.set_paused(false)
	game.advance_projectiles(0.1)
	check(game.projectiles[0].position.z < initial.z, "Projectile travels forward")
	check(game.projectiles[0].position.y < initial.y, "Gravity lowers projectile")
	game.advance_projectiles(4.0)
	check(game.projectiles.is_empty(), "Range or lifetime clears projectile")
	var target: StaticBody3D = game.box(Vector3(30, 2, -10), Vector3(2, 3, 1), Color.RED)
	game.targets.append(target)
	var wall: StaticBody3D = game.box(Vector3(30, 2, -5), Vector3(4, 4, 1), Color.GRAY)
	await physics_frame
	await physics_frame
	game.shot_remaining = 0.0
	check(game.fire_weapon(), "Obstructed shot fires")
	game.advance_projectiles(0.2)
	check(game.projectiles.is_empty(), "Wall stops projectile")
	check(target in game.targets, "Wall protects target")
	wall.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	game.shot_remaining = 0.0
	check(game.fire_weapon(), "Clear shot fires")
	game.advance_projectiles(0.2)
	check(target not in game.targets, "Unobstructed target receives impact")
	check(game.projectiles.is_empty(), "Impact clears projectile")
	game.finished = true
	check(not game.fire_weapon(), "Completion blocks firing")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PROJECTILE TESTS PASSED")
	quit(0 if failures == 0 else 1)
