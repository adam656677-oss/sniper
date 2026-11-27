extends SceneTree

# Playable prologue escape: the breached doorway, the Accord flashlight sweep in
# the yard, being spotted and sent back, cover, crouching and reaching the tree line.

# Resting heights of a 1.8 m capsule on the house floor and on the yard ground.
const HOUSE := 0.9
const YARD := 0.76

var failures := 0
var story: Node
var home: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

# True when the shared subtitle overlay is showing or holding a line containing text.
func dialogue_has(text: String) -> bool:
	var dialogue = root.get_node("StoryDialogue")
	if dialogue.panel.visible and dialogue.line_label.text.contains(text):
		return true
	return dialogue.queue.any(func(entry): return String(entry.line).contains(text))

func physics_frames(count: int) -> void:
	for i in count:
		await physics_frame

func push_player(action: String, frames: int) -> void:
	Input.action_press(action)
	await physics_frames(frames)
	Input.action_release(action)
	await physics_frame

func place_player(at: Vector3, yaw: float = 0.0) -> void:
	home.player.global_position = at
	home.player.rotation.y = yaw
	home.player.velocity = Vector3.ZERO
	await physics_frames(2)

func place_operative(operative: Node3D, at: Vector3, facing: Vector3) -> void:
	operative.global_position = at
	operative.look_at(at + facing, Vector3.UP)
	await physics_frames(2)

