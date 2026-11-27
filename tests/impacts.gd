extends SceneTree

# Ricochets off hard surfaces, their spark and whine, guards hearing them, the
# optional blood mist, and the hit marker staying the same in both blood modes.
# Geometry sits 40 m up, away from the range's own ground, plates and berm.

const Ballistics = preload("res://ballistics.gd")
const ImpactSurfaces = preload("res://scenes/fx/impact_surfaces.gd")

var failures := 0
var checks := 0
var ricochets: Array = []
var impacts: Array = []
var hits: Array = []
var events: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func degrees_between(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized()))

func mirror(direction: Vector3, normal: Vector3) -> Vector3:
	var n := normal.normalized()
	return direction - 2.0 * direction.dot(n) * n

# A thin upright sheet 12 m long. A round flying along -Z through its centre meets
# its face at `graze` degrees; the face it meets has normal (-cos, 0, sin).
func sheet(level, centre: Vector3, graze: float, surface: String) -> StaticBody3D:
	var body: StaticBody3D = level.spawn_box(centre, Vector3(0.2, 4, 12), Color(0.45, 0.45, 0.48))
	body.rotation_degrees.y = graze
	body.set_meta("impact_surface", surface)
	return body

func face_normal(graze: float) -> Vector3:
	return Vector3(-cos(deg_to_rad(graze)), 0, sin(deg_to_rad(graze)))

func clear_logs() -> void:
	ricochets.clear()
	impacts.clear()
	hits.clear()
	events.clear()

func fire(game, origin: Vector3) -> void:
	game.camera.global_position = origin
	game.camera.global_rotation = Vector3.ZERO
	game.weapon.select_weapon(0)
	game.weapon.shot_remaining = 0.0
	game.weapon.reload_remaining = 0.0
	game.weapon.ammo = 5
	game.weapon.projectiles.clear()
	game.weapon.fire_weapon()

func settle() -> void:
	await physics_frame
	await physics_frame

func played(event_name: String, near: Vector3, tolerance: float = 0.5) -> bool:
	for event in events:
		if event[0] == event_name and Vector3(event[1]).distance_to(near) <= tolerance:
			return true
	return false

