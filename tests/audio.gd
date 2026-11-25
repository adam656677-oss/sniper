extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	await process_frame
	var director := root.get_node_or_null("AudioDirector")
	check(director != null, "AudioDirector autoload is registered")
	if director == null:
		quit(1)
		return
	check(director._streams.size() == director.EVENT_CONFIG.size(), "Every declared audio event has a generated stream")
	for event_name in director.EVENT_CONFIG:
		var stream: AudioStreamWAV = director._streams[event_name]
		check(stream is AudioStreamWAV and stream.data.size() > 0, "%s has PCM audio data" % event_name)
		check(stream.mix_rate == director.SAMPLE_RATE and not stream.stereo, "%s uses the expected mono sample format" % event_name)
	var report: AudioStreamWAV = director._streams["rifle_report"]
	var suppressed: AudioStreamWAV = director._streams["suppressed_report"]
	check(report.data.size() > suppressed.data.size(), "Suppressed cue is shorter than the unsuppressed report")
	var old_sfx: float = float(Settings.get_value("audio", "sfx"))
	Settings.set_value("audio", "sfx", 0.0)
	check(not director.play_event("rifle_report", Vector3.ZERO), "SFX mute prevents playback")
	Settings.set_value("audio", "sfx", old_sfx)
	check(director.play_event("reload_click", Vector3(1, 2, 3)), "A positional event can be played")
	check(director._voices.size() > 0, "Playback creates a tracked 3D voice")
	check(not director.play_event("not_a_real_event", Vector3.ZERO), "Unknown event names fail safely")
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("AUDIO TESTS PASSED")
	quit(0 if failures == 0 else 1)
