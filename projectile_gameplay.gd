extends "res://weapons.gd"

const ProjectileMath = preload("res://ballistics.gd")
const RIFLE_SPEED := 180.0 # Fictional prototype tuning in metres per second.
const PROJECTILE_LIFETIME := 3.0
var projectiles: Array[Dictionary] = []
var wind_acceleration := Vector3.ZERO

func fire_weapon() -> bool:
	if active_weapon != 0:
		return super.fire_weapon()
	if not can_fire():
		return false
	ammo -= 1
	shot_remaining = float(LOADOUT[0].interval)
	projectiles.append({
		"position": camera.global_position,
		"velocity": -camera.global_basis.z * RIFLE_SPEED,
		"age": 0.0,
		"distance": 0.0
	})
	return true

func advance_projectiles(delta: float) -> void:
	if paused or finished:
		return
	var elapsed := maxf(delta, 0.0)
	var excluded: Array[RID] = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		var remaining := minf(elapsed, PROJECTILE_LIFETIME - float(projectile.age))
		var removed := false
		while remaining > 0.0:
			var dt := minf(remaining, 1.0 / 120.0)
			var start: Vector3 = projectile.position
			var state := ProjectileMath.step(start, projectile.velocity, dt, 9.81, wind_acceleration)
			var finish: Vector3 = state.position
			var segment_length := start.distance_to(finish)
			var range_left := maxf(0.0, float(LOADOUT[0].range) - float(projectile.distance))
			if segment_length > range_left:
				finish = start.move_toward(finish, range_left)
			var hit := ProjectileMath.trace_segment(space, start, finish, excluded)
			if not hit.is_empty():
				if hit.collider in targets:
					targets.erase(hit.collider)
					hit.collider.queue_free()
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

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if finished:
		projectiles.clear()
		return
	advance_projectiles(delta)
	if not paused:
		hud.text += "\nRifle: projectile travel + gravity | In flight: %d" % projectiles.size()
