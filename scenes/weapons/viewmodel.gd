class_name WeaponViewmodel
extends Node3D

# Original, code-built first-person weapon presentation. These are deliberately
# lightweight placeholder meshes: production weapon/hand art and animations
# can replace this node without changing WeaponRig or ballistics.

const DARK_METAL := Color(0.075, 0.085, 0.09)
const EDGE_METAL := Color(0.19, 0.20, 0.19)
const POLYMER := Color(0.055, 0.06, 0.055)
const RUBBER := Color(0.025, 0.03, 0.028)
const CLOTH := Color(0.12, 0.14, 0.13)

var weapon: WeaponRig
var model_root: Node3D
var weapon_root: Node3D
var slide: Node3D
var magazine: Node3D
var muzzle_flash: MeshInstance3D
var flash_light: OmniLight3D
var active_profile: WeaponProfile
var clock := 0.0
var recoil := 0.0
var flash_remaining := 0.0
var slide_remaining := 0.0
var switch_remaining := 0.0
var reload_duration := 2.0
var base_position := Vector3(0.25, -0.22, -0.48)
var aim_position := Vector3(0.04, -0.16, -0.40)

func _ready() -> void:
	position = base_position
	visible = false

func bind_weapon(rig: WeaponRig) -> void:
	weapon = rig
	if not weapon.fired.is_connected(on_fired):
		weapon.fired.connect(on_fired)
	if not weapon.profiles.is_empty():
		set_profile(weapon.profile())
	visible = true

func set_profile(profile: WeaponProfile) -> void:
	if active_profile == profile:
		return
	active_profile = profile
	switch_remaining = 0.22
	_build_model(profile)

func on_fired(_profile: WeaponProfile) -> void:
	recoil = minf(recoil + (0.10 if active_profile and active_profile.family == "sidearm" else 0.075), 0.22)
	flash_remaining = 0.055
	slide_remaining = 0.085
	if muzzle_flash:
		muzzle_flash.visible = true
	if flash_light:
		flash_light.visible = true

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

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

