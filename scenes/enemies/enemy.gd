class_name Enemy
extends CharacterBody3D

# Hostile with perception, a behaviour state machine, navigation and return fire.
# Fictional tuning. tick() is the whole brain so tests can drive it with any delta.

const HitZones = preload("res://scenes/targets/hit_zones.gd")

enum State { PATROL, SUSPICIOUS, INVESTIGATE, ALERT, SEARCH, FLEE, DEAD }

signal died(enemy: Enemy)
signal state_changed(enemy: Enemy, state: int)
signal fired_at_player(enemy: Enemy, hit: bool)

const MAX_HEALTH := 100.0
const GRAVITY := 20.0
const PATROL_SPEED := 1.8
const INVESTIGATE_SPEED := 2.6
const ALERT_SPEED := 4.0
const SUSPICIOUS_THRESHOLD := 0.3
const INVESTIGATE_DELAY := 2.0
const INVESTIGATE_LINGER := 4.0
const LOSE_SIGHT_SECONDS := 8.0
const SEARCH_SECONDS := 15.0
const SEARCH_RADIUS := 12.0
const FLEE_DISTANCE := 60.0
const FLEE_SECONDS := 25.0
const FLEE_HEALTH_FRACTION := 0.25
const FIRE_INTERVAL := 1.2
const DAMAGE_PER_HIT := 20.0
const SHOT_NOISE_RADIUS := 300.0
const ARRIVE_DISTANCE := 1.5
const SUPPRESSION_PER_MISS := 0.35
const FLANK_DISTANCE := 15.0

@export var patrol_points: PackedVector3Array = PackedVector3Array()

var health := MAX_HEALTH
var state: int = State.PATROL
var state_time := 0.0
var since_seen := 0.0
var fire_timer := 0.0
var patrol_index := 0
var last_known := Vector3.ZERO
var has_last_known := false
var search_point := Vector3.ZERO
var has_search_point := false
var arrived_time := -1.0
var seen_bodies: Dictionary = {} # body name -> position where this guard saw it
var flank_point := Vector3.ZERO
var has_flank_point := false
var carried := false
var rng := RandomNumberGenerator.new()
var level: Node = null
var coordinator: AlertCoordinator = null
@onready var perception: Perception = $Perception
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	health = MAX_HEALTH
	rng.seed = hash(name)

func player() -> Node:
	if level and level.get("player"):
		return level.player
	return null

func is_alive() -> bool:
	return state != State.DEAD

func awareness() -> float:
	return perception.awareness

func state_name() -> String:
	return State.keys()[state]

# 0 patrol, 1 suspicious or investigating, 2 alert, search or flee.
func threat_level() -> int:
	match state:
		State.PATROL, State.DEAD:
			return 0
		State.SUSPICIOUS, State.INVESTIGATE:
			return 1
	return 2

func change_state(new_state: int) -> void:
	if state == new_state or state == State.DEAD:
		return
	state = new_state
	state_time = 0.0
	arrived_time = -1.0
	has_search_point = false
	has_flank_point = false
	state_changed.emit(self, state)

func take_hit(shape_index: int, damage: float) -> float:
	if not is_alive():
		return 0.0
	var dealt: float = maxf(damage, 0.0) * HitZones.multiplier(HitZones.zone_for_shape(self, shape_index))
	health = maxf(0.0, health - dealt)
	if health == 0.0:
		die()
	elif state != State.ALERT and state != State.FLEE:
		var target := player()
		if target:
			last_known = target.global_position
			has_last_known = true
		become_alert()
	return dealt

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	state_changed.emit(self, state)
	if coordinator:
		coordinator.report_body(String(name), global_position)
	died.emit(self)

func become_alert() -> void:
	var was_alert := state == State.ALERT
	change_state(State.ALERT)
	if coordinator and not was_alert and has_last_known:
		coordinator.report_contact(self, last_known)

# Squad shared a contact position.
func receive_contact(position: Vector3) -> void:
	if not is_alive():
		return
	last_known = position
	has_last_known = true
	perception.awareness = maxf(perception.awareness, 0.6)
	if state == State.PATROL or state == State.SUSPICIOUS:
		change_state(State.INVESTIGATE)

