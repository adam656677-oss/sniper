extends LevelBase

# First campaign vertical slice: a fictional border depot in Kestrel Pass.
# The layout is a compact playable blockout of the larger 1 km² design.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const REINFORCEMENT_COUNT := 4

@export var ledger_point := Vector3(-10, 1, -74)
@export var radio_point := Vector3(25, 1, -84)
@export var gate_point := Vector3(0, 1, -178)

var exfil_zone: TriggerZone
var reinforcements_spawned := 0

func _ready() -> void:
	_build_environment()
	super._ready()
	build_flat_navmesh(Vector3(0, 0, 0), Vector2(390, 390))
	target_killed.connect(_on_target_killed)

func setup_objectives() -> void:
	mission_log.add("commander", "Eliminate the depot commander")
	mission_log.add("ledger", "Recover the depot ledger", MissionLog.Kind.PRIMARY, 1, true)
	mission_log.add("exfil", "Reach the north saddle", MissionLog.Kind.PRIMARY, 1, true)
	mission_log.add("radio", "Disable the radio mast before lockdown", MissionLog.Kind.SECONDARY)
	mission_log.add("undetected", "Stay undetected", MissionLog.Kind.SECONDARY)
	mission_log.add("long_shot", "Eliminate the commander from beyond 500 m", MissionLog.Kind.OPTIONAL)
	mission_log.add("silent", "Fire only suppressed weapons", MissionLog.Kind.OPTIONAL)
	coordinator.level_changed.connect(_on_alert_changed)
	exfil_zone = add_trigger("NorthSaddleExfil", gate_point, Vector3(12, 5, 12))
	exfil_zone.enabled = false
	exfil_zone.entered.connect(func(_zone): mission_log.complete("exfil"))

func restore_triggers() -> void:
	if exfil_zone:
		exfil_zone.enabled = mission_log.status("exfil") == MissionLog.Status.ACTIVE

func _on_alert_changed(level: int) -> void:
	if level >= AlertCoordinator.Level.ALERT:
		mission_log.fail("undetected")
	if level >= AlertCoordinator.Level.LOCKDOWN and mission_log.status("radio") == MissionLog.Status.ACTIVE:
		mission_log.fail("radio")

func report_noise(position: Vector3, radius: float, loudness: float = 1.0) -> void:
	super.report_noise(position, radius, loudness)
	if loudness >= 1.0 and radius > 100.0:
		mission_log.fail("silent")

func on_enemy_died(enemy: Node) -> void:
	super.on_enemy_died(enemy)
	if enemy.name == "Commander":
		mission_log.complete("commander")
		mission_log.activate("ledger")

func _on_target_killed(body: Node3D, distance: float) -> void:
	if body and body.name == "Commander" and distance >= 500.0:
		mission_log.complete("long_shot")

func interact(point: Vector3) -> void:
	if mission_log.status("radio") == MissionLog.Status.ACTIVE and point.distance_to(radio_point) <= INTERACT_DISTANCE:
		mission_log.complete("radio")
		return
	if mission_log.status("ledger") == MissionLog.Status.ACTIVE and point.distance_to(ledger_point) <= INTERACT_DISTANCE:
		mission_log.complete("ledger")
		mission_log.activate("exfil")
		exfil_zone.enabled = true

func spawn_reinforcements(position: Vector3) -> void:
	for i in range(REINFORCEMENT_COUNT):
		var enemy := ENEMY_SCENE.instantiate()
		enemy.name = "NorthGateReinforcement%d" % (reinforcements_spawned + 1)
		reinforcements_spawned += 1
		enemy.position = gate_point + Vector3(float(i) * 2.5 - 3.75, 0, 3)
		enemy.patrol_points = PackedVector3Array([enemy.position, position, gate_point])
		$Enemies.add_child(enemy)
		register_enemy(enemy)
		enemy.receive_contact(position)

