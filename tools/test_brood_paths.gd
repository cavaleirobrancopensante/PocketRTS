extends SceneTree
## BROOD PATHS (the owner's playtest, 2026-10-31):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_paths.gd
##  A. grubs bringing food from a Rootmaw 25+ tiles away reach the Brood Mother when her Sires are rooted close round
##     her (one-tile gaps between their footprints and hers): every grub delivers again and again, none stands stuck
##  B. a creature rooting over bodies (and a food pile) pushes them just outside its footprint, onto free ground the
##     grubs can walk to; their value and rot clock are kept (the Mother's growth and a building placed over a body too)
## Prints PASS / FAIL lines and "brood_paths: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
const T := Defs.TILE


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


## An open, level rectangle of w x h cells far from every start (its top-left cell).
func _open_area(w: int, h: int, skip: Array = []) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for u in g.units:
		if u.team == 1:
			starts.append(u.position)
	for y in range(3, g.H - h - 3):
		for x in range(3, g.W - w - 3):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in range(0, h, 2):
				for xx in range(0, w, 2):
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
				if p.distance_to(s) < 900.0:
					ok = false
			for s in skip:
				if p.distance_to(s) < 400.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A rooted `k` of ours with its footprint's top-left cell at c (as if it had rooted there).
func rooted(k: String, c: Vector2i) -> Unit:
	var u: Unit = g._add_unit(k, 0, BroodRoot.feet_at(k, c))
	u.facing = BroodNew.SE
	u.tesla_mode = "deployed"
	u.nb["m"] = "deployed"
	u.nb_mass = 1000.0
	BroodRoot.footprint_on(g, u, false)
	return u


func clear_ours() -> void:
	for u in g.units.duplicate():
		if u.team == 0:
			BroodRoot.footprint_off(g, u)
			g.consume_unit(u)
	g.nb_queen[0] = null


## A body of a Musketeer of the enemy's at p (dead, lying there, in the harvest list).
func body_at(p: Vector2) -> Unit:
	var m: Unit = g._add_unit("musketeer", 1, p)
	m.take_damage(9999.0, null)
	return m


