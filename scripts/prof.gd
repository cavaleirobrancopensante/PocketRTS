class_name Prof
## A cheap profiler for the match log's lag lines: time (microseconds) spent in each part of
## the game since the last minute, and how often. MatchLog prints and resets it each minute.
static var us := {}
static var calls := {}
## The parts timed hundreds of times a second (every unit's and building's tick) add up here
## first, without the dictionaries, and go in with flush().
static var unit_us := 0
static var unit_n := 0
static var bld_us := 0
static var bld_n := 0


static func add(key: String, t0: int) -> void:
	var dt := Time.get_ticks_usec() - t0
	us[key] = int(us.get(key, 0)) + dt
	calls[key] = int(calls.get(key, 0)) + 1


## Put the batched parts in (before reading us / calls).
static func flush() -> void:
	if unit_n > 0:
		us["units"] = int(us.get("units", 0)) + unit_us
		calls["units"] = int(calls.get("units", 0)) + unit_n
		unit_us = 0
		unit_n = 0
	if bld_n > 0:
		us["buildings"] = int(us.get("buildings", 0)) + bld_us
		calls["buildings"] = int(calls.get("buildings", 0)) + bld_n
		bld_us = 0
		bld_n = 0


static func reset() -> void:
	us.clear()
	calls.clear()
	unit_us = 0
	unit_n = 0
	bld_us = 0
	bld_n = 0
