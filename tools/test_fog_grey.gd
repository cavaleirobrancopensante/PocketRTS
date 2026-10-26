extends SceneTree
## The fog of war is grey only (as in StarCraft 2): the whole map's ground is under a grey fog
## from the start and your side's sight is clear; the enemy base (buildings, units, its swamp,
## effects there) stays hidden until seen, then its buildings are remembered under the grey;
## a building may be ordered anywhere, and an enemy building you had never seen in the way
## fails it when the worker gets there ("the spot is blocked", cost refunded). Also: flowers
## under an unseen enemy building stay until it's seen, the spectator's per-player view, and
## the explored map an older save brings back.
##   godot --headless --fixed-fps 30 --script res://tools/test_fog_grey.gd
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _make(demo: bool) -> Game:
	Defs.line_mode = false
	Defs.gear_mode = true
	Defs.cw_roster = false
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = demo
	g.factions = ["crown", "brood"]
	g.sides = [0, 1]
	root.add_child(g)
	return g


## One simulated step of the whole game (units, buildings, the game's own tick).
func _step(g: Game, secs: float) -> void:
	for i in int(secs * 30.0):
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)


func _hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t) and not b.dead:
			return b
	return null


## The fog picture's alpha values: {value: count}.
func _alphas(g: Game) -> Dictionary:
	var data := g.fog_img.get_data()
	var out := {}
	for i in range(1, data.size(), 2):
		out[data[i]] = int(out.get(data[i], 0)) + 1
	return out


func _only_grey(al: Dictionary) -> bool:
	return al.keys().all(func(v) -> bool: return v == 0 or v == Game.FOG_GREY)


func _alpha_at(g: Game, c: Vector2i) -> int:
	return g.fog_img.get_data()[g.idx(c) * 2 + 1]


## Team t's swamp cells and how many of them the minimap shows.
func _swamp_shown(g: Game, t: int) -> Vector2i:
	var sw: PackedByteArray = g.swamp[t]
	var n := 0
	var shown := 0
	for i in g.W * g.H:
		if sw[i] == 1:
			n += 1
			if g.swamp_img.get_pixel(i % g.W, i / g.W).a > 0.0:
				shown += 1
	return Vector2i(n, shown)


## The minimap shows exactly the enemy swamp on ground your side has looked at.
func _swamp_follows_explored(g: Game, t: int) -> bool:
	var sw: PackedByteArray = g.swamp[t]
	for i in g.W * g.H:
		if sw[i] == 1 and (g.swamp_img.get_pixel(i % g.W, i / g.W).a > 0.0) != (g.explored[i] == 1):
			return false
	return true


