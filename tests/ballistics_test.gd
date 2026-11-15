extends SceneTree

const Ballistics = preload("res://ballistics.gd")
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

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

	# Drag model and flat-fire helpers.
	var vacuum := Ballistics.make_params(9.81, 0.0, Vector3.ZERO)
	var dragged := Ballistics.make_params(9.81, 0.0004, Vector3.ZERO)
	var drag_step := Ballistics.step_drag(initial, velocity, 0.5, vacuum)
	check(drag_step.position.is_equal_approx(half.position) and drag_step.velocity.is_equal_approx(half.velocity), "Drag step matches legacy step without drag or wind")
	var vacuum_drop := Ballistics.drop_at_range(180.0, 300.0, vacuum)
	check(absf(vacuum_drop - 0.5 * 9.81 * pow(300.0 / 180.0, 2)) < 0.05, "Vacuum drop at 300 m matches closed form")
	var flight := Ballistics.simulate_flat(820.0, 0.0, 300.0, dragged)
	check(flight.reached and flight.speed < 820.0 and flight.speed > 500.0, "Drag slows the bullet over 300 m")
	check(Ballistics.drop_at_range(820.0, 600.0, dragged) > Ballistics.drop_at_range(820.0, 600.0, vacuum), "Drag increases drop at 600 m")
	var elevation := Ballistics.zero_angle(820.0, 100.0, dragged)
	check(elevation > 0.0 and absf(Ballistics.simulate_flat(820.0, elevation, 100.0, dragged).height) < 0.01, "Zeroing puts the bullet on the bore line at 100 m")
	check(absf(Ballistics.holdover(820.0, 100.0, 100.0, dragged)) < 0.01, "Holdover at the zero range is zero")
	var hold_300 := Ballistics.holdover(820.0, 300.0, 100.0, dragged)
	var hold_600 := Ballistics.holdover(820.0, 600.0, 100.0, dragged)
	check(hold_300 > 0.0 and hold_600 > hold_300, "Holdover grows with range beyond the zero")
	var crosswind := Ballistics.make_params(9.81, 0.0004, Vector3(0, 0, 5))
	check(Ballistics.simulate_flat(820.0, 0.0, 600.0, crosswind).drift > 0.05, "Crosswind drifts the bullet downwind")
	var headwind := Ballistics.make_params(9.81, 0.0004, Vector3(-10, 0, 0))
	check(Ballistics.drop_at_range(820.0, 600.0, headwind) > Ballistics.drop_at_range(820.0, 600.0, dragged), "Headwind increases drop")
	check(Ballistics.zero_angle(820.0, 0.0, dragged) == 0.0 and Ballistics.zero_angle(0.0, 100.0, dragged) == 0.0, "Degenerate zero inputs return no elevation")
	print("Ballistics: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
