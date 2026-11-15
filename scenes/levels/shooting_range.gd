extends LevelBase

# 1000 m shooting range: a steel plate every 100 m, each on its own bearing from the
# firing line so no plate masks another. Complete when every plate has rung.

var plates: Array[SteelPlate] = []
var rung_plates := {}

func _ready() -> void:
	super._ready()
	for child in $Plates.get_children():
		if child is SteelPlate:
			plates.append(child)
			child.rung.connect(on_plate_rung)
	plates.sort_custom(func(a, b): return a.range_metres < b.range_metres)

func on_plate_rung(plate: SteelPlate, _label: String) -> void:
	rung_plates[plate] = true

func plate_at(range_metres: float) -> SteelPlate:
	for plate in plates:
		if is_equal_approx(plate.range_metres, range_metres):
			return plate
	return null

func objective_text() -> String:
	return "Ring every plate (%d / %d)" % [rung_plates.size(), plates.size()]

func is_complete() -> bool:
	return not plates.is_empty() and rung_plates.size() == plates.size()
