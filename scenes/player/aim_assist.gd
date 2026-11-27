class_name AimAssist
extends RefCounted

# Controller aim friction. While the right stick looks and the crosshair or
# scope centre crosses a live hostile in plain sight, look speed drops so the
# reticle is easier to settle on the body. It only scales the speed the player
# asks for, equally on both axes: it never turns the view on its own, never
# snaps and never changes where the stick points. The shot stays the player's.

const BODY_LOW := -0.7 # hostile centre line, metres from its origin (feet to head with the half width)
const BODY_HIGH := 0.85
const BODY_HALF_WIDTH := 0.3 # aim this close to the centre line is on the body: full friction
const ZONE_RADIUS := 0.9 # friction fades out by this distance from the centre line
const MAX_RANGE := 1000.0
const STRENGTH := 0.4 # share of look speed removed on the body at Normal
const MAX_STRENGTH := 0.7

# Hard gets less help and Easy more, by the same multiplier that scales guard perception.
static func strength_for(difficulty_multiplier: float) -> float:
	return clampf(STRENGTH / maxf(difficulty_multiplier, 0.1), 0.0, MAX_STRENGTH)

# Closest distance between the aim ray and the hostile's centre line, or INF when it is behind.
static func miss_distance(origin: Vector3, forward: Vector3, hostile_origin: Vector3) -> float:
	var low := hostile_origin + Vector3(0, BODY_LOW, 0)
	var line := Vector3(0, BODY_HIGH - BODY_LOW, 0)
	var from_low := origin - low
	var along_ray := forward.dot(line)
	var line_squared := line.dot(line)
	var ray_side := forward.dot(from_low)
	var line_side := line.dot(from_low)
	var denominator := line_squared - along_ray * along_ray
	var s := 0.0
	if denominator > 0.000001:
		s = maxf(0.0, (along_ray * line_side - ray_side * line_squared) / denominator)
	var t := (along_ray * s + line_side) / line_squared
	if t < 0.0:
		t = 0.0
		s = maxf(0.0, -ray_side)
	elif t > 1.0:
		t = 1.0
		s = maxf(0.0, along_ray - ray_side)
	if s <= 0.0 or s > MAX_RANGE:
		return INF
	return (origin + forward * s).distance_to(low + line * t)

# 1 with the aim on the body, easing to 0 at the edge of the zone.
static func falloff(miss: float) -> float:
	return 1.0 - smoothstep(BODY_HALF_WIDTH, ZONE_RADIUS, miss)

# Clear line of sight to the hostile's centre or head; friction never leaks through cover.
static func in_sight(space: PhysicsDirectSpaceState3D, origin: Vector3, hostile: Node3D, exclude: Array[RID]) -> bool:
	if space == null:
		return true
	for point in [hostile.global_position, hostile.global_position + Vector3(0, BODY_HIGH, 0)]:
		var query := PhysicsRayQueryParameters3D.create(origin, point)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider == hostile:
			return true
	return false

# Multiplier for stick look speed: 1 with nothing near the aim, down to 1 - strength on a hostile.
static func look_scale(origin: Vector3, forward: Vector3, hostiles: Array, strength: float, space: PhysicsDirectSpaceState3D = null, exclude: Array[RID] = []) -> float:
	var best := 0.0
	for hostile in hostiles:
		if not is_instance_valid(hostile) or not (hostile is Node3D):
			continue
		if hostile.has_method("is_alive") and not hostile.is_alive():
			continue
		var weight := falloff(miss_distance(origin, forward, hostile.global_position))
		if weight > best and in_sight(space, origin, hostile, exclude):
			best = weight
	return 1.0 - strength * best
