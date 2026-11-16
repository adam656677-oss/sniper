class_name StealthKit
extends Node

# Player stealth tools: binoculars with target tagging, a footstep noise model,
# and throwable stones for distraction. Owned by the mission.

signal tagged(enemy: Node)
signal stone_thrown(landing: Vector3)

const BINOCULAR_FOV := 12.0
const TAG_RANGE := 400.0
const STONE_COUNT := 3
const STONE_RANGE := 20.0
const STONE_NOISE_RADIUS := 30.0
const FOOTSTEP_INTERVAL := 0.5
const FOOTSTEP_RADIUS := 14.0
const FOOTSTEP_LOUDNESS := 0.3
const STANCE_NOISE := {0: 1.0, 1: 0.5, 2: 0.25} # Player.Stance order: stand, crouch, prone.

var binoculars := false
var stones := STONE_COUNT
var tagged_enemies: Array = []
var footstep_timer := 0.0
var camera: Camera3D
var player: Node3D
var level: Node

func noise_level() -> float:
	if player == null:
		return 0.0
	var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.1
	if not moving:
		return 0.0
	return float(STANCE_NOISE.get(player.stance, 1.0))

func set_binoculars(value: bool) -> bool:
	if not GameState.simulation_active() or camera == null:
		return false
	binoculars = value
	camera.fov = BINOCULAR_FOV if binoculars else clampf(float(Settings.get_value("video", "fov")), 60.0, 110.0)
	return binoculars

func toggle_binoculars() -> bool:
	return set_binoculars(not binoculars)

func target_under_crosshair() -> Node:
	if camera == null or player == null:
		return null
	var origin := camera.global_position
	var finish := origin - camera.global_basis.z * TAG_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, finish)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.collider

func tag() -> Node:
	if not GameState.simulation_active() or not binoculars:
		return null
	var target := target_under_crosshair()
	if target == null or not target.has_method("tick") or not target.is_alive():
		return null
	if target not in tagged_enemies:
		tagged_enemies.append(target)
		tagged.emit(target)
	return target

func live_tags() -> Array:
	var alive: Array = []
	for enemy in tagged_enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			alive.append(enemy)
	return alive

func throw_stone() -> bool:
	if not GameState.simulation_active() or stones <= 0 or camera == null or level == null:
		return false
	stones -= 1
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var landing := origin + forward * STONE_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, landing)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		landing = hit.position
	level.report_noise(landing, STONE_NOISE_RADIUS, 0.5)
	stone_thrown.emit(landing)
	return true

func advance(delta: float) -> void:
	if not GameState.simulation_active() or level == null or player == null:
		return
	var noise := noise_level()
	if noise <= 0.0:
		footstep_timer = 0.0
		return
	footstep_timer += delta
	if footstep_timer >= FOOTSTEP_INTERVAL:
		footstep_timer = 0.0
		level.report_noise(player.global_position, FOOTSTEP_RADIUS * noise, FOOTSTEP_LOUDNESS)
