class_name Perf
## Cheap timers for the hot paths. Off in a normal match (one bool test each); the
## benchmark (tools/perf_bench.gd) turns them on and reads the totals every minute.
##   var t0 := Perf.t0()  ...  Perf.add(&"ai", t0)

static var on := false
static var acc := {}            # zone name -> microseconds since the last reset
static var calls := {}          # zone name -> times it ran


static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(zone: StringName, since: int) -> void:
	if not on:
		return
	acc[zone] = int(acc.get(zone, 0)) + Time.get_ticks_usec() - since
	calls[zone] = int(calls.get(zone, 0)) + 1


static func reset() -> void:
	acc.clear()
	calls.clear()