func _cylinder(parent: Node3D, label: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation.x = -PI * 0.5
	parent.add_child(part)
	return part

func _build_model(profile: WeaponProfile) -> void:
	if model_root:
		model_root.queue_free()
	model_root = Node3D.new()
	model_root.name = "GeneratedViewmodel"
	add_child(model_root)
	weapon_root = Node3D.new()
	weapon_root.name = "Weapon"
	model_root.add_child(weapon_root)
	var metal := _material(DARK_METAL, 0.72, 0.32)
	var edges := _material(EDGE_METAL, 0.82, 0.28)
	var polymer := _material(POLYMER, 0.0, 0.82)
	var rubber := _material(RUBBER, 0.0, 0.94)
	var cloth := _material(CLOTH, 0.0, 0.9)

	# Forearms and sleeves give the weapon a consistent first-person scale.
	var left_arm := _cylinder(model_root, "LeftSleeve", 0.075, 0.48, Vector3(-0.22, -0.30, -0.22), cloth)
	left_arm.rotation.z = -0.38
	var right_arm := _cylinder(model_root, "RightSleeve", 0.075, 0.48, Vector3(0.22, -0.34, -0.05), cloth)
	right_arm.rotation.z = 0.38

	if profile.family == "sidearm":
		_box(weapon_root, "PistolFrame", Vector3(0.16, 0.10, 0.29), Vector3(0, 0, -0.12), polymer)
		slide = Node3D.new()
		slide.name = "SlideAssembly"
		weapon_root.add_child(slide)
		_box(slide, "Slide", Vector3(0.145, 0.095, 0.31), Vector3(0, 0.055, -0.16), metal)
		_box(slide, "RearSight", Vector3(0.075, 0.025, 0.035), Vector3(0, 0.115, -0.025), edges)
		_box(slide, "FrontSight", Vector3(0.035, 0.025, 0.025), Vector3(0, 0.115, -0.30), edges)
		_cylinder(weapon_root, "PistolBarrel", 0.026, 0.20, Vector3(0, 0.035, -0.39), edges)
		var grip := _box(weapon_root, "Grip", Vector3(0.12, 0.22, 0.13), Vector3(0, -0.13, -0.015), rubber)
		grip.rotation.x = -0.22
		magazine = Node3D.new()
		magazine.name = "Magazine"
		weapon_root.add_child(magazine)
		_box(magazine, "MagazineBody", Vector3(0.09, 0.17, 0.095), Vector3(0, -0.18, -0.01), metal)
		_box(weapon_root, "TriggerGuard", Vector3(0.10, 0.035, 0.11), Vector3(0, -0.065, -0.12), edges)
		_box(weapon_root, "Trigger", Vector3(0.018, 0.05, 0.025), Vector3(0, -0.075, -0.12), edges)
	else:
		_box(weapon_root, "Receiver", Vector3(0.18, 0.16, 0.34), Vector3(0, 0, -0.12), metal)
		_box(weapon_root, "Handguard", Vector3(0.15, 0.13, 0.34), Vector3(0, 0.005, -0.43), polymer)
		_cylinder(weapon_root, "RifleBarrel", 0.025, 0.48, Vector3(0, 0.015, -0.77), edges)
		_box(weapon_root, "Stock", Vector3(0.14, 0.13, 0.30), Vector3(0, -0.015, 0.20), rubber)
		_box(weapon_root, "PistolGrip", Vector3(0.11, 0.20, 0.12), Vector3(0, -0.16, -0.02), rubber)
		_box(weapon_root, "OpticBase", Vector3(0.08, 0.035, 0.13), Vector3(0, 0.105, -0.16), edges)
		_box(weapon_root, "Optic", Vector3(0.09, 0.10, 0.11), Vector3(0, 0.17, -0.16), polymer)
		magazine = Node3D.new()
		magazine.name = "Magazine"
		weapon_root.add_child(magazine)
		_box(magazine, "MagazineBody", Vector3(0.11, 0.20, 0.13), Vector3(0, -0.17, -0.12), metal)

	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.name = "MuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.055
	flash_mesh.height = 0.11
	muzzle_flash.mesh = flash_mesh
	muzzle_flash.material_override = _material(Color(1.0, 0.55, 0.16), 0.0, 0.2)
	muzzle_flash.position = Vector3(0, 0.035, -0.51 if profile.family == "sidearm" else -1.02)
	muzzle_flash.visible = false
	weapon_root.add_child(muzzle_flash)
	flash_light = OmniLight3D.new()
	flash_light.name = "MuzzleFlashLight"
	flash_light.light_color = Color(1.0, 0.55, 0.22)
	flash_light.light_energy = 1.6
	flash_light.omni_range = 2.0
	flash_light.visible = false
	flash_light.position = muzzle_flash.position
	weapon_root.add_child(flash_light)
	reload_duration = maxf(profile.reload_seconds, 0.1)

func advance(delta: float, aiming: bool, reload_remaining: float, move_speed: float) -> void:
	if not weapon or not active_profile:
		return
	clock += delta
	if weapon.profile() != active_profile:
		set_profile(weapon.profile())
	recoil = move_toward(recoil, 0.0, delta * 1.9)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	slide_remaining = maxf(0.0, slide_remaining - delta)
	switch_remaining = maxf(0.0, switch_remaining - delta)
	if muzzle_flash:
		muzzle_flash.visible = flash_remaining > 0.0
	if flash_light:
		flash_light.visible = flash_remaining > 0.0
	if slide:
		slide.position.z = -0.025 if slide_remaining > 0.0 else 0.0

	var speed_factor := clampf(move_speed / 5.0, 0.0, 1.0)
	var sway_x := sin(clock * 1.7) * 0.004
	var sway_y := cos(clock * 2.1) * 0.003
	var bob := sin(clock * 8.0) * 0.012 * speed_factor
	var target := aim_position if aiming else base_position
	target.x += sway_x
	target.y += sway_y - bob
	target.z += recoil * 0.55
	var reload_blend := 0.0
	if reload_remaining > 0.0:
		reload_blend = sin(PI * clampf(1.0 - reload_remaining / reload_duration, 0.0, 1.0))
		target.y -= 0.12 * reload_blend
		target.x += 0.08 * reload_blend
	position = position.lerp(target, minf(1.0, delta * 12.0))
	rotation = Vector3(-recoil * 0.7, sway_x * 0.8, sway_y * 0.8)
	if magazine:
		magazine.position.y = -0.16 - (0.20 * reload_blend if reload_remaining > 0.0 else 0.0)
