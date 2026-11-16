extends SceneTree

var failures := 0
var state: Node
var transitions: Array = []

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func on_state_changed(enemy: Node, new_state: int) -> void:
	transitions.append([enemy.name, new_state])

func _initialize() -> void:
	call_deferred("run_tests")

func place(enemy: Node, position: Vector3, facing: Vector3) -> void:
	enemy.global_position = position
	enemy.look_at(Vector3(facing.x, position.y, facing.z), Vector3.UP)

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var level = game.level
	level.time_of_day = 1
	level.weather = 0
	var player = game.player
	var coordinator = level.coordinator
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		enemy.state_changed.connect(on_state_changed)
	check(level.enemies.size() == 4 and level.player == player, "Four hostiles spawn and know the player")
	var all_patrol := true
	for enemy in level.enemies:
		all_patrol = all_patrol and enemy.state == enemy.State.PATROL
	check(all_patrol and coordinator.level == coordinator.Level.CALM, "Hostiles start on patrol with the squad calm")
	var guard = level.enemies[0]
	var perception = guard.perception
	# Perception geometry.
	player.global_position = Vector3(0, 1, -20)
	place(guard, Vector3(0, 1, 0), Vector3(0, 1, -20))
	await physics_frame
	var facing_visibility: float = perception.visibility_of_player(player)
	check(facing_visibility > 0.5, "Standing player 20 m ahead is clearly visible")
	place(guard, Vector3(0, 1, 0), Vector3(0, 1, 20))
	await physics_frame
	check(perception.visibility_of_player(player) == 0.0, "Player behind the guard is invisible")
	place(guard, Vector3(0, 1, 0), Vector3(0, 1, -20))
	player.global_position = Vector3(0, 1, -80)
	await physics_frame
	var far_visibility: float = perception.visibility_of_player(player)
	check(far_visibility > 0.0 and far_visibility < facing_visibility * 0.5, "Distance reduces visibility")
	player.global_position = Vector3(0, 1, -200)
	await physics_frame
	check(perception.visibility_of_player(player) == 0.0, "Beyond view distance is invisible")
	player.global_position = Vector3(0, 1, -20)
	player.set_stance(player.Stance.PRONE)
	await physics_frame
	check(perception.visibility_of_player(player) < facing_visibility * 0.5, "Prone player is much harder to see")
	player.set_stance(player.Stance.STAND)
	var wall: StaticBody3D = level.spawn_box(Vector3(0, 2, -10), Vector3(6, 4, 1), Color.GRAY)
	await physics_frame
	await physics_frame
	check(perception.visibility_of_player(player) == 0.0, "A wall blocks line of sight")
	wall.queue_free()
	await physics_frame
	await physics_frame
	# Awareness and state machine.
	guard.tick(0.2)
	check(guard.awareness() > 0.0 and guard.awareness() < 0.3 and guard.state == guard.State.PATROL, "A glimpse raises awareness without alarm")
	guard.tick(0.5)
	check(guard.state == guard.State.SUSPICIOUS, "Awareness past the threshold makes the guard suspicious")
	for i in range(6):
		guard.tick(0.5)
	check(guard.state == guard.State.ALERT and coordinator.level >= coordinator.Level.ALERT, "Sustained sight makes the guard alert and escalates the squad")
	check(guard.last_known == player.global_position, "Alert guard knows the player's position")
	var others_moving := 0
	for enemy in level.enemies:
		if enemy != guard and enemy.state == enemy.State.INVESTIGATE:
			others_moving += 1
	check(others_moving >= 1, "Nearby squad members converge on the shared contact")
	# Difficulty scaling.
	state.difficulty = state.Difficulty.HARD
	var hard_perception = level.enemies[1].perception
	hard_perception.awareness = 0.0
	hard_perception.accumulate(0.5, 1.0)
	var hard_gain: float = hard_perception.awareness
	state.difficulty = state.Difficulty.EASY
	hard_perception.awareness = 0.0
	hard_perception.accumulate(0.5, 1.0)
	check(hard_gain > hard_perception.awareness and hard_gain == 0.75, "Difficulty scales perception gain")
	state.difficulty = state.Difficulty.NORMAL
	check(guard.hit_probability(50.0, 0.0, 1.5) > guard.hit_probability(50.0, 0.0, 1.0), "Difficulty scales enemy accuracy")
	check(guard.hit_probability(20.0, 4.0) > guard.hit_probability(20.0, 0.0) and guard.hit_probability(200.0, 0.0) < guard.hit_probability(20.0, 0.0), "Accuracy rises with target stillness and falls with distance")
	# Return fire and player health.
	var health_before: float = player.health
	var shots := 0
	for i in range(12):
		guard.fire_timer = 0.0
		guard.tick(0.1)
		shots += 1
	check(player.health < health_before and player.health > 0.0, "Alert guard's return fire wounds the player")
	player.advance_health(6.0)
	check(player.health > health_before - 100.0 and player.since_damage >= 5.0, "Health regenerates after a quiet spell")
	# Losing sight, search, back to patrol.
	player.global_position = Vector3(0, 1, 40)
	await physics_frame
	guard.tick(9.0)
	check(guard.state == guard.State.SEARCH, "Losing the player for long enough starts a search")
	guard.tick(16.0)
	check(guard.state == guard.State.PATROL and guard.awareness() == 0.0, "A fruitless search returns the guard to patrol")
	# Hearing.
	var listener = level.enemies[2]
	listener.change_state(listener.State.PATROL)
	listener.perception.awareness = 0.0
	level.report_noise(listener.global_position + Vector3(0, 0, 300), 400.0)
	check(listener.state == listener.State.INVESTIGATE and listener.last_known.z == listener.global_position.z + 300, "A distant rifle shot sends a guard to investigate the sound")
	listener.change_state(listener.State.PATROL)
	level.report_noise(listener.global_position + Vector3(0, 0, 60), 25.0)
	check(listener.state == listener.State.PATROL, "A suppressed shot 60 m away is not heard")
	level.report_noise(listener.global_position + Vector3(0, 0, 20), 400.0)
	check(listener.state == listener.State.ALERT, "A close loud shot alarms the guard outright")
	# Being shot alerts a patrolling guard.
	var sentry = level.enemies[3]
	sentry.change_state(sentry.State.PATROL)
	sentry.take_hit(-1, 30.0)
	check(sentry.state == sentry.State.ALERT and sentry.health == 70.0, "Taking a hit alerts the guard")
	# Flee when badly hurt while the squad is alert.
	sentry.take_hit(-1, 50.0)
	player.global_position = Vector3(0, 1, 40)
	sentry.tick(0.1)
	check(sentry.state == sentry.State.FLEE, "A badly wounded guard flees")
	# Bodies and lockdown.
	var dead_count_before: int = level.enemies.size()
	place(listener, Vector3(10, 1, -40), Vector3(10, 1, -60))
	place(sentry, Vector3(10, 1, -55), Vector3(10, 1, -70))
	await physics_frame
	listener.change_state(listener.State.PATROL)
	listener.perception.awareness = 0.0
	sentry.take_hit(-1, 500.0)
	check(not sentry.is_alive() and level.enemies.size() == dead_count_before - 1 and coordinator.bodies.size() == 1, "A lethal hit kills the guard and leaves a body")
	await physics_frame
	listener.tick(0.1)
	check(listener.state == listener.State.SEARCH and coordinator.level >= coordinator.Level.ALERT, "Discovering a body starts a search and escalates the squad")
	var enemies_before: int = level.enemies.size()
	coordinator.escalate(coordinator.Level.ALERT)
	guard.take_hit(-1, 500.0)
	coordinator.advance(0.1)
	check(coordinator.level == coordinator.Level.LOCKDOWN and level.enemies.size() == enemies_before - 1 + 2, "Two deaths while alert trigger lockdown and reinforcements")
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	# Navigation: an investigating guard closes on its target.
	var mover = level.enemies[0]
	mover.change_state(mover.State.INVESTIGATE)
	mover.last_known = mover.global_position + Vector3(0, 0, -12)
	mover.has_last_known = true
	mover.perception.awareness = 0.5
	player.global_position = Vector3(0, 1, 40)
	var start_distance: float = mover.horizontal_distance(mover.last_known)
	for i in range(90):
		await physics_frame
		mover.tick(1.0 / 60.0)
	check(mover.horizontal_distance(mover.last_known) < start_distance - 2.0, "Guard navigates toward the investigation point")
	# Player death fails the mission.
	player.take_damage(1000.0)
	check(state.failed and state.finished, "Lethal damage fails the mission")
	game.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(game.hud.text.contains("MISSION FAILED"), "HUD reports mission failure")
	check(transitions.size() > 10, "State transitions are observable")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("ENEMY TESTS PASSED")
	quit(0 if failures == 0 else 1)
