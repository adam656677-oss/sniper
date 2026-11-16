extends RefCounted

# Time-of-day and weather presets. Pure data plus helpers so levels, perception
# and tests share one definition. Fictional tuning.

enum TimeOfDay { DAWN, NOON, DUSK, NIGHT }
enum Weather { CLEAR, WINDY, RAIN, DUST }

const TIME := {
	TimeOfDay.DAWN: {"sun_pitch": -12.0, "sun_color": Color(1.0, 0.72, 0.5), "sun_energy": 0.7, "sky_top": Color(0.35, 0.45, 0.65), "horizon": Color(0.95, 0.7, 0.55), "ambient": 0.3, "visibility": 0.8},
	TimeOfDay.NOON: {"sun_pitch": -55.0, "sun_color": Color(1.0, 0.98, 0.94), "sun_energy": 1.0, "sky_top": Color(0.32, 0.5, 0.72), "horizon": Color(0.72, 0.78, 0.82), "ambient": 0.35, "visibility": 1.0},
	TimeOfDay.DUSK: {"sun_pitch": -14.0, "sun_color": Color(1.0, 0.6, 0.4), "sun_energy": 0.7, "sky_top": Color(0.22, 0.25, 0.45), "horizon": Color(0.9, 0.5, 0.35), "ambient": 0.55, "visibility": 0.7},
	TimeOfDay.NIGHT: {"sun_pitch": -40.0, "sun_color": Color(0.55, 0.65, 0.9), "sun_energy": 0.15, "sky_top": Color(0.02, 0.03, 0.08), "horizon": Color(0.08, 0.1, 0.16), "ambient": 0.12, "visibility": 0.4},
}
const WEATHER := {
	Weather.CLEAR: {"wind_scale": 1.0, "gust": 0.15, "fog": 0.00012, "visibility": 1.0, "hearing": 1.0},
	Weather.WINDY: {"wind_scale": 2.5, "gust": 0.5, "fog": 0.00015, "visibility": 0.95, "hearing": 0.75},
	Weather.RAIN: {"wind_scale": 1.5, "gust": 0.3, "fog": 0.0012, "visibility": 0.6, "hearing": 0.5},
	Weather.DUST: {"wind_scale": 3.0, "gust": 0.6, "fog": 0.003, "visibility": 0.4, "hearing": 0.7},
}

static func visibility(time_of_day: int, weather: int) -> float:
	return float(TIME[time_of_day].visibility) * float(WEATHER[weather].visibility)

static func hearing(weather: int) -> float:
	return float(WEATHER[weather].hearing)

# Wind at time t: base vector scaled by the weather, with a smooth gust term that
# varies strength by up to +/- gust fraction. Deterministic in t.
static func wind_at(base: Vector3, weather: int, t: float) -> Vector3:
	var preset: Dictionary = WEATHER[weather]
	var gust := float(preset.gust) * (0.6 * sin(t * 0.37) + 0.4 * sin(t * 1.13 + 1.7))
	return base * float(preset.wind_scale) * (1.0 + gust)