func run_tests() -> void:
	story = root.get_node("StoryCampaign")
	story.start_new_campaign()
	var scene: PackedScene = load("res://scenes/ui/prologue_home.tscn")
	home = scene.instantiate()
	home.auto_transition = false
	root.add_child(home)
	await physics_frames(3)

	# Before the attack the house is closed.
	check(not home.doorway_open(), "Front doorway is shut before the attack")
	await place_player(Vector3(0, HOUSE, 7.6))
	await push_player("move_back", 45)
	check(home.player.global_position.z < 8.8, "Player cannot walk out of the closed front door")
	await place_player(Vector3(2.6, HOUSE, 7.6))
	await push_player("move_back", 45)
	check(home.player.global_position.z < 8.8, "Front wall has no gap beside the door")
	check(home.operatives.size() == 2, "Two Accord operatives are staged in the yard")
	check(home.operatives.all(func(op): return not op.visible), "Operatives stay hidden until the attack")
	check(not home.exposure_bar.visible, "Exposure meter is hidden during the quiet scene")

	# The attack breaches the door and starts the sweep.
	home.interact_with("photo")
	home.interact_with("lena")
	home.interact_with("ledger")
	check(dialogue_has("Take it and go"), "Lena tells Elias to take the key and run when the door is breached")
	root.get_node("StoryDialogue").clear_queue()
	check(home.attack_started and home.doorway_open(), "The attack breaches the front doorway")
	check(home.operatives.all(func(op): return op.visible), "Operatives appear when the attack begins")
	check(home.operatives.all(func(op): return op.get_node_or_null("Flashlight") is SpotLight3D), "Each operative carries a flashlight")
	check(home.exposure_bar.visible, "Exposure meter appears for the escape")
	check(home.objective.text.contains("tree line"), "Objective directs the player to the tree line")
	await place_player(Vector3(0, HOUSE, 7.6))
	await push_player("move_back", 45)
	check(home.player.global_position.z > 8.8, "Player can leave through the breached doorway")
	await physics_frames(150)
	check(not home.lena.visible, "Lena leaves the room after the breach")

	# Crouching makes Elias harder to see.
	home.set_crouched(false)
	var standing: float = home.player_exposure()
	home.set_crouched(true)
	var crouched: float = home.player_exposure()
	check(crouched < standing and crouched > 0.0, "Crouching lowers exposure without removing it")
	check(home.camera.global_position.y < home.player.global_position.y + 0.3, "Crouching lowers the camera")
	home.set_crouched(false)

	# Flashlight cone, range and cover, with the patrols frozen for determinism.
	home.patrol_enabled = false
	var op: Node3D = home.operatives[0]
	await place_operative(op, Vector3(-4, YARD, 30), Vector3(0, 0, -1))
	await place_player(Vector3(-4, YARD, 24))
	check(home.visibility_to(op) > 0.0, "Operative sees a player standing in the flashlight beam")
	await place_player(Vector3(-4 + 6.0 * sin(deg_to_rad(40)), YARD, 30 - 6.0 * cos(deg_to_rad(40))))
	check(home.visibility_to(op) == 0.0, "Flashlight cone is narrower than a guard's full field of view")
	await place_player(Vector3(-4, YARD, 30 - home.FLASHLIGHT_RANGE - 2.0))
	check(home.visibility_to(op) == 0.0, "Flashlight has a limited range")
	await place_operative(op, Vector3(0, YARD, 32), Vector3(0, 0, -1))
	await place_player(Vector3(0, YARD, 18))
	check(home.visibility_to(op) == 0.0, "The response vehicle blocks the operative's line of sight")
	await place_player(Vector3(4.5, YARD, 18))
	check(home.visibility_to(op) > 0.0, "Stepping out from behind the vehicle exposes the player")
	await place_operative(op, Vector3(-6.5, YARD, 24), Vector3(0, 0, -1))
	await place_player(Vector3(-6.5, YARD, 14.0))
	check(home.visibility_to(op) > 0.0, "Standing behind the woodpile leaves the player visible")
	home.set_crouched(true)
	await physics_frames(2)
	check(home.visibility_to(op) == 0.0, "Crouching behind the woodpile hides the player")
	home.set_crouched(false)

	# Getting caught sends Elias back to the doorway instead of ending the scene.
	await place_operative(op, Vector3(-4, YARD, 30), Vector3(0, 0, -1))
	await place_player(Vector3(-4, YARD, 26))
	var spotted_before: int = home.spotted_count
	await physics_frames(240)
	check(home.spotted_count == spotted_before + 1, "Holding still in the beam gets the player spotted")
	check(home.player.global_position.distance_to(home.RESET_POINT) < 1.0, "Being spotted resets the player to the doorway")
	check(home.operatives.all(func(o): return o.get_node("Perception").awareness == 0.0), "Operatives lose track after the reset")
	check(not home.escaped, "Being spotted does not complete the escape")
	root.get_node("StoryDialogue").clear_queue()
	await physics_frames(100)
	await place_operative(op, Vector3(0, YARD, 12.5), Vector3(0, 0, -1))
	await place_player(Vector3(0, HOUSE, 7.6))
	var spotted_inside: int = home.spotted_count
	check(home.visibility_to(op) > 0.0, "An operative can see into the doorway")
	await physics_frames(120)
	check(home.spotted_count == spotted_inside and op.get_node("Perception").awareness == 0.0, "Watching the yard from inside the house is safe")

	# The yard is bounded and the tree line is the exit.
	check(home.in_tree_line(Vector3(-10, 1, 20)) and home.in_tree_line(Vector3(11, 1, 30)), "Both flanks of the tree line count as the escape")
	check(not home.in_tree_line(Vector3(0, 1, 20)), "The open drive is not the tree line")
	check(not home.in_tree_line(Vector3(-10, 1, 9.5)), "The corner of the house is not the tree line")
	await place_player(Vector3(-21.5, YARD, 10.5), 0.0)
	await push_player("move_left", 45)
	check(home.player.global_position.x > -23.5, "Yard boundary keeps the player in the play space")

	await place_player(Vector3(-10, YARD, 20))
	await physics_frames(3)
	check(home.escaped and story.get_flag("home_attack_survived"), "Reaching the tree line completes the escape")
	check(story.get_flag("prologue_escape_unseen", true) == false, "Story records that Elias was seen during the escape")

	# The outro fades to black, narrates the aftermath, then completes the chapter.
	var dialogue = root.get_node("StoryDialogue")
	var heard := ""
	for i in 900:
		if story.is_chapter_complete("prologue"):
			break
		if dialogue.panel.visible:
			heard += dialogue.line_label.text + "\n"
			dialogue.advance()
		await process_frame
	check(heard.contains("never made it out") and heard.contains("VARN ACCORD"), "The aftermath is narrated after the escape")
	check(home.fade_rect.modulate.a >= 0.99, "The aftermath plays over a black screen")
	var fade_layer: CanvasLayer = home.fade_rect.get_parent()
	var hud_layer: CanvasLayer = home.objective.get_parent().get_parent().get_parent()
	check(fade_layer.layer > hud_layer.layer and fade_layer.layer < dialogue.layer, "The black screen covers the HUD but not the subtitles")
	check(story.is_chapter_complete("prologue") and story.is_chapter_unlocked("kestrel_pass"), "The prologue completes once the aftermath has played")

	home.queue_free()
	await process_frame
	root.get_node("StoryDialogue").clear_queue()
	story.start_new_campaign()
	story.save_campaign()
	print("PROLOGUE ESCAPE TESTS PASSED") if failures == 0 else print("PROLOGUE ESCAPE TESTS FAILED")
	quit(0 if failures == 0 else 1)
