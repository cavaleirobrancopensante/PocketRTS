extends SceneTree
## How many Feeding Pits a Brood main base holds under the ground circles (Defs.PIT_CLAIM: living pits'
## circles may not overlap). For docs/brood_pit_ground.md.
##   godot --headless --fixed-fps 30 --script res://tools/measure_pit_room.gd -- map=<id> [radius=22]
## The main base: the cells joined to the capital's on its own height (no ramps), within `radius` tiles
## of it (a map with no plateau round the start is cut at that radius). Pits are packed greedily on it,
## farthest first (where pits pay most) and nearest first; ground under the other buildings and the
## swamp's reach are ignored (only the footprint, its margin and the circles count). One "ROOM" line.
var main: Node
var t := 0.0
var started := false
var opts := {}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and not started:
		started = true
		for a in OS.get_cmdline_user_args():
			if "=" in a:
				var kv: PackedStringArray = a.split("=", true, 1)
				opts[kv[0]] = kv[1]
		main.start({"map": String(opts.get("map", "greenhold")), "seed": 7, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null or t < 1.0:
		return false
	var g: Game = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	var radius := float(opts.get("radius", "22"))
	var cap := g.capital(0)
	var c0 := g.cell_of(cap.center())
	var h0 := int(g.height[g.idx(c0)])
	# the main base: flood from the capital over its own height
	var main_cells := {}
	var stack: Array[Vector2i] = [c0]
	var open := true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if main_cells.has(c) or not g.in_map(c):
			continue
		var i := g.idx(c)
		if int(g.height[i]) != h0 or g.ramp[i] != 0:
			continue
		if Vector2(c).distance_to(Vector2(c0)) > radius:
			open = false       # (cut at the radius: no plateau edge reached there)
			continue
		main_cells[c] = true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + dv)
	var size: Vector2i = Defs.BUILDINGS["feeding_pit"]["size"]
	var cands: Array = []
	for c in main_cells:
		var ok := true
		for y in size.y:
			for x in size.x:
				if not main_cells.has(c + Vector2i(x, y)):
					ok = false
		if ok:
			cands.append(c)
	var counts := []
	for order in ["far", "near"]:
		var cs := cands.duplicate()
		cs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := g.pit_mid(a).distance_to(cap.center())
			var db := g.pit_mid(b).distance_to(cap.center())
			return da > db if order == "far" else da < db)
		var placed: Array[Vector2] = []
		var dists: Array = []
		for p in g.buildings:
			if p.team == 0 and p.kind == "feeding_pit" and not p.dead:
				placed.append(p.center())        # (the starting pit stays where it is)
		for c in cs:
			var m := g.pit_mid(c)
			var clash := false
			for q in placed:
				if Game.pit_circles_overlap(q, m):
					clash = true
					break
			if clash or not g._footprint_open(c, size) or not g.margin_free(c, size):
				continue
			placed.append(m)
			dists.append(m.distance_to(cap.center()) / Defs.TILE)
		counts.append([placed.size(), dists])
	print("ROOM map=%s cells=%d %s far-first=%d near-first=%d farthest=%.1f" % [g.map_name, main_cells.size(), "plateau" if open else "cut at %d tiles" % int(radius),
		int(counts[0][0]), int(counts[1][0]), (counts[0][1] as Array).max() if not (counts[0][1] as Array).is_empty() else 0.0])
	quit()
	return true
