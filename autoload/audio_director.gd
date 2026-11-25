extends Node
## Lightweight procedural audio foundation. Replace these generated cues with licensed recordings as the art pass matures.
## Events are positional and respect the player's SFX slider.

const SAMPLE_RATE := 22050
const MAX_ACTIVE_VOICES := 24
const EVENT_CONFIG := {
	"rifle_report": {"duration": 0.72, "pitch": 1.0, "gain": 1.0, "low": 62.0, "crack": 1800.0},
	"suppressed_report": {"duration": 0.24, "pitch": 1.0, "gain": 0.36, "low": 105.0, "crack": 950.0},
	"sidearm_report": {"duration": 0.38, "pitch": 1.0, "gain": 0.72, "low": 92.0, "crack": 1450.0},
	"reload_click": {"duration": 0.10, "pitch": 1.0, "gain": 0.22, "low": 520.0, "crack": 2600.0},
	"impact": {"duration": 0.20, "pitch": 1.0, "gain": 0.32, "low": 150.0, "crack": 800.0},
	"footstep": {"duration": 0.12, "pitch": 1.0, "gain": 0.18, "low": 95.0, "crack": 420.0},
	"radio_static": {"duration": 0.45, "pitch": 1.0, "gain": 0.12, "low": 260.0, "crack": 2100.0}
}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	for event_name in EVENT_CONFIG:
		_streams[event_name] = _build_stream(EVENT_CONFIG[event_name])

func play_weapon_report(profile: WeaponProfile, world_position: Vector3) -> void:
	if profile == null:
		return
	var event_name := "rifle_report" if profile.simulated_projectile else "sidearm_report"
	if profile.suppressed:
		event_name = "suppressed_report"
	play_event(event_name, world_position)

func play_event(event_name: String, world_position: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0) -> bool:
	if not _streams.has(event_name) or not is_inside_tree():
		return false
	if Settings and float(Settings.get_value("audio", "sfx")) <= 0.001:
		return false
	_prune_voices()
	if _voices.size() >= MAX_ACTIVE_VOICES:
		var oldest: AudioStreamPlayer3D = _voices.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()
	var player := AudioStreamPlayer3D.new()
	player.stream = _streams[event_name]
	player.volume_db = volume_db + linear_to_db(clampf(float(Settings.get_value("audio", "sfx")), 0.0, 1.0))
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.max_distance = 240.0
	player.unit_size = 1.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	player.global_position = world_position
	_voices.append(player)
	player.finished.connect(_on_voice_finished.bind(player), CONNECT_ONE_SHOT)
	player.play()
	return true

func _prune_voices() -> void:
	for index in range(_voices.size() - 1, -1, -1):
		if not is_instance_valid(_voices[index]):
			_voices.remove_at(index)

func _on_voice_finished(player: AudioStreamPlayer3D) -> void:
	_voices.erase(player)
	if is_instance_valid(player):
		player.queue_free()

func _build_stream(config: Dictionary) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var count := int(float(config.duration) * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(float(config.low) * 1000.0 + float(config.crack))
	var phase_low := 0.0
	var phase_crack := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / maxf(float(count - 1), 1.0)
		var envelope := pow(1.0 - progress, 2.8)
		phase_low += TAU * float(config.low) / SAMPLE_RATE
		phase_crack += TAU * float(config.crack) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var low_tone := sin(phase_low) * 0.48
		var crack_tone := sin(phase_crack) * exp(-t * 34.0) * 0.22
		var transient := noise * exp(-t * 17.0) * 0.72
		var sample := clampf((low_tone + crack_tone + transient) * envelope * float(config.gain), -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		bytes.encode_s16(i * 2, pcm)
	stream.data = bytes
	return stream
