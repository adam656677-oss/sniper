extends SceneTree

const Gunsmith = preload("res://gunsmith.gd")
var failures := 0

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func csv_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			keys[row[0]] = row[1]
	return keys

# Checklist 5.3: additional scopes for the rifle families.
func scope_tests() -> void:
	var scoped := {"interval": 0.9, "reload": 2.2, "spread": 0.0, "range": 1200.0, "fov": 25.0, "capacity": 5, "pellets": 1,
		"zoom_min": 4.0, "zoom_max": 12.0, "zoom_step": 2.0, "reticle_step": 100.0, "reticle_max": 1000.0}
	var unscoped := {"interval": 0.9, "reload": 2.2, "spread": 0.0, "range": 1200.0, "fov": 25.0, "capacity": 5}
	for part_id in ["close_scope", "long_scope"]:
		check(Gunsmith.PARTS.has(part_id) and Gunsmith.PARTS[part_id].slot == "optic", "New scope is an optic part: " + part_id)
		for family in ["recon", "heavy_rifle", "carbine"]:
			check(Gunsmith.compatible(family, "optic", part_id) and not Gunsmith.calculate(scoped, family, {"optic": part_id}).is_empty(), "%s fits the %s family" % [part_id, family])
		for family in ["sidearm", "auto_shotgun", "pump_shotgun"]:
			check(not Gunsmith.compatible(family, "optic", part_id) and Gunsmith.calculate(scoped, family, {"optic": part_id}).is_empty(), "%s is refused on the %s family" % [part_id, family])
		check(not Gunsmith.compatible("recon", "stock", part_id) and Gunsmith.calculate(scoped, "recon", {"stock": part_id}).is_empty(), "%s is refused in the stock slot" % part_id)
		check(Gunsmith.calculate(unscoped, "recon", {"optic": part_id}).is_empty(), "%s needs a base profile with scope stats" % part_id)
	var standard := Gunsmith.calculate(scoped, "recon", {"optic": "precision_scope"})
	var close := Gunsmith.calculate(scoped, "recon", {"optic": "close_scope"})
	var long := Gunsmith.calculate(scoped, "heavy_rifle", {"optic": "long_scope"})
	check(standard.zoom_min == 4.0 and standard.zoom_max == 12.0 and standard.reticle_max == 1000.0, "Precision scope keeps the standard 4x to 12x and 1000 m reticle")
	check(close.zoom_min == 2.0 and close.zoom_max == 8.0 and close.zoom_step == 2.0, "Close-range scope magnifies 2x to 8x")
	check(close.reticle_step == 50.0 and close.reticle_max == 600.0, "Close-range scope marks a hold every 50 m out to 600 m")
	check(long.zoom_min == 6.0 and long.zoom_max == 24.0 and long.zoom_step == 3.0, "Long-range scope magnifies 6x to 24x in 3x steps")
	check(long.reticle_step == 100.0 and long.reticle_max == 1500.0, "Long-range scope marks holds out to 1500 m")
	check(close.fov > standard.fov and standard.fov > long.fov, "Aimed view: close-range scope widest, long-range scope narrowest")
	check(close.zoom_max < standard.zoom_max and long.zoom_min > standard.zoom_min, "Trade-off: the close scope tops out lower, the long scope cannot zoom out as wide")
	for stat in ["interval", "reload", "spread", "range", "capacity", "pellets"]:
		check(close[stat] == scoped[stat] and long[stat] == scoped[stat], "Scopes change only optical stats: " + stat)
	check(scoped.zoom_min == 4.0 and scoped.zoom_max == 12.0 and scoped.fov == 25.0, "Scope calculation leaves the base stats unchanged")
	var build := Gunsmith.calculate(scoped, "heavy_rifle", {"optic": "long_scope", "spring": "match_barrel", "stock": "stable_stock"})
	check(build.zoom_max == 24.0 and is_equal_approx(build.range, 1320.0) and is_equal_approx(build.reload, 2.31), "A long-range build combines scope, barrel and stock")
	check(Gunsmith.calculate(scoped, "recon", {"optic": "close_scope"}) == close, "Swapping scopes recalculates from the base")
	for part_id in Gunsmith.PARTS:
		var settings: Dictionary = Gunsmith.PARTS[part_id].set
		if settings.has("zoom_min"):
			var span: float = float(settings.zoom_max) - float(settings.zoom_min)
			check(float(settings.zoom_min) >= 1.0 and span > 0.0 and is_zero_approx(fmod(span, float(settings.zoom_step))), "Magnification steps evenly from minimum to maximum: " + part_id)
			check(float(settings.reticle_step) > 0.0 and float(settings.reticle_max) > float(settings.reticle_step), "Reticle spacing is sensible: " + part_id)
	var profile_stats := WeaponProfile.new().to_stats()
	check(profile_stats.zoom_min == 4.0 and profile_stats.zoom_max == 12.0 and profile_stats.zoom_step == 2.0 and profile_stats.reticle_step == 100.0 and profile_stats.reticle_max == 1000.0, "Profiles default to the standard scope")
	check(not Gunsmith.calculate(profile_stats, "recon", {"optic": "long_scope"}).is_empty(), "Profile stats accept the new scopes")
	# Display names: fictional, and in the translation table.
	var keys := csv_keys()
	for part_id in Gunsmith.PARTS:
		var name := Gunsmith.part_name(part_id)
		check(not name.is_empty() and keys.has(name), "Part has a translated display name: " + part_id)
	check(Gunsmith.part_name("close_scope") == "Thicket close-range scope" and Gunsmith.part_name("long_scope") == "Farwatch long-range scope", "New scopes carry fictional names")
	check(Gunsmith.part_name("unknown").is_empty(), "Unknown parts have no name")

func _initialize() -> void:
	var base := {"interval": 1.0, "reload": 2.0, "spread": 0.05, "fov": 75.0, "capacity": 8}
	var installed := {"spring": "light_spring", "stock": "stable_stock"}
	var result := Gunsmith.calculate(base, "auto_shotgun", installed)
	check(is_equal_approx(result.interval, 0.9), "Spring changes fictional cadence")
	check(is_equal_approx(result.spread, 0.0495), "Part tradeoffs combine")
	check(base.interval == 1.0 and base.spread == 0.05, "Base stats are unchanged")
	check(Gunsmith.calculate(base, "auto_shotgun", installed) == result, "Recalculation does not stack bonuses")
	check(Gunsmith.calculate(base, "auto_shotgun", {}) == base, "Removing parts restores base stats")
	check(Gunsmith.calculate(base, "pump_shotgun", {"spring": "light_spring"}).is_empty(), "Incompatible spring is rejected")
	check(Gunsmith.calculate(base, "auto_shotgun", {"stock": "reflex"}).is_empty(), "Wrong slot is rejected")
	check(Gunsmith.calculate(base, "auto_shotgun", {"optic": "unknown"}).is_empty(), "Unknown part is rejected")
	check(Gunsmith.calculate(base, "unknown", {}).is_empty(), "Unknown family is rejected")
	check(result.capacity == 8, "Upgrades do not grant ammunition capacity")
	for family in Gunsmith.FAMILIES:
		check(not Gunsmith.calculate(base, family, Gunsmith.upgraded_preset(family)).is_empty(), "Preset valid: " + family)
	scope_tests()
	if failures == 0:
		print("GUNSMITH TESTS PASSED")
	quit(0 if failures == 0 else 1)
