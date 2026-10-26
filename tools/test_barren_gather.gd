extends SceneTree
## Spent land takes no crew (v0.14.15 playtest: grubs sent to a barren Feeding Pit stood idle
## under "0/5" and were told "That Feeding Pit is fully crewed."):
## 1. Brood: the capital's ground spent, 8 grubs ordered to one of its pits: none stays in its
##    crew, the notice says the ground is spent (never "fully crewed"), the label reads "spent";
## 2. Crown: one Town Hall's soil spent, 8 labourers ordered to its Farm: they go to the Farm of
##    the other (fresh) Town Hall instead.
##   godot --headless --fixed-fps 30 --script res://tools/test_barren_gather.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _start(main: Node, fac: String) -> Game:
	main.start({"map": "greenhold", "seed": 77, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	return g


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(77)

	# ---- 1. Brood: every pit barren, no fresh land anywhere
	var g: Game = await _start(main, "brood")
	var cap: Building = g.capital(0)
	check(cap != null, "the Brood has a capital")
	var pit: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "feeding_pit" and b.built:
			pit = b
			break
	check(pit != null, "the capital has a Feeding Pit")
	cap.soil = 0.0
	check(pit.barren(), "with the ground spent the pit is barren")
	var grubs: Array = []
	for i in 8:
		var u: Unit = g._add_unit("grub", 0, pit.center() + Vector2(-80 + i * 20, 90))
		grubs.append(u)
	g._notify_t = -100000
	g.hud._msg = ""
	for u in grubs:
		u.cmd_gather(pit)
	for i in 30:
		await physics_frame
	var held := grubs.filter(func(u: Unit) -> bool: return pit.crew.has(u)).size()
	check(held == 0, "no grub stays in the barren pit's crew (%d do)" % held)
	check(not ("fully crewed" in g.hud._msg), "no \"fully crewed\" notice (got: %s)" % g.hud._msg)
	check("spent" in g.hud._msg, "the notice says the ground is spent (got: %s)" % g.hud._msg)
	var crews := 0
	for b in g.buildings:
		if b.team == 0 and b.kind == "feeding_pit":
			for u in grubs:
				if b.crew.has(u):
					crews += 1
	check(crews == 0, "no grub was put in any barren pit's crew (%d)" % crews)
	var started := grubs.all(func(u: Unit) -> bool: return u.order != "gather")
	check(started, "the grubs are not left on a gather order at the barren pit")
	await process_frame

	# ---- 2. Crown: one hall spent, a second hall with a fresh Farm
	g = await _start(main, "crown")
	var hall: Building = g.halls_of(0)[0]
	var farm: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "farm" and b.built and g.soil_hall(b) == hall:
			farm = b
			break
	check(farm != null, "the Town Hall has a Farm")
	# a second Town Hall away from the first (its own soil) with a Farm by it
	var c2: Vector2i = g.cell_of(hall.center()) + Vector2i(0, 26 if hall.center().y < Game.H * Game.T * 0.5 else -26)
	var hall2: Building = g._add_building("town_hall", 0, c2, true)
	var farm2: Building = g._add_building("farm", 0, c2 + Vector2i(6, 0), true)
	for b in g.buildings:
		if b.team == 0 and b.kind == "farm" and b != farm2:
			b.crew.clear()
	check(g.soil_hall(farm2) == hall2, "the new Farm draws on the new hall's soil")
	hall.soil = 0.0
	check(farm.barren() and not farm2.barren(), "the old Farm is barren, the new one fresh")
	var labs: Array = []
	for i in 8:
		var u: Unit = g._add_unit("labourer", 0, farm.center() + Vector2(-80 + i * 20, 90))
		labs.append(u)
	g._notify_t = -100000
	g.hud._msg = ""
	for u in labs:
		u.cmd_gather(farm)
	await physics_frame
	var at_old := labs.filter(func(u: Unit) -> bool: return farm.crew.has(u)).size()
	var at_new := labs.filter(func(u: Unit) -> bool: return farm2.crew.has(u)).size()
	check(at_old == 0, "no labourer joins the barren Farm (%d)" % at_old)
	check(at_new > 0, "the fresh Farm takes some of them (%d)" % at_new)
	var fresh := 0
	for u in labs:
		var h = u.home_mine
		if u.order == "gather" and h is Building and not (h as Building).barren() and (h as Building).crew.has(u):
			fresh += 1
	check(fresh == 8, "all 8 work fresh land instead (%d)" % fresh)
	check(not ("fully crewed" in g.hud._msg) or at_new == farm2.crew_max(), "no \"fully crewed\" notice for the barren Farm (got: %s)" % g.hud._msg)
	print("barren gather: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
