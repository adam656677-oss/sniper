extends SceneTree

const Gunsmith = preload("res://gunsmith.gd")
var failures := 0

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var base := {"interval": 1.0, "reload": 2.0, "spread": 0.05, "fov": 75.0, "capacity": 8}
	var installed := {"spring": "light_spring", "stock": "stable_stock"}
	var result := Gunsmith.calculate(base, "origin12", installed)
	check(is_equal_approx(result.interval, 0.9), "Spring changes fictional cadence")
	check(is_equal_approx(result.spread, 0.0495), "Part tradeoffs combine")
	check(base.interval == 1.0 and base.spread == 0.05, "Base stats are unchanged")
	check(Gunsmith.calculate(base, "origin12", installed) == result, "Recalculation does not stack bonuses")
	check(Gunsmith.calculate(base, "origin12", {}) == base, "Removing parts restores base stats")
	check(Gunsmith.calculate(base, "ksg", {"spring": "light_spring"}).is_empty(), "Incompatible spring is rejected")
	check(Gunsmith.calculate(base, "origin12", {"stock": "reflex"}).is_empty(), "Wrong slot is rejected")
	check(Gunsmith.calculate(base, "origin12", {"optic": "unknown"}).is_empty(), "Unknown part is rejected")
	check(Gunsmith.calculate(base, "unknown", {}).is_empty(), "Unknown family is rejected")
	check(result.capacity == 8, "Upgrades do not grant ammunition capacity")
	for family in Gunsmith.FAMILIES:
		check(not Gunsmith.calculate(base, family, Gunsmith.upgraded_preset(family)).is_empty(), "Preset valid: " + family)
	if failures == 0:
		print("GUNSMITH TESTS PASSED")
	quit(0 if failures == 0 else 1)
