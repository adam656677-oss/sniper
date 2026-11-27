extends Node3D

# First playable story sequence. Primitive blockout art is intentional until
# the production environment and character assets are ready.
#
# Quiet scene: explore the home and make three discoveries. Attack: the front
# door is breached and an Accord team sweeps the yard with flashlights. Escape:
# slip past them to the tree line. Being spotted sends Elias back to the doorway.
const PLAYER_SPEED := 4.2
const CROUCH_SPEED_SCALE := 0.55
const STAND_EYE_HEIGHT := 0.62
const CROUCH_EYE_HEIGHT := 0.1
const CROUCH_EXPOSURE := 0.5
const LOOK_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.8
const KESTREL_SCENE := "res://kestrel_mission.tscn"

# Yard layout. The house floor top is at y = 0; the yard ground sits lower.
const YARD_TOP := -0.145
const OPERATIVE_HEIGHT := YARD_TOP + 0.9
const RESET_POINT := Vector3(0, 0.9, 6.5)
const HOUSE_FRONT_Z := 8.95
const TREE_LINE_X := 8.5
const TREE_LINE_MIN_Z := 14.0
const TREE_LINE_MAX_Z := 47.0

# Escape sweep tuning.
const FLASHLIGHT_RANGE := 18.0
const FLASHLIGHT_CONE_DEGREES := 50.0
const OPERATIVE_SPEED := 1.6
const OPERATIVE_PAUSE := 1.6
const SWEEP_DEGREES := 35.0
const SPOTTED_GRACE := 1.5
# Each operative walks its route out and back, pausing to sweep at each point.
const PATROL_ROUTES := [
	[Vector3(-3.5, 0, 11.5), Vector3(-4.0, 0, 18.0), Vector3(-6.5, 0, 25.0)],
	[Vector3(6.5, 0, 25.0), Vector3(4.0, 0, 18.0), Vector3(3.5, 0, 11.5)],
]

var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var prompt: Label
var objective: Label
var exposure_label: Label
var exposure_bar: ProgressBar
var key_light: DirectionalLight3D
var front_door: Node3D
var door_collision: CollisionShape3D
var fade_rect: ColorRect
var alarm_rect: ColorRect
var attack_lights: Array[SpotLight3D] = []
var operatives: Array[CharacterBody3D] = []
var patrols: Array[Dictionary] = []
var interactables: Dictionary = {}
var discoveries: Array[String] = []
var attack_started := false
var escaped := false
var crouched := false
var patrol_enabled := true
var auto_transition := true
var spotted_count := 0
var grace_remaining := 0.0
var exposure := 0.0
var pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_build_house()
	_build_player()
	_build_hud()
	_add_interactable("photo", tr("Look at the photograph"), Vector3(2.0, 1.1, -3.7), Color(0.65, 0.43, 0.23))
	_add_interactable("lena", tr("Talk to Lena"), Vector3(-2.2, 1.0, -1.4), Color(0.72, 0.42, 0.34))
	_add_interactable("ledger", tr("Take Lena's data key"), Vector3(-1.1, 1.0, -1.4), Color(0.18, 0.65, 0.72))
	_update_objective()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.025, 0.04, 0.06)
	sky_mat.sky_horizon_color = Color(0.34, 0.24, 0.17)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.68, 0.62)
	env.ambient_light_energy = 0.95
	world.environment = env
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -25, 0)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	add_child(key_light)
	var living_light := OmniLight3D.new()
	living_light.light_color = Color(1.0, 0.78, 0.56)
	living_light.light_energy = 3.2
	living_light.omni_range = 16.0
	living_light.position = Vector3(1.0, 3.0, -1.0)
	add_child(living_light)
	var kitchen_light := OmniLight3D.new()
	kitchen_light.light_color = Color(1.0, 0.86, 0.68)
	kitchen_light.light_energy = 2.4
	kitchen_light.omni_range = 9.0
	kitchen_light.position = Vector3(-3.5, 2.8, -1.8)
	add_child(kitchen_light)

