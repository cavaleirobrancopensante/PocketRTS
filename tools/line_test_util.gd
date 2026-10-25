extends RefCounted
## Shared helpers for tools/test_line_*.gd.

static func make(root: Window, facs: Array = ["clockwork", "crown"], map := "") -> Game:
	var g := Game.new()
	g.map_id = map if map != "" else "ashford_crossing"
	g.demo = true
	g.factions = facs
	var sides: Array = []
	for i in facs.size():
		sides.append(i)
	g.sides = sides
	root.add_child(g)
	return g


static func hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			return b
	return null


## A built run of `n` segments for team t leaving the hall (as long and straight as the ground allows);
## returns the cells in order from the hall.
static func run_from_hall(g: Game, t: int, n: int) -> Array:
	g.line_net.clear()
	var h := hall(g, t)
	for c in g.line_net.ring(h):
		if not g.line_net.pipeable(t, c):
			continue
		# flood outward over free ground until a cell n-1 steps away is found
		var dist := {c: 0}
		var prev := {}
		var q: Array = [c]
		var i := 0
		var goal := Vector2i(-1, -1)
		var ring: Array = g.line_net.ring(h)
		while i < q.size() and goal.x < 0:
			var cur: Vector2i = q[i]
			i += 1
			for d in LineNetwork.DIRS:
				var nb: Vector2i = cur + d
				if not dist.has(nb) and g.line_net.pipeable(t, nb) and not ring.has(nb):
					dist[nb] = dist[cur] + 1
					prev[nb] = cur
					q.append(nb)
					if dist[nb] == n - 1:
						goal = nb
						break
		if goal.x < 0:
			continue
		var cells: Array = [goal]
		while cells[cells.size() - 1] != c:
			cells.append(prev[cells[cells.size() - 1]])
		cells.reverse()
		for cc in cells:
			g.line_net.add_built(t, cc)
		return cells
	return []


## Put a finished building of `kind` whose footprint touches cell `c` (a free spot on a free side).
static func building_beside(g: Game, t: int, kind: String, c: Vector2i) -> Building:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for d in LineNetwork.DIRS:
		for off in range(-size.x + 1, size.x):
			for off2 in range(-size.y + 1, size.y):
				var cell: Vector2i = c + d * 1 + Vector2i(off if d.y != 0 else 0, off2 if d.x != 0 else 0)
				# the footprint must contain the cell next to c on side d
				var origin := cell
				if d == Vector2i(1, 0):
					origin = Vector2i(c.x + 1, c.y + off2)
				elif d == Vector2i(-1, 0):
					origin = Vector2i(c.x - size.x, c.y + off2)
				elif d == Vector2i(0, 1):
					origin = Vector2i(c.x + off, c.y + 1)
				else:
					origin = Vector2i(c.x + off, c.y - size.y)
				if _free(g, origin, size):
					return g._add_building(kind, t, origin, true)
	return null


static func _free(g: Game, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cc := origin + Vector2i(x, y)
			if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.line_net.has_cell(cc) or g.ramp[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0:
				return false
	return true
