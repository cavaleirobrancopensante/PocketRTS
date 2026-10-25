extends SceneTree
## The Brood's Clutch Mound spreads the swamp (0.12.84; the Spore Vent and SEED VENT are gone):
##   godot --headless --fixed-fps 30 --script res://tools/test_mound_swamp.gd            (rules, built by a grub, retraction)
##   godot --headless --fixed-fps 30 --script res://tools/test_mound_swamp.gd -- ai      (the computer plants mounds, its swamp grows)
##  1. a mound is refused off swamp, and off swamp joined to a Burrow's; allowed on joined swamp
##  2. a grub is used up, the price paid; finished, the mound's swamp (10 tiles) spreads over a few seconds
##     and the pits' reach grows
##  3. destroying the mound retracts the swamp only it held
##  4. (ai) the Brood AI builds mounds and its swamp grows
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var ai_mode := false


func _initialize() -> void:
	ai_mode = OS.get_cmdline_user_args().has("ai")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "hard" if ai_mode else "you", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
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
		if not ai_mode:
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


func swamp_cells(team: int) -> int:
	var n := 0
	for v in (g.swamp[team] as PackedByteArray):
		n += int(v)
	return n


func _spot(cap: Building, d: float) -> Vector2i:
	var c0: Vector2 = cap.center() / Defs.TILE
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d - 4), int(c0.y + d + 5)):
		for x in range(int(c0.x - d - 4), int(c0.x + d + 5)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell) or not g._footprint_open(cell, Vector2i(2, 2)) or not g.margin_free(cell, Vector2i(2, 2)):
				continue
			if g.placement_problem(0, "clutch_mound", cell, true) != "":
				continue
			var sc := absf((Vector2(cell) + Vector2(1, 1)).distance_to(c0) - d)
			if sc < bs:
				bs = sc
				best = cell
	return best


