class_name ShotFeedback
extends Node3D

# Visual feedback for shots: tracer lines for rounds in flight, dust puffs and
# bullet holes where rounds land, and the camera offsets: recoil, head bob, the
# sprint field-of-view kick and the landing dip. Bob, kick and dip are off while
# aiming and with reduced motion. Lives under the mission; tracers and impacts
# are drawn in world space.

const MAX_HOLES := 64
const TRACER_MIN_DISTANCE := 60.0
const RECOIL_RECOVERY := 8.0 # per second, exponential
const BOB_AMPLITUDE := 0.035
const BOB_FREQUENCY := 9.0
const SPRINT_FOV_KICK := 5.0 # degrees added to the hip field of view at full sprint
const SPRINT_FOV_IN := 0.35 # seconds to ease the kick in
const SPRINT_FOV_OUT := 0.3 # seconds to ease it back out
const LANDING_DIP_MIN_SPEED := 5.0 # m/s at touch-down, about a 0.6 m drop; slower is a step, not a fall
const LANDING_DIP_FULL_SPEED := 12.0 # m/s for the deepest dip, about a 3.6 m drop
const LANDING_DIP_MIN := 0.05 # metres
const LANDING_DIP_MAX := 0.14
const LANDING_DIP_TIME := 0.4 # seconds down and back up
const LANDING_DIP_ATTACK := 0.25 # share of the dip spent going down

var recoil_degrees := 0.0
var bob_time := 0.0
var sprint_blend := 0.0
var dip_depth := 0.0
var dip_time := 0.0
var holes: Array[Node3D] = []
var tracer_mesh := ImmediateMesh.new()
var tracer_instance: MeshInstance3D
var hit_marker_time := 0.0
var hit_marker_kill := false
var last_impact_surface := "stone"
var last_impact_particle_count := 0

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

# Sprint kick and landing dip. Reduced motion clears both at once.
func advance_motion(delta: float, sprinting: bool, reduced_motion: bool) -> void:
	var dt := maxf(delta, 0.0)
	if reduced_motion:
		sprint_blend = 0.0
		dip_depth = 0.0
		dip_time = 0.0
		return
	var ease_time := SPRINT_FOV_IN if sprinting else SPRINT_FOV_OUT
	sprint_blend = move_toward(sprint_blend, 1.0 if sprinting else 0.0, dt / ease_time)
	if dip_depth > 0.0:
		dip_time += dt
		if dip_time >= LANDING_DIP_TIME:
			dip_depth = 0.0
			dip_time = 0.0

# Degrees to add to the hip field of view; eased in and out.
func sprint_fov_offset() -> float:
	return SPRINT_FOV_KICK * smoothstep(0.0, 1.0, sprint_blend)

# Starts a dip for a touch-down at fall_speed m/s. Steps, scoped landings and reduced motion get none.
func land(fall_speed: float, aiming: bool, reduced_motion: bool) -> bool:
	if reduced_motion or aiming or fall_speed < LANDING_DIP_MIN_SPEED:
		return false
	var weight := clampf((fall_speed - LANDING_DIP_MIN_SPEED) / (LANDING_DIP_FULL_SPEED - LANDING_DIP_MIN_SPEED), 0.0, 1.0)
	dip_depth = lerpf(LANDING_DIP_MIN, LANDING_DIP_MAX, weight)
	dip_time = 0.0
	return true

# Camera height offset in metres: a quick drop, then an eased recovery.
func dip_offset() -> float:
	if dip_depth <= 0.0:
		return 0.0
	var phase := dip_time / LANDING_DIP_TIME
	var envelope := sin(phase / LANDING_DIP_ATTACK * PI * 0.5) if phase < LANDING_DIP_ATTACK else 1.0 - smoothstep(LANDING_DIP_ATTACK, 1.0, phase)
	return -dip_depth * envelope

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

func impact(position: Vector3, normal: Vector3, leave_hole: bool, surface_type: String = "stone") -> void:
	var surface := surface_type.to_lower()
	if surface not in ["metal", "wood", "earth", "stone"]:
		surface = "stone"
	last_impact_surface = surface
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.direction = normal if normal != Vector3.ZERO else Vector3.UP
	puff.spread = 28.0 if surface == "metal" else 38.0
	puff.gravity = Vector3(0, -9.0, 0) if surface == "metal" else (Vector3(0, -5.0, 0) if surface == "wood" else Vector3(0, -3.0, 0))
	var particle_material := StandardMaterial3D.new()
	particle_material.vertex_color_use_as_albedo = true
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match surface:
		"metal":
			puff.amount = 12
			puff.lifetime = 0.42
			puff.initial_velocity_min = 2.5
			puff.initial_velocity_max = 7.5
			puff.scale_amount_min = 0.018
			puff.scale_amount_max = 0.045
			puff.color = Color(1.0, 0.58, 0.18)
			particle_material.emission_enabled = true
			particle_material.emission = Color(1.0, 0.36, 0.08)
			var spark_mesh := BoxMesh.new()
			spark_mesh.size = Vector3(0.018, 0.12, 0.018)
			puff.mesh = spark_mesh
		"wood":
			puff.amount = 14
			puff.lifetime = 0.55
			puff.initial_velocity_min = 1.2
			puff.initial_velocity_max = 3.8
			puff.scale_amount_min = 0.025
			puff.scale_amount_max = 0.09
			puff.color = Color(0.66, 0.48, 0.28)
			var splinter_mesh := BoxMesh.new()
			splinter_mesh.size = Vector3(0.025, 0.11, 0.018)
			puff.mesh = splinter_mesh
		_:
			puff.amount = 18 if surface == "earth" else 16
			puff.lifetime = 0.65 if surface == "earth" else 0.6
			puff.initial_velocity_min = 0.8
			puff.initial_velocity_max = 2.2 if surface == "earth" else 3.0
			puff.scale_amount_min = 0.05
			puff.scale_amount_max = 0.15
			puff.color = Color(0.42, 0.31, 0.20) if surface == "earth" else Color(0.55, 0.5, 0.42)
			var dust_mesh := QuadMesh.new()
			dust_mesh.size = Vector2(0.3, 0.3)
			puff.mesh = dust_mesh
	last_impact_particle_count = puff.amount
	puff.material_override = particle_material
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