func _build_house() -> void:
	_box("Floor", Vector3(0, -0.15, 0), Vector3(14, 0.3, 18), Color(0.19, 0.17, 0.14), true)
	_box("Back wall", Vector3(0, 1.8, -8.8), Vector3(14, 3.6, 0.3), Color(0.27, 0.24, 0.2), true)
	_box("Left wall", Vector3(-7, 1.8, 0), Vector3(0.3, 3.6, 18), Color(0.23, 0.21, 0.18), true)
	_box("Right wall", Vector3(7, 1.8, 0), Vector3(0.3, 3.6, 18), Color(0.23, 0.21, 0.18), true)
	# The front wall meets the 2.8 m doorway exactly so the only way out is the door.
	_box("Front left wall", Vector3(-4.2, 1.8, 8.8), Vector3(5.6, 3.6, 0.3), Color(0.23, 0.21, 0.18), true)
	_box("Front right wall", Vector3(4.2, 1.8, 8.8), Vector3(5.6, 3.6, 0.3), Color(0.23, 0.21, 0.18), true)
	_box("Door lintel", Vector3(0, 3.3, 8.8), Vector3(2.8, 0.6, 0.3), Color(0.23, 0.21, 0.18), false)
	_box("Ceiling", Vector3(0, 3.65, 0), Vector3(14, 0.3, 18), Color(0.12, 0.12, 0.11), true)
	_box("Sofa", Vector3(2, 0.55, -1.5), Vector3(3.4, 1.1, 1), Color(0.17, 0.19, 0.18), false)
	_box("Coffee table", Vector3(2, 0.38, -3), Vector3(2.2, 0.12, 1), Color(0.31, 0.2, 0.12), false)
	_box("Kitchen island", Vector3(-3.6, 0.55, -1.8), Vector3(2.2, 1.1, 1.2), Color(0.3, 0.25, 0.19), false)
	_box("Window", Vector3(0, 2, -8.62), Vector3(3, 1.6, 0.08), Color(0.08, 0.13, 0.18), false)
	_box("Photo frame", Vector3(2, 1.65, -3.65), Vector3(0.9, 0.7, 0.08), Color(0.65, 0.43, 0.23), false)
	_capsule("Lena silhouette", Vector3(-2.2, 0.9, -1.4), Color(0.48, 0.3, 0.25))
	_box("Data key", Vector3(-1.1, 1, -1.4), Vector3(0.22, 0.08, 0.38), Color(0.18, 0.65, 0.72), false)
	_build_front_door()
	_build_exterior()

func _build_front_door() -> void:
	# The door hangs from a hinge pivot so the breach swings it into the hall.
	front_door = Node3D.new()
	front_door.name = "Front door"
	front_door.position = Vector3(-1.4, 0, 8.68)
	add_child(front_door)
	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(2.8, 3, 0.16)
	panel.mesh = panel_mesh
	panel.material_override = _mat(Color(0.18, 0.13, 0.1))
	panel.position = Vector3(1.4, 1.5, 0)
	front_door.add_child(panel)
	var blocker := StaticBody3D.new()
	blocker.name = "Door blocker"
	blocker.position = Vector3(0, 1.8, 8.8)
	door_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.6, 0.3)
	door_collision.shape = shape
	blocker.add_child(door_collision)
	add_child(blocker)

