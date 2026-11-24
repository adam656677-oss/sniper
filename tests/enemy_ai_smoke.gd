extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var packed := load("res://enemy.tscn") as PackedScene
	check(packed != null, "Enemy scene loads")
	if packed == null:
		quit(1)
		return

	var enemy := packed.instantiate() as EchoRidgeEnemy
	check(enemy != null, "Enemy scene uses EchoRidgeEnemy script")
	if enemy == null:
		quit(1)
		return

	root.add_child(enemy)
	await process_frame
	check(enemy.current_health == enemy.maximum_health, "Enemy starts at full health")
	check(enemy.current_state == EchoRidgeEnemy.State.IDLE, "Enemy starts idle without patrol points")

	enemy.investigate_position_at(Vector3(8, 0, 0))
	check(enemy.current_state == EchoRidgeEnemy.State.INVESTIGATE, "Sound stimulus changes state to investigate")
	check(enemy._has_investigation_target, "Investigation stores stimulus position")

	enemy.receive_damage(25.0, Vector3(4, 0, 2))
	check(is_equal_approx(enemy.current_health, 75.0), "Damage reduces enemy health")
	check(enemy.current_state == EchoRidgeEnemy.State.INVESTIGATE, "Damage source can become investigation target")

	enemy.receive_damage(1000.0)
	check(enemy.current_state == EchoRidgeEnemy.State.DEAD, "Lethal damage enters dead state")
	await process_frame
	check(not is_instance_valid(enemy), "Eliminated enemy is removed from scene")

	print("Enemy checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
