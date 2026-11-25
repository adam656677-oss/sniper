extends LevelBase

# 1000 m shooting range: a steel plate every 100 m, each on its own bearing from the
# firing line so no plate masks another. Complete when every plate has rung.

var plates: Array[SteelPlate] = []
var rung_plates := {}

func _ready() -> void:
	for child in $Plates.get_children():
		if child is SteelPlate:
			plates.append(child)
			child.rung.connect(on_plate_rung)
	plates.sort_custom(func(a, b): return a.range_metres < b.range_metres)
	super._ready()

# Guided first steps, revealed one at a time as optional objectives.
const TUTORIAL := [
	["t_aim", "Aim down the scope (right click or left trigger)"],
	["t_ring_100", "Ring the 100 m plate"],
	["t_range", "Read a range of 300 m or more off the rangefinder"],
	["t_zero", "Raise your zero to 300 m with ] (d-pad up)"],
	["t_ring_300", "Ring the 300 m plate"],
	["t_breath", "Hold your breath (Shift or left stick) while scoped"],
	["t_holdover", "Ring a plate at 600 m or beyond using the reticle marks"],
]
var tutorial_step := 0

func setup_objectives() -> void:
	mission_log.add("plates", "Ring every plate", MissionLog.Kind.PRIMARY, maxi(plates.size(), 1))
	mission_log.add("long_shot", "Ring the 1000 m plate", MissionLog.Kind.SECONDARY)
	for step in TUTORIAL:
		mission_log.add(step[0], step[1], MissionLog.Kind.OPTIONAL, 1, true)
	mission_log.activate(TUTORIAL[0][0])

func tutorial_done() -> bool:
	return tutorial_step >= TUTORIAL.size()

func tutorial_condition(id: String) -> bool:
	if mission == null:
		return false
	match id:
		"t_aim":
			return mission.is_aiming()
		"t_ring_100":
			var plate := plate_at(100.0)
			return plate != null and plate.hit_count > 0
		"t_range":
			return mission.measured_range >= 300.0
		"t_zero":
			return mission.weapon.zero_range() >= 300.0
		"t_ring_300":
			var plate := plate_at(300.0)
			return plate != null and plate.hit_count > 0
		"t_breath":
			return mission.sway.holding
		"t_holdover":
			for plate in plates:
				if plate.range_metres >= 600.0 and plate.hit_count > 0:
					return true
	return false

func advance_tutorial() -> void:
	while not tutorial_done():
		var id: String = TUTORIAL[tutorial_step][0]
		if mission_log.status(id) != MissionLog.Status.ACTIVE:
			mission_log.activate(id)
		if not tutorial_condition(id):
			return
		mission_log.complete(id)
		tutorial_step += 1
		if not tutorial_done():
			mission_log.activate(TUTORIAL[tutorial_step][0])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if GameState.simulation_active():
		advance_tutorial()

func on_plate_rung(plate: SteelPlate, _label: String) -> void:
	if not rung_plates.has(plate):
		rung_plates[plate] = true
		mission_log.progress("plates")
	if is_equal_approx(plate.range_metres, 1000.0):
		mission_log.complete("long_shot")

func plate_at(range_metres: float) -> SteelPlate:
	for plate in plates:
		if is_equal_approx(plate.range_metres, range_metres):
			return plate
	return null

func is_complete() -> bool:
	return not plates.is_empty() and mission_log.all_primary_complete()
