extends SceneTree

var failures := 0
var state: Node

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var scene := load("res://main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var weapon = game.weapon
	state.set_paused(false)
	game.camera.global_position = Vector3(30, 2, 0)
	game.camera.global_rotation = Vector3.ZERO
	var ammo_before: int = weapon.ammo
	check(weapon.fire_weapon(), "Rifle fires")
	check(weapon.ammo == ammo_before - 1, "One round consumed")
	check(weapon.projectiles.size() == 1, "One projectile created")
	check(not weapon.fire_weapon(), "Cooldown blocks duplicate shot")
	var initial: Vector3 = weapon.projectiles[0].position
	state.set_paused(true)
	weapon.advance_projectiles(0.1)
	check(weapon.projectiles[0].position == initial, "Pause freezes flight")
	state.set_paused(false)
	weapon.advance_projectiles(0.1)
	check(weapon.projectiles[0].position.z < initial.z, "Projectile travels forward")
	check(weapon.projectiles[0].position.y < initial.y, "Gravity lowers projectile")
	weapon.advance_projectiles(4.0)
	check(weapon.projectiles.is_empty(), "Range or lifetime clears projectile")
	var target: StaticBody3D = game.level.spawn_box(Vector3(30, 2, -10), Vector3(2, 3, 1), Color.RED)
	game.level.targets.append(target)
	var wall: StaticBody3D = game.level.spawn_box(Vector3(30, 2, -5), Vector3(4, 4, 1), Color.GRAY)
	await physics_frame
	await physics_frame
	weapon.shot_remaining = 0.0
	check(weapon.fire_weapon(), "Obstructed shot fires")
	weapon.advance_projectiles(0.2)
	check(weapon.projectiles.is_empty(), "Wall stops projectile")
	check(target in game.level.targets, "Wall protects target")
	wall.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	weapon.shot_remaining = 0.0
	check(weapon.fire_weapon(), "Clear shot fires")
	weapon.advance_projectiles(0.2)
	check(target not in game.level.targets, "Unobstructed target receives impact")
	check(weapon.projectiles.is_empty(), "Impact clears projectile")
	state.finish_mission()
	check(not weapon.fire_weapon(), "Completion blocks firing")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PROJECTILE TESTS PASSED")
	quit(0 if failures == 0 else 1)
