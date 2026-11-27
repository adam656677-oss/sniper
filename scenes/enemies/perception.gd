class_name Perception
extends Node

# Vision for an enemy: cone, distance falloff, occlusion and the target's stance
# exposure. Awareness accumulates while the target is visible and decays otherwise.
# Attach as a child of the enemy body.

const VIEW_DISTANCE := 120.0
const FOV_DEGREES := 110.0
const GAIN_RATE := 1.0
const DECAY_RATE := 0.15
const BODY_VIEW_DISTANCE := 40.0
const EYE_HEIGHT := 0.85

var awareness := 0.0
# Per-instance cone width, for narrower sensors such as a flashlight beam.
var fov_degrees := FOV_DEGREES

func body() -> Node3D:
	return get_parent() as Node3D

func eye_position() -> Vector3:
	return body().global_position + Vector3(0, EYE_HEIGHT, 0)

func forward() -> Vector3:
	return -body().global_basis.z

# Instantaneous visibility of a world point in 0..1. Zero when out of range,
# outside the cone, or blocked by something before the point.
func visibility_of(point: Vector3, exposure: float, max_distance: float = VIEW_DISTANCE) -> float:
	var eye := eye_position()
	var distance := eye.distance_to(point)
	if distance > max_distance or distance < 0.001:
		return 0.0
	var direction := (point - eye) / distance
	var cosine := clampf(forward().dot(direction), -1.0, 1.0)
	if acos(cosine) > deg_to_rad(fov_degrees * 0.5):
		return 0.0
	var world := body().get_world_3d()
	if world:
		var excluded: Array[RID] = [body().get_rid()]
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1, excluded)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(point) > 0.6:
			return 0.0
	return clampf(1.0 - distance / max_distance, 0.0, 1.0) * clampf(exposure, 0.0, 1.0)

func conditions_factor() -> float:
	var level = body().get("level")
	return level.visibility_factor() if level and level.has_method("visibility_factor") else 1.0

func visibility_of_player(player: Node) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var head: Vector3 = player.camera.global_position if player.get("camera") else player.global_position
	var exposure: float = player.exposure() if player.has_method("exposure") else 1.0
	return visibility_of(head, exposure, VIEW_DISTANCE * conditions_factor())

func accumulate(visibility: float, delta: float) -> void:
	var dt := maxf(delta, 0.0)
	if visibility > 0.0:
		awareness = minf(1.0, awareness + visibility * GAIN_RATE * GameState.perception_multiplier() * dt)
	else:
		awareness = maxf(0.0, awareness - DECAY_RATE * dt)
