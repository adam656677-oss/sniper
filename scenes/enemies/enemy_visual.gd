class_name EnemyVisual
extends Node3D

# Lightweight original humanoid presentation built from Godot meshes.
# Collision/hit-zone shapes remain owned by Enemy and are not changed here.

const UNIFORM := Color(0.16, 0.19, 0.17)
const VEST := Color(0.075, 0.09, 0.085)
const WEBBING := Color(0.28, 0.25, 0.18)
const SKIN := Color(0.34, 0.25, 0.19)
const HELMET := Color(0.10, 0.13, 0.12)
const BOOT := Color(0.045, 0.05, 0.045)
const METAL := Color(0.065, 0.075, 0.07)

var enemy: Variant
var clock := 0.0
var torso: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_calf: Node3D
var right_calf: Node3D
var held_weapon: Node3D
var collapsed := false
var hit_reaction_time := 0.0
var hit_reaction_duration := 0.34
var hit_reaction_strength := 0.0
var hit_reaction_side := 1.0

func _ready() -> void:
	enemy = get_parent()
	if enemy.has_signal("hit_received"):
		enemy.hit_received.connect(_on_hit_received)
	_hide_blockout_meshes()
	_build_humanoid()


func _on_hit_received(_source: Node, _shape_index: int, damage: float) -> void:
	hit_reaction_time = hit_reaction_duration
	hit_reaction_strength = clampf(damage / 60.0, 0.2, 1.0)
	var target: Node3D = enemy.player() as Node3D
	if target:
		var incoming: Vector3 = enemy.global_position - target.global_position
		incoming.y = 0.0
		if incoming.length() > 0.01:
			var local_direction: Vector3 = enemy.global_basis.inverse() * incoming.normalized()
			hit_reaction_side = 1.0 if local_direction.x >= 0.0 else -1.0

