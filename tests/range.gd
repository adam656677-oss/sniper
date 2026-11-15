extends SceneTree

const Ballistics = preload("res://ballistics.gd")
var failures := 0
var state: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

# Aim the camera at a plate from the firing line, raising by holdover and
# correcting for computed wind drift, then fire and let the bullet fly.
func shoot_plate(game: Node, plate: Node, correct_wind: bool) -> void:
	var weapon = game.weapon
	var origin: Vector3 = plate.global_position + Vector3(0, 0, plate.range_metres)
	game.camera.global_position = origin
	var hold: float = weapon.holdover_at(plate.range_metres)
	var drift := 0.0
	if correct_wind:
		var params: Dictionary = weapon.ballistic_params()
		var elevation: float = Ballistics.zero_angle(weapon.profile().muzzle_velocity, weapon.zero_range(), params)
		# simulate_flat's frame is +X downrange, +Z right; our shot goes -Z with +X to the right.
		var shot_frame_wind := Vector3(-weapon.wind.z, weapon.wind.y, weapon.wind.x)
		var flight: Dictionary = Ballistics.simulate_flat(weapon.profile().muzzle_velocity, elevation, plate.range_metres, Ballistics.make_params(params.gravity, params.drag, shot_frame_wind))
		drift = float(flight.drift)
	var aim_point: Vector3 = plate.global_position + Vector3(-drift, hold, 0)
	game.camera.look_at(aim_point, Vector3.UP)
	weapon.shot_remaining = 0.0
	weapon.ammo = maxi(weapon.ammo, 1)
	weapon.fire_weapon()
	weapon.advance_projectiles(3.0)

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var level = game.level
	check(level.plates.size() == 10 and level.plates[0].range_metres == 100.0 and level.plates[9].range_metres == 1000.0, "Ten plates from 100 m to 1000 m")
	check(level.get_node("Plates").get_child_count() == 20, "Each plate has a distance marker")
	check(level.objective_text().begins_with("Ring every plate (0 / 10)"), "Objective counts rung plates")
	check(not level.is_complete() and not state.finished, "Range starts incomplete")
	var plate300 = level.plate_at(300.0)
	game.camera.global_position = Vector3(0, 1.4, 0)
	game.camera.look_at(plate300.global_position, Vector3.UP)
	check(absf(game.measure_range() - 300.0) < 0.5, "Rangefinder reads the 300 m plate")
	game.weapon.wind = Vector3.ZERO
	shoot_plate(game, plate300, false)
	check(plate300.hit_count == 1 and plate300.fallen, "Holdover-corrected shot rings the 300 m plate")
	var plate600 = level.plate_at(600.0)
	shoot_plate(game, plate600, false)
	check(plate600.hit_count == 1, "Holdover-corrected shot rings the 600 m plate in still air")
	game.weapon.wind = Vector3(6.0, 0.0, 0.0)
	var plate800 = level.plate_at(800.0)
	shoot_plate(game, plate800, false)
	check(plate800.hit_count == 0, "Uncorrected shot in a 6 m/s crosswind misses the 800 m plate")
	shoot_plate(game, plate800, true)
	check(plate800.hit_count == 1, "Drift-corrected shot rings the 800 m plate")
	game.weapon.wind = Vector3.ZERO
	var plate1000 = level.plate_at(1000.0)
	game.weapon.zero_ranges[0] = 600.0
	shoot_plate(game, plate1000, false)
	check(plate1000.hit_count == 1, "Rezeroed rifle rings the 1000 m plate with holdover")
	plate300.reset()
	check(not plate300.fallen and plate300.plate.rotation_degrees.x == 0.0, "Plate resets upright")
	plate300.take_hit(-1, 0.0)
	plate300._physics_process(5.0)
	check(not plate300.fallen, "Fallen plate stands back up after the reset delay")
	for plate in level.plates:
		if plate.hit_count == 0:
			plate.take_hit(-1, 0.0)
	check(level.is_complete(), "Ringing every plate completes the range")
	game.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(state.finished and game.hud.text.contains("MISSION COMPLETE"), "Mission finishes when the range is complete")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("RANGE TESTS PASSED")
	quit(0 if failures == 0 else 1)
