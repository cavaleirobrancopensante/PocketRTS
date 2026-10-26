extends SceneTree
## Crown workers take real posts first and haul only when every post is full (owner, 0.14.19):
## 1. a new game: the starting labourers work the Farm, none hauls;
## 2. every Farm and Mill full: a labourer trained with no rally becomes a hauler at the Town Hall;
## 3. the Town Hall's hauler slots full too: one more stands by (no hauler over the cap);
## 4. a rally on the ground still sends him to that spot.
##   godot --headless --fixed-fps 30 --script res://tools/test_haul_fallback.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 77, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 30:
		await physics_frame
	var hall: Building = g.nearest_hall(Vector2.ZERO, 0)
	var start_workers: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.is_worker())
	var farming := start_workers.filter(func(u: Unit) -> bool: return u.home_mine is Building and (u.home_mine as Building).kind == "farm").size()
	var hauling := start_workers.filter(func(u: Unit) -> bool: return u.is_hauler()).size()
	check(start_workers.size() == 4, "the Crown starts with 4 labourers (%d)" % start_workers.size())
	check(farming == start_workers.size(), "they all work the starting Farm (%d of %d)" % [farming, start_workers.size()])
	check(hauling == 0, "none of them hauls (%d)" % hauling)
	# fill every post
	for b in g.buildings.duplicate():
		if b.team == 0 and b.built and b.crew_max() > 0 and b.haul_cap() == 0:
			while b.crew.size() < b.crew_max():
				var w: Unit = g._add_unit("labourer", 0, b.center() + Vector2(0, 60))
				w.cmd_gather(b)
	for i in 5:
		await physics_frame
	check(g.free_site(0, hall.center()) == hall, "with every post full the free site is the Town Hall")
	g.spawn_trained(hall, "labourer")
	for i in 10:
		await physics_frame
	var u: Unit = g.units[g.units.size() - 1]
	check(u.kind == "labourer" and u.is_hauler() and u.home_mine == hall, "a new labourer with every post full becomes a hauler (%s)" % u.order)
	# fill the hall's hauler slots too
	while hall.haulers().size() < hall.haul_cap():
		var hw: Unit = g._add_unit("labourer", 0, hall.center() + Vector2(0, 70))
		hw.cmd_gather(hall)
	for i in 5:
		await physics_frame
	g.spawn_trained(hall, "labourer")
	for i in 10:
		await physics_frame
	u = g.units[g.units.size() - 1]
	check(not u.is_hauler() and hall.haulers().size() <= hall.haul_cap(), "with the hall's haulers full he does not haul (%d/%d)" % [hall.haulers().size(), hall.haul_cap()])
	# a rally on the ground is still obeyed
	hall.crew = hall.crew.slice(0, 2)
	for x in g.units:
		if x.team == 0 and x.is_hauler() and not hall.crew.has(x):
			x.cmd_stop()
	var spot: Vector2 = hall.center() + Vector2(160, 0)
	hall.rally = spot
	hall.rally_target = null
	g.spawn_trained(hall, "labourer")
	for i in 5:
		await physics_frame
	u = g.units[g.units.size() - 1]
	check(u.order == "move" or u.position.distance_to(spot) < 40.0, "a rally on the ground still sends him there (%s)" % u.order)
	print("haul fallback: ALL PASS" if fails == 0 else "haul fallback: %d FAILED" % fails)
	quit(1 if fails else 0)
