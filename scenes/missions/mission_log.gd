class_name MissionLog
extends Node

# Ordered objective list for a mission. Objectives are dictionaries so they
# serialise directly for saves and HUD rendering.

enum Kind { PRIMARY, SECONDARY, OPTIONAL }
enum Status { HIDDEN, ACTIVE, COMPLETE, FAILED }

signal objective_changed(id: String, status: int)

var objectives: Array[Dictionary] = []

func add(id: String, title: String, kind: int = Kind.PRIMARY, goal: int = 1, hidden: bool = false) -> Dictionary:
	var objective := {"id": id, "title": title, "kind": kind, "goal": maxi(goal, 1), "progress": 0,
		"status": Status.HIDDEN if hidden else Status.ACTIVE}
	objectives.append(objective)
	return objective

func find(id: String) -> Dictionary:
	for objective in objectives:
		if objective.id == id:
			return objective
	return {}

func status(id: String) -> int:
	var objective := find(id)
	return int(objective.status) if not objective.is_empty() else -1

func set_status(id: String, new_status: int) -> void:
	var objective := find(id)
	if objective.is_empty() or objective.status == new_status:
		return
	if objective.status == Status.COMPLETE or objective.status == Status.FAILED:
		return
	objective.status = new_status
	objective_changed.emit(id, new_status)

func activate(id: String) -> void:
	set_status(id, Status.ACTIVE)

func complete(id: String) -> void:
	var objective := find(id)
	if not objective.is_empty():
		objective.progress = objective.goal
	set_status(id, Status.COMPLETE)

func fail(id: String) -> void:
	set_status(id, Status.FAILED)

func progress(id: String, amount: int = 1) -> void:
	var objective := find(id)
	if objective.is_empty() or objective.status != Status.ACTIVE:
		return
	objective.progress = mini(int(objective.goal), int(objective.progress) + amount)
	if objective.progress >= objective.goal:
		complete(id)

func set_goal(id: String, goal: int) -> void:
	var objective := find(id)
	if not objective.is_empty():
		objective.goal = maxi(goal, 1)

func all_primary_complete() -> bool:
	var any_primary := false
	for objective in objectives:
		if objective.kind == Kind.PRIMARY:
			any_primary = true
			if objective.status != Status.COMPLETE:
				return false
	return any_primary

func any_primary_failed() -> bool:
	for objective in objectives:
		if objective.kind == Kind.PRIMARY and objective.status == Status.FAILED:
			return true
	return false

func first_active_primary() -> Dictionary:
	for objective in objectives:
		if objective.kind == Kind.PRIMARY and objective.status == Status.ACTIVE:
			return objective
	return {}

func line(objective: Dictionary) -> String:
	var mark := "[ ]"
	match int(objective.status):
		Status.COMPLETE:
			mark = "[x]"
		Status.FAILED:
			mark = "[!]"
	var text := "%s %s" % [mark, tr(String(objective.title))]
	if objective.goal > 1 and objective.status == Status.ACTIVE:
		text += " (%d/%d)" % [objective.progress, objective.goal]
	if objective.kind == Kind.SECONDARY:
		text += " " + tr("(secondary)")
	elif objective.kind == Kind.OPTIONAL:
		text += " " + tr("(optional)")
	if objective.status == Status.FAILED:
		text += " " + tr("FAILED")
	return text

# Completed optional objectives are dropped from the HUD list to keep it short.
func lines() -> Array[String]:
	var result: Array[String] = []
	for objective in objectives:
		if objective.status == Status.HIDDEN:
			continue
		if objective.kind == Kind.OPTIONAL and objective.status == Status.COMPLETE and String(objective.id).begins_with("t_"):
			continue
		result.append(line(objective))
	return result

func to_dict() -> Dictionary:
	var saved: Array = []
	for objective in objectives:
		saved.append(objective.duplicate())
	return {"objectives": saved}

func from_dict(data: Dictionary) -> void:
	if not data.has("objectives"):
		return
	for saved in data.objectives:
		var objective := find(String(saved.get("id", "")))
		if objective.is_empty():
			continue
		objective.status = int(saved.get("status", objective.status))
		objective.progress = int(saved.get("progress", objective.progress))
		objective.goal = int(saved.get("goal", objective.goal))
