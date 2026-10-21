extends SceneTree
## Regression test: Labourers stuck in narrow gaps between buildings (playtest screenshots).
##   godot --headless --fixed-fps 30 --script res://tools/test_stuck_gap.gd
## Builds each layout on open ground, puts a Labourer in the gap, orders it out to open
## ground and checks it gets there. Prints PASS / FAIL per case and "ALL PASS" at the end.
##  1. "farm strip": two Farms side by side with Cottages over the left farm's top crop row
##     (walkable, behind its windmill): the way out is round the windmill.
##  2. "cottage gap": a one-cell gap between two Cottages, a Powder Mill below it.
##  3. "sealed": the Labourer walled in on all sides by Cottages (a pocket that really is
##     closed): as a last resort it walks out through the nearest building edge.
##  4. "spawned in": a wall that shuts the ring, laid on top of a Labourer standing in its
##     mouth, puts him out on open ground, not into the pocket.
var main: Node
var t := 0.0
var g
var cases: Array = []
var ci := -1
var case_t := 0.0
var u
var goal := Vector2.ZERO
var built: Array = []
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _open_area(w: int, h: int) -> Vector2i:
	# a w x h block of open, flat ground away from both bases
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
				if p.distance_to(s) < 500.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear() -> void:
	for b in built:
		if is_instance_valid(b) and not b.dead:
			g._mark(b.cell, b.size, 0)
			g.buildings.erase(b)
			b.queue_free()
	built.clear()
	if u and is_instance_valid(u):
		g.units.erase(u)
		u.queue_free()
	u = null


func _b(k: String, c: Vector2i) -> void:
	built.append(g._add_building(k, 0, origin + c, true))


func _setup_case(name: String) -> void:
	_clear()
	var at := Vector2i.ZERO
	match name:
		"farm strip":
			# farm A at (2,4), farm B right beside it; the Labourer stands on A's top crop
			# row (row 4, behind its windmill's block in rows 5-6); Cottages sit right over
			# it, so the row only opens round the windmill, down A's side plots
			var fw: int = Defs.BUILDINGS["farm"]["size"].x
			_b("farm", Vector2i(2, 4))
			_b("farm", Vector2i(2 + fw, 4))
			for x in range(5, 2 + fw, 2):
				_b("cottage", Vector2i(x, 2))
			at = Vector2i(6, 4)
			goal = g.cell_center(origin + Vector2i(6, 0))
		"cottage gap":
			_b("cottage", Vector2i(4, 3))
			_b("cottage", Vector2i(7, 3))
			_b("powder_mill", Vector2i(5, 5))
			at = Vector2i(6, 4)
			goal = g.cell_center(origin + Vector2i(6, 0))
		"sealed", "spawned in":
			# a ring of Cottages round the cell (6,4), open only below, at (6,5)
			for c in [Vector2i(4, 2), Vector2i(6, 2), Vector2i(7, 4), Vector2i(4, 4)]:
				_b("cottage", c)
			if name == "sealed":
				_b("wall", Vector2i(6, 5))      # ... and that shut too
			at = Vector2i(6, 4) if name == "sealed" else Vector2i(6, 5)
			goal = g.cell_center(origin + Vector2i(6, 10))
	u = g._add_unit("labourer", 0, g.cell_center(origin + at) - Vector2(0, 8 if name == "spawned in" else 0))
	if name == "spawned in":
		_b("wall", Vector2i(6, 5))     # shuts the ring on top of him: he must be put outside, not in
		var pc: Vector2i = g.cell_of(u.position) - origin
		print("  pushed out to ", pc)
	u.cmd_move(goal)
	case_t = 0.0


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "random", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if origin.x < 0:
		if t < 1.0:
			return false
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		origin = _open_area(16, 13)
		if origin.x < 0:
			print("FAIL: no open ground for the test")
			quit(1)
			return true
		cases = ["farm strip", "cottage gap", "sealed", "spawned in"]
		ci = 0
		_setup_case(cases[ci])
		return false
	case_t += delta
	var got: bool = u.position.distance_to(goal) < 24.0
	if got or case_t > 12.0:
		var name: String = cases[ci]
		if got:
			print("PASS %s: out in %.1f s" % [name, case_t])
		else:
			fails += 1
			print("FAIL %s: still at cell %s (started in the gap), goal cell %s" % [name, g.cell_of(u.position) - origin, g.cell_of(goal) - origin])
		ci += 1
		if ci >= cases.size():
			print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
			quit(0 if fails == 0 else 1)
			return true
		_setup_case(cases[ci])
	return false
