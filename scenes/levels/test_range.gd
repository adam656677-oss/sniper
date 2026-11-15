extends LevelBase

# Test range: collect intel at the terminal, return to extraction.

@export var terminal_point := Vector3(0, 1, -60)
@export var extraction_point := Vector3(0, 1, 3)

func near_terminal(point: Vector3) -> bool:
	return point.distance_to(terminal_point) < INTERACT_DISTANCE

func near_extraction(point: Vector3) -> bool:
	return point.distance_to(extraction_point) < INTERACT_DISTANCE

func interact(point: Vector3) -> void:
	if near_terminal(point):
		GameState.collect_intel()
	if GameState.intel and near_extraction(point):
		GameState.finish_mission()

func objective_text() -> String:
	return "Return to the green extraction marker and press E" if GameState.intel else "Reach the gold terminal ahead and press E"
