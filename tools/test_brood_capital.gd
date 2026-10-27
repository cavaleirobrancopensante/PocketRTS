extends SceneTree
## The Brood CAPITAL (design_principles 2 and 3: economy forces expansion, drop-offs make placement matter):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_capital.gd
##  1. grubs unload only at the capital (the first Burrow), never at a nearer second one
##  2. the capital dies: the next oldest Burrow takes over (no ground passes on: the pits own it, 0.14.37)
##  3. cancelling a hatching egg refunds the cost but NOT the egg
##  4. eggs are laid every 9 s (was 6)
##  5. pit crews grow with distance from the capital (base 6); pits need swamp joined to it and reach grows with Clutch Mounds
## (each pit's own ground and its circle: tools/test_brood_pit_ground.gd)
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
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
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


## A free spot of w x h cells (solid ground, one height) for a test building.
func free_spot(near: Vector2i, w: int, h: int) -> Vector2i:
	for r in range(6, 40):
		for y in range(near.y - r, near.y + r):
			for x in range(near.x - r, near.x + r):
				var ok := true
				for yy in h:
					for xx in w:
						var c := Vector2i(x + xx, y + yy)
						if not g.in_map(c) or not g.is_free(c):
							ok = false
							break
					if not ok:
						break
				if ok:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func hall() -> Building:
	var hs: Array = g.halls_of(0)
	return hs[0] if not hs.is_empty() else null


