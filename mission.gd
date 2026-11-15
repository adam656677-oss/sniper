extends Node3D

# Mission root: wires the level, player, weapon rig and HUD together and
# routes input to the right system. Simulation state lives in GameState.

@onready var level: LevelBase = $Level
@onready var player: Player = $Player
@onready var weapon: WeaponRig = $WeaponRig
@onready var hud: Label = $HUDLayer/HUD
@onready var sway: AimSway = $AimSway
@onready var killcam: KillCam = $KillCam
var measured_range := -1.0
var last_long_shot := 0.0
var camera: Camera3D

func _ready() -> void:
	GameState.reset()
	camera = player.camera
	player.spawn_point = level.spawn_point
	player.position = level.spawn_point
	weapon.camera = camera
	weapon.excluded = [player.get_rid()]
	weapon.body_hit.connect(level.on_body_hit)
	weapon.wind = level.wind
	level.target_killed.connect(on_target_killed)
	update_hud()

func on_target_killed(_body: Node3D, distance: float) -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
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
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("fire"):
			weapon.fire_weapon()
		elif event.is_action_pressed("aim"):
			weapon.toggle_aim()

func update_hud() -> void:
	var objective: String = level.objective_text()
	if GameState.finished:
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
	hud.text = "ECHO RIDGE | prototype\n%s\n%s | Ammo %d / %d | %s | Targets left: %d | In flight: %d\n%s | %s\n%s | %s%s\n1-2 weapon | Left fire | Right aim | Shift hold breath | C crouch | Z prone | [ ] zero | R reload | E interact | Escape pause" % [
		objective, weapon.profile().display_name, weapon.ammo, weapon.reserve_ammo, weapon.status_text(), level.targets.size(), weapon.projectiles.size(), stance_name, breath, range_line, wind_text(), shot_line]

func is_aiming() -> bool:
	return camera.fov < 70.0

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
	measured_range = measure_range() if is_aiming() else -1.0
	if not GameState.finished and level.is_complete():
		GameState.finish_mission()
	if GameState.finished:
		weapon.projectiles.clear()
	update_hud()
