extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var intel := false
var finished := false
var ammo := 5
var targets: Array[StaticBody3D] = []

func box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collision.shape = bounds
	body.add_child(collision)
	add_child(body)
	return body

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.45, 0.62, 0.74))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.4
	add_child(sun)
	box(Vector3(0, -0.5, -25), Vector3(80, 1, 100), Color(0.24, 0.32, 0.23))
	for p in [Vector3(-8, 2, -18), Vector3(7, 2, -35), Vector3(-10, 2, -48)]:
		box(p, Vector3(6, 4, 5), Color(0.4, 0.43, 0.4))
	for p in [Vector3(0, 1, -20), Vector3(12, 1, -42), Vector3(-3, 1, -55)]:
		targets.append(box(p, Vector3(0.8, 2, 0.6), Color(0.7, 0.25, 0.18)))
	box(Vector3(0, 0.5, -60), Vector3(1, 1, 1), Color(0.95, 0.75, 0.12))
	box(Vector3(0, 0.05, 3), Vector3(3, 0.1, 3), Color(0.1, 0.8, 0.4))
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1, 3)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.current = true
	player.add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 20)
	layer.add_child(hud)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(crosshair)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_R:
			ammo = 5
		if event.keycode == KEY_N:
			get_tree().reload_current_scene()
		if event.keycode == KEY_E and not finished:
			if player.position.distance_to(Vector3(0, 1, -60)) < 3:
				intel = true
			if intel and player.position.distance_to(Vector3(0, 1, 3)) < 3:
				finished = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not finished:
		player.rotate_y(-event.relative.x * 0.002)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.4, 1.4)
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			camera.fov = 25.0 if camera.fov > 30 else 75.0
		if event.button_index == MOUSE_BUTTON_LEFT and ammo > 0 and not finished:
			ammo -= 1
			var start := camera.global_position
			var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * 300)
			query.exclude = [player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit and hit.collider in targets:
				targets.erase(hit.collider)
				hit.collider.queue_free()

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not finished:
		direction = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = player.basis * direction.normalized()
	player.velocity.x = direction.x * 5
	player.velocity.z = direction.z * 5
	if not player.is_on_floor():
		player.velocity.y -= 20 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()
	var objective := "Return to green extraction marker; press E" if intel else "Reach gold terminal ahead; press E"
	if finished:
		objective = "MISSION COMPLETE — N to restart"
	hud.text = "ECHO RIDGE | Native 3D foundation\n%s\nAmmo: %d | Targets: %d\nWASD move | Mouse aim | Left click fire | Right click zoom\nR refill | E interact | Escape release mouse | N restart" % [objective, ammo, targets.size()]