func doorway_open() -> bool:
	return door_collision.disabled

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "ProloguePlayer"
	player.position = Vector3(0, 1, 4.2)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)
	head = Node3D.new()
	head.position.y = STAND_EYE_HEIGHT
	player.add_child(head)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 76
	head.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	fade_rect = _overlay(Color.BLACK)
	layer.add_child(fade_rect)
	alarm_rect = _overlay(Color(0.55, 0.04, 0.02))
	layer.add_child(alarm_rect)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.025
	panel.anchor_right = 0.52
	panel.anchor_bottom = 0.2
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = tr("THE LAST QUIET NIGHT  //  2041")
	title.add_theme_color_override("font_color", Color(0.82, 0.66, 0.42))
	column.add_child(title)
	objective = Label.new()
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective)
	var exposure_row := HBoxContainer.new()
	column.add_child(exposure_row)
	exposure_label = Label.new()
	exposure_label.text = tr("EXPOSURE")
	exposure_label.add_theme_font_size_override("font_size", 12)
	exposure_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.32))
	exposure_row.add_child(exposure_label)
	exposure_bar = ProgressBar.new()
	exposure_bar.min_value = 0.0
	exposure_bar.max_value = 1.0
	exposure_bar.step = 0.0
	exposure_bar.show_percentage = false
	exposure_bar.custom_minimum_size = Vector2(220, 12)
	exposure_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.32, 0.16)
	exposure_bar.add_theme_stylebox_override("fill", fill)
	exposure_row.add_child(exposure_bar)
	exposure_label.visible = false
	exposure_bar.visible = false
	prompt = Label.new()
	prompt.anchor_left = 0.2
	prompt.anchor_right = 0.8
	prompt.anchor_top = 0.78
	prompt.anchor_bottom = 0.9
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(prompt)
	var controls := Label.new()
	controls.text = tr("WASD Move  •  Mouse Look  •  E Interact  •  C Crouch  •  Esc Release Mouse")
	controls.anchor_left = 0.02
	controls.anchor_right = 0.72
	controls.anchor_top = 0.94
	controls.anchor_bottom = 0.99
	controls.add_theme_font_size_override("font_size", 11)
	layer.add_child(controls)

func _overlay(tint: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = tint
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func _box(label: String, at: Vector3, size: Vector3, tint: Color, solid: bool) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _mat(tint)
	root.add_child(mesh)
	root.name = label
	root.position = at
	add_child(root)
	return root

# Invisible collision that keeps the player inside the yard.
func _boundary(label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _capsule(label: String, at: Vector3, tint: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = 0.28
	shape.height = 1.55
	mesh.mesh = shape
	mesh.material_override = _mat(tint)
	mesh.position = at
	mesh.name = label
	add_child(mesh)

func _build_exterior() -> void:
	_box("Yard ground", Vector3(0, -0.32, 27), Vector3(46, 0.35, 40), Color(0.12, 0.14, 0.12), true)
	_box("Gravel drive", Vector3(0, -0.1, 23), Vector3(5.2, 0.06, 28), Color(0.25, 0.23, 0.19), false)
	# A box van tall enough to hide a standing man; low cover on each flank only
	# hides a crouching one.
	_box("Accord response vehicle", Vector3(0, YARD_TOP + 1.05, 24), Vector3(2.6, 2.1, 5.8), Color(0.055, 0.065, 0.07), true)
	_box("Vehicle windshield", Vector3(0, YARD_TOP + 1.55, 21.08), Vector3(2.3, 0.62, 0.05), Color(0.1, 0.13, 0.16), false)
	_box("Woodpile", Vector3(-6.5, YARD_TOP + 0.575, 16.0), Vector3(0.9, 1.15, 3.0), Color(0.24, 0.16, 0.09), true)
	_box("Garden wall", Vector3(6.5, YARD_TOP + 0.575, 16.0), Vector3(0.9, 1.15, 3.0), Color(0.29, 0.28, 0.26), true)
	_boundary("Yard boundary west", Vector3(-23.15, 1.5, 27), Vector3(0.3, 4, 40))
	_boundary("Yard boundary east", Vector3(23.15, 1.5, 27), Vector3(0.3, 4, 40))
	_boundary("Yard boundary north", Vector3(0, 1.5, 47.15), Vector3(46.6, 4, 0.3))
	_boundary("Yard boundary near west", Vector3(-15, 1.5, 6.85), Vector3(16, 4, 0.3))
	_boundary("Yard boundary near east", Vector3(15, 1.5, 6.85), Vector3(16, 4, 0.3))
	for x in [-13.0, -9.0, 9.0, 13.0]:
		for z in [13.0, 21.0, 30.0, 38.0]:
			_tree(Vector3(x, 0, z))
	for x in [-0.9, 0.9]:
		var headlight := SpotLight3D.new()
		headlight.light_color = Color(0.78, 0.86, 1.0)
		headlight.light_energy = 0.0
		headlight.spot_range = 25.0
		headlight.spot_angle = 28.0
		headlight.position = Vector3(x, YARD_TOP + 0.75, 20.95)
		add_child(headlight)
		attack_lights.append(headlight)
	for index in PATROL_ROUTES.size():
		_add_operative(index)

func _tree(at: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.8
	trunk.mesh = trunk_mesh
	trunk.material_override = _mat(Color(0.18, 0.13, 0.09))
	trunk.position = at + Vector3(0, 1.4, 0)
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.5
	crown_mesh.height = 4.2
	crown.mesh = crown_mesh
	crown.material_override = _mat(Color(0.055, 0.11, 0.075))
	crown.position = at + Vector3(0, 3.8, 0)
	add_child(crown)

# A dark capsule figure with a flashlight, a faint visible beam and the shared
# Perception component narrowed to the beam.
func _add_operative(index: int) -> void:
	var body := CharacterBody3D.new()
	body.name = "Accord operative %d" % (index + 1)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collider.shape = capsule
	body.add_child(collider)
	var figure := MeshInstance3D.new()
	var figure_mesh := CapsuleMesh.new()
	figure_mesh.radius = 0.3
	figure_mesh.height = 1.8
	figure.mesh = figure_mesh
	figure.material_override = _mat(Color(0.07, 0.08, 0.075))
	body.add_child(figure)
	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.34, 0.1, 0.08)
	visor.mesh = visor_mesh
	var visor_mat := _mat(Color(0.4, 0.75, 0.9))
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0.25, 0.6, 0.8)
	visor.material_override = visor_mat
	visor.position = Vector3(0, 0.62, -0.27)
	body.add_child(visor)
	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.86, 0.9, 1.0)
	flashlight.light_energy = 6.0
	flashlight.spot_range = FLASHLIGHT_RANGE
	flashlight.spot_angle = FLASHLIGHT_CONE_DEGREES * 0.5
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.2, 0.45, -0.32)
	body.add_child(flashlight)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var beam_length := FLASHLIGHT_RANGE * 0.55
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = tan(deg_to_rad(FLASHLIGHT_CONE_DEGREES * 0.5)) * beam_length
	beam_mesh.height = beam_length
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Plain alpha mixing: additive blending floods the whole view white in the
	# Compatibility renderer once the camera is near or inside a cone.
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(0.75, 0.82, 1.0, 0.04)
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder's narrow top faces the torch; its wide base reaches forward.
	beam.rotation.x = PI * 0.5
	beam.position = flashlight.position + Vector3(0, 0, -beam_length * 0.5)
	body.add_child(beam)
	var perception := Perception.new()
	perception.name = "Perception"
	perception.fov_degrees = FLASHLIGHT_CONE_DEGREES
	body.add_child(perception)
	var route: Array = PATROL_ROUTES[index]
	# The second operative starts mid-route so the two flanks are out of phase.
	var start := 0 if index == 0 else 1
	body.position = _ground(route[start])
	body.visible = false
	add_child(body)
	operatives.append(body)
	patrols.append({"body": body, "route": route, "target": start, "step": 1, "wait": OPERATIVE_PAUSE, "phase": 0.0})
	body.rotation.y = _yaw_towards(body.position, _ground(route[_next_target(patrols.back())]))

