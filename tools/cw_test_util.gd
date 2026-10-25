extends RefCounted
## Shared helpers for tools/test_cw_*.gd (the Clockwork roster prototype).
const U := preload("res://tools/line_test_util.gd")


## A Clockwork (team 0) against a Crown (team 1) with the roster on, rich, with the Line's pressure not enforced.
static func make(root: Window) -> Game:
	Defs.cw_roster = true
	var g := U.make(root)
	g.line_net.enforce = false
	return g


static func rich(g: Game, t := 0) -> void:
	g.players[t]["gold"] = 50000
	g.players[t]["res2"] = 500.0


## n finished Line cells in a straight row on free ground near the team's hall (the first such row found, nearest
## the hall first); returns the cells in order (empty if the ground has no room).
static func row(g: Game, t: int, n: int, horizontal := true) -> Array:
	var h := U.hall(g, t)
	var d := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var spots: Array = []
	for oy in range(-18, 19):
		for ox in range(-18, 19):
			spots.append(h.cell + Vector2i(ox, oy))
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - h.cell).length() < Vector2(b - h.cell).length())
	for c in spots:
		var cells: Array = []
		var ok := true
		for i in n:
			var cc: Vector2i = c + d * i
			if not g.line_net.pipeable(t, cc) or g.line_net.segs.has(cc) or g.line_net.has_cell(cc) or _near_building(g, cc):
				ok = false
				break
			cells.append(cc)
		if ok:
			for cc in cells:
				g.line_net.add_built(t, cc)
			return cells
	return []


static func _near_building(g: Game, c: Vector2i) -> bool:
	for b in g.buildings:
		if c.x >= b.cell.x - 1 and c.x <= b.cell.x + b.size.x and c.y >= b.cell.y - 1 and c.y <= b.cell.y + b.size.y:
			return true
	return false


static func spawn(g: Game, kind: String, t: int, at: Vector2) -> Unit:
	return g._add_unit(kind, t, at)


static func step(tree: SceneTree, g: Game, secs: float, hook := Callable()) -> void:
	var n := int(secs * 30.0)
	for i in n:
		if hook.is_valid():
			hook.call()
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		if i % 8 == 0:
			await tree.process_frame
