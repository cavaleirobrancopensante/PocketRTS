extends SceneTree
## THE CROWN'S RALLY ON A BUILDING GOING UP (the owner, 2026-10-30 20:12): a Town Hall's rally set on an unfinished
## building sends each new Labourer to help build it (as a right-click on it would); a rally on a working site (a Farm)
## still puts them to work there. The Clockwork's Clocktower is left as it was.
##   godot --headless --fixed-fps 30 --script res://tools/test_rally_build.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0):
			hall = b
	check(hall != null, "a Town Hall")
	# an unfinished Cottage near it
	var site: Building = null
	var hc: Vector2i = g.cell_of(hall.center())
	for r in range(5, 14):
		for i in 16:
			var c: Vector2i = hc + Vector2i(Vector2.from_angle(TAU * i / 16.0) * r)
			if g.placement_problem(0, "cottage", c) == "":
				site = g._add_building("cottage", 0, c, false)
				break
		if site != null:
			break
	check(site != null and not site.built, "an unfinished Cottage")
	g.set_rally(hall, site.center())
	check(hall.rally_target == site, "the Town Hall's rally is on it")
	g.spawn_trained(hall, "labourer")
	await physics_frame
	var lab: Unit = null
	for u in g.units:
		if u.team == 0 and u.kind == "labourer" and (u.order == "build" or u.order_target == site):
			lab = u
	check(lab != null and lab.order == "build", "a new Labourer joins its construction (order %s)" % (lab.order if lab else "-"))
	var p0: float = site.progress if "progress" in site else 0.0
	for k in 240:
		await physics_frame
	check(site.built or (("progress" in site) and site.progress > p0), "   and builds it")
	# a rally on a Farm: they work it
	var farm: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "farm" and b.built:
			farm = b
	if farm != null:
		g.set_rally(hall, farm.center())
		var n0: int = farm.crew.size()
		g.spawn_trained(hall, "labourer")
		await physics_frame
		var newest: Unit = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == "labourer").back()
		check(newest.order == "gather" and newest.home_mine == farm or farm.crew.size() > n0, "a rally on a Farm: the new Labourer works it (%s)" % newest.order)
	print("rally_build: %d failures" % fails)
	quit(1 if fails > 0 else 0)