func _run() -> void:
	if ai_mode:
		await _run_ai()
	else:
		await _run_rules()
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _run_rules() -> void:
	g.explored.fill(1)
	var cap: Building = g.capital(0)
	var p: Dictionary = g.players[0]
	p["gold"] = 2000
	check(Defs.BUILDINGS["clutch_mound"]["swamp"] == 10, "the mound's swamp radius is 10 tiles")
	check(not Defs.BUILDINGS.has("spore_vent") and not g.has_method("seed_vent"), "the Spore Vent and SEED VENT are gone")
	var reach0: float = g.swamp_reach[0]
	var cells0 := swamp_cells(0)
	# 1. refused off swamp
	var far := Vector2i(-1, -1)
	var c0: Vector2 = cap.center() / Defs.TILE
	for y in range(int(c0.y - 40), int(c0.y + 40)):
		for x in range(int(c0.x - 40), int(c0.x + 40)):
			var cell := Vector2i(x, y)
			if g.in_map(cell) and g._footprint_open(cell, Vector2i(2, 2)) and (Vector2(cell) + Vector2(1, 1)).distance_to(c0) > reach0 + 14.0 and (Vector2(cell) + Vector2(1, 1)).distance_to(c0) < reach0 + 20.0:
				far = cell
	var why: String = g.placement_problem(0, "clutch_mound", far, true)
	check(far.x >= 0 and why != "", "1. a mound off the swamp is refused (%s)" % why)
	# a swamp patch NOT joined to a Burrow's: a rooted-style island is made by hand
	var island := Vector2i(-1, -1)
	for y in range(int(c0.y - 30), int(c0.y + 30)):
		for x in range(int(c0.x - 30), int(c0.x + 30)):
			var cell := Vector2i(x, y)
			if g.in_map(cell) and g._footprint_open(cell, Vector2i(2, 2)) and (Vector2(cell) + Vector2(1, 1)).distance_to(c0) > reach0 + 8.0 and (Vector2(cell) + Vector2(1, 1)).distance_to(c0) < reach0 + 14.0:
				island = cell
	g._update_swamp()
	var sw: PackedByteArray = g.swamp[0]
	for yy in 2:
		for xx in 2:
			sw[g.idx(island + Vector2i(xx, yy))] = 1
	g.swamp[0] = sw
	g._update_conn()
	why = g.placement_problem(0, "clutch_mound", island, true)
	check(why.contains("joined"), "   swamp that is not joined to a Burrow's does not count (%s)" % why)
	g._update_swamp()
	# joined swamp, near its edge
	var spot := _spot(cap, reach0 - 2.0)
	check(spot.x >= 0, "   a spot on joined swamp near the edge %s" % str(spot))
	check(g.placement_problem(0, "clutch_mound", spot, false) == "", "   allowed there")
	# 2. built by a grub
	var grubs0: int = g.units.filter(func(u): return u.team == 0 and u.kind == "grub" and not u.dead).size()
	var gold0: int = p["gold"]
	var grub = g.units.filter(func(u): return u.team == 0 and u.kind == "grub" and not u.dead)[0]
	var m: Building = g.place_building(0, "clutch_mound", spot, [grub])
	check(m != null and p["gold"] == gold0 - int(Defs.BUILDINGS["clutch_mound"]["cost"]), "2. placed: a ghost, the price paid")
	var end: float = g.clock + 60.0
	while g.clock < end and not (m.built or m.dead):
		await physics_frame
	check(m.built and not m.dead, "   the grub became the mound and it finished (%.0f s)" % (g.clock - (end - 60.0)))
	var grubs1: int = g.units.filter(func(u): return u.team == 0 and u.kind == "grub" and not u.dead).size()
	check(grubs1 == grubs0 - 1 and not is_instance_valid(grub) or grub.dead, "   the grub was used up (%d -> %d)" % [grubs0, grubs1])
	await wait(1.0)
	var part := swamp_cells(0)
	await wait(14.0)
	var cells1 := swamp_cells(0)
	check(part < cells1 and cells1 > cells0 + 100, "   the swamp spreads over a few seconds (%d -> %d -> %d cells)" % [cells0, part, cells1])
	var mc: Vector2i = g.cell_of(m.center())
	var covered := 0
	for dx in range(-10, 11):
		if g.in_map(mc + Vector2i(dx, 0)) and g.swamp[0][g.idx(mc + Vector2i(dx, 0))] == 1:
			covered += 1
	check(covered >= 17, "   about 10 tiles each way along the row of the mound (%d of 21 cells)" % covered)
	var reach1: float = g.swamp_reach[0]
	check(reach1 > reach0 + 2.0, "   the pits' reach grows (%.1f -> %.1f tiles)" % [reach0, reach1])
	# the chain: a second mound on the new swamp is allowed
	var spot2 := _spot(cap, reach1 - 2.0)
	check(spot2.x >= 0 and spot2 != spot, "   a second mound can be planted on the new swamp (chain) %s" % str(spot2))
	# 3. it dies: the swamp only it held retracts
	var peak := swamp_cells(0)
	m.take_damage(9999999.0, null)
	await wait(0.8)
	var mid := swamp_cells(0)
	check(m.dead and mid < peak and mid > cells0 + 4, "   it retreats gradually, not at once (%d cells after 0.8 s, from %d)" % [mid, peak])
	await wait(9.0)
	check(m.dead and swamp_cells(0) <= cells0 + 4, "3. the mound is destroyed: its swamp retracts (%d cells, was %d)" % [swamp_cells(0), cells0])
	check(absf(float(g.swamp_reach[0]) - reach0) < 1.0, "   the pits' reach is back (%.1f)" % float(g.swamp_reach[0]))
	check(g.placement_problem(0, "clutch_mound", spot2, true) != "" , "   and the far spot is refused again")


func _run_ai() -> void:
	var cells0 := swamp_cells(0)
	var reach0: float = g.swamp_reach[0]
	Engine.time_scale = 8.0
	var end: float = g.clock + 420.0
	var maxm := 0
	while g.clock < end:
		await physics_frame
		maxm = maxi(maxm, g.buildings.filter(func(b): return b.team == 0 and b.kind == "clutch_mound" and not b.dead).size())
	Engine.time_scale = 1.0
	var cap: Building = g.capital(0)
	for b in g.buildings:
		if b.team == 0 and b.kind == "clutch_mound":
			print("  mound at %.1f tiles from the capital, built %s, dead %s" % [b.center().distance_to(cap.center()) / Defs.TILE, b.built, b.dead])
	print("  no-room %s, reach %.1f, pits %d" % [str(g.ais[0]._no_room.keys()), g.swamp_reach[0], g.econ_count(0, "feeding_pit")])
	check(maxm >= 1, "4. the Brood AI built Clutch Mounds (%d at most at once)" % maxm)
	check(swamp_cells(0) > cells0 + 20 and g.swamp_reach[0] > reach0 + 2.5, "   its swamp grew (%d -> %d cells, reach %.1f -> %.1f)" % [cells0, swamp_cells(0), reach0, g.swamp_reach[0]])
