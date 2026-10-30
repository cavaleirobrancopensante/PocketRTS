## The countdown over the Brood Mother (eggs x/y and the time to her next egg, BroodNew.next_egg_in).
##   godot --headless --fixed-fps 30 --script res://tools/test_mother_egg_timer.gd
extends SceneTree
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-60s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := Game.new()
	g.map_id = "greenhold"
	g.demo = true
	g.factions = ["brood", "crown"]
	g.sides = [0, 1]
	root.add_child(g)
	await process_frame
	await process_frame
	var q := BroodNew.queen(g, 0)
	q.nb["eggs"] = 0
	q.nb["egg_t"] = 0.0
	q.nb["rate"] = 1.0
	var full_t := float(Defs.NB["egg_time"])
	check("an empty clutch counts down a whole egg", absf(BroodNew.next_egg_in(q) - full_t) < 0.01, "%.2f s" % BroodNew.next_egg_in(q))
	q.nb["egg_t"] = full_t * 0.5
	q.nb["rate"] = 2.0
	check("half way at twice the rate: a quarter of the time", absf(BroodNew.next_egg_in(q) - full_t * 0.25) < 0.01, "%.2f s" % BroodNew.next_egg_in(q))
	q.nb["eggs"] = BroodNew.eggs_max(q)
	check("a full clutch shows no countdown", BroodNew.next_egg_in(q) < 0.0)
	q.nb["eggs"] = 0
	q.nb["grow_t"] = 10.0
	check("growing: no countdown", BroodNew.next_egg_in(q) < 0.0)
	q.nb["grow_t"] = 0.0
	# it really counts down in play
	q.nb["egg_t"] = 0.0
	for i in 20:          # (her real rate first: the levers are looked at twice a second)
		g._physics_process(1.0 / 30.0)
		q._physics_process(1.0 / 30.0)
	var t0 := BroodNew.next_egg_in(q)
	for i in 30:
		g._physics_process(1.0 / 30.0)
		q._physics_process(1.0 / 30.0)
	var t1 := BroodNew.next_egg_in(q)
	check("it counts down in play", t1 < t0 and t1 >= 0.0, "%.2f -> %.2f s" % [t0, t1])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