func _run() -> void:
	g.explored.fill(1)
	g.players[0]["gold"] = 0
	await wait(0.5)
	await _paths()
	if OS.get_environment("ONLY") == "":
		await _bodies()
	print("brood_paths: %d failures" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ A. the long way in to a boxed-in Mother

## layout: [name, [[kind, cell offset from her footprint's top-left]...], the Rootmaw's direction from her]
func _layouts() -> Array:
	var Q := BroodNew.QUEEN
	var F := BroodNew.FATHER
	var D := BroodNew.DILO
	var P := BroodNew.PTERO
	var TU := BroodNew.TURTLE
	var M := BroodNew.MAW
	return [
		# her front (south) shut by two Sires with a 1-tile gap between them and 1 tile from her; a third at her west
		["south shut, Rootmaw south", [[F, Vector2i(0, 5)], [P, Vector2i(5, 5)], [D, Vector2i(-4, 0)]], Vector2(0, 1)],
		# the Sires hugging her (1-tile gaps) on three sides, the Rootmaw far off the west
		["three sides, Rootmaw west", [[F, Vector2i(-5, 0)], [D, Vector2i(10, 0)], [P, Vector2i(2, 5)]], Vector2(-1, 0.3)],
		# the Sires along her north, 1-tile gaps, the Rootmaw north
		["north row, Rootmaw north", [[F, Vector2i(-1, -4)], [D, Vector2i(4, -4)], [P, Vector2i(8, -4)]], Vector2(0.2, -1)],
		# packed: the Sires at her two ends and below, gaps of 1 tile, the Rootmaw south-east
		["packed, Rootmaw south-east", [[F, Vector2i(-5, 1)], [P, Vector2i(10, 1)], [D, Vector2i(3, 5)]], Vector2(1, 0.8)],
		# boxed: a ring of rooted creatures (3 Sires, turtles, a Rootmaw) one tile out from her all round, the only ways
		# in 1-tile gaps between them; a crowd of grubs coming and going through them
		["boxed in, Rootmaw south", [[F, Vector2i(-1, -4)], [D, Vector2i(4, -4)], [TU, Vector2i(8, -4)], [P, Vector2i(0, 5)],
			[TU, Vector2i(5, 5)], [M, Vector2i(9, 5)], [TU, Vector2i(-4, 0)], [TU, Vector2i(10, 0)]], Vector2(0.3, 1)],
		# hugging her (no gap on some sides), the gaps between them 1 tile, the Rootmaw west
		["hugging, Rootmaw west", [[F, Vector2i(-4, 0)], [D, Vector2i(0, 4)], [P, Vector2i(4, 4)], [TU, Vector2i(9, 1)]], Vector2(-1, 0.6)],
	]


func _paths() -> void:
	var used: Array = []
	var only := OS.get_environment("ONLY")
	var li := -1
	for lay in _layouts():
		li += 1
		if only != "" and only != str(li):
			continue
		clear_ours()
		await wait(0.2)
		var o := _open_area(30, 22, used)
		if o.x < 0:
			check(false, "A. %s: no open ground for the test" % lay[0])
			continue
		var qc := o + Vector2i(10, 8)
		var q := rooted(BroodNew.QUEEN, qc)
		g.nb_queen[0] = q
		used.append(q.position)
		var bad := false
		for s in lay[1]:
			var c: Vector2i = qc + (s[1] as Vector2i)
			var k: String = s[0]
			var sz: Vector2i = BroodRoot.fp(k)[0]
			for yy in sz.y:
				for xx in sz.x:
					if g.solid[g.idx(c + Vector2i(xx, yy))] != 0:
						if not bad:
							print("  (layout %s: %s at %s, cell %s is %d)" % [lay[0], k, s[1], c + Vector2i(xx, yy) - qc, g.solid[g.idx(c + Vector2i(xx, yy))]])
						bad = true
			rooted(k, c)
		# the Rootmaw 25-34 tiles off in the layout's direction, on her ground's region, on free cells
		var dir: Vector2 = (lay[2] as Vector2).normalized()
		var home: int = g.region_of(g.nearest_free(g.cell_of(q.position + Vector2(0, 3 * T)), 8))
		var m: Unit = null
		var m2: Unit = null
		for r in [28.0, 26.0, 30.0, 32.0, 25.0, 34.0]:
			for a in [0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75]:
				var p: Vector2 = q.position + dir.rotated(a) * r * T
				var mc := BroodRoot.cell_for(BroodNew.MAW, p)
				var ok: bool = g.in_map(mc) and g.in_map(mc + Vector2i(4, 4))
				if ok:
					for yy in range(-1, 3):
						for xx in range(-1, 4):
							var cc := mc + Vector2i(xx, yy)
							if g.solid[g.idx(cc)] != 0 or g.region_of(cc) != home:
								ok = false
				if ok and m and m.position.distance_to(BroodRoot.feet_at(BroodNew.MAW, mc)) < 6.0 * T:
					ok = false
				if ok:
					if m == null:
						m = rooted(BroodNew.MAW, mc)
					else:
						m2 = rooted(BroodNew.MAW, mc)
						break
			if m2:
				break
		if m == null:
			check(false, "A. %s: no Rootmaw spot" % lay[0])
			continue
		var grubs: Array = []
		for mm in [m, m2]:
			if mm == null:
				continue
			mm.nb["food"] = 9000.0
			BroodNew._claim(g, mm)
			for i in BroodNew.crew_max(g, mm):
				var gr: Unit = g._add_unit("grub", 0, g.cell_center(g.nearest_free(g.cell_of(mm.position + Vector2(-50 + i * 15, 50)), 6)))
				gr.cmd_gather(mm)
				grubs.append(gr)
		await wait(0.2)
		var dist: float = q.position.distance_to(m.position) / T
		var ring := q.rect().grow(T * 1.5)
		var open_way := false
		for c in _ring_cells(q.rect()):
			if g.region_of(c) == home:
				open_way = true
		# watch: deliveries per grub, the longest any grub went without delivering
		var count := {}
		var last := {}
		var was := {}
		for gr in grubs:
			count[gr] = 0
			last[gr] = g.clock
			was[gr] = 0
		var t_end: float = g.clock + 75.0
		var worst := 0.0
		while g.clock < t_end:
			await physics_frame
			for gr in grubs:
				if gr.dead:
					continue
				if int(was[gr]) > 0 and gr.carrying == 0:
					count[gr] = int(count[gr]) + 1
					last[gr] = g.clock
				was[gr] = gr.carrying
				worst = maxf(worst, g.clock - float(last[gr]))
		var n := 0
		var least := 999
		for gr in grubs:
			n += int(count[gr])
			least = mini(least, int(count[gr]))
		var why := ""
		if least == 0:
			for gr in grubs:
				if int(count[gr]) == 0:
					why = " (a grub: work %s, at %s, %.0f px from her, path %d/%d, pass %.1f, goal %s)" % [gr.work, gr.position,
						q.edge_distance(gr.position), gr.path_i, gr.path.size(), gr.nb_pass, gr.path_goal]
					if OS.get_environment("PATH_DEBUG") != "":
						print("  path ", gr.path, " stuck ", gr.stuck_t, " order ", gr.order, " vel ", gr.velocity, " pending ", gr.path_pending, " q at ", q.position, " qrect ", q.rect())
						print("  find_path now: ", g.find_path(gr.position, gr.path_goal, false, 7.0))
						var cc: Vector2i = g.cell_of(gr.position)
						for yy in range(-3, 4):
							var row := ""
							for xx in range(-3, 4):
								row += str(g.solid[g.idx(cc + Vector2i(xx, yy))])
							print("   ", row)
					break
		check(open_way, "A. %s: the layout (an open way to her rim%s)" % [lay[0], "; a cell of it was a tree or rock" if bad else ""])
		check(least >= 2 and worst < 45.0, "A. %s, the Rootmaws %.0f tiles off, %d grubs: %d deliveries, each grub %d or more, longest wait %.0f s%s" % [lay[0], dist, grubs.size(), n, least, worst, why])
		for gr in grubs:
			if ring.has_point(gr.position) and not g._clear_at(gr.position, gr.ground_r(), 0):
				check(false, "A. %s: a grub inside a footprint at %s" % [lay[0], gr.position])


## The cells just outside a rect (its ring).
func _ring_cells(r: Rect2) -> Array:
	var c0: Vector2i = g.cell_of(r.position) - Vector2i.ONE
	var c1: Vector2i = g.cell_of(r.end - Vector2(1, 1)) + Vector2i.ONE
	var out: Array = []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if (x == c0.x or x == c1.x or y == c0.y or y == c1.y) and g.is_free(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


# ------------------------------------------------------------------ B. bodies under a rooting creature

## Is a body (or pile) where a grub can get at it: on free, open ground of the rooted creature's region, outside r?
func _reachable(b: Unit, r: Rect2, home: int) -> bool:
	var c: Vector2i = g.cell_of(b.position)
	return g.is_free(c) and g.region_of(c) == home and not r.has_point(b.position)


func _bodies() -> void:
	clear_ours()
	await wait(0.2)
	var o := _open_area(30, 22)
	if o.x < 0:
		check(false, "B. no open ground for the test")
		return
	var qc := o + Vector2i(10, 8)
	var q := rooted(BroodNew.QUEEN, qc)
	g.nb_queen[0] = q
	var home: int = g.region_of(qc + Vector2i(0, -2))
	# a Tyrannosaur (Sire) roots over two bodies
	var fc := qc + Vector2i(0, 6)
	var fr := BroodRoot.rect_for(BroodNew.FATHER, BroodRoot.feet_at(BroodNew.FATHER, fc))
	var b1 := body_at(fr.get_center())
	var b2 := body_at(fr.position + Vector2(20, 20))
	await wait(2.0)        # (they come to rest)
	var v1: float = g.corpse_value(b1)
	var died1: float = b1.died_at
	var f := rooted(BroodNew.FATHER, fc)
	await wait(0.1)
	var r: Rect2 = BroodRoot.rect_of(f)
	check(g.corpses.has(b1) and g.corpses.has(b2), "B. the bodies are still there to harvest")
	check(_reachable(b1, r, home) and _reachable(b2, r, home),
		"B. a Sire rooted over two bodies: both pushed outside his footprint onto open ground (%.0f, %.0f px from its edge)" % [f.edge_distance(b1.position), f.edge_distance(b2.position)])
	check(f.edge_distance(b1.position) < 2.5 * T and f.edge_distance(b2.position) < 2.5 * T, "B. ... just outside it, not far off")
	check(absf(g.corpse_value(b1) - v1) < 0.01 and b1.died_at == died1, "B. ... its value (%.1f) and its rot clock kept" % g.corpse_value(b1))
	# a food pile under a Rootmaw rooting again
	var mc := qc + Vector2i(14, 0)
	var mp: Vector2 = BroodRoot.feet_at(BroodNew.MAW, mc)
	var pile: Unit = g._add_unit(BroodNew.PILE, 0, BroodRoot.rect_for(BroodNew.MAW, mp).get_center())
	pile.nb["food"] = 120.0
	await wait(0.1)
	var maw := rooted(BroodNew.MAW, mc)
	await wait(0.1)
	var mr: Rect2 = BroodRoot.rect_of(maw)
	check(_reachable(pile, mr, home) and float(pile.nb.get("food", 0.0)) > 110.0, "B. a food pile under a Rootmaw rooting: pushed out, its food kept (%.0f px from its edge, %.0f food after its rot)" % [maw.edge_distance(pile.position), float(pile.nb.get("food", 0.0))])
	# the Mother grows: a body just under her new edge
	var qr0: Rect2 = BroodRoot.rect_of(q)
	var b3 := body_at(Vector2(qr0.get_center().x, qr0.position.y - 20.0))
	await wait(2.0)
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	var qr1: Rect2 = BroodRoot.rect_of(q)
	check(qr1.size.y > qr0.size.y, "B. (the Mother grew: %s -> %s)" % [qr0.size, qr1.size])
	check(_reachable(b3, qr1, g.region_of(g.cell_of(b3.position))) and not qr1.has_point(b3.position) and g.is_free(g.cell_of(b3.position)),
		"B. the Mother grown over a body: pushed outside her new footprint (%.0f px from her edge)" % q.edge_distance(b3.position))
	# a building placed over a body
	var bc := qc + Vector2i(-8, -6)
	var b4 := body_at(Vector2(bc) * T + Vector2(T, T))
	await wait(2.0)
	g.factions[0] = "crown"
	var cot: Building = g._add_building("cottage", 0, bc, true)
	g.factions[0] = "brood"
	var cr: Rect2 = cot.rect()
	check(not cr.has_point(b4.position) and g.is_free(g.cell_of(b4.position)), "B. a building put over a body: the body pushed off it onto free ground")
