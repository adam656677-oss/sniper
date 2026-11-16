extends RefCounted

# The playable missions, in menu order.

const MISSIONS := [
	{"id": "range", "title": "Shooting range", "scene": "res://range_mission.tscn", "brief": "Learn drop, wind and zeroing on a 1000 m range. Ring every plate."},
	{"id": "echo_ridge", "title": "Echo Ridge recon", "scene": "res://main.tscn", "brief": "Reach the terminal, pull the intel and get back to extraction."},
	{"id": "compound", "title": "The compound", "scene": "res://compound_mission.tscn", "brief": "Four hostiles patrol a walled compound. Clear it quietly and leave by the north gate."},
]

static func count() -> int:
	return MISSIONS.size()

static func get_mission(index: int) -> Dictionary:
	return MISSIONS[index] if index >= 0 and index < MISSIONS.size() else {}

static func index_for_scene(scene_path: String) -> int:
	for i in range(MISSIONS.size()):
		if MISSIONS[i].scene == scene_path:
			return i
	return -1