func _ground(point: Vector3) -> Vector3:
	return Vector3(point.x, OPERATIVE_HEIGHT, point.z)

func _yaw_towards(from: Vector3, to: Vector3) -> float:
	return atan2(from.x - to.x, from.z - to.z)

# Routes are walked out and back rather than looped.
func _next_target(patrol: Dictionary) -> int:
	var route: Array = patrol.route
	var next: int = patrol.target + patrol.step
	if next < 0 or next >= route.size():
		return patrol.target - patrol.step
	return next

func _update_patrols(delta: float) -> void:
	for patrol in patrols:
		var body: CharacterBody3D = patrol.body
		if patrol.wait > 0.0:
			# Hold position and sweep the beam toward the next leg of the route.
			patrol.wait -= delta
			patrol.phase += delta
			var ahead := _ground(patrol.route[_next_target(patrol)])
			var sweep := deg_to_rad(SWEEP_DEGREES) * sin(patrol.phase * 1.8)
			body.rotation.y = lerp_angle(body.rotation.y, _yaw_towards(body.global_position, ahead) + sweep, minf(1.0, 5.0 * delta))
			if patrol.wait <= 0.0:
				var next := _next_target(patrol)
				patrol.step = signi(next - patrol.target)
				patrol.target = next
			continue
		var goal := _ground(patrol.route[patrol.target])
		var to_goal := goal - body.global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.05:
			patrol.wait = OPERATIVE_PAUSE
			patrol.phase = 0.0
			continue
		body.global_position += to_goal.normalized() * minf(OPERATIVE_SPEED * delta, to_goal.length())
		body.rotation.y = lerp_angle(body.rotation.y, _yaw_towards(body.global_position, goal), minf(1.0, 6.0 * delta))

