extends SceneTree
## Brood fixes from the playtest (you: the Brood, against the Crown):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_fixes.gd
##  1. a Brood ghost whose grub isn't coming any more goes, all of its cost back: the grub
##     ordered elsewhere, killed, stopped, or unable to get there; a Shift-queued site stays
##     while the grub has it in its queue; a grub that gets there becomes the building.
##     The same for a Clockwork site whose Winder gives up before he has the crate.
##  2. attack-move: Raptors go for the Musketeers, not the Barracks beside them; Raptors
##     hitting a building switch to Musketeers that come into reach
##  3. the Bloater's acid cloud eats enemy buildings inside it (at BLOAT.buildings of its rate)
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "brood", "colour": 1, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 0, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _gold() -> int:
	return int(g.players[0]["gold"])


func _run() -> void:
	origin = _open_area(26, 20)
	g.explored.fill(1)
	# (no income: the gold only moves with what's paid and refunded)
	for u in g.units.duplicate():
		if u.team == 0 and u.is_worker():
			g.consume_unit(u)
	await wait(1.0)
	g.players[0]["gold"] = 5000
	var hive: Building = g.halls_of(0)[0]
	var home: Vector2 = hive.center() + Vector2(0, hive.rect().size.y * 0.5 + 40.0)
	var spot: Vector2i = g.find_spot(0, "feeding_pit", hive, 4, 10, "near")
	check(spot.x >= 0, "a spot for a Feeding Pit on the swamp")
	var cost := int(Defs.BUILDINGS["feeding_pit"]["cost"])

	# 1a: the grub is ordered elsewhere
	var gr := unit("grub", home)
	var g0 := _gold()
	var b: Building = g.place_building(0, "feeding_pit", spot, [gr])
	check(b != null and b.ghost and _gold() == g0 - cost, "placed: a ghost, %d paid" % cost)
	await wait(0.6)
	gr.give({"o": "move", "p": home + Vector2(-120, 0)})
	var gone := await wait_for(func() -> bool: return b.dead, 3.0)
	check(gone and _gold() == g0 and not g.buildings.has(b), "(a) grub ordered elsewhere: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])
	check(g.side_ghost_at(0, spot) == null, "(a) its ground is free again")

	# 1b: the grub is killed
	g0 = _gold()
	b = g.place_building(0, "feeding_pit", spot, [gr])
	await wait(0.6)
	gr.take_damage(99999.0, null)
	gone = await wait_for(func() -> bool: return b.dead, 3.0)
	check(gone and _gold() == g0, "(b) grub killed: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])

	# 1c: the grub is stopped
	gr = unit("grub", home)
	g0 = _gold()
	b = g.place_building(0, "feeding_pit", spot, [gr])
	await wait(0.6)
	gr.cmd_stop()
	gone = await wait_for(func() -> bool: return b.dead, 3.0)
	check(gone and _gold() == g0, "(c) grub stopped: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])

	# 1d: Shift-queued behind a move: the ghost stays while it's in the grub's queue
	g0 = _gold()
	gr.give({"o": "move", "p": home + Vector2(-900, 300)})
	b = g.place_building(0, "feeding_pit", spot, [gr], true)
	await wait(1.5)
	check(b != null and not b.dead and b.ghost, "(d) Shift-queued site: the ghost stays while the grub has it queued")
	gr.give({"o": "move", "p": home})
	gone = await wait_for(func() -> bool: return b.dead, 3.0)
	check(gone and _gold() == g0, "(d) a plain order clears the queue: the ghost goes, refunded")

	# 1e: the grub gets there: it becomes the building
	g0 = _gold()
	b = g.place_building(0, "feeding_pit", spot, [gr])
	var started_ok := await wait_for(func() -> bool: return not b.ghost and b.seeded, 25.0)
	await wait(2.0)
	check(started_ok and not b.dead and _gold() == g0 - cost, "(e) the grub reaches it: it grows (ghost %s, seeded %s, dead %s)" % [b.ghost, b.seeded, b.dead])

	# 1f: the grub can't get there (shut in by rock)
	var c0: Vector2i = origin + Vector2i(13, 10)
	var ring: Array = []
	for y in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) == 2 or absi(y) == 2:
				ring.append(c0 + Vector2i(x, y))
	for c in ring:
		g._mark(c, Vector2i.ONE, 1)
	g._astar_dirty = true
	await wait(0.2)
	var shut := unit("grub", g.cell_center(c0))
	var spot2: Vector2i = g.find_spot(0, "feeding_pit", hive, 4, 12, "near")
	g0 = _gold()
	b = g.place_building(0, "feeding_pit", spot2, [shut])
	check(b != null and shut.order == "build", "(f) placed for a shut-in grub (%s)" % shut.order)
	gone = await wait_for(func() -> bool: return b.dead, 8.0)
	check(gone and _gold() == g0 and shut.order != "build", "(f) the grub can't get there: the ghost goes, refunded, the grub stops (%s)" % shut.order)
	for c in ring:
		g._mark(c, Vector2i.ONE, 0)
	g._astar_dirty = true
	g.consume_unit(shut)

	# 1g: Clockwork: a Winder on his way to fetch the crate is sent elsewhere
	g.factions[0] = "clockwork"       # (for a moment: a Clocktower of ours to fetch the crate from)
	var tower: Building = g._add_building("clocktower", 0, origin + Vector2i(2, 2), true)
	var w := unit("winder", g.cell_center(origin + Vector2i(4, 9)))
	g0 = _gold()
	b = g.place_building(0, "spring_tower", origin + Vector2i(10, 3), [w])
	check(b != null and b.ghost and b.crate == "tower", "(g) Clockwork site placed (crate at the Clocktower)")
	await wait(0.6)
	w.give({"o": "move", "p": at(60, 500)})
	gone = await wait_for(func() -> bool: return b.dead, 3.0)
	check(gone and _gold() == g0, "(g) Winder sent elsewhere before the crate: the ghost goes, refunded")
	# a dropped crate keeps its site (another Winder can carry it on)
	g0 = _gold()
	b = g.place_building(0, "spring_tower", origin + Vector2i(10, 3), [w])
	var carried := await wait_for(func() -> bool: return b.crate == "carried", 20.0)
	w.give({"o": "move", "p": at(60, 560)})
	await wait(3.0)
	check(carried and not b.dead and b.crate == "ground", "(g) a crate dropped on the way keeps its site (%s)" % b.crate)
	g.abandon(b)
	g.consume_unit(w)
	g._remove_quietly(tower)
	g.factions[0] = "brood"

	# 2a: Raptors attack-moving past a Barracks with Musketeers by it
	var bar: Building = g._add_building("barracks", 1, origin + Vector2i(12, 4), true)
	var raps: Array = []
	for i in 6:
		raps.append(unit("raptor", at(130 + (i % 3) * 18, 170 + (i / 3) * 18)))
	var mus: Array = []
	for i in 3:
		var m := unit("musketeer", at(330 + i * 20, 300), 1)
		m.cmd_hold()
		mus.append(m)
	await wait(0.1)
	for r in raps:
		r.cmd_move(at(700, 160), true)
	await wait(2.5)
	# (who each went for, the fallen too: the Musketeers shoot back)
	var on_men := raps.filter(func(r: Unit) -> bool: return r.target is Unit and (r.target as Unit).kind == "musketeer").size()
	var on_bar := raps.filter(func(r: Unit) -> bool: return r.target == bar).size()
	check(on_men >= 4 and on_bar == 0, "(2a) attack-move: Raptors go for the Musketeers (%d), not the Barracks (%d)" % [on_men, on_bar])
	for u in raps + mus:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	await wait(0.2)

	# 2b: Raptors hitting the Barracks switch to Musketeers that come into reach
	raps.clear()
	for i in 4:
		raps.append(unit("raptor", at(330 + i * 16, 110)))
	for r in raps:
		r.cmd_move(at(700, 160), true)
	var hitting := await wait_for(func() -> bool: return raps.filter(func(r: Unit) -> bool: return r.target == bar).size() >= 3, 6.0)
	check(hitting, "(2b) with nobody about, the Raptors go for the Barracks")
	mus.clear()
	for i in 2:
		mus.append(unit("musketeer", at(330 + i * 24, 230), 1))
	var switched := await wait_for(func() -> bool: return raps.filter(func(r: Unit) -> bool: return not r.dead and r.target is Unit).size() >= 3, 3.0)
	check(switched, "(2b) Musketeers come into reach: the Raptors leave the Barracks for them (%d)" % raps.filter(func(r: Unit) -> bool: return not r.dead and r.target is Unit).size())
	for u in raps + mus:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	await wait(0.2)

	# 3: the Bloater's cloud eats buildings
	bar.hp = bar.max_hp
	var far: Building = g._add_building("barracks", 1, origin + Vector2i(2, 12), true)
	var far_hp: float = far.hp
	var bl := unit("bloater", bar.center() + Vector2(0, bar.rect().size.y * 0.5 + 10.0))
	bl.gas = 100.0
	g.bloat_burst(bl)
	g.consume_unit(bl)
	var h1: float = bar.hp
	check(h1 < bar.max_hp, "(3) the burst hurts the Barracks (%.0f / %.0f)" % [h1, bar.max_hp])
	await wait(3.0)
	var lost: float = h1 - bar.hp
	var want: float = float(Defs.BLOAT["dps"]) * float(Defs.BLOAT["buildings"]) * 3.0
	check(lost > want * 0.8 and lost < want * 1.25, "(3) the cloud eats it: %.1f in 3 s (expected ~%.1f)" % [lost, want])
	check(far.hp == far_hp, "(3) a building outside the cloud is untouched")

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
