class_name AlertCoordinator
extends Node

# Squad-level awareness. Shares contacts between nearby enemies, relays noise,
# tracks bodies, and escalates the mission alert level up to lockdown.

enum Level { CALM, SUSPICIOUS, ALERT, LOCKDOWN }

signal level_changed(level: int)
signal reinforcements_requested(position: Vector3)

const SHARE_RADIUS := 150.0
const LOCKDOWN_ALERT_SECONDS := 20.0
const LOCKDOWN_DEATHS := 2
const CALM_AFTER_SECONDS := 30.0

var level: int = Level.CALM
var enemies: Array = []
var bodies: Dictionary = {} # body name -> world position
var alert_time := 0.0
var quiet_time := 0.0
var deaths_while_alert := 0
var lockdown_triggered := false
var last_contact := Vector3.ZERO

func register(enemy: Node) -> void:
	if enemy not in enemies:
		enemies.append(enemy)

func unregister(enemy: Node) -> void:
	enemies.erase(enemy)

func level_name() -> String:
	return Level.keys()[level]

func escalate(new_level: int) -> void:
	if new_level <= level:
		return
	level = new_level
	level_changed.emit(level)
	if level == Level.LOCKDOWN and not lockdown_triggered:
		lockdown_triggered = true
		reinforcements_requested.emit(last_contact)

func report_contact(reporter: Node, position: Vector3) -> void:
	last_contact = position
	escalate(Level.ALERT)
	for enemy in enemies:
		if enemy == reporter or not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(reporter.global_position) <= SHARE_RADIUS:
			enemy.receive_contact(position)

# loudness caps how alarming the sound is: 1.0 gunfire, 0.5 distant or thrown,
# 0.3 footsteps. Within a quarter of the radius a loud sound is unmistakable.
func report_noise(position: Vector3, radius: float, source: Node = null, loudness: float = 1.0) -> void:
	for enemy in enemies:
		if enemy == source or not enemy.is_alive():
			continue
		var distance: float = enemy.global_position.distance_to(position)
		if distance <= radius:
			var heard := 1.0 if distance <= radius * 0.25 else 0.5
			enemy.on_noise(position, minf(heard, loudness))

func report_body(body_name: String, position: Vector3) -> void:
	bodies[body_name] = position

func move_body(body_name: String, position: Vector3) -> void:
	if bodies.has(body_name):
		bodies[body_name] = position

func report_death(_enemy: Node) -> void:
	if level >= Level.ALERT:
		deaths_while_alert += 1

func highest_enemy_state() -> int:
	var highest := -1
	for enemy in enemies:
		if enemy.is_alive():
			highest = maxi(highest, enemy.threat_level())
	return highest

# threat_level: 0 patrol, 1 suspicious or investigating, 2 alert, search or flee.
func advance(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	var threat := highest_enemy_state()
	if threat >= 2:
		escalate(Level.ALERT)
	elif threat == 1:
		escalate(Level.SUSPICIOUS)
	if level >= Level.ALERT:
		alert_time += dt
		if alert_time >= LOCKDOWN_ALERT_SECONDS or deaths_while_alert >= LOCKDOWN_DEATHS:
			escalate(Level.LOCKDOWN)
	if threat <= 0:
		quiet_time += dt
		if quiet_time >= CALM_AFTER_SECONDS and level != Level.CALM:
			level = Level.CALM
			alert_time = 0.0
			deaths_while_alert = 0
			lockdown_triggered = false
			level_changed.emit(level)
	else:
		quiet_time = 0.0
