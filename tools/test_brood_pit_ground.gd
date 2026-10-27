extends SceneTree
## PIT GROUND (owner's decision 2026-10-27; design_principles 2: an economy that runs down and forces
## expansion; 3: placement that matters, shown before you click):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_pit_ground.gd
##  1. every Feeding Pit has its own ground (Defs.PIT_GROUND); two pits draw separately; grubs draw a real pit's
##  2. a spent pit pays nothing (barren, efficiency 0)
##  3. circles: a pit whose circle overlaps one of your living pits' is refused with the message; exactly
##     2 x PIT_CLAIM apart is fine; another player's pit doesn't count; place_building refuses it too
##  4. a dead pit leaves its circle as old ground; a pit raised over it takes over what was left; over two
##     old spots it takes the SMALLEST; the spots merge into its claim; a pit on fresh land gets it all
##  5. save and load keep the pits' ground and the old spots
##  6. the computer's pit spots obey the circles and stay off spent old ground
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
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
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


func pits(team: int) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == team and b.kind == "feeding_pit" and not b.dead)


## A cell where team 0 may place a Feeding Pit (every rule), whose centre is `d0`..`d1` tiles from `from` (px).
func spot_near(from: Vector2, d0: float, d1: float) -> Vector2i:
	var c0: Vector2 = from / Defs.TILE
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d1 - 3), int(c0.y + d1 + 3)):
		for x in range(int(c0.x - d1 - 3), int(c0.x + d1 + 3)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell):
				continue
			var dd: float = g.pit_mid(cell).distance_to(from) / Defs.TILE
			if dd < d0 or dd > d1:
				continue
			if g.placement_problem(0, "feeding_pit", cell, true) != "" or not g.margin_free(cell, Vector2i(3, 3)):
				continue
			if dd < bs:
				bs = dd
				best = cell
	return best


