extends Node3D

# Mission root: wires the level, player, weapon rig and HUD together and
# routes input to the right system. Simulation state lives in GameState.

@onready var level: LevelBase = $Level
@onready var player: Player = $Player
@onready var weapon: WeaponRig = $WeaponRig
@onready var hud: Label = $HUDLayer/HUD
@onready var sway: AimSway = $AimSway
@onready var killcam: KillCam = $KillCam
@onready var stealth: StealthKit = $StealthKit
var measured_range := -1.0
var last_long_shot := 0.0
var stats := {"shots": 0, "hits": 0, "kills": 0, "longest_kill": 0.0, "elapsed": 0.0, "detections": 0}
var camera: Camera3D

func _ready() -> void:
	GameState.reset()
	Settings.apply()
	killcam.enabled = bool(Settings.get_value("gameplay", "killcam"))
	camera = player.camera
	player.spawn_point = level.spawn_point
	player.position = level.spawn_point
	weapon.camera = camera
	weapon.excluded = [player.get_rid()]
	weapon.body_hit.connect(level.on_body_hit)
	weapon.wind = level.wind
	level.player = player
	stealth.camera = camera
	stealth.player = player
	stealth.level = level
	level.target_killed.connect(on_target_killed)
	weapon.fired.connect(on_weapon_fired)
	weapon.body_hit.connect(on_body_hit)
	level.coordinator.level_changed.connect(on_alert_changed)
	level.mission_log.objective_changed.connect(on_objective_changed)
	SaveSystem.apply_pending(self)

func on_objective_changed(_id: String, status: int) -> void:
	if status == MissionLog.Status.COMPLETE and not GameState.finished and not level.is_complete():
		SaveSystem.save_game(SaveSystem.CHECKPOINT_SLOT, self)

func quick_save() -> bool:
	if not GameState.simulation_active():
		return false
	return SaveSystem.save_game(SaveSystem.QUICK_SLOT, self)

func load_slot(slot: String) -> bool:
	if not SaveSystem.request_load(slot):
		return false
	get_tree().reload_current_scene()
	return true

func on_weapon_fired(profile: WeaponProfile) -> void:
	stats.shots += 1
	level.report_noise(camera.global_position, 25.0 if profile.suppressed else 400.0)

func on_body_hit(body: Node3D, _shape_index: int, _damage: float, _distance: float) -> void:
	if body and body.has_method("take_hit"):
		stats.hits += 1

func on_alert_changed(level_value: int) -> void:
	if level_value >= AlertCoordinator.Level.ALERT:
		stats.detections += 1

func accuracy() -> float:
	return 0.0 if stats.shots == 0 else float(stats.hits) / float(stats.shots)
	update_hud()

func on_target_killed(_body: Node3D, distance: float) -> void:
	stats.kills += 1
	stats.longest_kill = maxf(stats.longest_kill, distance)
	if killcam.consider(distance):
		last_long_shot = distance

# Laser range to whatever the camera points at, or -1 when nothing is within reach.
func measure_range(max_distance: float = 2000.0) -> float:
	var origin := camera.global_position
	var finish := origin - camera.global_basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(origin, finish)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return -1.0 if hit.is_empty() else origin.distance_to(hit.position)

# Wind split into the shooter's frame: x is crosswind (positive from the left,
# pushing right), z is headwind (positive into the shooter's face).
func wind_relative() -> Vector3:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	return Vector3(weapon.wind.dot(right), 0.0, -weapon.wind.dot(forward))

func wind_text() -> String:
	var relative := wind_relative()
	var cross := "L>R" if relative.x > 0.05 else ("R>L" if relative.x < -0.05 else "none")
	return "Wind %.1f m/s cross %s %.1f | head %.1f" % [weapon.wind.length(), cross, absf(relative.x), relative.z]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		GameState.set_paused(true)

func interact() -> void:
	level.interact(player.position)
	check_outcome()