func _unexplored_round(g: Game, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cc := c + Vector2i(dx, dy)
			if g.in_map(cc) and g.explored[g.idx(cc)] == 1:
				return false
	return true


## A free spot for `kind` (the computer's rule: open ground, no ramp near) on ground your side
## has never looked at, as far as can be from all the `avoid` cells.
func _far_spot(g: Game, kind: String, avoid: Array, clear := 12) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := -1.0
	for y in range(4, g.H - 6, 2):
		for x in range(4, g.W - 6, 2):
			var c := Vector2i(x, y)
			if g.placement_problem(0, kind, c, true) != "" or not _unexplored_round(g, c, clear):
				continue
			var d := INF
			for a in avoid:
				d = minf(d, Vector2(c - (a as Vector2i)).length())
			if d > bd:
				bd = d
				best = c
	return best


## A free cell `dist` cells or so from c that units walking from it can reach c's foot from.
func _walk_spot(g: Game, c: Vector2i, foot: Vector2i, dist: int) -> Vector2i:
	for r in range(dist, dist + 8):
		for a in 32:
			var cc := c + Vector2i(roundi(cos(a * TAU / 32.0) * r), roundi(sin(a * TAU / 32.0) * r))
			if g.is_free(cc) and g.is_free(foot) and not g.astar.get_id_path(cc, foot).is_empty():
				return cc
	return Vector2i(-1, -1)


func _run() -> void:
	var g := _make(false)
	await process_frame
	await process_frame
	g._update_swamp()
	g._update_vis()
	var me := _hall(g, 0)
	var hive := _hall(g, 1)
	check("both halls stand", me != null and hive != null)
	var hc := g.cell_of(hive.center())
	var n := g.W * g.H
	# ---- the start: all the ground grey, your base clear, nothing black
	var al := _alphas(g)
	check("the fog picture holds only grey and clear (no darker unexplored shade)", _only_grey(al), str(al))
	check("most of the map is grey at the start", int(al.get(Game.FOG_GREY, 0)) > n * 0.8, "%d of %d" % [int(al.get(Game.FOG_GREY, 0)), n])
	check("your base is clear", _alpha_at(g, g.cell_of(me.center())) == 0)
	check("the enemy base is grey, not black", _alpha_at(g, hc) == Game.FOG_GREY)
	# ---- the enemy base: hidden until seen
	check("the enemy hall is hidden before it's seen", not hive.visible and not hive.seen_by_human)
	var foes: Array = g.units.filter(func(u) -> bool: return u.team == 1)
	check("the enemy's units are hidden", not foes.is_empty() and foes.all(func(u) -> bool: return not u.visible), "%d units" % foes.size())
	var sw := _swamp_shown(g, 1)
	check("the enemy's swamp is off the minimap", sw.x > 0 and sw.y == 0, "%d swamp cells, %d shown" % [sw.x, sw.y])
	var fx := g.spawn_effect("dust", hive.center())
	var fx2 := g.spawn_effect("dust", me.center())
	check("an effect where you have never looked is hidden, one at home shows", not fx.visible and fx2.visible)
	var loop_fx := g.spawn_effect("dust", hive.center() + Vector2(0, 24), 1.0, true)
	var shot := Shot.new()
	shot.launch(g, "ball", hive.center(), hive.center() + Vector2(60, 0), 900.0)
	check("a shot fired and landing there is hidden", not shot.visible)
	# ---- placement anywhere
	var far := _far_spot(g, "cottage", [me.cell, hive.cell])
	check("a free spot on never-seen ground found", far.x >= 0, str(far))
	check("a far-away spot you have never seen may be built on", g.placement_problem(0, "cottage", far) == "",
		"'%s' at %s" % [g.placement_problem(0, "cottage", far), far])
	check("and its ghost cells read free", g.looks_free(0, far) and g.looks_free(0, far + Vector2i(1, 1)))
	check("an enemy hall you have never seen doesn't stop the order", g.placement_problem(0, "cottage", hive.cell) == "",
		g.placement_problem(0, "cottage", hive.cell))
	check("nor shows on the build grid", BuildGrid.cell_class(g, hive.cell) == BuildGrid.FREE)
	check("the computer's rule sees the map as it is", g.placement_problem(0, "cottage", hive.cell, true) == "Blocked.")
	check("the enemy's own placement sees your hall", g.placement_problem(1, "cottage", me.cell) == "Blocked.")
	check("off the map still blocks", g.placement_problem(0, "cottage", Vector2i(-1, -1)) == "Blocked.")
	# ---- seen once: remembered
	var scout: Unit = g._add_unit("musketeer", 0, hive.center() + Vector2(0, hive.rect().size.y * 0.5 + 40.0))
	g._update_vis()
	check("a scout at the enemy hall sees it", hive.visible and hive.seen_by_human)
	check("the looping effect shows once its ground is seen", loop_fx.visible)
	var sw2 := _swamp_shown(g, 1)
	check("the enemy swamp it looked at is on the minimap (and only that)", sw2.y > 0 and _swamp_follows_explored(g, 1), "%d of %d" % [sw2.y, sw2.x])
	check("a seen enemy building blocks the order", g.placement_problem(0, "cottage", hive.cell) == "Blocked.")
	check("and shows on the build grid", BuildGrid.cell_class(g, hive.cell) == BuildGrid.BUILDING)
	g.consume_unit(scout)
	g._update_vis()
	check("gone again: the hall is remembered under the grey", hive.visible and _alpha_at(g, hc) == Game.FOG_GREY)
	foes = g.units.filter(func(u) -> bool: return u.team == 1)
	check("and the enemy's units are hidden again", foes.all(func(u) -> bool: return not u.visible))
	check("the swamp looked at stays drawn", _swamp_shown(g, 1).y == sw2.y)
	# ---- flowers under an enemy building you haven't seen stay until you see it
	var deco_c := Vector2i(-1, -1)
	for i in g._deco_at:
		var c := Vector2i(i % g.W, i / g.W)
		if g.placement_problem(0, "cottage", c, true) == "" and _unexplored_round(g, c, 10):
			deco_c = c
			break
	if deco_c.x >= 0:
		var flowers: Array = g._deco_at[g.idx(deco_c)]
		var hut := g._add_building("brood_pen", 1, deco_c, true)
		check("an unseen enemy building leaves the flowers under it standing", flowers.all(func(s) -> bool: return s.visible))
		var eye: Unit = g._add_unit("musketeer", 0, hut.center() + Vector2(0, hut.rect().size.y * 0.5 + 30.0))
		g._update_vis()
		check("once seen, they are gone under it", hut.visible and flowers.all(func(s) -> bool: return not s.visible))
		g.consume_unit(eye)
		g._update_vis()
	else:
		print("(no walk-through decoration on unseen open ground: flowers check skipped)")
	# ---- an enemy building you had never seen fails the site when the worker gets there
	var pen_at := _far_spot(g, "barracks", [me.cell, hive.cell, deco_c], 14)
	check("an open spot for an enemy pen on never-seen ground", pen_at.x >= 0, str(pen_at))
	var pen := g._add_building("brood_pen", 1, pen_at, true)
	g._update_swamp()
	g._update_vis()
	check("a Brood Pen out there stands unseen", not pen.visible and not pen.seen_by_human)
	check("its swamp stays off the minimap", _swamp_follows_explored(g, 1))
	var site_at := pen_at + Vector2i(1, 1)
	check("you may order a Cottage over it", g.placement_problem(0, "cottage", site_at) == "", g.placement_problem(0, "cottage", site_at))
	var foot := Vector2i(-1, -1)            # a free cell at the pen's edge, by the planned site
	for c in [pen_at + Vector2i(1, 3), pen_at + Vector2i(2, 3), pen_at + Vector2i(0, 3), pen_at + Vector2i(-1, 1), pen_at + Vector2i(4, 1), pen_at + Vector2i(1, -1)]:
		if g.is_free(c):
			foot = c
			break
	var lab_cell := _walk_spot(g, g.cell_of(pen.center()), foot, 10)
	check("a spot for the labourer that can walk to it", lab_cell.x >= 0, str(lab_cell))
	var lab: Unit = g._add_unit("labourer", 0, g.cell_center(lab_cell))
	g._update_vis()
	check("the pen is still unseen from where the labourer starts", not pen.seen_by_human)
	var gold0 := int(g.players[0]["gold"])
	var site := g.place_building(0, "cottage", site_at, [lab])
	check("the order is taken (a ghost site)", site != null and site.ghost)
	check("and paid", int(g.players[0]["gold"]) == gold0 - int(Defs.BUILDINGS["cottage"]["cost"]))
	var t := 0.0
	while t < 60.0 and site != null and not site.dead:
		_step(g, 0.5)
		t += 0.5
	check("the site fails when the worker gets there", site == null or site.dead, "%.1f s" % t)
	check("its cost comes back", int(g.players[0]["gold"]) == gold0, "%d vs %d" % [int(g.players[0]["gold"]), gold0])
	var why := ""
	for ln in g.mlog.lines:
		if String(ln).contains("couldn't start a Cottage"):
			why = String(ln)
	check("as blocked (not unreachable)", why.contains("blocked"), why)
	check("the worker has seen the pen now (remembered)", pen.seen_by_human and pen.visible)
	check("the labourer lives on", is_instance_valid(lab) and not lab.dead)
	check("the minimap swamp still follows what was looked at", _swamp_follows_explored(g, 1))
	# ---- an older save's explored map comes back: the fog stays grey, the swamp follows it
	var b64 := Marshalls.raw_to_base64(g.explored)
	var all := PackedByteArray()
	all.resize(n)
	all.fill(1)
	g.explored = all
	g.fog_base_dirty = true
	g._update_vis()
	check("with everything explored: still only grey and clear", _only_grey(_alphas(g)))
	var sw3 := _swamp_shown(g, 1)
	check("and all the enemy swamp is drawn", sw3.y == sw3.x and sw3.x > 0, "%d of %d" % [sw3.y, sw3.x])
	g.explored = Marshalls.base64_to_raw(b64)
	g.fog_base_dirty = true
	g._update_vis()
	check("back to the saved map: the swamp follows it again", _swamp_follows_explored(g, 1))
	g.queue_free()
	await process_frame
	# ---- watching computers: one player's view
	var d := _make(true)
	await process_frame
	await process_frame
	d._update_swamp()
	var dhive := _hall(d, 1)
	d.view_team = 0
	d.refresh_fog()
	check("spectator, P1's eyes: only grey and clear", _only_grey(_alphas(d)), str(_alphas(d)))
	check("spectator, P1's eyes: the enemy hall is hidden", not dhive.visible)
	check("spectator, P1's eyes: its swamp is off the minimap", _swamp_shown(d, 1).y == 0)
	d.view_team = 1
	d.refresh_fog()
	var ds := _swamp_shown(d, 1)
	check("spectator, P2's eyes: its own hall and swamp show", dhive.visible and ds.y == ds.x and ds.x > 0, "%d of %d" % [ds.y, ds.x])
	d.view_team = -1
	d.refresh_fog()
	check("spectator, all vision: no fog drawn", not d.fog_sprite.visible and dhive.visible)
	d.queue_free()
	print("fog grey: %s" % ("ALL OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