func _add_interactable(id: String, label: String, at: Vector3, tint: Color) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	marker.mesh = sphere
	marker.material_override = _mat(tint)
	marker.position = at
	marker.name = "Interact_" + id
	add_child(marker)
	interactables[id] = {"node": marker, "label": label}

func _nearest_interactable() -> String:
	var nearest := ""
	var nearest_distance := INTERACT_DISTANCE
	for id in interactables:
		if discoveries.has(id):
			continue
		var marker: Node3D = interactables[id].node
		var distance := player.global_position.distance_to(marker.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = id
	return nearest

func _process(_delta: float) -> void:
	if escaped:
		return
	if Input.is_action_just_pressed("crouch"):
		set_crouched(not crouched)
	var target := _nearest_interactable()
	prompt.text = tr("[E] %s") % String(interactables[target].label) if not target.is_empty() else ""
	if Input.is_action_just_pressed("interact") and not target.is_empty():
		interact_with(target)

func interact_with(id: String) -> bool:
	if escaped or not interactables.has(id) or discoveries.has(id):
		return false
	discoveries.append(id)
	match id:
		"photo":
			StoryCampaign.dialogue_requested.emit(tr("ELIAS VANCE"), tr("That was the first week we moved here. You said the roof leaked. I said I could fix anything."))
		"lena":
			StoryCampaign.dialogue_requested.emit(tr("LENA VALE"), tr("You promised me one quiet night. I intend to hold you to it."))
			StoryCampaign.dialogue_requested.emit(tr("ELIAS VANCE"), tr("Then tonight, the world can wait."))
		"ledger":
			StoryCampaign.dialogue_requested.emit(tr("LENA VALE"), tr("I copied the files. If anything happens, this key is the only piece they won't find in the system."))
			StoryCampaign.add_evidence("black_ledger_fragment_00")
	if discoveries.size() == interactables.size():
		_begin_attack()
	else:
		_update_objective()
	return true

func _begin_attack() -> void:
	if attack_started:
		return
	attack_started = true
	for headlight in attack_lights:
		headlight.light_energy = 7.5
	key_light.light_energy = 0.12
	key_light.light_color = Color(0.45, 0.16, 0.12)
	StoryCampaign.set_flag("home_attack_survived", false)
	StoryCampaign.dialogue_requested.emit(tr("LENA VALE"), tr("Elias—those headlights aren't ours."))
	StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("Echo, get down! That's an Accord team. Move!"))
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.25, 0.12)
	flash.light_energy = 4
	flash.omni_range = 10
	flash.position = Vector3(0, 2, 7.8)
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 1.4)
	tween.tween_callback(flash.queue_free)
	door_collision.disabled = true
	var door_tween := create_tween()
	door_tween.tween_property(front_door, "rotation:y", deg_to_rad(72), 0.8).set_delay(0.5)
	for operative in operatives:
		operative.visible = true
	exposure_label.visible = true
	exposure_bar.visible = true
	StoryCampaign.dialogue_requested.emit(tr("NARRATOR"), tr("The front door buckles inward. The house is no longer safe."))
	StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("Two of them are sweeping the yard with lights. Stay out of the beams and make for the trees."))
	_update_objective()

# How visible Elias is to a flashlight, from 0 (invisible) to 1 (fully exposed).
# Perception multiplies this by the beam's distance falloff and the difficulty.
func player_exposure() -> float:
	var value := CROUCH_EXPOSURE if crouched else 1.0
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed > PLAYER_SPEED * 0.75:
		value *= 1.15
	return clampf(value, 0.0, 1.0)