func _build_environment() -> void:
	# Raised overlooks and access ramps give the player two distinct approaches.
	var ridge := spawn_box(Vector3(-122, 4, 12), Vector3(78, 8, 66), Color(0.27, 0.29, 0.25))
	ridge.name = "KestrelRidge"
	var ridge_ramp := spawn_box(Vector3(-122, 4.0, 66), Vector3(34, 1, 82), Color(0.24, 0.27, 0.23))
	ridge_ramp.name = "RidgeAccessSlope"
	ridge_ramp.rotation.x = 0.12
	var shelf := spawn_box(Vector3(122, 2, -8), Vector3(64, 4, 54), Color(0.29, 0.30, 0.25))
	shelf.name = "PineShelf"
	var shelf_ramp := spawn_box(Vector3(122, 2.2, 36), Vector3(30, 1, 58), Color(0.25, 0.28, 0.23))
	shelf_ramp.name = "ShelfAccessSlope"
	shelf_ramp.rotation.x = 0.07

	# Depot perimeter, with an obvious vehicle gate at the north.
	var wall_mat := Color(0.34, 0.32, 0.27)
	spawn_box(Vector3(-48, 2, -82), Vector3(2, 4, 92), wall_mat).name = "WestPerimeter"
	spawn_box(Vector3(48, 2, -82), Vector3(2, 4, 92), wall_mat).name = "EastPerimeter"
	spawn_box(Vector3(-43.75, 2, -128), Vector3(10.5, 4, 2), wall_mat).name = "NorthPerimeterWestOuter"
	spawn_box(Vector3(-23.25, 2, -128), Vector3(16.5, 4, 2), wall_mat).name = "NorthPerimeterWestInner"
	spawn_box(Vector3(32, 2, -128), Vector3(34, 4, 2), wall_mat).name = "NorthPerimeterEast"
	spawn_box(Vector3(-38, 1.5, -130), Vector3(1, 3, 24), Color(0.28, 0.29, 0.27)).name = "CulvertWestWall"
	spawn_box(Vector3(-32, 1.5, -130), Vector3(1, 3, 24), Color(0.28, 0.29, 0.27)).name = "CulvertEastWall"
	spawn_box(Vector3(-35, 3, -130), Vector3(7, 0.8, 24), Color(0.24, 0.25, 0.23)).name = "CulvertRoof"
	spawn_box(Vector3(-35, 0.125, -130), Vector3(7, 0.25, 24), Color(0.30, 0.30, 0.27)).name = "CulvertFloor"
	spawn_box(Vector3(-14, 2.0, -128), Vector3(1.5, 4, 2), wall_mat).name = "NorthGatePostWest"
	spawn_box(Vector3(14, 2.0, -128), Vector3(1.5, 4, 2), wall_mat).name = "NorthGatePostEast"
	spawn_box(Vector3(8, 1.1, -134), Vector3(8, 2.2, 4), Color(0.20, 0.24, 0.20)).name = "NorthGateTruck"
	spawn_box(Vector3(10, 2.4, -135), Vector3(3.5, 1.8, 3.2), Color(0.24, 0.27, 0.23)).name = "NorthGateTruckCab"
	spawn_box(Vector3(-31, 2, -36), Vector3(36, 4, 2), wall_mat).name = "SouthWestPerimeter"
	spawn_box(Vector3(31, 2, -36), Vector3(36, 4, 2), wall_mat).name = "SouthEastPerimeter"

	# Office, storage huts, fuel tanks and concrete cover.
	spawn_box(Vector3(-22, 2, -74), Vector3(16, 4, 13), Color(0.38, 0.36, 0.31)).name = "DepotOffice"
	spawn_box(Vector3(18, 2, -55), Vector3(17, 4, 12), Color(0.39, 0.37, 0.32)).name = "StorageHut"
	spawn_box(Vector3(-16, 2, -105), Vector3(20, 4, 12), Color(0.36, 0.34, 0.29)).name = "Workshop"
	spawn_box(Vector3(0, 1.2, -92), Vector3(10, 2.4, 2), Color(0.30, 0.31, 0.28)).name = "ConcreteCoverA"
	spawn_box(Vector3(31, 1.2, -105), Vector3(2, 2.4, 12), Color(0.30, 0.31, 0.28)).name = "ConcreteCoverB"

	_add_fuel_tank(Vector3(28, 0, -73))
	_add_fuel_tank(Vector3(36, 0, -73))
	_add_radio_mast(Vector3(radio_point.x, 0, radio_point.z))
	_add_ledger_marker(ledger_point)
	_add_tree_cluster()
	_add_environment_dressing()

	# A broken road leads from the gully through the gate and out to the saddle.
	spawn_box(Vector3(0, 0.03, 8), Vector3(12, 0.06, 350), Color(0.19, 0.19, 0.17)).name = "PassRoad"
	spawn_box(Vector3(0, 0.04, -177), Vector3(24, 0.08, 18), Color(0.23, 0.22, 0.19)).name = "ExtractionSaddle"

