extends "res://scenes/levels/shooting_range.gd"

# A long-shot challenge on the 1000 m range. The challenge (ChallengeCatalog)
# chooses which plates stand, the time of day, weather and wind, the rifle's
# round budget and an optional clock. It passes when every plate has rung (in
# order, nearest first, when the challenge says so) and fails when the rounds
# or the clock run out first. The result goes to the challenge leaderboard in
# Progression, not to the mission records, and saves are refused so a budget
# cannot be reloaded. The plain range mission and its tutorial do not use this.

const ChallengeCatalog = preload("res://scenes/challenges/challenge_catalog.gd")

enum Outcome { RUNNING, PASSED, OUT_OF_ROUNDS, OUT_OF_TIME }

@export var challenge_id := "warmup"

var challenge: Dictionary = {}
var outcome: int = Outcome.RUNNING
var elapsed := 0.0 # challenge clock: unpaused seconds since the start
var finish_time := 0.0 # clock when the challenge passed or failed
var rung_metres := 0.0
var begun := false

func _ready() -> void:
	challenge = ChallengeCatalog.find(challenge_id)
	if challenge.is_empty():
		challenge = ChallengeCatalog.get_challenge(0)
		challenge_id = String(challenge.id)
	time_of_day = int(challenge.time_of_day)
	weather = int(challenge.weather)
	wind = challenge.wind
	keep_challenge_plates()
	super._ready()
	# The mission root binds itself after every level _ready; arm the rifle then.
	begin_challenge.call_deferred()

# Remove the plates, and their distance markers, that this challenge does not use.
func keep_challenge_plates() -> void:
	var holder: Node = $Plates
	for child in holder.get_children():
		if child is SteelPlate and not challenge.plates.has(child.range_metres):
			var marker := holder.get_node_or_null("Marker%d" % int(child.range_metres))
			for node in [child, marker]:
				if node:
					holder.remove_child(node)
					node.queue_free()

func setup_objectives() -> void:
	var goal := maxi(plates.size(), 1)
	if is_ordered():
		mission_log.add("plates", "Ring the plates in order, nearest first", MissionLog.Kind.PRIMARY, goal)
	else:
		mission_log.add("plates", "Ring every challenge plate", MissionLog.Kind.PRIMARY, goal)

# Load the round budget into the rifle and empty the sidearms.
func begin_challenge() -> void:
	if begun or mission == null:
		return
	begun = true
	var weapon: WeaponRig = mission.weapon
	var rounds := int(challenge.rounds)
	for index in range(weapon.stored.size()):
		weapon.stored[index] = {"ammo": 0, "reserve": 0, "cooldown": 0.0}
	var loaded := mini(rounds, weapon.profiles[0].capacity)
	weapon.stored[0] = {"ammo": loaded, "reserve": rounds - loaded, "cooldown": 0.0}
	weapon.ammo = int(weapon.stored[weapon.active].ammo)
	weapon.reserve_ammo = int(weapon.stored[weapon.active].reserve)
	mission.update_hud()

func is_ordered() -> bool:
	return bool(challenge.get("ordered", false))

func time_limit() -> float:
	return float(challenge.get("time_limit", 0.0))

func time_left() -> float:
	return maxf(time_limit() - elapsed, 0.0)

# Rounds left across the whole rig; only the rifle carries any.
func rounds_left() -> int:
	if mission == null or not begun:
		return int(challenge.rounds)
	var weapon: WeaponRig = mission.weapon
	var total := 0
	for index in range(weapon.stored.size()):
		if index == weapon.active:
			total += weapon.ammo + weapon.reserve_ammo
		else:
			total += int(weapon.stored[index].ammo) + int(weapon.stored[index].reserve)
	return total

func rounds_used() -> int:
	return maxi(int(challenge.rounds) - rounds_left(), 0)

# The plate that counts next on an ordered challenge, or null.
func next_plate() -> SteelPlate:
	for plate in plates:
		if not rung_plates.has(plate):
			return plate
	return null

# No guided steps in a challenge.
func advance_tutorial() -> void:
	pass

func tutorial_done() -> bool:
	return true

func on_plate_rung(plate: SteelPlate, _label: String) -> void:
	if outcome != Outcome.RUNNING or rung_plates.has(plate):
		return
	if is_ordered() and plate != next_plate():
		return
	rung_plates[plate] = true
	rung_metres += plate.range_metres
	mission_log.progress("plates")
	if mission_log.all_primary_complete():
		outcome = Outcome.PASSED
		finish_time = elapsed

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not GameState.simulation_active() or not begun or outcome != Outcome.RUNNING:
		return
	elapsed += delta
	evaluate()

# Fail on the clock, or once the last round has landed without a pass.
func evaluate() -> void:
	if outcome != Outcome.RUNNING:
		return
	if time_limit() > 0.0 and elapsed >= time_limit():
		fail(Outcome.OUT_OF_TIME)
	elif rounds_left() == 0 and mission.weapon.projectiles.is_empty():
		fail(Outcome.OUT_OF_ROUNDS)

func fail(reason: int) -> void:
	outcome = reason
	finish_time = minf(elapsed, time_limit()) if reason == Outcome.OUT_OF_TIME else elapsed
	mission_log.fail("plates")

func end_banner(failed: bool) -> String:
	return tr("CHALLENGE FAILED - {restart} to retry") if failed else tr("CHALLENGE PASSED - {restart} to retry")

func allows_saves() -> bool:
	return false

func conditions_text() -> String:
	var parts: Array[String] = [super.conditions_text(), tr("Rounds %d / %d") % [rounds_left(), int(challenge.rounds)]]
	if time_limit() > 0.0:
		var left := int(ceil(time_left()))
		parts.append(tr("Time left %d:%02d") % [left / 60, left % 60])
	else:
		parts.append(tr("Time %d:%02d") % [int(elapsed) / 60, int(elapsed) % 60])
	var next := next_plate()
	if is_ordered() and next and outcome == Outcome.RUNNING:
		parts.append(tr("Next %d m") % int(next.range_metres))
	return "  |  ".join(parts)

# Everything the leaderboard and the results screen need about this attempt.
func result() -> Dictionary:
	var passed := outcome == Outcome.PASSED
	var seconds := finish_time if outcome != Outcome.RUNNING else elapsed
	var longest := 0.0
	for plate in rung_plates:
		longest = maxf(longest, plate.range_metres)
	var parts := ChallengeCatalog.score_parts(challenge, rung_metres, rounds_used(), seconds, passed)
	var reason := ""
	match outcome:
		Outcome.OUT_OF_ROUNDS:
			reason = "out_of_rounds"
		Outcome.OUT_OF_TIME:
			reason = "out_of_time"
	return {
		"id": challenge_id, "title": String(challenge.title), "passed": passed, "outcome": outcome, "reason": reason,
		"score": int(parts.total), "parts": parts, "plates_rung": rung_plates.size(), "plate_count": plates.size(),
		"rounds_used": rounds_used(), "rounds": int(challenge.rounds), "time": seconds, "time_limit": time_limit(),
		"longest": longest,
	}

func record_progress(_mission_id: String, _stats: Dictionary) -> Dictionary:
	var attempt := result()
	var progress := Progression.record_challenge(challenge_id, attempt)
	progress.challenge = attempt
	return progress