func set_crouched(value: bool) -> void:
	crouched = value
	head.position.y = CROUCH_EYE_HEIGHT if crouched else STAND_EYE_HEIGHT

func visibility_to(operative: Node3D) -> float:
	var perception: Perception = operative.get_node("Perception")
	return perception.visibility_of(camera.global_position, player_exposure(), FLASHLIGHT_RANGE)

func in_tree_line(point: Vector3) -> bool:
	return absf(point.x) >= TREE_LINE_X and point.z >= TREE_LINE_MIN_Z and point.z <= TREE_LINE_MAX_Z

func _update_detection(delta: float) -> void:
	if grace_remaining > 0.0:
		grace_remaining = maxf(0.0, grace_remaining - delta)
		exposure = 0.0
	else:
		exposure = 0.0
		# The house is the safe zone: the player can watch the sweep from the
		# doorway and pick a moment without being caught through the frame.
		var outside := player.global_position.z > HOUSE_FRONT_Z
		for operative in operatives:
			var perception: Perception = operative.get_node("Perception")
			perception.accumulate(visibility_to(operative) if outside else 0.0, delta)
			exposure = maxf(exposure, perception.awareness)
		if exposure >= 1.0:
			_spotted()
	exposure_bar.value = exposure

func _spotted() -> void:
	spotted_count += 1
	for operative in operatives:
		var perception: Perception = operative.get_node("Perception")
		perception.awareness = 0.0
	exposure = 0.0
	grace_remaining = SPOTTED_GRACE
	player.global_position = RESET_POINT
	player.velocity = Vector3.ZERO
	player.rotation.y = PI
	pitch = 0.0
	camera.rotation.x = 0.0
	alarm_rect.modulate.a = 0.45
	var flash := create_tween()
	flash.tween_property(alarm_rect, "modulate:a", 0.0, 0.9)
	if spotted_count == 1:
		StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("They saw you! Get back inside and wait for the lights to pass."))
	else:
		StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("Low and slow, Echo. Crouch behind the woodpile or the wall and let the beams go by."))

func _escape_home() -> void:
	escaped = true
	StoryCampaign.set_flag("home_attack_survived", true)
	StoryCampaign.set_flag("prologue_escape_unseen", spotted_count == 0)
	exposure_label.visible = false
	exposure_bar.visible = false
	if spotted_count == 0:
		StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("They never saw you. Keep moving, Echo."))
	else:
		StoryCampaign.dialogue_requested.emit(tr("MARA QUILL — RADIO"), tr("You're clear. Barely. Keep moving."))
	StoryCampaign.dialogue_requested.emit(tr("NARRATOR"), tr("Elias disappears into the tree line with Lena's data key. By sunrise, Asterion will call him the attacker."))
	objective.text = tr("PROLOGUE COMPLETE  //  KESTREL PASS UNLOCKED")
	prompt.text = tr("Moving to Kestrel Pass...")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if auto_transition:
		_finish_escape_transition()

func _finish_escape_transition() -> void:
	# Let every queued line finish so the final story beat is never cut off.
	while StoryDialogue.panel.visible or not StoryDialogue.queue.is_empty():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await fade.finished
	StoryCampaign.complete_prologue()
	get_tree().change_scene_to_file(KESTREL_SCENE)

func _update_objective() -> void:
	if attack_started:
		objective.text = tr("OBJECTIVE  //  Slip past the Accord team and reach the tree line") + "\n" + tr("Stay out of the flashlights. Crouch (C) behind cover.")
	else:
		objective.text = tr("OBJECTIVE  //  Look around. Talk to Lena. Find out what she discovered.") + "\n" + tr("Discoveries: %d / 3") % discoveries.size()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if escaped:
		return
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.global_transform.basis * Vector3(movement.x, 0, movement.y)).normalized()
	var speed := PLAYER_SPEED * (CROUCH_SPEED_SCALE if crouched else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor():
		player.velocity.y = 0
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
	if player.global_position.y < -4.0:
		player.global_position = RESET_POINT
		player.velocity = Vector3.ZERO
	if not attack_started:
		return
	if patrol_enabled:
		_update_patrols(delta)
	_update_detection(delta)
	if in_tree_line(player.global_position):
		_escape_home()