func _run() -> void:
	var cap: Building = g.capital(0)
	var r: float = Defs.PIT_CLAIM * Defs.TILE
	check(Defs.PIT_GROUND == 3000 and Defs.PIT_CLAIM == 5.0 and int(Defs.BUILDINGS["feeding_pit"]["crew"]) == 6, "0. the numbers: 3,000 ground a pit, a 5-tile circle, crew 6")
	check(cap != null and cap.reserve() == 0.0 and cap.soil == 0.0, "   the capital has no ground of its own")
	var start: Building = pits(0)[0] if not pits(0).is_empty() else null
	check(start != null and is_equal_approx(start.soil, float(Defs.PIT_GROUND)), "   the starting pit has its own fresh ground (%d)" % (int(start.soil) if start else -1))
	# 1. two pits draw separately
	var c2: Vector2i = spot_near(start.center(), 2.0 * Defs.PIT_CLAIM, 2.0 * Defs.PIT_CLAIM + 4.0)
	check(c2.x >= 0, "1. (a spot for a second pit just outside the first one's circle: %s)" % str(c2))
	var p2: Building = g._add_building("feeding_pit", 0, c2, true)
	await wait(0.2)
	check(is_equal_approx(p2.soil, float(Defs.PIT_GROUND)), "   the second pit has fresh ground of its own (%d)" % int(p2.soil))
	var s1: float = start.soil
	var v: float = g.pit_load(p2)
	check(v > 0.0 and p2.soil < float(Defs.PIT_GROUND) and is_equal_approx(start.soil, s1), "   a load from the second draws only on its ground (%.1f: %d left; the first %d -> %d)" % [v, int(p2.soil), int(s1), int(start.soil)])
	# grubs at work draw on the real pit
	var s0: float = start.soil
	await wait(25.0)
	check(start.soil < s0, "   grubs hauling from the first pit draw on its own ground (%d -> %d)" % [int(s0), int(start.soil)])
	# 2. a spent pit pays nothing
	p2.soil = 0.0
	var gold0: int = int(g.players[0]["gold"])
	var v2: float = g.pit_load(p2)
	var eff: Array = p2.efficiency()
	check(v2 == 0.0 and p2.barren() and g.load_value(p2) == 0.0 and (eff.is_empty() or float(eff[0]) == 0.0), "2. a spent pit pays nothing (load %.1f, barren, efficiency %s)" % [v2, str(eff[0]) if not eff.is_empty() else "-"])
	check(int(g.players[0]["gold"]) == gold0, "   and no biomass came in")
	check(start.soil > 0.0, "   while the other pit still has its ground (%d)" % int(start.soil))
	# 3. circles may not overlap
	var near_cell := Vector2i(-1, -1)
	for y in range(c2.y - 8, c2.y + 9):
		for x in range(c2.x - 8, c2.x + 9):
			var cc := Vector2i(x, y)
			var dd: float = g.pit_mid(cc).distance_to(p2.center()) / Defs.TILE
			if dd > 4.0 and dd < 9.0 and g.pit_overlaps(0, g.pit_mid(cc)).size() > 0:
				near_cell = cc
	var why: String = g.placement_problem(0, "feeding_pit", near_cell, true) if near_cell.x >= 0 else ""
	check(why == "Too close to another Feeding Pit: their grounds would overlap.", "3. an overlapping circle is refused: \"%s\"" % why)
	check(Loc.table("pt").has(why) and Loc.table("es").has(why), "   the message has pt and es")
	check(not Game.pit_circles_overlap(Vector2.ZERO, Vector2(2.0 * r, 0.0)) and Game.pit_circles_overlap(Vector2.ZERO, Vector2(2.0 * r - 8.0, 0.0)), "   centres exactly 10 tiles apart are fine, a little less overlaps")
	g.players[0]["gold"] = 1000
	var refused: Building = g.place_building(0, "feeding_pit", near_cell, []) if near_cell.x >= 0 else null
	check(refused == null, "   place_building refuses it too")
	var foe_pit: Building = null
	for b in pits(1):
		foe_pit = b
	check(foe_pit != null and g.pit_overlaps(0, foe_pit.center()).is_empty() and g.pit_overlaps(1, foe_pit.center() + Vector2(r, 0)).size() == 1, "   only your own pits' circles count")
	# a planned (ghost) pit claims its circle too
	var c3: Vector2i = spot_near(start.center(), 2.0 * Defs.PIT_CLAIM, 2.0 * Defs.PIT_CLAIM + 10.0)
	var gh: Building = g.place_building(0, "feeding_pit", c3, []) if c3.x >= 0 else null
	check(gh != null and gh.ghost and g.pit_overlaps(0, gh.center() + Vector2(r, 0)).has(gh), "   a planned pit's circle counts as soon as it is placed")
	if gh:
		gh.die()
		await wait(0.2)
	check(g.pit_spots.is_empty(), "   a cancelled plan leaves no old ground (%d spots)" % g.pit_spots.size())
	# 4. old ground
	p2.soil = 500.0
	var at2: Vector2i = p2.cell
	var mid2: Vector2 = p2.center()
	p2.hp = 0.0
	p2.die()
	await wait(0.3)
	check(g.pit_spots.size() == 1 and is_equal_approx(float(g.pit_spots[0][1]), 500.0), "4. a dead pit leaves its circle as old ground (%d spots, %s left)" % [g.pit_spots.size(), str(g.pit_spots[0][1]) if not g.pit_spots.is_empty() else "-"])
	check(is_equal_approx(g.pit_ground_at(mid2), 500.0) and is_equal_approx(g.pit_ground_at(mid2 + Vector2(1.5 * r, 0)), 500.0), "   a pit whose circle overlaps it would take over 500")
	check(g.pit_ground_at(mid2 + Vector2(2.0 * r + 40.0, 0)) == float(Defs.PIT_GROUND), "   one clear of it gets fresh ground")
	# a second old spot overlapping the same place, with more left
	g.pit_spots.append([mid2 + Vector2(1.6 * r, 0.0), 1200.0, 0])
	check(is_equal_approx(g.pit_ground_at(mid2 + Vector2(0.8 * r, 0.0)), 500.0), "   over two old spots (500 and 1,200) it takes the smallest: %d" % int(g.pit_ground_at(mid2 + Vector2(0.8 * r, 0.0))))
	g.pit_spots.remove_at(1)
	check(g.placement_problem(0, "feeding_pit", at2, true) == "", "   (the spot is free to build on again)")
	var p3: Building = g._add_building("feeding_pit", 0, at2, true)
	await wait(0.2)
	check(is_equal_approx(p3.soil, 500.0), "   the pit rebuilt there takes over what was left (%d), not fresh ground" % int(p3.soil))
	check(g.pit_spots.is_empty(), "   and the old spot merged into its claim (%d spots left)" % g.pit_spots.size())
	# a spent spot: rebuilding there yields nothing
	p3.soil = 0.0
	p3.hp = 0.0
	p3.die()
	await wait(0.3)
	check(g.pit_spots.size() == 1 and float(g.pit_spots[0][1]) == 0.0, "   a spent pit leaves spent old ground")
	var p4: Building = g._add_building("feeding_pit", 0, at2 + Vector2i(2, 0), true)
	await wait(0.2)
	check(p4.soil == 0.0 and p4.barren(), "   a pit raised beside a spent spot can't refresh the ground (%d)" % int(p4.soil))
	# 5. save and load
	g._remove_quietly(p4)
	await wait(0.2)
	g.pit_spots.clear()
	g.pit_spots.append([mid2, 777.0, 0])
	start.soil = 1234.0
	var start_cell: Vector2i = start.cell
	SaveGame.save(g, {"map": "hollowfen", "seed": 4242})
	var d := SaveGame.peek()
	SaveGame.restore(g, d)
	await wait(0.5)
	var st2: Building = null
	for b in pits(0):
		if b.cell == start_cell:
			st2 = b
	check(st2 != null and is_equal_approx(st2.soil, 1234.0), "5. after save and load the pit keeps its ground (%d)" % (int(st2.soil) if st2 else -1))
	check(g.pit_spots.size() == 1 and is_equal_approx(float(g.pit_spots[0][1]), 777.0) and (g.pit_spots[0][0] as Vector2).distance_to(mid2) < 1.0, "   and the old spot is still there (%s)" % str(g.pit_spots))
	# 6. the computer's spots
	var ai: AI = null
	for a in g.ais:
		if a.team == 1:
			ai = a
	var ok_ai := ai != null
	if ai:
		var foe_cap: Building = g.capital(1)
		var spent_at: Vector2 = Vector2.INF
		var fp: Array = pits(1)
		if not fp.is_empty():
			# its starting pit dies spent: the next pit must not take that spent ground over
			var fpit: Building = fp[0]
			fpit.soil = 0.0
			spent_at = fpit.center()
			fpit.hp = 0.0
			fpit.die()
			await wait(0.3)
		var placed: Array = []
		for i in 4:
			var sp: Vector2i = ai._econ_spot("feeding_pit")
			if sp.x < 0:
				break
			var nb: Building = g._add_building("feeding_pit", 1, sp, true)
			placed.append(nb)
			await wait(0.1)
		for b in placed:
			if not g.pit_overlaps(1, b.center(), b).is_empty():
				ok_ai = false
			if b.soil <= 0.0:
				ok_ai = false
		check(ok_ai and placed.size() >= 2 and foe_cap != null, "6. the computer's %d new pits keep their circles apart and stay off spent old ground (%s)" % [placed.size(), str(placed.map(func(b): return int(b.soil)))])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