func _hide_blockout_meshes() -> void:
	if not enemy:
		return
	for path in ["Head/HeadMesh", "Torso/TorsoMesh", "Legs/LegsMesh"]:
		var part := enemy.get_node_or_null(path) as MeshInstance3D
		if part:
			part.visible = false

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _capsule(parent: Node3D, label: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part

func _segment(parent: Node3D, label: String, length: float, radius: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	parent.add_child(pivot)
	_capsule(pivot, "Mesh", radius, length, Vector3(0, -length * 0.5, 0), material)
	return pivot

func _build_humanoid() -> void:
	var uniform := _mat(UNIFORM)
	var vest_mat := _mat(VEST)
	var webbing := _mat(WEBBING)
	var skin := _mat(SKIN)
	var helmet_mat := _mat(HELMET)
	var boot_mat := _mat(BOOT)
	var metal := _mat(METAL, 0.68, 0.42)

	_capsule(self, "Neck", 0.07, 0.18, Vector3(0, 0.72, 0), skin)
	torso = Node3D.new()
	torso.name = "TorsoRig"
	torso.position = Vector3(0, 0.37, 0)
	add_child(torso)
	_capsule(torso, "Body", 0.22, 0.70, Vector3(0, 0, 0), uniform)
	_box(torso, "PlateCarrier", Vector3(0.43, 0.48, 0.24), Vector3(0, 0.01, -0.025), vest_mat)
	_box(torso, "FrontPanel", Vector3(0.29, 0.20, 0.025), Vector3(0, 0.08, -0.155), webbing)
	for i in range(3):
		_box(torso, "MagazinePouch%d" % i, Vector3(0.075, 0.11, 0.055), Vector3(-0.11 + float(i) * 0.11, -0.08, -0.17), webbing)
	_box(torso, "ShoulderStrapL", Vector3(0.075, 0.38, 0.04), Vector3(-0.16, 0.12, -0.145), webbing)
	_box(torso, "ShoulderStrapR", Vector3(0.075, 0.38, 0.04), Vector3(0.16, 0.12, -0.145), webbing)
	_box(self, "Belt", Vector3(0.40, 0.075, 0.24), Vector3(0, 0.08, 0), webbing)

	head = Node3D.new()
	head.name = "HeadRig"
	head.position = Vector3(0, 0.82, 0)
	add_child(head)
	_capsule(head, "HeadMesh", 0.135, 0.29, Vector3(0, 0, 0), skin)
	var helmet := _capsule(head, "Helmet", 0.16, 0.23, Vector3(0, 0.085, 0.015), helmet_mat)
	helmet.scale = Vector3(1.05, 0.82, 1.05)
	_box(head, "HelmetBrim", Vector3(0.30, 0.035, 0.20), Vector3(0, 0.065, -0.075), helmet_mat)
	_box(head, "EyeShadow", Vector3(0.18, 0.025, 0.018), Vector3(0, 0.015, -0.125), vest_mat)

	left_arm = _segment(self, "LeftUpperArm", 0.39, 0.075, uniform)
	left_arm.position = Vector3(-0.29, 0.56, 0)
	right_arm = _segment(self, "RightUpperArm", 0.39, 0.075, uniform)
	right_arm.position = Vector3(0.29, 0.56, 0)
	left_forearm = _segment(left_arm, "LeftForearm", 0.34, 0.065, uniform)
	left_forearm.position = Vector3(0, -0.36, -0.01)
	right_forearm = _segment(right_arm, "RightForearm", 0.34, 0.065, uniform)
	right_forearm.position = Vector3(0, -0.36, -0.01)
	_capsule(left_forearm, "Glove", 0.067, 0.13, Vector3(0, -0.32, -0.025), boot_mat)
	_capsule(right_forearm, "Glove", 0.067, 0.13, Vector3(0, -0.32, -0.025), boot_mat)

	left_leg = _segment(self, "LeftThigh", 0.43, 0.105, uniform)
	left_leg.position = Vector3(-0.14, 0.02, 0)
	right_leg = _segment(self, "RightThigh", 0.43, 0.105, uniform)
	right_leg.position = Vector3(0.14, 0.02, 0)
	left_calf = _segment(left_leg, "LeftCalf", 0.40, 0.075, uniform)
	left_calf.position = Vector3(0, -0.40, 0)
	right_calf = _segment(right_leg, "RightCalf", 0.40, 0.075, uniform)
	right_calf.position = Vector3(0, -0.40, 0)
	_box(left_calf, "Boot", Vector3(0.15, 0.10, 0.25), Vector3(0, -0.23, -0.055), boot_mat)
	_box(right_calf, "Boot", Vector3(0.15, 0.10, 0.25), Vector3(0, -0.23, -0.055), boot_mat)

	# A fictional compact rifle silhouette; actual enemy fire remains governed by AI.
	held_weapon = Node3D.new()
	held_weapon.name = "HeldWeapon"
	held_weapon.position = Vector3(0, 0.34, -0.25)
	add_child(held_weapon)
	_box(held_weapon, "Receiver", Vector3(0.12, 0.11, 0.30), Vector3(0, 0, -0.05), metal)
	_box(held_weapon, "Handguard", Vector3(0.09, 0.09, 0.24), Vector3(0, 0.005, -0.31), vest_mat)
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.018
	barrel_mesh.bottom_radius = 0.018
	barrel_mesh.height = 0.32
	barrel.mesh = barrel_mesh
	barrel.material_override = metal
	barrel.rotation.x = -PI * 0.5
	barrel.position = Vector3(0, 0.01, -0.57)
	held_weapon.add_child(barrel)
	_box(held_weapon, "Stock", Vector3(0.10, 0.11, 0.20), Vector3(0, 0, 0.19), boot_mat)
	held_weapon.visible = false

func _process(delta: float) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	clock += delta
	hit_reaction_time = maxf(0.0, hit_reaction_time - delta)
	var hit_blend := clampf(hit_reaction_time / hit_reaction_duration, 0.0, 1.0)
	hit_blend = hit_blend * hit_blend * (3.0 - 2.0 * hit_blend)
	var dead: bool = int(enemy.state) == 6
	var moving: bool = Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.25 and not dead
	var stride := sin(clock * 8.0) * (0.55 if moving else 0.025)
	var blend := minf(1.0, delta * 9.0)
	var aiming: bool = int(enemy.state) == 3
	left_leg.rotation.x = lerpf(left_leg.rotation.x, stride, blend)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -stride, blend)
	left_calf.rotation.x = lerpf(left_calf.rotation.x, maxf(0.0, -stride) * 0.65, blend)
	right_calf.rotation.x = lerpf(right_calf.rotation.x, maxf(0.0, stride) * 0.65, blend)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.72 if aiming else -stride * 0.55, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.72 if aiming else stride * 0.55, blend)
	left_forearm.rotation.x = lerpf(left_forearm.rotation.x, -0.55 if aiming else 0.0, blend)
	right_forearm.rotation.x = lerpf(right_forearm.rotation.x, -0.55 if aiming else 0.0, blend)
	torso.position.y = lerpf(torso.position.y, 0.37 + (absf(sin(clock * 8.0)) * 0.025 if moving else sin(clock * 1.8) * 0.006), blend)
	torso.rotation.x = -0.18 * hit_reaction_strength * hit_blend
	torso.rotation.z = -0.13 * hit_reaction_side * hit_reaction_strength * hit_blend
	head.rotation.y = lerpf(head.rotation.y, sin(clock * 0.75) * 0.035 if not aiming else 0.0, blend)
	head.rotation.z = 0.08 * hit_reaction_side * hit_reaction_strength * hit_blend
	left_arm.rotation.z = 0.12 * hit_reaction_side * hit_reaction_strength * hit_blend
	right_arm.rotation.z = 0.12 * hit_reaction_side * hit_reaction_strength * hit_blend
	held_weapon.visible = aiming or enemy.state == 4
	if dead:
		rotation.z = lerpf(rotation.z, 1.25, blend)
		position.y = lerpf(position.y, -0.45, blend)
