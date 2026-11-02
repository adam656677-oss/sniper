extends RefCounted

# Wind is represented as an acceleration in metres per second squared.
static func step(position: Vector3, velocity: Vector3, delta: float, gravity: float = 9.81, wind_acceleration: Vector3 = Vector3.ZERO) -> Dictionary:
	var dt := maxf(delta, 0.0)
	var acceleration := Vector3.DOWN * maxf(gravity, 0.0) + wind_acceleration
	return {
		"position": position + velocity * dt + acceleration * (0.5 * dt * dt),
		"velocity": velocity + acceleration * dt
	}

# Trace each old-to-new position segment during integration to avoid tunnelling.
static func trace_segment(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, excluded: Array[RID], collision_mask: int = 1) -> Dictionary:
	if start.is_equal_approx(finish):
		return {}
	var query := PhysicsRayQueryParameters3D.create(start, finish, collision_mask, excluded)
	return space.intersect_ray(query)
