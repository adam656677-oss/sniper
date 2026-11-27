extends SceneTree

# Sprint: the remappable action shared with hold breath, speed and the states
# that block it, louder footsteps, the eased field-of-view kick, the landing dip
# after a real fall, and reduced motion switching both camera effects off.

var failures := 0
var settings: Node
var state: Node
var rest_y := 0.9

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func joy_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event

# Shift is bound to both sprint and hold breath, so pressing it presses both actions.
func press_shift() -> void:
	Input.action_press("sprint")
	Input.action_press("hold_breath")

func release_shift() -> void:
	Input.action_release("sprint")
	Input.action_release("hold_breath")

func release_inputs() -> void:
	release_shift()
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func horizontal_speed(player: Node) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func reset_player(game: Node) -> void:
	release_inputs()
	var player = game.player
	if game.weapon.aiming:
		game.weapon.toggle_aim()
	if game.stealth.binoculars:
		game.stealth.set_binoculars(false)
	player.set_stance(player.Stance.STAND)
	player.carrying = null
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.global_position = Vector3(0, rest_y, 3)
	player.exertion = 0.0
	await frames(30)

# Lowest camera height relative to the head over the next frames (0 when it never dips).
func lowest_camera(game: Node, count: int) -> float:
	var lowest := 0.0
	for i in count:
		await physics_frame
		lowest = minf(lowest, game.camera.position.y)
	return lowest

