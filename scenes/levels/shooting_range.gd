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

func setup_objectives() -> void:
	mission_log.add("plates", "Ring every plate", MissionLog.Kind.PRIMARY, maxi(plates.size(), 1))
	mission_log.add("long_shot", "Ring the 1000 m plate", MissionLog.Kind.SECONDARY)

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