# loudness 1.0 is close and unmistakable; 0.5 is distant or thrown; below 0.5
# is a faint sound such as footsteps that only makes a patrol suspicious.
func on_noise(position: Vector3, loudness: float) -> void:
	if not is_alive():
		return
	last_known = position
	has_last_known = true
	if loudness >= 1.0:
		perception.awareness = 1.0
		become_alert()
	elif loudness >= 0.5:
		if state == State.PATROL or state == State.SUSPICIOUS:
			perception.awareness = maxf(perception.awareness, 0.5)
			change_state(State.INVESTIGATE)
	elif state == State.PATROL:
		perception.awareness = maxf(perception.awareness, SUSPICIOUS_THRESHOLD)
		change_state(State.SUSPICIOUS)

func on_body_seen(position: Vector3) -> void:
	last_known = position
	has_last_known = true
	perception.awareness = maxf(perception.awareness, 0.6)
	if coordinator:
		coordinator.escalate(AlertCoordinator.Level.ALERT)
	if state == State.PATROL or state == State.SUSPICIOUS or state == State.INVESTIGATE:
		change_state(State.SEARCH)

static func hit_probability(distance: float, target_still_seconds: float, accuracy_multiplier: float = 1.0) -> float:
	var base := 0.3
	var range_factor := clampf(1.0 - distance / 250.0, 0.05, 1.0)
	var stillness := 1.0 + minf(maxf(target_still_seconds, 0.0), 4.0) * 0.15
	return clampf(base * range_factor * stillness * accuracy_multiplier, 0.02, 0.9)

func shoot_at_player() -> void:
	var target := player()
	if target == null or fire_timer > 0.0:
		return
	fire_timer = FIRE_INTERVAL
	var distance := global_position.distance_to(target.global_position)
	var still: float = target.still_seconds if target.get("still_seconds") != null else 0.0
	var probability := hit_probability(distance, still, GameState.accuracy_multiplier())
	var hit := rng.randf() < probability
	if hit and target.has_method("take_damage"):
		target.take_damage(DAMAGE_PER_HIT)
	if target.has_method("suppress"):
		target.suppress(SUPPRESSION_PER_MISS if not hit else SUPPRESSION_PER_MISS * 0.5)
	fired_at_player.emit(self, hit)
	if coordinator:
		coordinator.report_noise(global_position, SHOT_NOISE_RADIUS, self)

# A point beside the last known position, off to one side of the line from this
# guard, so guards converging on a contact approach from different angles.
func choose_flank_point() -> Vector3:
	var approach := last_known - global_position
	approach.y = 0.0
	if approach.length() < 0.1:
		return last_known
	var side := approach.normalized().cross(Vector3.UP)
	var sign := 1.0 if (hash(name) & 1) == 0 else -1.0
	return last_known + side * FLANK_DISTANCE * sign

func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.01:
		look_at(flat, Vector3.UP)

func horizontal_distance(point: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(point.x, point.z))

func arrived_at(point: Vector3) -> bool:
	return horizontal_distance(point) <= ARRIVE_DISTANCE

func move_toward_point(point: Vector3, speed: float, delta: float) -> void:
	if arrived_at(point):
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		agent.target_position = point
		var next := agent.get_next_path_position()
		var direction := next - global_position
		direction.y = 0.0
		if direction.length() < 0.05:
			direction = point - global_position
			direction.y = 0.0
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		face(global_position + direction)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

func stand_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

func patrol(delta: float) -> void:
	if patrol_points.is_empty():
		stand_still(delta)
		return
	var goal := patrol_points[patrol_index]
	move_toward_point(goal, PATROL_SPEED, delta)
	if arrived_at(goal):
		patrol_index = (patrol_index + 1) % patrol_points.size()

func pick_search_point() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(3.0, SEARCH_RADIUS)
	search_point = last_known + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	has_search_point = true

func flee_point() -> Vector3:
	var target := player()
	var away := Vector3.FORWARD
	if target:
		away = global_position - target.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	return global_position + away * FLEE_DISTANCE