func run_tests() -> void:
	settings = root.get_node("Settings")
	state = root.get_node("GameState")
	settings.reset()
	settings.clear_bindings()
	settings.apply()
	# Binding and remapping.
	check(InputMap.has_action("sprint"), "A sprint action exists")
	check(InputMap.event_is_action(key_event(KEY_SHIFT), "sprint") and InputMap.event_is_action(joy_button(JOY_BUTTON_LEFT_STICK), "sprint"), "Sprint is on Shift and the left stick click")
	check(InputMap.event_is_action(key_event(KEY_SHIFT), "hold_breath") and InputMap.event_is_action(joy_button(JOY_BUTTON_LEFT_STICK), "hold_breath"), "Hold breath shares Shift and the left stick click")
	check("sprint" in settings.REMAPPABLE, "Sprint is a remappable action")
	check(settings.remap("sprint", key_event(KEY_V)) and InputMap.event_is_action(key_event(KEY_V), "sprint") and not InputMap.event_is_action(key_event(KEY_SHIFT), "sprint"), "Sprint can move to another key")
	check(InputMap.event_is_action(key_event(KEY_SHIFT), "hold_breath"), "Moving sprint leaves hold breath on Shift")
	check(settings.save_settings(), "Settings with a sprint binding save")
	settings.reset()
	settings.clear_bindings()
	check(InputMap.event_is_action(key_event(KEY_SHIFT), "sprint"), "Clearing bindings puts sprint back on Shift")
	check(settings.load_settings() and settings.bindings.get("sprint", "") == "key:%d" % KEY_V, "The sprint binding loads from disk")
	settings.apply()
	check(InputMap.event_is_action(key_event(KEY_V), "sprint"), "The loaded sprint binding applies")
	settings.reset()
	settings.clear_bindings()
	settings.save_settings()
	var screen = load("res://scenes/ui/settings_screen.gd").new()
	root.add_child(screen)
	await process_frame
	check(screen.REMAP_LABELS.has("sprint") and screen.remap_buttons.has("sprint") and screen.remap_buttons["sprint"].text == "Shift", "The keys tab lists sprint on Shift")
	screen.start_listening("sprint")
	check(screen.capture_binding(key_event(KEY_V)) and screen.remap_buttons["sprint"].text == "V" and InputMap.event_is_action(key_event(KEY_V), "sprint"), "Sprint remaps by listening for a key")
	screen.queue_free()
	await process_frame
	settings.reset()
	settings.clear_bindings()
	settings.apply()
	settings.save_settings()
	# Speed, field of view, noise and sway on the range.
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	var player = game.player
	var fx = game.feedback
	var hip: float = game.hip_fov()
	rest_y = player.global_position.y
	check(player.is_on_floor() and not player.sprinting and is_equal_approx(game.camera.fov, hip), "The player starts on the ground at the hip field of view")
	Input.action_press("move_forward")
	await frames(8)
	check(not player.sprinting and absf(horizontal_speed(player) - 5.0) < 0.1, "Walking forward stays at walking speed")
	var walk_noise: float = game.stealth.noise_level()
	press_shift()
	await frames(5)
	var early_fov: float = game.camera.fov
	await frames(30)
	check(player.sprinting, "Holding Shift while walking forward sprints")
	check(is_equal_approx(player.move_speed(), 5.0 * player.SPRINT_MULTIPLIER) and horizontal_speed(player) > 5.0 * player.SPRINT_MULTIPLIER - 0.1, "Sprinting moves at %.1fx walking speed" % player.SPRINT_MULTIPLIER)
	check(early_fov > hip + 0.01 and early_fov < hip + fx.SPRINT_FOV_KICK * 0.5, "The sprint field of view eases in (%.2f after a few frames)" % (early_fov - hip))
	check(absf(game.camera.fov - (hip + fx.SPRINT_FOV_KICK)) < 0.05, "Sprinting widens the view by %.0f degrees" % fx.SPRINT_FOV_KICK)
	check(game.stealth.noise_level() > walk_noise and walk_noise == 1.0, "Sprinting is louder than walking upright")
	check(not game.sway.holding, "Shift at the hip never holds breath")
	var winded_sway: float = player.sway_multiplier()
	check(winded_sway > player.STANCE_SWAY[player.Stance.STAND] and winded_sway < player.STANCE_SWAY[player.Stance.STAND] * 1.5, "A sprint leaves the aim slightly unsteady")
	release_shift()
	await frames(4)
	check(not player.sprinting and game.camera.fov > hip and game.camera.fov < hip + fx.SPRINT_FOV_KICK, "Releasing Shift eases the view back")
	await frames(30)
	check(is_equal_approx(game.camera.fov, hip) and absf(horizontal_speed(player) - 5.0) < 0.1, "After a sprint the view and speed return to walking")
	check(player.sway_multiplier() < winded_sway, "The sprint sway penalty fades")
	# Direction: forward and forward diagonals only.
	Input.action_release("move_forward")
	press_shift()
	await frames(4)
	check(not player.sprinting, "Standing still with Shift held does not sprint")
	release_shift()
	await reset_player(game)
	press_shift()
	Input.action_press("move_back")
	await frames(4)
	check(not player.sprinting and absf(horizontal_speed(player) - 5.0) < 0.1, "Backing up cannot sprint")
	Input.action_release("move_back")
	Input.action_press("move_left")
	await frames(4)
	check(not player.sprinting, "Strafing cannot sprint")
	Input.action_press("move_forward")
	await frames(4)
	check(player.sprinting, "A forward diagonal sprints")
	# Aiming cancels the sprint and owns Shift while scoped.
	await reset_player(game)
	Input.action_press("move_forward")
	press_shift()
	await frames(30)
	check(player.sprinting, "Sprinting before raising the scope")
	var aim_fov: float = game.weapon.profile().aim_fov
	var scope_fov: float = game.scope_view.current_fov()
	game.weapon.toggle_aim()
	await frames(4)
	check(not player.sprinting and absf(horizontal_speed(player) - 5.0) < 0.1, "Aiming cancels the sprint")
	check(is_equal_approx(game.camera.fov, aim_fov), "The aiming field of view ignores the sprint kick")
	check(is_equal_approx(game.scope_view.current_fov(), scope_fov) and is_equal_approx(scope_fov, game.scope_view.fov_for_zoom(game.scope_view.zoom, hip)), "Scope magnification is unaffected by the sprint")
	check(not game.sway.holding, "A Shift still held from sprinting does not hold breath when scoping in")
	release_shift()
	await frames(2)
	press_shift()
	await frames(3)
	check(game.sway.holding and not player.sprinting, "Pressing Shift again while scoped holds breath and does not sprint")
	game.weapon.toggle_aim()
	await frames(4)
	check(not game.sway.holding and not player.sprinting, "Leaving the scope with Shift held neither holds breath nor sprints")
	release_shift()
	await frames(2)
	press_shift()
	await frames(4)
	check(player.sprinting and not game.sway.holding, "A fresh Shift press at the hip sprints again")
	# Stances, binoculars and carrying.
	player.toggle_stance(player.Stance.CROUCH)
	await frames(4)
	check(not player.sprinting and absf(horizontal_speed(player) - 2.5) < 0.1, "Crouching cancels the sprint")
	player.set_stance(player.Stance.PRONE)
	await frames(4)
	check(not player.sprinting and absf(horizontal_speed(player) - 1.0) < 0.1, "Prone cannot sprint")
	player.set_stance(player.Stance.STAND)
	await frames(4)
	check(player.sprinting, "Standing up with Shift held sprints again")
	game.stealth.set_binoculars(true)
	await frames(4)
	check(not player.sprinting and game.camera.fov == game.stealth.BINOCULAR_FOV, "Binoculars stop the sprint and keep their view")
	game.stealth.set_binoculars(false)
	await frames(4)
	check(not player.sprinting, "Lowering the binoculars with Shift held does not resume the sprint")
	release_shift()
	await frames(2)
	press_shift()
	await frames(4)
	check(player.sprinting, "A fresh press after the binoculars sprints")
	var body := Node3D.new()
	game.add_child(body)
	player.carrying = body
	await frames(4)
	check(not player.sprinting and horizontal_speed(player) <= player.CARRY_SPEED + 0.01, "Carrying a body cannot sprint")
	player.carrying = null
	body.queue_free()
	# Controller: clicking the left stick sprints until the player stops.
	await reset_player(game)
	Input.action_press("move_forward")
	await frames(4)
	game._unhandled_input(joy_button(JOY_BUTTON_LEFT_STICK))
	await frames(4)
	check(player.sprinting and not Input.is_action_pressed("sprint"), "Clicking the left stick sprints without holding it")
	Input.action_release("move_forward")
	await frames(4)
	check(not player.sprinting, "Stopping ends a clicked sprint")
	Input.action_press("move_forward")
	await frames(4)
	check(not player.sprinting, "Moving again walks until the next click")
	game._unhandled_input(joy_button(JOY_BUTTON_LEFT_STICK))
	await frames(4)
	game.weapon.toggle_aim()
	await frames(4)
	check(not player.sprinting, "Aiming ends a clicked sprint")
	game.weapon.toggle_aim()
	await frames(4)
	check(not player.sprinting, "A clicked sprint does not come back after aiming")
	# Landing dip: only after a real fall.
	await reset_player(game)
	Input.action_press("move_forward")
	press_shift()
	var flat_dip := 0.0
	for i in 60:
		await physics_frame
		flat_dip = minf(flat_dip, fx.dip_offset())
	check(player.sprinting and flat_dip == 0.0, "Walking and sprinting on flat ground never dip the camera")
	await reset_player(game)
	player.global_position.y = rest_y + 0.3
	var step_dip: float = await lowest_camera(game, 40)
	check(player.is_on_floor() and step_dip == 0.0, "Dropping off a 30 cm step does not dip")
	await reset_player(game)
	player.global_position.y = rest_y + 3.0
	var fall_dip: float = await lowest_camera(game, 70)
	check(player.is_on_floor() and player.last_landing_speed > fx.LANDING_DIP_MIN_SPEED, "A 3 m fall lands hard (%.1f m/s)" % player.last_landing_speed)
	check(fall_dip < -0.05 and fall_dip >= -fx.LANDING_DIP_MAX - 0.001, "Landing after a real fall dips the camera (%.3f m)" % fall_dip)
	await frames(30)
	check(fx.dip_offset() == 0.0 and absf(game.camera.position.y) < 0.001, "The camera recovers from the dip")
	await reset_player(game)
	game.weapon.toggle_aim()
	player.global_position.y = rest_y + 3.0
	var scoped_dip: float = await lowest_camera(game, 70)
	check(player.is_on_floor() and scoped_dip == 0.0, "No dip through the scope")
	# Reduced motion keeps the sprint but drops the FOV kick and the dip.
	settings.set_value("accessibility", "reduced_motion", true)
	await reset_player(game)
	Input.action_press("move_forward")
	press_shift()
	await frames(30)
	check(player.sprinting and is_equal_approx(game.camera.fov, hip), "Reduced motion sprints without the field-of-view kick")
	await reset_player(game)
	player.global_position.y = rest_y + 3.0
	var calm_dip: float = await lowest_camera(game, 70)
	check(player.is_on_floor() and calm_dip == 0.0 and player.last_landing_speed > fx.LANDING_DIP_MIN_SPEED, "Reduced motion skips the landing dip")
	settings.set_value("accessibility", "reduced_motion", false)
	release_inputs()
	game.queue_free()
	await process_frame
	# Noise: a sprint carries footsteps to a guard that walking would not reach.
	var compound = load("res://compound_mission.tscn").instantiate()
	root.add_child(compound)
	compound.set_physics_process(false)
	await frames(2)
	var level = compound.level
	level.time_of_day = 1
	level.weather = 0
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	var runner = compound.player
	runner.set_physics_process(false)
	var stealth = compound.stealth
	var listener = level.enemies[0]
	listener.change_state(listener.State.PATROL)
	listener.perception.awareness = 0.0
	listener.global_position = runner.global_position + Vector3(0, 0, -20)
	await frames(1)
	runner.sprinting = false
	runner.velocity = Vector3(5, 0, 0)
	stealth.footstep_timer = 0.0
	stealth.advance(0.6)
	check(listener.state == listener.State.PATROL, "Walking footsteps do not reach a guard 20 m away")
	runner.sprinting = true
	runner.velocity = Vector3(8, 0, 0)
	check(stealth.noise_level() > 1.0, "The noise meter reads above walking while sprinting")
	stealth.footstep_timer = 0.0
	stealth.advance(0.6)
	check(listener.state == listener.State.INVESTIGATE, "Sprinting footsteps send a guard 20 m away to investigate")
	compound.queue_free()
	await process_frame
	settings.reset()
	settings.clear_bindings()
	settings.save_settings()
	if failures == 0:
		print("SPRINT TESTS PASSED")
	quit(0 if failures == 0 else 1)
