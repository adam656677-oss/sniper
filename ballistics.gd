extends RefCounted

# Pure projectile mathematics. No scene access except trace_segment.
# Frame for the flat-fire helpers: +X downrange, +Y up, +Z to the shooter's right.
# Drag model: deceleration = drag * |v_rel| * v_rel, where v_rel is velocity
# relative to the moving air mass (wind is a velocity in m/s). Fictional tuning.

const DEFAULT_GRAVITY := 9.81
const DEFAULT_SUBSTEP := 1.0 / 240.0
const MAX_FLIGHT_SECONDS := 12.0

static func make_params(gravity: float = DEFAULT_GRAVITY, drag: float = 0.0, wind: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"gravity": maxf(gravity, 0.0), "drag": maxf(drag, 0.0), "wind": wind}

# Legacy constant-acceleration step kept for the projectile integration tests.
static func step(position: Vector3, velocity: Vector3, delta: float, gravity: float = DEFAULT_GRAVITY, wind_acceleration: Vector3 = Vector3.ZERO) -> Dictionary:
	var dt := maxf(delta, 0.0)
	var acceleration := Vector3.DOWN * maxf(gravity, 0.0) + wind_acceleration
	return {
		"position": position + velocity * dt + acceleration * (0.5 * dt * dt),
		"velocity": velocity + acceleration * dt
	}

static func acceleration(velocity: Vector3, params: Dictionary) -> Vector3:
	var relative: Vector3 = velocity - params.wind
	return Vector3.DOWN * float(params.gravity) - relative * relative.length() * float(params.drag)

# Semi-implicit step with trapezoidal position update. Stable at 120 Hz for rifle speeds.
static func step_drag(position: Vector3, velocity: Vector3, delta: float, params: Dictionary) -> Dictionary:
	var dt := maxf(delta, 0.0)
	var next_velocity := velocity + acceleration(velocity, params) * dt
	return {
		"position": position + (velocity + next_velocity) * (0.5 * dt),
		"velocity": next_velocity
	}

# Simulate a shot from the origin along +X with the given elevation until it reaches
# `distance` downrange. Returns height (Y, negative is below the bore line), drift (Z),
# time of flight and remaining speed at that distance.
static func simulate_flat(muzzle_velocity: float, elevation: float, distance: float, params: Dictionary, substep: float = DEFAULT_SUBSTEP) -> Dictionary:
	var position := Vector3.ZERO
	var velocity := Vector3(cos(elevation), sin(elevation), 0.0) * maxf(muzzle_velocity, 0.0)
	var time := 0.0
	var dt := maxf(substep, 1.0 / 1000.0)
	while position.x < distance and time < MAX_FLIGHT_SECONDS:
		var state := step_drag(position, velocity, dt, params)
		var next: Vector3 = state.position
		if next.x >= distance:
			var span: float = next.x - position.x
			var fraction: float = 1.0 if span <= 0.0 else clampf((distance - position.x) / span, 0.0, 1.0)
			position = position.lerp(next, fraction)
			velocity = velocity.lerp(state.velocity, fraction)
			time += dt * fraction
			break
		position = next
		velocity = state.velocity
		time += dt
	return {"height": position.y, "drift": position.z, "time": time, "speed": velocity.length(), "reached": position.x >= distance - 0.001}

static func drop_at_range(muzzle_velocity: float, distance: float, params: Dictionary) -> float:
	return -float(simulate_flat(muzzle_velocity, 0.0, distance, params).height)

# Elevation (radians) that puts the bullet on the bore line at zero_range. Bisection.
static func zero_angle(muzzle_velocity: float, zero_range: float, params: Dictionary) -> float:
	if zero_range <= 0.0 or muzzle_velocity <= 0.0:
		return 0.0
	var low := 0.0
	var high := 0.25
	for i in range(40):
		var mid := (low + high) * 0.5
		var height := float(simulate_flat(muzzle_velocity, mid, zero_range, params).height)
		if height < 0.0:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5

# Metres the aim point must be raised to hit at target_range when zeroed at zero_range.
# Positive means the bullet lands below the line of sight.
static func holdover(muzzle_velocity: float, target_range: float, zero_range: float, params: Dictionary) -> float:
	var elevation := zero_angle(muzzle_velocity, zero_range, params)
	return -float(simulate_flat(muzzle_velocity, elevation, target_range, params).height)

# Trace each old-to-new position segment during integration to avoid tunnelling.
static func trace_segment(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, excluded: Array[RID], collision_mask: int = 1) -> Dictionary:
	if start.is_equal_approx(finish):
		return {}
	var query := PhysicsRayQueryParameters3D.create(start, finish, collision_mask, excluded)
	return space.intersect_ray(query)
