class_name WeaponRig
extends Node

# Owns the loadout, per-weapon ammunition, reload and cycling timers, and
# fires either hitscan pellets or a simulated projectile (see ballistics.gd).
# Needs `camera` and `excluded` set by the mission before firing.

const Ballistics = preload("res://ballistics.gd")
const DEFAULT_PROFILES := [
	"res://scenes/weapons/profiles/ridgeline_recon.tres",
	"res://scenes/weapons/profiles/whisper_sidearm.tres"
]
const ZERO_STEP := 100.0
const ZERO_MIN := 100.0
const ZERO_MAX := 1000.0
const PROJECTILE_LIFETIME := 3.0
const SUBSTEP := 1.0 / 120.0

signal body_hit(body: Node3D, shape_index: int, damage: float, distance: float)
signal fired(profile: WeaponProfile)

var profiles: Array[WeaponProfile] = []
var active := 0
var ammo := 0
var reserve_ammo := 0
var reload_remaining := 0.0
var shot_remaining := 0.0
var stored: Array[Dictionary] = []
var zero_ranges: Array[float] = []
var projectiles: Array[Dictionary] = []
var wind := Vector3.ZERO # Air-mass velocity in m/s.
var spread_rng := RandomNumberGenerator.new()
var camera: Camera3D
var aiming := false
var excluded: Array[RID] = []

func _ready() -> void:
	spread_rng.randomize()
	if profiles.is_empty():
		for path in DEFAULT_PROFILES:
			profiles.append(load(path) as WeaponProfile)
	for profile in profiles:
		stored.append({"ammo": profile.capacity, "reserve": profile.reserve, "cooldown": 0.0})
		zero_ranges.append(profile.zero_range)
	ammo = profiles[active].capacity
	reserve_ammo = profiles[active].reserve

func hip_fov() -> float:
	return clampf(float(Settings.get_value("video", "fov")), 60.0, 110.0)

func profile() -> WeaponProfile:
	return profiles[active]

func select_weapon(index: int) -> bool:
	if not GameState.simulation_active() or reload_remaining > 0.0 or index < 0 or index >= profiles.size():
		return false
	stored[active] = {"ammo": ammo, "reserve": reserve_ammo, "cooldown": shot_remaining}
	active = index
	ammo = int(stored[index].ammo)
	reserve_ammo = int(stored[index].reserve)
	shot_remaining = float(stored[index].cooldown)
	aiming = false
	if camera:
		camera.fov = hip_fov()
	return true

func zero_range() -> float:
	return zero_ranges[active]

# Move the elevation turret by whole steps. Only meaningful for projectile weapons.
func adjust_zero(steps: int) -> bool:
	if not GameState.simulation_active() or not profile().simulated_projectile or steps == 0:
		return false
	var target := clampf(zero_ranges[active] + ZERO_STEP * steps, ZERO_MIN, ZERO_MAX)
	if target == zero_ranges[active]:
		return false
	zero_ranges[active] = target
	return true

func ballistic_params() -> Dictionary:
	return Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, profile().drag_coefficient, wind)

# Metres of holdover at a range for the active weapon and its current zero.
func holdover_at(distance: float) -> float:
	var current := profile()
	if not current.simulated_projectile or distance <= 0.0:
		return 0.0
	return Ballistics.holdover(current.muzzle_velocity, distance, zero_range(), ballistic_params())

func toggle_aim() -> void:
	if camera and GameState.simulation_active():
		aiming = not aiming
		camera.fov = profile().aim_fov if aiming else hip_fov()

func begin_reload() -> bool:
	if not GameState.simulation_active() or reload_remaining > 0.0 or ammo >= profile().capacity or reserve_ammo <= 0:
		return false
	reload_remaining = profile().reload_seconds
	return true

func advance_weapon(delta: float) -> void:
	if not GameState.simulation_active():
		return
	var elapsed := maxf(delta, 0.0)
	shot_remaining = maxf(0.0, shot_remaining - elapsed)
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - elapsed)
		if reload_remaining == 0.0:
			var transfer := mini(profile().capacity - ammo, reserve_ammo)
			ammo += transfer
			reserve_ammo -= transfer

func can_fire() -> bool:
	return GameState.simulation_active() and ammo > 0 and reload_remaining == 0.0 and shot_remaining == 0.0

func fire_weapon() -> bool:
	if not can_fire() or camera == null:
		return false
	ammo -= 1
	var current := profile()
	shot_remaining = current.shot_interval
	if current.simulated_projectile:
		var params := ballistic_params()
		var elevation := Ballistics.zero_angle(current.muzzle_velocity, zero_range(), params)
		var direction := (-camera.global_basis.z).rotated(camera.global_basis.x, elevation)
		projectiles.append({
			"position": camera.global_position,
			"velocity": direction * current.muzzle_velocity,
			"age": 0.0,
			"distance": 0.0,
			"profile": current
		})
		fired.emit(current)
		return true
	var space := camera.get_world_3d().direct_space_state
	for pellet in range(current.pellets):
		var angle := spread_rng.randf_range(0.0, TAU)
		var radius := sqrt(spread_rng.randf()) * current.spread
		var local_direction := Vector3(cos(angle) * radius, sin(angle) * radius, -1.0).normalized()
		var origin := camera.global_position
		var finish := origin + camera.global_basis * local_direction * current.max_range
		var hit := Ballistics.trace_segment(space, origin, finish, excluded)
		if not hit.is_empty():
			body_hit.emit(hit.collider, int(hit.get("shape", -1)), current.damage, origin.distance_to(hit.position))
	fired.emit(current)
	return true

func advance_projectiles(delta: float) -> void:
	if not GameState.simulation_active() or camera == null:
		return
	var elapsed := maxf(delta, 0.0)
	var space := camera.get_world_3d().direct_space_state
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		var shot_profile: WeaponProfile = projectile.profile
		var max_range: float = shot_profile.max_range
		var params := Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, shot_profile.drag_coefficient, wind)
		var remaining := minf(elapsed, PROJECTILE_LIFETIME - float(projectile.age))
		var removed := false
		while remaining > 0.0:
			var dt := minf(remaining, SUBSTEP)
			var start: Vector3 = projectile.position
			var state := Ballistics.step_drag(start, projectile.velocity, dt, params)
			var finish: Vector3 = state.position
			var segment_length := start.distance_to(finish)
			var range_left := maxf(0.0, max_range - float(projectile.distance))
			if segment_length > range_left:
				finish = start.move_toward(finish, range_left)
			var hit := Ballistics.trace_segment(space, start, finish, excluded)
			if not hit.is_empty():
				var travelled: float = float(projectile.distance) + start.distance_to(hit.position)
				body_hit.emit(hit.collider, int(hit.get("shape", -1)), shot_profile.damage, travelled)
				removed = true
				break
			projectile.position = finish
			projectile.velocity = state.velocity
			projectile.age = float(projectile.age) + dt
			projectile.distance = float(projectile.distance) + start.distance_to(finish)
			remaining = maxf(0.0, remaining - dt)
			if segment_length >= range_left:
				removed = true
				break
		if removed or float(projectile.age) >= PROJECTILE_LIFETIME:
			projectiles.remove_at(index)

func status_text() -> String:
	if reload_remaining > 0.0:
		return "RELOADING %.1fs" % reload_remaining
	if ammo == 0:
		return "EMPTY - R to reload"
	if shot_remaining > 0.0:
		return "CYCLING"
	return "READY"