func check_bodies() -> void:
	if coordinator == null:
		return
	for body_name in coordinator.bodies:
		var body_position: Vector3 = coordinator.bodies[body_name]
		if seen_bodies.has(body_name) and seen_bodies[body_name].distance_to(body_position) < 2.0:
			continue
		if perception.visibility_of(body_position + Vector3(0, 0.3, 0), 1.0, Perception.BODY_VIEW_DISTANCE) > 0.0:
			seen_bodies[body_name] = body_position
			on_body_seen(body_position)

func tick(delta: float) -> void:
	if not is_alive() or not GameState.simulation_active():
		return
	var dt := maxf(delta, 0.0)
	state_time += dt
	fire_timer = maxf(0.0, fire_timer - dt)
	var target := player()
	var visibility := perception.visibility_of_player(target)
	perception.accumulate(visibility, dt)
	if visibility > 0.0 and target:
		last_known = target.global_position
		has_last_known = true
		since_seen = 0.0
	else:
		since_seen += dt
	check_bodies()
	match state:
		State.PATROL:
			patrol(dt)
			if perception.awareness >= SUSPICIOUS_THRESHOLD:
				change_state(State.SUSPICIOUS)
		State.SUSPICIOUS:
			stand_still(dt)
			if has_last_known:
				face(last_known)
			if perception.awareness >= 1.0:
				become_alert()
			elif perception.awareness <= 0.0:
				change_state(State.PATROL)
			elif state_time >= INVESTIGATE_DELAY:
				change_state(State.INVESTIGATE)
		State.INVESTIGATE:
			if perception.awareness >= 1.0:
				become_alert()
				return
			move_toward_point(last_known, INVESTIGATE_SPEED, dt)
			if arrived_at(last_known):
				if arrived_time < 0.0:
					arrived_time = state_time
				elif state_time - arrived_time >= INVESTIGATE_LINGER:
					perception.awareness = 0.0
					change_state(State.PATROL)
		State.ALERT:
			if health <= MAX_HEALTH * FLEE_HEALTH_FRACTION and coordinator and coordinator.level >= AlertCoordinator.Level.ALERT:
				change_state(State.FLEE)
				return
			if visibility > 0.0 and target:
				has_flank_point = false
				stand_still(dt)
				face(target.global_position)
				shoot_at_player()
			else:
				if not has_flank_point:
					flank_point = choose_flank_point()
					has_flank_point = true
				var goal := flank_point if not arrived_at(flank_point) else last_known
				move_toward_point(goal, ALERT_SPEED, dt)
				if since_seen >= LOSE_SIGHT_SECONDS:
					change_state(State.SEARCH)
		State.SEARCH:
			if visibility > 0.0:
				become_alert()
				return
			if not has_search_point or arrived_at(search_point):
				pick_search_point()
			move_toward_point(search_point, INVESTIGATE_SPEED, dt)
			if state_time >= SEARCH_SECONDS:
				perception.awareness = 0.0
				change_state(State.PATROL)
		State.FLEE:
			move_toward_point(flee_point(), ALERT_SPEED, dt)
			if state_time >= FLEE_SECONDS:
				change_state(State.SEARCH)

func capture() -> Dictionary:
	return {
		"name": name, "position": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y,
		"state": state, "health": health, "awareness": perception.awareness, "patrol_index": patrol_index,
		"last_known": [last_known.x, last_known.y, last_known.z], "has_last_known": has_last_known
	}

func restore(data: Dictionary) -> void:
	var p = data.get("position", [0, 0, 0])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(data.get("yaw", 0.0))
	velocity = Vector3.ZERO
	health = float(data.get("health", MAX_HEALTH))
	perception.awareness = float(data.get("awareness", 0.0))
	patrol_index = int(data.get("patrol_index", 0)) % maxi(patrol_points.size(), 1)
	var lk = data.get("last_known", [0, 0, 0])
	last_known = Vector3(float(lk[0]), float(lk[1]), float(lk[2]))
	has_last_known = bool(data.get("has_last_known", false))
	var saved_state := int(data.get("state", State.PATROL))
	if saved_state == State.DEAD:
		die()
	else:
		state = saved_state
		state_time = 0.0

func _physics_process(delta: float) -> void:
	tick(delta)