func _run() -> void:
	var p: Dictionary = g.players[0]
	var cap := hall()
	check(g.capital(0) == cap, "0. the starting Burrow is the capital")
	check(g.capital(1) == null, "   a Crown player has none")
	# 1. a second Burrow right beside a pit: still no unloading there
	var pit: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "feeding_pit":
			pit = b
	check(pit != null, "   a starting Feeding Pit")
	var spot := free_spot(pit.cell, 5, 4)
	var h2: Building = g._add_building("hive", 0, spot, true)
	await wait(0.3)
	check(g.nearest_hall(pit.center(), 0) != null, "   (second Burrow stands)")
	check(g.dropoff_hall(pit.center(), 0) == cap and g.dropoff_hall(h2.center(), 0) == cap, "1. the drop-off is the capital for every pit and spot")
	g.ais.clear()
	await wait(1.0)
	check(cap.life != null and cap.life.queen != null and cap.life.queen.visible and not h2.life.queen.visible, "   the Queen sits at the capital only (still sprite)")
	var soil_pit0: float = pit.soil
	p["gold"] = 0
	var got: bool = await wait_for(func() -> bool: return int(p["gold"]) > 0, 90.0)
	check(got and pit.soil < soil_pit0 and cap.soil == 0.0 and h2.soil == 0.0 and cap.reserve() == 0.0,
		"   food arrives, drawn from the pit's own ground; the Burrows have none (%d gold; pit %d -> %d, capital %d, second %d)" % [int(p["gold"]), int(soil_pit0), int(pit.soil), int(cap.soil), int(h2.soil)])
	# 3/4. eggs
	check(Defs.EGG_TIME == 9.0, "4. EGG_TIME is 9 s (was 6)")
	cap.eggs = 0
	cap.egg_t = 0.0
	var t0: float = g.clock
	var laid: bool = await wait_for(func() -> bool: return cap.eggs >= 1, 20.0)
	var dt: float = g.clock - t0
	check(laid and dt > 8.4 and dt < 10.0, "   first egg after %.1f s (about 9; no Clutch Mounds)" % dt)
	p["gold"] = 500
	cap.eggs = 3
	check(g.train(cap, "grub") == "" and cap.eggs == 2, "3. a hatching Raptor uses an egg (%d left)" % cap.eggs)
	var gold1: int = int(p["gold"])
	g.cancel_train(cap)
	check(cap.eggs == 2 and cap.queue.is_empty(), "   cancelled: the egg is NOT given back (%d eggs)" % cap.eggs)
	check(int(p["gold"]) > gold1, "   the biomass is refunded (%d -> %d)" % [gold1, int(p["gold"])])
	g.train(cap, "grub")
	g.train(cap, "grub")
	var e0: int = cap.eggs
	g.cancel_train_at(cap, 0)
	check(cap.eggs == e0, "   cancelling one in the middle of the line neither (%d eggs)" % cap.eggs)
	# 5. crew by distance and reach by swamp
	var near_pit := pit
	var dn: float = g.capital_dist(0, near_pit.center())
	check(int(Defs.BUILDINGS["feeding_pit"]["crew"]) == 6 and near_pit.crew_max() == 6 + maxi(0, int((dn - Defs.FOOD_NEAR) / Defs.PIT_CREW_STEP)), "5. a pit %.1f tiles out takes %d (base 6)" % [dn, near_pit.crew_max()])
	var reach0: float = g.swamp_reach[0]
	check(reach0 > 9.0 and reach0 <= Defs.BROOD_RESOURCE_MAX_D, "   the swamp reaches %.1f tiles from the capital" % reach0)
	var far_cell := _cell_at(cap, reach0 + 6.0)
	check(far_cell.x >= 0, "   (found a free cell %.0f tiles out)" % (reach0 + 6.0))
	check(_placeable(cap, reach0 + 0.5).x < 0, "   no pit farther than the swamp's reach can be placed")
	var why: String = g.placement_problem(0, "feeding_pit", far_cell, true)
	check(why != "", "   a pit beyond the swamp is refused (%s)" % why)
	# a Clutch Mound at the swamp's edge pushes the reach out
	# (the mound goes at the swamp's edge on a side with room to grow: not into a corner or a cliff)
	var vent: Building = null
	var fc2 := Vector2i(-1, -1)
	var reach1 := reach0
	var c0: Vector2 = cap.center() / Defs.TILE
	var cands: Array = []
	for y in range(int(c0.y - reach0), int(c0.y + reach0)):
		for x in range(int(c0.x - reach0), int(c0.x + reach0)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell) or not g._footprint_open(cell, Vector2i(2, 2)) or not g.margin_free(cell, Vector2i(2, 2)):
				continue
			var dd := (Vector2(cell) + Vector2(1, 1)).distance_to(c0)
			if dd > reach0 - 7.0 and dd < reach0 - 1.0 and g.placement_problem(0, "clutch_mound", cell, true) == "":
				cands.append(cell)
	# (the outermost first: a mound near the swamp's edge pushes the reach out the most)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) + Vector2.ONE).distance_to(c0) > (Vector2(b) + Vector2.ONE).distance_to(c0))
	for edge in cands:
		vent = g._add_building("clutch_mound", 0, edge, true)
		g._update_swamp()
		await wait(0.3)
		reach1 = g.swamp_reach[0]
		fc2 = _placeable(cap, reach0 + 0.5)
		if fc2.x >= 0:
			break
		g._remove_quietly(vent)
		vent = null
		g._update_swamp()
		await wait(0.1)
	check(vent != null, "   (found a side with room for a Clutch Mound: %d tried)" % cands.size())
	check(reach1 > reach0 + 3.0, "   a Clutch Mound at the edge: reach %.1f -> %.1f tiles" % [reach0, reach1])
	check(fc2.x >= 0, "   a pit farther than the old reach (%.1f) is now allowed (cell %s)" % [reach0, str(fc2)])
	if fc2.x < 0:
		fc2 = _cell_at(cap, reach0)
	var far_pit: Building = g._add_building("feeding_pit", 0, fc2, true)
	check(far_pit.crew_max() > 6, "   and takes more hands than a near one (%d at %.1f tiles)" % [far_pit.crew_max(), g.capital_dist(0, far_pit.center())])
	# no count cap: any spot whose ground circle is free of our pits' takes another
	var free_pit := _placeable(cap, 0.0)
	var many: String = g.placement_problem(0, "feeding_pit", free_pit, true) if free_pit.x >= 0 else "no spot"
	check(g.econ_count(0, "feeding_pit") >= 2 and many == "", "   no count cap on pits (%d standing; another fits at %s)" % [g.econ_count(0, "feeding_pit"), str(free_pit)])
	# 2. the capital falls
	var pit_soil: float = pit.soil
	cap.hp = 0.0
	cap.die()
	await wait(0.3)
	var nc: Building = g.capital(0)
	check(nc == h2 and nc != cap, "2. the capital died: the next oldest Burrow is the capital")
	check(nc != null and nc.soil == 0.0 and absf(pit.soil - pit_soil) < 40.0, "   no ground passes on (the new capital %d); the pits keep their own (%d vs %d)" % [int(nc.soil) if nc else -1, int(pit.soil), int(pit_soil)])
	check(g.dropoff_hall(pit.center(), 0) == h2, "   grubs now unload there")
	await wait(1.0)
	check(h2.life.queen.visible, "   and the Queen is at the new capital")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


## A free cell (any footprint of 3x3 open, on land) about d tiles from the capital, on the side away from the enemy.
func _cell_at(cap: Building, d: float) -> Vector2i:
	var c0: Vector2 = cap.center() / Defs.TILE
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d - 3), int(c0.y + d + 4)):
		for x in range(int(c0.x - d - 3), int(c0.x + d + 4)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell) or not g._footprint_open(cell, Vector2i(2, 2)) or not g.margin_free(cell, Vector2i(2, 2)):
				continue
			var dd := (Vector2(cell) + Vector2(1, 1)).distance_to(c0)
			var sc := absf(dd - d)
			if sc < bs:
				bs = sc
				best = cell
	return best


## A cell where a Feeding Pit can be placed (placement rules) whose middle is at least d tiles from the capital.
func _placeable(cap: Building, d: float) -> Vector2i:
	var c0: Vector2 = cap.center() / Defs.TILE
	for y in range(int(c0.y - 40), int(c0.y + 40)):
		for x in range(int(c0.x - 40), int(c0.x + 40)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell) or (Vector2(cell) + Vector2(1.5, 1.5)).distance_to(c0) < d:
				continue
			if g.placement_problem(0, "feeding_pit", cell, true) == "" and g.margin_free(cell, Vector2i(3, 3)):
				return cell
	return Vector2i(-1, -1)
