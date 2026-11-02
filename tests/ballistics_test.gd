extends SceneTree

const Ballistics = preload("res://ballistics.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var initial := Vector3(0, 10, 0)
	var velocity := Vector3(100, 0, 0)
	var result := Ballistics.step(initial, velocity, 1.0)
	check(result.position.is_equal_approx(Vector3(100, 5.095, 0)), "Gravity displacement")
	check(result.velocity.is_equal_approx(Vector3(100, -9.81, 0)), "Gravity velocity")
	var zero := Ballistics.step(initial, velocity, 0.0)
	check(zero.position == initial and zero.velocity == velocity, "Zero time")
	var negative := Ballistics.step(initial, velocity, -1.0)
	check(negative.position == initial and negative.velocity == velocity, "Negative time clamped")
	var wind := Ballistics.step(Vector3.ZERO, Vector3.ZERO, 2.0, 0.0, Vector3(0, 0, 2))
	check(wind.position.is_equal_approx(Vector3(0, 0, 4)), "Wind displacement")
	check(wind.velocity.is_equal_approx(Vector3(0, 0, 4)), "Wind velocity")
	var half := Ballistics.step(initial, velocity, 0.5)
	var split := Ballistics.step(half.position, half.velocity, 0.5)
	check(split.position.is_equal_approx(result.position), "Step subdivision position")
	check(split.velocity.is_equal_approx(result.velocity), "Step subdivision velocity")
	print("Ballistics: 8 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
