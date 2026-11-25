class_name ShotFeedback
extends Node3D

# Visual feedback for shots: tracer lines for rounds in flight, dust puffs and
# bullet holes where rounds land, and recoil/head-bob camera offsets.
# Lives under the mission; tracers and impacts are drawn in world space.

const MAX_HOLES := 64
const TRACER_MIN_DISTANCE := 60.0
const RECOIL_RECOVERY := 8.0 # per second, exponential
const BOB_AMPLITUDE := 0.035
const BOB_FREQUENCY := 9.0

var recoil_degrees := 0.0
var bob_time := 0.0
var holes: Array[Node3D] = []
var tracer_mesh := ImmediateMesh.new()
var tracer_instance: MeshInstance3D
var hit_marker_time := 0.0
var hit_marker_kill := false

func _ready() -> void:
	tracer_instance = MeshInstance3D.new()
	tracer_instance.mesh = tracer_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_instance.material_override = material
	tracer_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer_instance)

func kick(profile: WeaponProfile) -> void:
	recoil_degrees += profile.recoil_degrees

func show_hit(killed: bool) -> void:
	hit_marker_time = 0.35 if killed else 0.2
	hit_marker_kill = killed

func advance(delta: float, moving_speed: float, aiming: bool, reduced_motion: bool) -> void:
	recoil_degrees *= exp(-RECOIL_RECOVERY * maxf(delta, 0.0))
	if recoil_degrees < 0.01:
		recoil_degrees = 0.0
	hit_marker_time = maxf(0.0, hit_marker_time - delta)
	if moving_speed > 0.5 and not aiming and not reduced_motion:
		bob_time += delta * BOB_FREQUENCY * clampf(moving_speed / 5.0, 0.4, 1.2)
	else:
		bob_time = 0.0

func bob_offset() -> float:
	return sin(bob_time) * BOB_AMPLITUDE if bob_time > 0.0 else 0.0

# Lines from each round's launch point to its current position, once it is far enough out to read.
func draw_tracers(projectiles: Array[Dictionary]) -> void:
	tracer_mesh.clear_surfaces()
	var drawn := 0
	for projectile in projectiles:
		if float(projectile.distance) < TRACER_MIN_DISTANCE or not projectile.has("origin"):
			continue
		if drawn == 0:
			tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var head: Vector3 = projectile.position
		var tail: Vector3 = head - Vector3(projectile.velocity).normalized() * 25.0
		tracer_mesh.surface_add_vertex(tail)
		tracer_mesh.surface_add_vertex(head)
		drawn += 1
	if drawn > 0:
		tracer_mesh.surface_end()

func tracer_count() -> int:
	return tracer_mesh.get_surface_count()

func impact(position: Vector3, normal: Vector3, leave_hole: bool) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 16
	puff.lifetime = 0.6
	puff.explosiveness = 0.9
	puff.direction = normal if normal != Vector3.ZERO else Vector3.UP
	puff.spread = 35.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 3.0
	puff.gravity = Vector3(0, -3, 0)
	puff.scale_amount_min = 0.05
	puff.scale_amount_max = 0.15
	puff.color = Color(0.55, 0.5, 0.42)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	puff.mesh = quad
	add_child(puff)
	puff.global_position = position
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)
	if leave_hole:
		add_hole(position, normal)

func add_hole(position: Vector3, normal: Vector3) -> void:
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	hole.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.05, 0.05)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole.material_override = material
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.BACK
	hole.global_position = position + n * 0.01
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	hole.look_at(hole.global_position - n, up)
	holes.append(hole)
	while holes.size() > MAX_HOLES:
		holes.pop_front().queue_free()
