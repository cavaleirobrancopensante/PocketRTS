class_name Prof
## A cheap profiler for the match log's lag lines: time (microseconds) spent in each part of
## the game since the last minute, and how often. MatchLog prints and resets it each minute.
static var us := {}
static var calls := {}


static func add(key: String, t0: int) -> void:
	var dt := Time.get_ticks_usec() - t0
	us[key] = int(us.get(key, 0)) + dt
	calls[key] = int(calls.get(key, 0)) + 1


static func reset() -> void:
	us.clear()
	calls.clear()
