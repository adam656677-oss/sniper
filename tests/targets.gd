extends SceneTree

var failures := 0
var state: Node
var deaths := 0

func on_died(_target: Node) -> void:
	deaths += 1

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func shape_index(body: CollisionObject3D, node_name: String) -> int:
	var node: CollisionShape3D = body.get_node(node_name)
	for owner_id in body.get_shape_owners():
		if body.shape_owner_get_owner(owner_id) == node:
			return body.shape_owner_get_shape_index(owner_id, 0)
	return -1

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var level = game.level
	check(level.targets.size() == 3 and level.targets[0].has_method("take_hit"), "Range targets are dummies with hit zones")
	var dummy = level.targets[0]
	var head := shape_index(dummy, "Head")
	var torso := shape_index(dummy, "Torso")
	var legs := shape_index(dummy, "Legs")
	check(head >= 0 and torso >= 0 and legs >= 0, "Hit zone shapes resolve")
	check(dummy.zone_for_shape(head) == "head" and dummy.zone_for_shape(torso) == "torso" and dummy.zone_for_shape(legs) == "limb", "Shapes map to zones")
	check(dummy.zone_for_shape(-1) == "torso", "Unknown shape defaults to torso")
	check(is_equal_approx(dummy.take_hit(legs, 50.0), 20.0) and dummy.is_alive(), "Limb hit deals reduced damage")
	check(is_equal_approx(dummy.take_hit(torso, 50.0), 50.0) and dummy.is_alive(), "Torso hit deals full damage")
	dummy.died.connect(on_died)
	check(dummy.take_hit(torso, 50.0) > 0.0 and not dummy.is_alive(), "Torso damage accumulates to a kill")
	check(dummy.take_hit(torso, 50.0) == 0.0, "Dead target takes no more damage")
	check(deaths == 1 and dummy not in level.targets and level.targets.size() == 2, "Death removes the target from the level once")
	await process_frame
	check(not is_instance_valid(dummy), "Dead target is freed")
	var second = level.targets[0]
	check(second.take_hit(shape_index(second, "Head"), 90.0) > 0.0 and not second.is_alive(), "Rifle headshot is lethal")
	await process_frame
	var third = level.targets[0]
	third.take_hit(shape_index(third, "Torso"), 90.0)
	check(third.is_alive(), "Single rifle torso hit is survivable")
	# Live shot: aim the rifle at the remaining dummy's head from 15 m.
	state.set_paused(false)
	game.weapon.select_weapon(0)
	game.camera.global_position = third.global_position + Vector3(0, 0.85, 15)
	game.camera.global_rotation = Vector3.ZERO
	game.weapon.shot_remaining = 0.0
	check(game.weapon.fire_weapon(), "Rifle fires at the dummy")
	game.weapon.advance_projectiles(0.1)
	check(not third.is_alive() and level.targets.is_empty(), "Projectile headshot kills the last target")
	await process_frame
	game.queue_free()
	await process_frame
	if failures == 0:
		print("TARGET TESTS PASSED")
	quit(0 if failures == 0 else 1)
