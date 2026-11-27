extends RefCounted

# Long-shot challenges on the 1000 m range, in menu order. Each one keeps some
# of the range's plates and sets the time of day, weather and wind, a round
# budget and an optional clock. Rifles and ballistics are untouched: only the
# conditions change. Fictional balancing.
#
# time_of_day and weather index Atmosphere.TimeOfDay and Atmosphere.Weather.
# wind is the base air-mass velocity in m/s (+X blows from the shooter's left);
# the weather scales it and adds gusts. time_limit 0 means no clock. ordered
# plates count only nearest first.

const ROUND_BONUS := 100 # points per unused round on a pass
const SECOND_BONUS := 10 # points per whole second left on a timed pass

const CHALLENGES := [
	{"id": "warmup", "title": "Calm warm-up", "scene": "res://scenes/challenges/warmup.tscn",
		"brief": "Three plates at 200, 300 and 400 m in calm noon air. Six rounds and no clock: settle your zero and holdover.",
		"plates": [200.0, 300.0, 400.0], "ordered": false,
		"time_of_day": 1, "weather": 0, "wind": Vector3(0.5, 0.0, 0.0), "rounds": 6, "time_limit": 0.0},
	{"id": "crosswind", "title": "Gusting crosswind", "scene": "res://scenes/challenges/crosswind.tscn",
		"brief": "The 700 m and 800 m plates at dawn in a wind from the left that gusts by half its strength. Read the wind before every shot. Six rounds.",
		"plates": [700.0, 800.0], "ordered": false,
		"time_of_day": 0, "weather": 1, "wind": Vector3(2.0, 0.0, 0.0), "rounds": 6, "time_limit": 0.0},
	{"id": "kilometre", "title": "Kilometre shot", "scene": "res://scenes/challenges/kilometre.tscn",
		"brief": "One plate at 1000 m at dusk with a light wind from the right. Three rounds to ring it.",
		"plates": [1000.0], "ordered": false,
		"time_of_day": 2, "weather": 0, "wind": Vector3(-1.5, 0.0, 0.0), "rounds": 3, "time_limit": 0.0},
	{"id": "sequence", "title": "Timed sequence", "scene": "res://scenes/challenges/sequence.tscn",
		"brief": "Ring 300, 500, 700 and 900 m in that order before three minutes run out. A plate hit out of order does not count. Ten rounds.",
		"plates": [300.0, 500.0, 700.0, 900.0], "ordered": true,
		"time_of_day": 1, "weather": 0, "wind": Vector3(2.0, 0.0, 0.0), "rounds": 10, "time_limit": 180.0},
]

static func count() -> int:
	return CHALLENGES.size()

static func get_challenge(index: int) -> Dictionary:
	return CHALLENGES[index] if index >= 0 and index < CHALLENGES.size() else {}

static func index_of(id: String) -> int:
	for i in range(CHALLENGES.size()):
		if CHALLENGES[i].id == id:
			return i
	return -1

static func find(id: String) -> Dictionary:
	return get_challenge(index_of(id))

# A pass scores the metres of the plates rung, ROUND_BONUS per unused round and,
# on a timed challenge, SECOND_BONUS per whole second left. A failure scores 0.
static func score_parts(challenge: Dictionary, rung_metres: float, rounds_used: int, elapsed: float, passed: bool) -> Dictionary:
	var parts := {"distance": 0, "rounds": 0, "time": 0, "total": 0}
	if not passed:
		return parts
	parts.distance = int(round(rung_metres))
	parts.rounds = ROUND_BONUS * maxi(int(challenge.get("rounds", 0)) - rounds_used, 0)
	var limit := float(challenge.get("time_limit", 0.0))
	if limit > 0.0:
		parts.time = SECOND_BONUS * int(floor(maxf(limit - elapsed, 0.0)))
	parts.total = parts.distance + parts.rounds + parts.time
	return parts

static func score_for(challenge: Dictionary, rung_metres: float, rounds_used: int, elapsed: float, passed: bool) -> int:
	return int(score_parts(challenge, rung_metres, rounds_used, elapsed, passed).total)