func _add_fuel_tank(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "FuelTank"
	body.position = at + Vector3(0, 2.0, 0)
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.0
	mesh.bottom_radius = 2.0
	mesh.height = 4.0
	mesh.radial_segments = 20
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.38, 0.34)
	material.metallic = 0.55
	material.roughness = 0.48
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.0
	shape.height = 4.0
	collision.shape = shape
	body.add_child(collision)

func _add_radio_mast(at: Vector3) -> void:
	var mast := Node3D.new()
	mast.name = "RadioMast"
	mast.position = at
	add_child(mast)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 14.0
	pole.mesh = pole_mesh
	pole.position.y = 7.0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.20, 0.22, 0.20)
	metal.metallic = 0.7
	pole.material_override = metal
	mast.add_child(pole)
	for y in [4.0, 8.0, 12.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(2.0, 0.07, 0.07)
		arm.mesh = arm_mesh
		arm.position = Vector3(0, y, 0)
		arm.material_override = metal
		mast.add_child(arm)

func _add_ledger_marker(at: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "LedgerMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.28, 0.06, 0.20)
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.28, 0.12)
	material.roughness = 0.9
	marker.material_override = material
	marker.position = at + Vector3(0, 0.8, 0)
	add_child(marker)

func _add_tree_cluster() -> void:
	var tree_positions := [
		Vector3(-175, 0, 95), Vector3(-155, 0, 120), Vector3(-185, 0, 145),
		Vector3(170, 0, 75), Vector3(185, 0, 100), Vector3(155, 0, 125),
		Vector3(-165, 0, -20), Vector3(-180, 0, -55), Vector3(175, 0, -20),
		Vector3(185, 0, -55), Vector3(-145, 0, -145), Vector3(145, 0, -150)
	]
	for i in range(tree_positions.size()):
		var tree := Node3D.new()
		tree.name = "PineTree%d" % i
		tree.position = tree_positions[i]
		add_child(tree)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.12
		trunk_mesh.bottom_radius = 0.20
		trunk_mesh.height = 2.0
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.0
		var bark := StandardMaterial3D.new()
		bark.albedo_color = Color(0.20, 0.16, 0.12)
		trunk.material_override = bark
		tree.add_child(trunk)
		for tier in range(3):
			var foliage := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.0 - float(tier) * 0.20
			cone.height = 2.2
			cone.radial_segments = 8
			foliage.mesh = cone
			foliage.position.y = 2.0 + float(tier) * 1.0
			var pine := StandardMaterial3D.new()
			pine.albedo_color = Color(0.08, 0.14, 0.10)
			pine.roughness = 0.96
			foliage.material_override = pine
			tree.add_child(foliage)


# Decorative dressing is deliberately mesh-only: it adds a stronger mountain
# silhouette without changing collision, navigation, objective or sightline logic.
func _add_environment_dressing() -> void:
	var dressing := Node3D.new()
	dressing.name = "EnvironmentDressing"
	add_child(dressing)

	var tree_positions := [
		Vector3(-188, 0, 78), Vector3(-166, 0, 104), Vector3(-190, 0, 132),
		Vector3(-174, 0, 158), Vector3(-190, 0, -8), Vector3(-182, 0, -42),
		Vector3(-190, 0, -78), Vector3(184, 0, 58), Vector3(190, 0, 92),
		Vector3(164, 0, 122), Vector3(188, 0, 150), Vector3(190, 0, -14),
		Vector3(184, 0, -48), Vector3(190, 0, -82), Vector3(-148, 0, -164),
		Vector3(-108, 0, -188), Vector3(108, 0, -188), Vector3(150, 0, -164)
	]
	for i in range(tree_positions.size()):
		_add_dressed_pine(dressing, "RidgePine_%02d" % i, tree_positions[i], 0.82 + float(i % 4) * 0.12, i)

	var rock_positions := [
		Vector3(-146, 0, 36), Vector3(-158, 0, 54), Vector3(-142, 0, 76),
		Vector3(-166, 0, 138), Vector3(-148, 0, 158), Vector3(-176, 0, -22),
		Vector3(-160, 0, -66), Vector3(-148, 0, -112), Vector3(-132, 0, -160),
		Vector3(146, 0, 32), Vector3(160, 0, 54), Vector3(144, 0, 78),
		Vector3(166, 0, 136), Vector3(150, 0, 158), Vector3(178, 0, -24),
		Vector3(160, 0, -68), Vector3(148, 0, -116), Vector3(132, 0, -160)
	]
	for i in range(rock_positions.size()):
		var width := 1.4 + float(i % 3) * 0.55
		_add_dressed_rock(dressing, "RidgeRock_%02d" % i, rock_positions[i], Vector3(width, 0.9 + float(i % 2) * 0.45, width * 0.82), i)

	var scrub_positions := [
		Vector3(-104, 0, 132), Vector3(104, 0, 138), Vector3(-96, 0, -158),
		Vector3(96, 0, -158), Vector3(-184, 0, 14), Vector3(184, 0, 12),
		Vector3(-122, 0, -180), Vector3(122, 0, -180), Vector3(-154, 0, 88),
		Vector3(154, 0, 92)
	]
	for i in range(scrub_positions.size()):
		_add_scrub_cluster(dressing, "RidgeScrub_%02d" % i, scrub_positions[i], i)


func _add_dressed_pine(parent: Node3D, tree_name: String, at: Vector3, scale_factor: float, variant: int) -> void:
	var tree := Node3D.new()
	tree.name = tree_name
	tree.position = at
	tree.rotation.y = float(variant % 7) * 0.71
	tree.scale = Vector3.ONE * scale_factor
	parent.add_child(tree)

	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.19, 0.15, 0.11)
	bark.roughness = 0.98
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 3.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6
	trunk.material_override = bark
	tree.add_child(trunk)

	var pine_colors: Array[Color] = [
		Color(0.055, 0.105, 0.075), Color(0.075, 0.13, 0.085),
		Color(0.09, 0.145, 0.095), Color(0.065, 0.12, 0.09)
	]
	for tier in range(4):
		var foliage := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.035
		cone.bottom_radius = 1.55 - float(tier) * 0.25
		cone.height = 2.65
		cone.radial_segments = 9
		foliage.mesh = cone
		foliage.position.y = 2.1 + float(tier) * 1.12
		var needles := StandardMaterial3D.new()
		needles.albedo_color = pine_colors[(variant + tier) % pine_colors.size()]
		needles.roughness = 0.97
		foliage.material_override = needles
		tree.add_child(foliage)


