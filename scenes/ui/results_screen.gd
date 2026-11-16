class_name ResultsScreen
extends Control

# End-of-mission summary. Score is fictional balancing.

var mission: Node
var text: Label
var panel: VBoxContainer

func _ready() -> void:
	mission = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = VBoxContainer.new()
	center.add_child(panel)
	text = Label.new()
	panel.add_child(text)
	button("Retry", func(): get_tree().reload_current_scene())
	button("Mission select", func(): mission.quit_to_menu())
	visible = false

func button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

static func score_for(stats: Dictionary, objectives: Node, failed: bool) -> int:
	if failed:
		return 0
	var score := int(stats.kills) * 100
	score += int(round(stats.longest_kill))
	if int(stats.shots) > 0:
		score += int(round(100.0 * float(stats.hits) / float(stats.shots)))
	for objective in objectives.objectives:
		if objective.status == objectives.Status.COMPLETE:
			score += 250 if objective.kind == objectives.Kind.PRIMARY else 150
	score -= int(stats.detections) * 50
	return maxi(score, 0)

func stealth_rating(stats: Dictionary, objectives: Node) -> String:
	if objectives.status("undetected") == objectives.Status.COMPLETE:
		return tr("Ghost")
	if int(stats.detections) == 0:
		return tr("Unseen")
	return tr("Compromised") if int(stats.detections) < 3 else tr("Loud")

func show_results(progress: Dictionary = {}) -> void:
	var stats: Dictionary = mission.stats
	var objectives = mission.level.mission_log
	var lines: Array[String] = []
	lines.append(tr("MISSION FAILED") if GameState.failed else tr("MISSION COMPLETE"))
	lines.append(tr("Score: %d") % score_for(stats, objectives, GameState.failed))
	lines.append(tr("Time: %d:%02d") % [int(stats.elapsed) / 60, int(stats.elapsed) % 60])
	lines.append(tr("Shots: %d | Hits: %d | Accuracy: %d%%") % [stats.shots, stats.hits, int(round(mission.accuracy() * 100.0))])
	lines.append(tr("Kills: %d | Longest shot: %.0f m") % [stats.kills, stats.longest_kill])
	lines.append(tr("Stealth: %s (%d detections)") % [stealth_rating(stats, objectives), stats.detections])
	if progress.get("new_best", false):
		lines.append(tr("New best score"))
	for id in progress.get("unlocked", []):
		lines.append(tr("Achievement unlocked:") + " " + tr(String(Progression.ACHIEVEMENTS[id].title)))
	for line in objectives.lines():
		lines.append(line)
	text.text = "\n".join(lines)
	visible = true