func run_tests() -> void:
	var settings: Node = root.get_node("Settings")
	settings.reset()
	var audio: Node = root.get_node("AudioDirector")
	# --- Deflection maths ---
	var up := Vector3.UP
	var ten := Vector3(0, -sin(deg_to_rad(10.0)), -cos(deg_to_rad(10.0))) * 800.0
	check(absf(Ballistics.incidence_angle(ten, up) - 10.0) < 0.01, "A round 10 degrees off a surface strikes it at 10 degrees")
	check(absf(Ballistics.incidence_angle(Vector3.DOWN, up) - 90.0) < 0.01, "A round straight into a surface strikes it at 90 degrees")
	check(Ballistics.RICOCHET_MAX_ANGLE == 15.0 and Ballistics.RICOCHET_SPEED_RETENTION == 0.6, "Ricochets need a strike of 15 degrees or less and keep 60% of the speed")
	var bounce: Dictionary = Ballistics.ricochet(ten, up, true, null, 0.0)
	check(not bounce.is_empty(), "A 10 degree strike on a hard surface ricochets")
	var bounced: Vector3 = bounce.get("velocity", Vector3.ZERO)
	check(degrees_between(bounced, mirror(ten, up)) < 0.01, "Without scatter it leaves along the mirror reflection")
	check(absf(bounced.length() - 800.0 * 0.6) < 0.01, "It keeps 60% of its speed")
	check(bounced.dot(up) > 0.0, "It leaves the surface")
	var fourteen := Vector3(0, -sin(deg_to_rad(14.0)), -cos(deg_to_rad(14.0))) * 800.0
	var sixteen := Vector3(0, -sin(deg_to_rad(16.0)), -cos(deg_to_rad(16.0))) * 800.0
	check(not Ballistics.ricochet(fourteen, up, true, null, 0.0).is_empty(), "14 degrees is shallow enough to ricochet")
	check(Ballistics.ricochet(sixteen, up, true, null, 0.0).is_empty(), "16 degrees is too steep: the round stops")
	check(Ballistics.ricochet(Vector3.DOWN * 800.0, up, true, null, 0.0).is_empty(), "A head-on strike stops")
	check(Ballistics.ricochet(ten, up, false, null, 0.0).is_empty(), "A soft surface stops even a grazing round")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 4242
	rng_b.seed = 4242
	var within_cone := true
	var leaves := true
	var repeatable := true
	var varied := false
	var first := Vector3.ZERO
	for i in range(40):
		var a: Dictionary = Ballistics.ricochet(ten, up, true, rng_a, Ballistics.RICOCHET_SCATTER_DEGREES)
		var b: Dictionary = Ballistics.ricochet(ten, up, true, rng_b, Ballistics.RICOCHET_SCATTER_DEGREES)
		var va: Vector3 = a.velocity
		repeatable = repeatable and va == Vector3(b.velocity)
		within_cone = within_cone and degrees_between(va, mirror(ten, up)) <= Ballistics.RICOCHET_SCATTER_DEGREES + 0.001
		leaves = leaves and va.dot(up) > 0.0 and absf(va.length() - 480.0) < 0.01
		if i == 0:
			first = va
		elif degrees_between(va, first) > 0.1:
			varied = true
	check(repeatable, "The same seed gives the same scatter")
	check(within_cone and varied, "Scatter spreads rounds within %.0f degrees of the reflection" % Ballistics.RICOCHET_SCATTER_DEGREES)
	check(leaves, "Scattered rounds still leave the surface at the retained speed")
	check(ImpactSurfaces.is_hard("metal") and ImpactSurfaces.is_hard("stone"), "Metal and stone are hard surfaces")
	check(not ImpactSurfaces.is_hard("earth") and not ImpactSurfaces.is_hard("wood") and not ImpactSurfaces.is_hard("flesh"), "Earth, wood and flesh are soft")
	# --- Live rounds in a mission ---
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var weapon = game.weapon
	var fx = game.feedback
	var level = game.level
	level.weather = 0
	level.wind = Vector3.ZERO
	weapon.wind = Vector3.ZERO
	weapon.ricochet_scatter = 0.0
	weapon.ricochet.connect(func(position, normal, incoming, outgoing, body): ricochets.append({"position": position, "normal": normal, "incoming": incoming, "outgoing": outgoing, "body": body}))
	weapon.impact.connect(func(position, normal, body): impacts.append({"position": position, "normal": normal, "body": body}))
	weapon.body_hit.connect(func(body, shape, damage, distance): hits.append({"body": body, "damage": damage, "distance": distance}))
	audio.event_played.connect(func(event_name, position): events.append([event_name, position]))
	# Grazing metal: deflects and still hits a target on its new path.
	var metal := sheet(level, Vector3(0, 40, -40), 10.0, "metal")
	var expected := Vector3(-sin(deg_to_rad(20.0)), 0, -cos(deg_to_rad(20.0)))
	var strike := Vector3(0, 40, -40 + 0.1 / sin(deg_to_rad(10.0)))
	var target: StaticBody3D = level.spawn_box(strike + expected * 20.0, Vector3(2, 3, 1), Color.RED)
	level.targets.append(target)
	await settle()
	check(weapon.deflects_off(metal) and game.impact_surface_for(metal) == "metal", "A metal sheet can deflect a round")
	clear_logs()
	var ricochets_before: int = fx.ricochet_count
	fire(game, Vector3(0, 40, 0))
	weapon.advance_projectiles(0.2)
	check(ricochets.size() == 1, "A 10 degree strike on metal ricochets")
	if ricochets.size() == 1:
		var r: Dictionary = ricochets[0]
		check(Vector3(r.position).distance_to(strike) < 0.1 and r.body == metal, "The ricochet starts where the round meets the sheet")
		check(degrees_between(r.normal, face_normal(10.0)) < 0.5 and absf(Ballistics.incidence_angle(r.incoming, r.normal) - 10.0) < 0.5, "The round met the sheet face at 10 degrees")
		check(degrees_between(r.outgoing, mirror(r.incoming, r.normal)) < 0.01, "It leaves along the reflection of its path about the surface normal")
		check(degrees_between(r.outgoing, expected) < 0.5, "So it turns 20 degrees off its line")
		check(absf(Vector3(r.outgoing).length() / Vector3(r.incoming).length() - 0.6) < 0.001, "It keeps 60% of its speed through the ricochet")
		check(impacts.size() >= 1 and impacts[0].body == metal, "The sheet still shows a strike where the round skipped")
		check(hits.filter(func(hit): return hit.body == metal).is_empty(), "The skipped sheet takes no hit")
		check(fx.ricochet_count == ricochets_before + 1 and degrees_between(fx.last_ricochet_direction, r.outgoing) < 0.01, "Ricochet sparks fly along the new path")
		var sparks: CPUParticles3D = fx.last_ricochet_sparks
		check(sparks != null and degrees_between(sparks.direction, r.outgoing) < 0.01 and sparks.global_position.distance_to(r.position) < 0.05, "The spark streak starts at the strike and points along the new path")
		check(played("ricochet", r.position) and not played("impact", r.position), "The strike plays the ricochet whine there, not a plain impact")
	var target_hits: Array = hits.filter(func(hit): return hit.body == target)
	check(target_hits.size() == 1 and target not in level.targets, "The deflected round hits a target on its new path")
	if target_hits.size() == 1:
		check(absf(float(target_hits[0].damage) - weapon.profile().damage * 0.36) < 0.01, "A ricochet hit carries the energy it kept: 36% damage")
		check(float(target_hits[0].distance) > 55.0, "The hit distance counts the whole path, bounce included")
	check(played("impact", strike + expected * 19.5, 2.0), "The deflected round lands with an ordinary impact")
	check(weapon.projectiles.is_empty(), "The deflected round stops in the target")
	metal.queue_free()
	await settle()
	# A deflected round only carries a short way.
	var far_sheet := sheet(level, Vector3(200, 40, -40), 10.0, "metal")
	await settle()
	clear_logs()
	fire(game, Vector3(200, 40, 0))
	var last_position := Vector3.ZERO
	var steps := 0
	while not weapon.projectiles.is_empty() and steps < 400:
		last_position = weapon.projectiles[0].position
		weapon.advance_projectiles(1.0 / 120.0)
		steps += 1
	check(ricochets.size() == 1 and weapon.projectiles.is_empty(), "A deflected round falls out of flight")
	if ricochets.size() == 1:
		var carried: float = Vector3(ricochets[0].position).distance_to(last_position)
		check(carried > weapon.RICOCHET_RANGE - 5.0 and carried <= weapon.RICOCHET_RANGE + 0.1, "It carries only %d m after the ricochet (%.1f m)" % [int(weapon.RICOCHET_RANGE), carried])
	# The scatter is seedable, so a test or a replay can repeat a ricochet.
	weapon.ricochet_scatter = Ballistics.RICOCHET_SCATTER_DEGREES
	var outgoing_runs: Array = []
	for run in range(2):
		clear_logs()
		weapon.ricochet_rng.seed = 99
		fire(game, Vector3(200, 40, 0))
		weapon.advance_projectiles(0.1)
		outgoing_runs.append(ricochets[0].outgoing if ricochets.size() == 1 else Vector3.ZERO)
	check(outgoing_runs[0] != Vector3.ZERO and outgoing_runs[0] == outgoing_runs[1], "The same ricochet seed repeats the same deflection")
	check(degrees_between(outgoing_runs[0], expected) <= Ballistics.RICOCHET_SCATTER_DEGREES + 0.5, "Scatter keeps a live ricochet near the reflection")
	weapon.ricochet_scatter = 0.0
	far_sheet.queue_free()
	await settle()
	# Steep strikes and soft materials stop the round as before.
	var cases := [["metal", 45.0, 300.0, "A 45 degree strike on metal stops the round"],
		["stone", 30.0, 340.0, "A 30 degree strike on stone stops the round"],
		["wood", 10.0, 380.0, "A grazing strike on wood stops the round"],
		["earth", 10.0, 420.0, "A grazing strike on earth stops the round"]]
	for scenario in cases:
		var body := sheet(level, Vector3(scenario[2], 40, -40), scenario[1], scenario[0])
		await settle()
		clear_logs()
		fire(game, Vector3(scenario[2], 40, 0))
		weapon.advance_projectiles(0.2)
		check(ricochets.is_empty() and weapon.projectiles.is_empty() and impacts.size() == 1 and impacts[0].body == body, scenario[3])
		check(fx.last_impact_surface == scenario[0] and played("impact", impacts[0].position if impacts.size() == 1 else Vector3.INF), "It shows the %s impact and plays the impact cue" % scenario[0])
		body.queue_free()
		await settle()
	var stone := sheet(level, Vector3(460, 40, -40), 10.0, "stone")
	await settle()
	clear_logs()
	fire(game, Vector3(460, 40, 0))
	weapon.advance_projectiles(0.1)
	check(ricochets.size() == 1, "A grazing strike on stone or rock ricochets too")
	stone.queue_free()
	await settle()
	# Guards hear a ricochet near them. A suppressed shot is too quiet to reach them from the firing point.
	var rifle = weapon.profiles[0]
	rifle.suppressed = true
	var guard_scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var guards: Array = []
	for spot in [Vector3(800, 39.1, -42), Vector3(770, 39.1, -55), Vector3(1000, 39.1, -40)]:
		var guard = guard_scene.instantiate()
		level.add_child(guard)
		guard.global_position = spot
		guard.set_physics_process(false)
		level.register_enemy(guard)
		guards.append(guard)
	var near_guard = guards[0]
	var mid_guard = guards[1]
	var far_guard = guards[2]
	near_guard.global_position = Vector3(5000, 39.1, 0) # out of the way for the first shot
	var guard_sheet := sheet(level, Vector3(800, 40, -40), 10.0, "metal")
	await settle()
	check(not weapon.deflects_off(near_guard) and game.impact_surface_for(near_guard) == "flesh", "A hostile never deflects a round")
	clear_logs()
	fire(game, Vector3(800, 40, 0))
	weapon.advance_projectiles(0.1)
	var guard_strike: Vector3 = ricochets[0].position if ricochets.size() == 1 else Vector3.INF
	check(ricochets.size() == 1, "A suppressed round also ricochets")
	check(mid_guard.state == mid_guard.State.INVESTIGATE and mid_guard.last_known.distance_to(guard_strike) < 0.5, "A ricochet 30 m from a guard draws them to investigate it")
	check(far_guard.state == far_guard.State.PATROL, "A guard 200 m away does not hear it")
	mid_guard.global_position = Vector3(-5000, 39.1, 0)
	near_guard.global_position = Vector3(800 - 4.0, 39.1, -41.0)
	await settle()
	clear_logs()
	fire(game, Vector3(800, 40, 0))
	weapon.advance_projectiles(0.1)
	check(ricochets.size() == 1 and near_guard.state == near_guard.State.ALERT and near_guard.last_known.distance_to(guard_strike) < 0.5, "A ricochet whining past a guard 4 m away alarms them")
	check(far_guard.state == far_guard.State.PATROL, "The distant guard still hears nothing")
	rifle.suppressed = false
	guard_sheet.queue_free()
	# --- Blood ---
	check(settings.get_value("gameplay", "blood_effects") == true and settings.blood_effects(), "Blood effects default to on")
	var dummy_scene: PackedScene = load("res://scenes/targets/target_dummy.tscn")
	var dummies: Array = []
	for i in range(4):
		var dummy = dummy_scene.instantiate()
		level.add_child(dummy)
		dummy.global_position = Vector3(1200 + i * 10, 40, -20)
		level.register_target(dummy)
		dummies.append(dummy)
	await settle()
	var plate = level.plate_at(100.0)
	check(game.impact_surface_for(dummies[0]) == "flesh" and game.impact_surface_for(plate) != "flesh", "Dummies are flesh, steel plates are not")
	check(not weapon.deflects_off(dummies[0]) and not weapon.deflects_off(plate), "Targets never deflect a round")
	var markers: Array = []
	var blood_before: int = fx.blood_count
	var holes_before: int = fx.holes.size()
	for blood in [true, false]:
		settings.set_value("gameplay", "blood_effects", blood)
		for kill in [false, true]:
			var dummy = dummies[markers.size()]
			fx.advance(1.0, 0.0, false, false)
			game.update_crosshair()
			clear_logs()
			fire(game, dummy.global_position + Vector3(0, 0.85 if kill else -0.55, 20))
			weapon.advance_projectiles(0.1)
			game.update_crosshair()
			markers.append({"text": game.crosshair.text, "color": game.crosshair.modulate, "time": fx.hit_marker_time, "kill": fx.hit_marker_kill, "surface": fx.last_impact_surface, "puff": fx.last_impact_puff})
			check(hits.size() == 1 and hits[0].body == dummy and dummy.is_alive() != kill, "%s hit lands with blood %s" % ["Head" if kill else "Leg", "on" if blood else "off"])
	check(markers[0].surface == "flesh" and markers[1].surface == "flesh" and fx.blood_count == blood_before + 2, "With blood on, hits on a body show a blood mist")
	var mist: CPUParticles3D = markers[0].puff
	check(mist != null and mist.color.r > 0.2 and mist.color.r < 0.5 and mist.color.g < mist.color.r * 0.25 and mist.color.b < mist.color.r * 0.25, "The mist is dark red")
	check(mist != null and mist.amount <= 12 and mist.lifetime <= 0.5 and mist.initial_velocity_max <= 2.0, "The mist is small and brief")
	check(markers[2].surface == "stone" and markers[3].surface == "stone" and fx.blood_count == blood_before + 2, "With blood off, the same hits show only the neutral dust puff")
	check(fx.holes.size() == holes_before, "Body hits never leave holes or decals")
	check(markers[0].text == "X" and markers[0].color == Color(1, 1, 1) and markers[1].text == "X" and markers[1].color == Color(1, 0.2, 0.2), "Hits and kills show the hit marker")
	check(markers[2].text == markers[0].text and markers[2].color == markers[0].color and markers[2].time == markers[0].time and markers[2].kill == markers[0].kill, "The hit marker is the same with blood off")
	check(markers[3].text == markers[1].text and markers[3].color == markers[1].color and markers[3].time == markers[1].time and markers[3].kill == markers[1].kill, "The kill marker is the same with blood off")
	settings.set_value("gameplay", "blood_effects", true)
	game.on_impact(plate.global_position, Vector3.BACK, plate)
	check(fx.last_impact_surface != "flesh" and fx.blood_count == blood_before + 2, "Steel plates never bleed")
	game.on_impact(near_guard.global_position, Vector3.BACK, near_guard)
	check(fx.last_impact_surface == "flesh" and fx.blood_count == blood_before + 3, "Hostiles show the mist when blood is on")
	settings.set_value("gameplay", "blood_effects", false)
	game.on_impact(near_guard.global_position, Vector3.BACK, near_guard)
	check(fx.last_impact_surface == "stone" and fx.blood_count == blood_before + 3, "Hostiles show the neutral puff when blood is off")
	# --- Straight shots are untouched ---
	settings.reset()
	level.wind = Vector3(3, 0, 0)
	weapon.wind = Vector3(3, 0, 0)
	fire(game, Vector3(-3000, 40, 0))
	var round: Dictionary = weapon.projectiles[0]
	var position: Vector3 = round.position
	var velocity: Vector3 = round.velocity
	var params: Dictionary = weapon.ballistic_params()
	for i in range(30):
		var state: Dictionary = Ballistics.step_drag(position, velocity, weapon.SUBSTEP, params)
		position = state.position
		velocity = state.velocity
	weapon.advance_projectiles(30.0 / 120.0)
	check(weapon.projectiles.size() == 1 and Vector3(weapon.projectiles[0].position).is_equal_approx(position) and Vector3(weapon.projectiles[0].velocity).is_equal_approx(velocity), "A round in open air follows the unchanged drag integration")
	var flown := 0.0
	steps = 0
	while not weapon.projectiles.is_empty() and steps < 400:
		flown = float(weapon.projectiles[0].distance)
		weapon.advance_projectiles(1.0 / 60.0)
		steps += 1
	check(flown > weapon.profile().max_range - 20.0, "A straight round still flies to the rifle's full %d m range" % int(weapon.profile().max_range))
	game.queue_free()
	await process_frame
	settings.reset()
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("IMPACTS TESTS PASSED")
	quit(0 if failures == 0 else 1)
