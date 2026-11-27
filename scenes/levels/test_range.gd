extends LevelBase

# Test range: collect intel at the terminal, return to extraction.

@export var terminal_point := Vector3(0, 1, -60)
@export var extraction_point := Vector3(0, 1, 3)

func near_terminal(point: Vector3) -> bool:
	return point.distance_to(terminal_point) < INTERACT_DISTANCE

func near_extraction(point: Vector3) -> bool:
	return point.distance_to(extraction_point) < INTERACT_DISTANCE

func setup_objectives() -> void:
	mission_log.add("intel", "Reach the gold terminal ahead and press {interact}")
	mission_log.add("extract", "Return to the green extraction marker and press {interact}", MissionLog.Kind.PRIMARY, 1, true)
	mission_log.add("targets", "Drop the three practice targets", MissionLog.Kind.OPTIONAL, 3)

func on_target_died(body: Node3D) -> void:
	super.on_target_died(body)
	mission_log.progress("targets")

func interact(point: Vector3) -> void:
	if near_terminal(point) and not GameState.intel:
		GameState.collect_intel()
		mission_log.activate("extract")
		mission_log.complete("intel")
	if GameState.intel and near_extraction(point):
		mission_log.complete("extract")
