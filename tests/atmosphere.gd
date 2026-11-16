extends SceneTree

const Atmosphere = preload("res://scenes/levels/atmosphere.gd")
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
	check(Atmosphere.visibility(Atmosphere.TimeOfDay.NOON, Atmosphere.Weather.CLEAR) == 1.0, "Clear noon is full visibility")
	check(Atmosphere.visibility(Atmosphere.TimeOfDay.NIGHT, Atmosphere.Weather.CLEAR) < Atmosphere.visibility(Atmosphere.TimeOfDay.DUSK, Atmosphere.Weather.CLEAR), "Night is darker than dusk")
	check(Atmosphere.visibility(Atmosphere.TimeOfDay.NOON, Atmosphere.Weather.DUST) < 0.5, "Dust storms cut visibility hard")
	check(Atmosphere.hearing(Atmosphere.Weather.RAIN) < Atmosphere.hearing(Atmosphere.Weather.CLEAR), "Rain masks sound")
	var base := Vector3(2, 0, 0)
	var windy_peak := 0.0
	var windy_low := 100.0
	for i in range(400):
		var w: Vector3 = Atmosphere.wind_at(base, Atmosphere.Weather.WINDY, float(i) * 0.25)
		windy_peak = maxf(windy_peak, w.length())
		windy_low = minf(windy_low, w.length())
	check(windy_peak > 2.0 * 2.5 * 1.2 and windy_low < 2.0 * 2.5 * 0.8, "Windy weather gusts above and below its mean")
	check(Atmosphere.wind_at(base, Atmosphere.Weather.CLEAR, 3.0) == Atmosphere.wind_at(base, Atmosphere.Weather.CLEAR, 3.0), "Wind is deterministic in time")
	check(Atmosphere.wind_at(base, Atmosphere.Weather.WINDY, 7.0).normalized().is_equal_approx(base.normalized()), "Gusts change strength, not direction")
	# Levels apply their presets.
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var level = game.level
	check(level.time_of_day == Atmosphere.TimeOfDay.DUSK and level.weather == Atmosphere.Weather.WINDY, "The compound is a windy dusk")
	check(level.conditions_text() == "Dusk, windy" and game.hud.text.contains("Dusk, windy"), "HUD names the conditions")
	var sun: DirectionalLight3D = level.get_node("Sun")
	check(sun.shadow_enabled and is_equal_approx(sun.light_energy, 0.7) and is_equal_approx(sun.rotation_degrees.x, -14.0), "Dusk lowers and dims the sun")
	var world: WorldEnvironment = level.get_node("WorldEnvironment")
	check(is_equal_approx(world.environment.fog_density, 0.00015), "Weather sets the haze")
	var guard = level.enemies[0]
	for other in level.enemies:
		other.set_physics_process(false)
		if other != guard:
			other.global_position = Vector3(-55, 1, -5)
	check(absf(guard.perception.conditions_factor() - 0.7 * 0.95) < 0.001, "Guards see less far at a windy dusk")
	game.player.global_position = Vector3(0, 1, -10)
	guard.global_position = Vector3(0, 1, -95)
	guard.look_at(Vector3(0, 1, -10), Vector3.UP)
	await physics_frame
	await physics_frame
	check(guard.perception.visibility_of_player(game.player) == 0.0, "A player 85 m away is invisible at dusk")
	level.time_of_day = Atmosphere.TimeOfDay.NOON
	level.weather = Atmosphere.Weather.CLEAR
	check(guard.perception.visibility_of_player(game.player) > 0.0, "The same player is visible at clear noon")
	level.weather = Atmosphere.Weather.WINDY
	level.clock = 0.0
	game._physics_process(0.0)
	var w0: Vector3 = game.weapon.wind
	level.clock = 5.0
	game._physics_process(0.0)
	check(w0 != game.weapon.wind and w0.length() > level.wind.length(), "The rifle reads the gusting level wind each step")
	game.queue_free()
	await process_frame
	var range_game = load("res://range_mission.tscn").instantiate()
	root.add_child(range_game)
	await process_frame
	check(range_game.level.time_of_day == Atmosphere.TimeOfDay.NOON and range_game.level.weather == Atmosphere.Weather.CLEAR, "The range is clear noon")
	range_game.queue_free()
	await process_frame
	if failures == 0:
		print("ATMOSPHERE TESTS PASSED")
	quit(0 if failures == 0 else 1)
