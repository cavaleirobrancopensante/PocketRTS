extends SceneTree
## BROOD DISTANCE PAY (0.24.22, docs/brood_new.md "0.24.22 distance pay"): the numbers pinned. Game.food_mult is 1 near
## the Mother (her own Rootmaw, ~8.5 tiles, pays as before 0.24.22), rises to 2.5 at FOOD_FAR and stays there; a load
## (Game.food_at) and the far Rootmaw's drinking both scale with it. The live measurement: tools/measure_brood_far.gd.
##   godot --headless --script res://tools/test_brood_far.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var m := func(d: float) -> float: return Game.food_mult(d)
	check(is_equal_approx(m.call(6.0), 1.0) and m.call(8.5) < 1.06, "near home the pay is as before: x%.2f at 6 tiles, x%.2f at 8.5" % [m.call(6.0), m.call(8.5)])
	check(m.call(14.0) > 1.5 and m.call(14.0) < 1.6, "x%.2f at 14 tiles" % m.call(14.0))
	check(m.call(22.0) > 2.2 and m.call(22.0) < 2.4, "x%.2f at 22 tiles" % m.call(22.0))
	check(is_equal_approx(m.call(24.0), 2.5) and is_equal_approx(m.call(30.0), 2.5) and is_equal_approx(m.call(45.0), 2.5),
		"x2.5 from 24 tiles out (x%.2f at 30, x%.2f at 45)" % [m.call(30.0), m.call(45.0)])
	var d := 6.0
	var last := 0.0
	var rising := true
	while d <= 40.0:
		rising = rising and m.call(d) >= last
		last = m.call(d)
		d += 0.5
	check(rising, "it never falls with distance")
	check(is_equal_approx(Game.food_at(22.0, 10.0), Defs.FOOD_RATE * m.call(22.0) * (Defs.PIT_TIME + Defs.FOOD_TRIP * (10.0 - Defs.FOOD_REACH))),
		"a load is the rate x the multiplier x the trip (%.1f food from 22 tiles, gap 10)" % Game.food_at(22.0, 10.0))
	check(is_equal_approx(WorkerLabels._rate_guess(22.0), Defs.FOOD_RATE * m.call(22.0)), "the GRUBS label uses the same rate")
	print("brood far: %d failed" % fails)
	quit(1 if fails > 0 else 0)