func _add_dressed_rock(parent: Node3D, rock_name: String, at: Vector3, rock_scale: Vector3, variant: int) -> void:
	var rock := MeshInstance3D.new()
	rock.name = rock_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	rock.mesh = mesh
	rock.position = at + Vector3(0, rock_scale.y * 0.72, 0)
	rock.scale = rock_scale
	rock.rotation = Vector3(float(variant % 3) * 0.11, float(variant) * 0.37, float(variant % 4) * 0.09)
	var stone := StandardMaterial3D.new()
	var shades: Array[Color] = [
		Color(0.25, 0.26, 0.24), Color(0.31, 0.29, 0.25),
		Color(0.35, 0.34, 0.30), Color(0.22, 0.24, 0.23)
	]
	stone.albedo_color = shades[variant % shades.size()]
	stone.roughness = 0.94
	rock.material_override = stone
	parent.add_child(rock)


func _add_scrub_cluster(parent: Node3D, scrub_name: String, at: Vector3, variant: int) -> void:
	var scrub := Node3D.new()
	scrub.name = scrub_name
	scrub.position = at
	scrub.rotation.y = float(variant) * 0.63
	parent.add_child(scrub)
	var colors: Array[Color] = [Color(0.13, 0.17, 0.11), Color(0.17, 0.19, 0.12), Color(0.12, 0.15, 0.10)]
	for i in range(3):
		var tuft := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.72
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 4
		tuft.mesh = mesh
		tuft.position = Vector3(float(i - 1) * 0.55, 0.38 + float(i % 2) * 0.08, float(i % 2) * 0.35)
		tuft.scale = Vector3(1.0, 0.72, 0.82)
		var leaves := StandardMaterial3D.new()
		leaves.albedo_color = colors[(variant + i) % colors.size()]
		leaves.roughness = 0.99
		tuft.material_override = leaves
		scrub.add_child(tuft)
