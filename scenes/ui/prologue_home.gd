extends Node3D

# First playable story sequence. Primitive blockout art is intentional until
# the production environment and character assets are ready.
const PLAYER_SPEED := 4.2
const LOOK_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.8
const KESTREL_SCENE := "res://kestrel_mission.tscn"

var player: CharacterBody3D
var camera: Camera3D
var prompt: Label
var objective: Label
var key_light: DirectionalLight3D
var front_door: Node3D
var interactables: Dictionary = {}
var discoveries: Array[String] = []
var attack_started := false
var escaped := false
var pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_build_house()
	_build_player()
	_build_hud()
	_add_interactable("photo", "Look at the photograph", Vector3(2.0, 1.1, -3.7), Color(0.65, 0.43, 0.23))
	_add_interactable("lena", "Talk to Lena", Vector3(-2.2, 1.0, -1.4), Color(0.72, 0.42, 0.34))
	_add_interactable("ledger", "Take Lena's data key", Vector3(-1.1, 1.0, -1.4), Color(0.18, 0.65, 0.72))
	_add_interactable("exit", "Escape through the front door", Vector3(0.0, 1.0, 7.0), Color(0.5, 0.5, 0.5))
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
	env.ambient_light_color = Color(0.42, 0.36, 0.29)
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -25, 0)
	key_light.light_energy = 0.8
	key_light.shadow_enabled = true
	add_child(key_light)

func _build_house() -> void:
	_box("Floor", Vector3(0, -0.15, 0), Vector3(14, 0.3, 18), Color(0.19, 0.17, 0.14), true)
	_box("Back wall", Vector3(0, 1.8, -8.8), Vector3(14, 3.6, 0.3), Color(0.27, 0.24, 0.2), true)
	_box("Left wall", Vector3(-7, 1.8, 0), Vector3(0.3, 3.6, 18), Color(0.23, 0.21, 0.18), true)
	_box("Right wall", Vector3(7, 1.8, 0), Vector3(0.3, 3.6, 18), Color(0.23, 0.21, 0.18), true)
	_box("Front left wall", Vector3(-5.3, 1.8, 8.8), Vector3(3.4, 3.6, 0.3), Color(0.23, 0.21, 0.18), true)
	_box("Front right wall", Vector3(5.3, 1.8, 8.8), Vector3(3.4, 3.6, 0.3), Color(0.23, 0.21, 0.18), true)
	_box("Ceiling", Vector3(0, 3.65, 0), Vector3(14, 0.3, 18), Color(0.12, 0.12, 0.11), true)
	_box("Sofa", Vector3(2, 0.55, -1.5), Vector3(3.4, 1.1, 1), Color(0.17, 0.19, 0.18), false)
	_box("Coffee table", Vector3(2, 0.38, -3), Vector3(2.2, 0.12, 1), Color(0.31, 0.2, 0.12), false)
	_box("Kitchen island", Vector3(-3.6, 0.55, -1.8), Vector3(2.2, 1.1, 1.2), Color(0.3, 0.25, 0.19), false)
	_box("Window", Vector3(0, 2, -8.62), Vector3(3, 1.6, 0.08), Color(0.08, 0.13, 0.18), false)
	_box("Photo frame", Vector3(2, 1.65, -3.65), Vector3(0.9, 0.7, 0.08), Color(0.65, 0.43, 0.23), false)
	_capsule("Lena silhouette", Vector3(-2.2, 0.9, -1.4), Color(0.48, 0.3, 0.25))
	_box("Data key", Vector3(-1.1, 1, -1.4), Vector3(0.22, 0.08, 0.38), Color(0.18, 0.65, 0.72), false)
	front_door = _box("Front door", Vector3(0, 1.5, 8.68), Vector3(2.8, 3, 0.16), Color(0.18, 0.13, 0.1), false)

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
	var head := Node3D.new()
	head.position.y = 0.62
	player.add_child(head)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 76
	head.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.025
	panel.anchor_right = 0.52
	panel.anchor_bottom = 0.17
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
	controls.text = tr("WASD Move  •  Mouse Look  •  E Interact  •  Esc Release Mouse")
	controls.anchor_left = 0.02
	controls.anchor_right = 0.72
	controls.anchor_top = 0.94
	controls.anchor_bottom = 0.99
	controls.add_theme_font_size_override("font_size", 11)
	layer.add_child(controls)

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
		if id == "exit" and not attack_started:
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
	var target := _nearest_interactable()
	prompt.text = tr("[E] %s") % String(interactables[target].label) if not target.is_empty() else ""
	if Input.is_action_just_pressed("interact") and not target.is_empty():
		interact_with(target)

func interact_with(id: String) -> bool:
	if escaped or not interactables.has(id):
		return false
	if id == "exit":
		if not attack_started:
			return false
		_escape_home()
		return true
	if discoveries.has(id):
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
	if discoveries.size() == 3:
		_begin_attack()
	else:
		_update_objective()
	return true

func _begin_attack() -> void:
	if attack_started:
		return
	attack_started = true
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
	var door_tween := create_tween()
	door_tween.tween_property(front_door, "rotation:y", deg_to_rad(-72), 0.8).set_delay(0.5)
	StoryCampaign.dialogue_requested.emit(tr("NARRATOR"), tr("The front door buckles inward. The house is no longer safe."))
	_update_objective()

func _escape_home() -> void:
	escaped = true
	StoryCampaign.set_flag("home_attack_survived", true)
	StoryCampaign.dialogue_requested.emit(tr("NARRATOR"), tr("Elias disappears into the tree line with Lena's data key. By sunrise, Asterion will call him the attacker."))
	objective.text = tr("PROLOGUE COMPLETE  //  KESTREL PASS UNLOCKED")
	prompt.text = tr("Moving to Kestrel Pass...")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StoryCampaign.complete_prologue()
	get_tree().create_timer(1.6).timeout.connect(func(): get_tree().change_scene_to_file(KESTREL_SCENE))

func _update_objective() -> void:
	if attack_started:
		objective.text = tr("OBJECTIVE  //  Escape through the front door")
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
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	if player.is_on_floor():
		player.velocity.y = 0
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