func check_outcome() -> void:
	if GameState.finished:
		return
	if level.is_failed():
		GameState.fail_mission()
	elif level.is_complete():
		GameState.finish_mission()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("quick_save"):
		quick_save()
		return
	if event.is_action_pressed("quick_load"):
		if not load_slot(SaveSystem.QUICK_SLOT):
			load_slot(SaveSystem.CHECKPOINT_SLOT)
		return
	if event.is_action_pressed("pause"):
		if not GameState.finished:
			GameState.set_paused(not GameState.paused)
		return
	if not GameState.simulation_active():
		return
	if event.is_action_pressed("reload"):
		weapon.begin_reload()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("weapon_1"):
		weapon.select_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		weapon.select_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		weapon.select_weapon(2)
	elif event.is_action_pressed("crouch"):
		player.toggle_stance(Player.Stance.CROUCH)
	elif event.is_action_pressed("prone"):
		player.toggle_stance(Player.Stance.PRONE)
	elif event.is_action_pressed("zero_up"):
		weapon.adjust_zero(1)
	elif event.is_action_pressed("zero_down"):
		weapon.adjust_zero(-1)
	elif event.is_action_pressed("skip_killcam"):
		killcam.skip()
	elif event.is_action_pressed("binoculars"):
		stealth.toggle_binoculars()
	elif event.is_action_pressed("tag"):
		stealth.tag()
	elif event.is_action_pressed("throw"):
		stealth.throw_stone()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("fire"):
			if stealth.binoculars:
				stealth.tag()
			else:
				weapon.fire_weapon()
		elif event.is_action_pressed("aim"):
			if stealth.binoculars:
				stealth.set_binoculars(false)
			else:
				weapon.toggle_aim()

func update_hud() -> void:
	var objective: String = level.objective_text()
	if GameState.failed:
		objective = "MISSION FAILED - N to restart"
	elif GameState.finished:
		objective = "MISSION COMPLETE - N to restart"
	elif GameState.paused:
		objective = "PAUSED - Escape to resume | N to restart"
	var stance_name: String = Player.Stance.keys()[player.stance].capitalize()
	var breath := "Breath %d%%" % int(round(sway.breath_fraction() * 100.0))
	if sway.exhausted:
		breath = "WINDED"
	elif sway.holding:
		breath = "HOLDING %d%%" % int(round(sway.breath_fraction() * 100.0))
	var range_line := "Range --" if measured_range < 0.0 else "Range %.0f m" % measured_range
	if weapon.profile().simulated_projectile:
		range_line += " | Zero %.0f m" % weapon.zero_range()
		if measured_range > 0.0:
			range_line += " | Hold %.2f m" % weapon.holdover_at(measured_range)
	var shot_line := ""
	if killcam.active():
		shot_line = "\nLONG SHOT %.0f m (Space to skip)" % last_long_shot
	var noise_bar := "Noise %d%%" % int(round(stealth.noise_level() * 100.0))
	var tags := stealth.live_tags()
	var tag_line := "Tagged: none" if tags.is_empty() else "Tagged: " + ", ".join(tags.map(func(e): return "%s %.0f m" % [e.name, player.global_position.distance_to(e.global_position)]))
	var alert_line := "Health %d | Alert: %s | Hostiles: %d | %s | Stones %d | %s%s" % [int(round(player.health)), level.coordinator.level_name(), level.enemies.size(), noise_bar, stealth.stones, tag_line, " | BINOCULARS" if stealth.binoculars else ""]
	var objective_lines: String = "\n".join(level.mission_log.lines())
	hud.text = "ECHO RIDGE | prototype\n%s\n%s\n%s | Ammo %d / %d | %s | Targets left: %d | In flight: %d\n%s | %s | %s\n%s | %s%s\n1-2 weapon | Left fire | Right aim | B binoculars (fire tags) | G throw stone | Shift hold breath | C crouch | Z prone | [ ] zero | R reload | E interact | F5 save | F9 load | Escape pause" % [
		objective, objective_lines, weapon.profile().display_name, weapon.ammo, weapon.reserve_ammo, weapon.status_text(), level.targets.size(), weapon.projectiles.size(), stance_name, breath, alert_line, range_line, wind_text(), shot_line]

func hip_fov() -> float:
	return clampf(float(Settings.get_value("video", "fov")), 60.0, 110.0)

func is_aiming() -> bool:
	return camera.fov < 70.0 and not stealth.binoculars

func advance_sway(delta: float) -> void:
	sway.stance_multiplier = player.sway_multiplier()
	if GameState.simulation_active():
		sway.set_holding(is_aiming() and Input.is_action_pressed("hold_breath"))
		sway.advance(delta)
	var offset := sway.offset_degrees() if is_aiming() and GameState.simulation_active() else Vector2.ZERO
	camera.rotation_degrees = Vector3(offset.y, offset.x, 0.0)

func _physics_process(delta: float) -> void:
	weapon.advance_weapon(delta)
	weapon.advance_projectiles(delta)
	advance_sway(delta)
	killcam.advance(delta)
	stealth.advance(delta)
	measured_range = measure_range() if is_aiming() or stealth.binoculars else -1.0
	if GameState.simulation_active():
		stats.elapsed += delta
	check_outcome()
	if GameState.finished:
		weapon.projectiles.clear()
	update_hud()
