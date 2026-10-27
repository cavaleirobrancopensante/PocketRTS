extends RefCounted
## Shared helpers for tools/test_gear_*.gd (the Clockwork gear field and cog presses, docs/clockwork_gear_prototype.md).


## A Clockwork (team 0) against a Crown (team 1), gear mode on, the Line shelved.
static func make(root: Window, facs: Array = ["clockwork", "crown"], map := "", demo := true) -> Game:
	Defs.line_mode = false
	Defs.gear_mode = true
	Defs.cw_roster = false
	var g := Game.new()
	g.map_id = map if map != "" else "ashford_crossing"
	g.demo = demo
	g.factions = facs
	var sides: Array = []
	for i in facs.size():
		sides.append(i)
	g.sides = sides
	root.add_child(g)
	return g


static func hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t) and not b.dead:
			return b
	return null


## One simulated step of the whole game (units, buildings, the game's own tick).
static func step(g: Game, secs: float) -> void:
	var n := int(secs * 30.0)
	for i in n:
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)


## A cell where a finished building of this kind links to the field (the rule says "") and fits, nearest the hall first.
static func linked_spot(g: Game, t: int, kind: String, near: Vector2i, big := false, skip: Array = []) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(near.y - 26, near.y + 27):
		for x in range(near.x - 26, near.x + 27):
			var c := Vector2i(x, y)
			if skip.has(c) or not g.in_map(c):
				continue
			var d := Vector2(c - near).length()
			if d >= bd:
				continue
			if g.placement_problem(t, kind, c) != "" or g.gear_net.candidate(t, kind, c, big)["state"] != "ok":
				continue
			if not g.margin_free(c, size):
				continue
			best = c
			bd = d
	return best


## Put a finished building of `kind` on a linking spot; null if none.
static func put(g: Game, t: int, kind: String, near: Vector2i, big := false) -> Building:
	var c := linked_spot(g, t, kind, near, big)
	if c.x < 0:
		return null
	var b := g._add_building(kind, t, c, true)
	b.gear_big = big
	g.gear_net.solve()
	return b


## A finished building of `kind` far from every ring (unlinked on purpose): on any free ground at least `far` tiles from the hall.
static func put_far(g: Game, t: int, kind: String, far := 22) -> Building:
	var h := hall(g, t)
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for y in range(h.cell.y - 40, h.cell.y + 41):
		for x in range(h.cell.x - 40, h.cell.x + 41):
			var c := Vector2i(x, y)
			if not g.in_map(c) or Vector2(c - h.cell).length() < far:
				continue
			if g.margin_free(c, size) and g.is_free(c) and g.gear_net.candidate(t, kind, c, false)["state"] == "far":
				var ok := true
				for yy in size.y:
					for xx in size.x:
						if not g.is_free(c + Vector2i(xx, yy)):
							ok = false
				if ok:
					var b := g._add_building(kind, t, c, true)
					g.gear_net.solve()
					return b
	return null


## A linking spot whose ring touches `parent`'s ring but NOT the Clocktower's (so it depends on `parent`), nearest `parent` first.
static func chain_spot(g: Game, t: int, kind: String, parent: Building, big := false) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var tower := hall(g, t)
	var best := Vector2i(-1, -1)
	var bd := INF
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	for y in range(parent.cell.y - 20, parent.cell.y + 21):
		for x in range(parent.cell.x - 20, parent.cell.x + 21):
			var c := Vector2i(x, y)
			if not g.in_map(c) or not _free_fp(g, c, size):
				continue
			var centre := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var gap := centre.distance_to(GearNet.b_c(tower)) - (GearNet.ring_r(kind, size, big) + GearNet.b_r(tower))
			if gap <= slack * 1.05:
				continue
			var near_other := false
			for o in g.buildings:
				if o != parent and o != tower and o.team == t and not o.dead and GearNet.has_gear(o):
					if centre.distance_to(GearNet.b_c(o)) - (GearNet.ring_r(kind, size, big) + GearNet.b_r(o)) <= slack * 1.05:
						near_other = true
			if near_other:
				continue
			var pgap := centre.distance_to(GearNet.b_c(parent)) - (GearNet.ring_r(kind, size, big) + GearNet.b_r(parent))
			if pgap > slack * 0.9 or pgap < -float(Defs.GEAR["overlap"]) * Defs.TILE * 0.9:
				continue
			if not GearNet.level_ok(g, kind, c, big, parent):
				continue          # (gears mesh only on the same ground level)
			var d := Vector2(c - parent.cell).length()
			if d < bd:
				bd = d
				best = c
	return best


static func _free_fp(g: Game, c: Vector2i, size: Vector2i) -> bool:
	for yy in size.y:
		for xx in size.x:
			if not g.is_free(c + Vector2i(xx, yy)):
				return false
	return true
