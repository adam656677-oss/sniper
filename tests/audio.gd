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

# Sign changes between two times in a mono 16-bit cue: about twice its pitch in Hz per second.
func zero_crossings(stream: AudioStreamWAV, from_seconds: float, to_seconds: float) -> int:
	var first := int(from_seconds * stream.mix_rate)
	var last := mini(int(to_seconds * stream.mix_rate), stream.data.size() / 2 - 1)
	var count := 0
	var previous := stream.data.decode_s16(first * 2)
	for i in range(first + 1, last):
		var sample := stream.data.decode_s16(i * 2)
		if (sample >= 0) != (previous >= 0):
			count += 1
		previous = sample
	return count

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
	var settings: Node = root.get_node("Settings")
	var old_sfx: float = float(settings.get_value("audio", "sfx"))
	settings.set_value("audio", "sfx", 0.0)
	check(not director.play_event("rifle_report", Vector3.ZERO), "SFX mute prevents playback")
	settings.set_value("audio", "sfx", old_sfx)
	check(director.play_event("reload_click", Vector3(1, 2, 3)), "A positional event can be played")
	check(director._voices.size() > 0, "Playback creates a tracked 3D voice")
	check(not director.play_event("not_a_real_event", Vector3.ZERO), "Unknown event names fail safely")
	# Ricochet: a procedural whine that glides down in pitch as the round tumbles away.
	check(director.EVENT_CONFIG.has("ricochet") and director._streams.has("ricochet"), "A ricochet whine cue is generated")
	if director._streams.has("ricochet"):
		var whine: AudioStreamWAV = director._streams["ricochet"]
		var thud: AudioStreamWAV = director._streams["impact"]
		check(whine.data.size() > thud.data.size(), "The whine trails on longer than a plain impact")
		var early := zero_crossings(whine, 0.08, 0.16)
		var late := zero_crossings(whine, 0.40, 0.48)
		check(late > 20 and early * 2 > late * 3, "The whine falls in pitch (%d then %d crossings)" % [early, late])
	var heard: Array = []
	if director.has_signal("event_played"):
		director.event_played.connect(func(event_name, position): heard.append([event_name, position]))
	check(director.play_event("ricochet", Vector3(4, 5, 6)) and heard.size() == 1 and heard[0][0] == "ricochet" and heard[0][1] == Vector3(4, 5, 6), "Playing a cue reports the event and where it played")
	settings.set_value("audio", "sfx", 0.0)
	director.play_event("ricochet", Vector3.ZERO)
	settings.set_value("audio", "sfx", old_sfx)
	check(heard.size() == 1, "A muted cue reports nothing")
	print("Checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("AUDIO TESTS PASSED")
	quit(0 if failures == 0 else 1)
