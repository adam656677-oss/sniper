class_name KillCam
extends Node

# Long-shot slow motion. Two ways in: consider() after a kill (any weapon), or
# follow() at the moment of firing when the round is predicted to kill beyond
# the threshold; then a camera rides behind the bullet until it lands and
# holds on the impact briefly.

const DISTANCE_THRESHOLD := 150.0
const SLOW_SCALE := 0.25
const DURATION_SECONDS := 2.5

const FOLLOW_SCALE := 0.15
const FOLLOW_OFFSET := 1.6
const IMPACT_HOLD := 1.0

var enabled := true
var remaining := 0.0
var last_distance := 0.0
var followed: Dictionary = {}
var following := false
var hold_remaining := 0.0
var impact_point := Vector3.ZERO
var camera: Camera3D
var return_camera: Camera3D
var bullet_mesh: MeshInstance3D

func _ready() -> void:
	bullet_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.025
	capsule.height = 0.14
	bullet_mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.6, 0.3)
	material.metallic = 0.9
	material.roughness = 0.25
	bullet_mesh.material_override = material
	bullet_mesh.visible = false
	add_child(bullet_mesh)

func active() -> bool:
	return remaining > 0.0

func consider(distance: float) -> bool:
	if not enabled or distance < DISTANCE_THRESHOLD or active() or following:
		return false
	last_distance = distance
	remaining = DURATION_SECONDS
	Engine.time_scale = SLOW_SCALE
	return true

func follow(projectile: Dictionary, distance: float, impact_position: Vector3) -> bool:
	if not enabled or distance < DISTANCE_THRESHOLD or active() or following:
		return false
	followed = projectile
	following = true
	impact_point = impact_position
	last_distance = distance
	hold_remaining = IMPACT_HOLD
	Engine.time_scale = FOLLOW_SCALE
	if camera:
		place_camera()
		camera.current = true
	return true

func place_camera() -> void:
	var position: Vector3 = followed.position
	var direction: Vector3 = Vector3(followed.velocity).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	camera.global_position = position - direction * FOLLOW_OFFSET + side * 0.35 + Vector3(0, 0.12, 0)
	var target := position + direction * 6.0
	if camera.global_position.distance_to(target) > 0.01:
		camera.look_at(target, Vector3.UP)
	if bullet_mesh:
		bullet_mesh.visible = true
		bullet_mesh.global_position = position
		if direction.length() > 0.01:
			bullet_mesh.look_at(position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
			bullet_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func end_follow() -> void:
	if bullet_mesh:
		bullet_mesh.visible = false
	following = false
	followed = {}
	hold_remaining = 0.0
	Engine.time_scale = 1.0
	if return_camera:
		return_camera.current = true

# Called each physics step with whether the followed round is still in flight.
func advance_follow(delta: float, in_flight: bool) -> void:
	if not following:
		return
	if in_flight:
		if camera:
			place_camera()
		return
	if bullet_mesh:
		bullet_mesh.visible = false
	hold_remaining -= maxf(delta, 0.0) / maxf(Engine.time_scale, 0.01)
	if camera and camera.global_position.distance_to(impact_point) > 0.01:
		camera.look_at(impact_point, Vector3.UP)
	if hold_remaining <= 0.0:
		end_follow()

func skip() -> void:
	if following:
		end_follow()
	if active():
		remaining = 0.0
		Engine.time_scale = 1.0

# delta is scaled game time; convert back to real seconds.
func advance(delta: float) -> void:
	if not active():
		return
	remaining = maxf(0.0, remaining - maxf(delta, 0.0) / maxf(Engine.time_scale, 0.01))
	if remaining == 0.0:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	following = false
