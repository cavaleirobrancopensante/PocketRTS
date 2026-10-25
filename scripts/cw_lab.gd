class_name CwLab
extends RefCounted
## The CLOCKWORK LAB (EDITOR menu): the human Clockwork starts with plenty of ore and a Line run with a Rail Yard,
## Assembly Works, Engine Hall, Boiler and Pylon beside it, and a hint line on how to spawn the experimental units.
## Also holds the Line helpers the cw tests share (run_from_hall, beside).


static func setup(game: Game) -> void:
	var t := game.human
	var cfg: Dictionary = Defs.CW["lab"]
	game.players[t]["gold"] = int(cfg["ore"])
	game.players[t]["res2"] = float(cfg["res2"])
	var cells := run_from_hall(game, t, 44)
	if cells.is_empty():
		return
	var i := 3
	for k in cfg["buildings"]:
		while i < cells.size():
			var b := beside(game, t, String(k), cells[i])
			i += 3
			if b != null:
				break
	game.line_net.solve()
	var layer := CanvasLayer.new()
	layer.layer = 40
	var l := Label.new()
	l.text = hint_text()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.position = Vector2(14, 62)
	l.custom_minimum_size = Vector2(420, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(l)
	game.add_child(layer)


static func hint_text() -> String:
	return Loc.t("CLOCKWORK LAB: open SANDBOX, tab CLOCK, to spawn the new units (rail vehicles land on the Line). The Rail Yard and Assembly Works train them too. The enemy never attacks.")


## A built straight-ish run of n segments for team t leaving its hall; returns the cells in order from the hall.
static func run_from_hall(g: Game, t: int, n: int) -> Array:
	var h: Building = null
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			h = b
			break
	if h == null:
		return []
	var ring: Array = g.line_net.ring(h)
	for c in ring:
		if not g.line_net.pipeable(t, c):
			continue
		var dist := {c: 0}
		var prev := {}
		var q: Array = [c]
		var i := 0
		var goal := Vector2i(-1, -1)
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


## A finished building of `kind` whose footprint touches the Line cell c.
static func beside(g: Game, t: int, kind: String, c: Vector2i) -> Building:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for d in LineNetwork.DIRS:
		for off in range(-size.x + 1, 1):
			for off2 in range(-size.y + 1, 1):
				var origin := c
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
