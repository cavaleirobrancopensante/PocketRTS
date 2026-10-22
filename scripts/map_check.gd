class_name MapCheck
## The map checks, shared by the map editor's CHECK and tools/check_maps.gd (every named
## map): every start and hall spot can be walked to from the first start, each main sits on
## high ground whose ramps can be walled, ramps join high ground to low ground, hall spots
## stand on open ground, no decoration stands on a ramp or a hall's land, every start has
## room for its economy and an expansion nearby, and (in the editor) the map matches its
## mirror copies.
##
## run() returns a list of {"text", "cells" (to highlight), "warn" (a warning, not a fault)}.

const SYMMETRY := ["off", "rotate", "mirror_lr", "mirror_tb", "4-way", "turn90"]
const ECONOMY_CELLS := 140        # open cells a start needs within 11 of its hall (farms, mills...)
const MAX_RAMP_TOP := 5           # a ramp wider than this at its top is too much to wall


## The copies of a point (in cells, continuous) under a symmetry, with whether each copy
## is seen mirrored (a decoration on it is flipped). The point itself comes first.
static func mirror_points(p: Vector2, mode: String, w: int, h: int) -> Array:
	var out: Array = [[p, false]]
	match mode:
		"rotate", "2-way":
			out.append([Vector2(w, h) - p, true])
		"mirror_lr":
			out.append([Vector2(w - p.x, p.y), true])
		"mirror_tb":
			out.append([Vector2(p.x, h - p.y), false])
		"4-way":
			out.append([Vector2(w, h) - p, true])
			out.append([Vector2(w - p.x, p.y), true])
			out.append([Vector2(p.x, h - p.y), false])
		"turn90":
			if w == h:
				var q := p
				for k in 3:
					q = Vector2(w - q.y, q.x)
					out.append([q, false])
	return out


## The copies of a cell.
static func mirror_cells(c: Vector2i, mode: String, w: int, h: int) -> Array:
	var out: Array = []
	for m in mirror_points(Vector2(c) + Vector2(0.5, 0.5), mode, w, h):
		var mc := Vector2i(floori((m[0] as Vector2).x), floori((m[0] as Vector2).y))
		if not out.has(mc):
			out.append(mc)
	return out


## The copies of a rectangle's top-left cell (a hall spot), keeping its size.
static func mirror_rects(at: Vector2i, size: Vector2i, mode: String, w: int, h: int) -> Array:
	var out: Array = []
	for m in mirror_points(Vector2(at) + Vector2(size) * 0.5, mode, w, h):
		var p: Vector2 = (m[0] as Vector2) - Vector2(size) * 0.5
		var mc := Vector2i(roundi(p.x), roundi(p.y))
		if not out.has(mc):
			out.append(mc)
	return out


static func _rect_cells(at: Vector2i, size: Vector2i) -> Array:
	var out: Array = []
	for y in size.y:
		for x in size.x:
			out.append(at + Vector2i(x, y))
	return out


static func _centre(at: Vector2i) -> Vector2i:
	return at + Vector2i(2, 2)


## Every cell reachable on foot from `from` (4-way, open cells; `no_ramps`: not onto ramps).
static func _flood(g: Game, from: Vector2i, no_ramps := false) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(Game.W * Game.H)
	if not g.in_map(from) or g.solid[g.idx(from)] != 0:
		return seen
	var q: Array = [from]
	seen[g.idx(from)] = 1
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in d4:
			var n: Vector2i = c + d
			if not g.in_map(n):
				continue
			var i := g.idx(n)
			if seen[i] == 1 or g.solid[i] != 0 or (no_ramps and g.ramp[i] == 1):
				continue
			seen[i] = 1
			q.append(n)
	return seen


## Ramp groups (4-connected ramp cells), each an Array of cells.
static func ramp_groups(g: Game) -> Array:
	var seen := PackedByteArray()
	seen.resize(Game.W * Game.H)
	var out: Array = []
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in Game.W * Game.H:
		if g.ramp[i] != 1 or seen[i] == 1:
			continue
		var grp: Array = []
		var q: Array = [Vector2i(i % Game.W, i / Game.W)]
		seen[i] = 1
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			grp.append(c)
			for d in d4:
				var n: Vector2i = c + d
				if g.in_map(n) and g.ramp[g.idx(n)] == 1 and seen[g.idx(n)] == 0:
					seen[g.idx(n)] = 1
					q.append(n)
		out.append(grp)
	return out


## The ramp cells that don't join high ground to low ground (a ramp needs both beside it).
static func bad_ramps(g: Game) -> Array:
	var out: Array = []
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for grp in ramp_groups(g):
		var hi := false
		var lo := false
		for c in grp:
			for d in d4:
				var n: Vector2i = c + d
				if not g.in_map(n):
					continue
				var i := g.idx(n)
				if g.ramp[i] == 1 or g.water[i] == 1:
					continue
				if g.height[i] == 1:
					hi = true
				else:
					lo = true
		if not (hi and lo):
			out.append_array(grp)
	return out


static func _add(out: Array, text: String, cells: Array, warn := false) -> void:
	out.append({"text": text, "cells": cells, "warn": warn})


## Check a built map. `starts` / `halls`: hall top-left cells; `cells` and `mirror`: the
## editor's map and symmetry (for the symmetry check; leave empty to skip it).
static func run(g: Game, starts: Array, halls: Array, cells := "", mirror := "off") -> Array:
	var out: Array = []
	var W := Game.W
	var H := Game.H
	var hall := MapGen.HALL
	if starts.size() < 2:
		_add(out, "Place at least two start spots (there are %d)." % starts.size(), [])
	if starts.size() > 8:
		_add(out, "At most eight start spots (there are %d)." % starts.size(), [])
	var spots: Array = starts + halls
	var spot_name := func(k: int) -> String:
		return ("Start %d" % (k + 1)) if k < starts.size() else ("Hall spot %d" % (k - starts.size() + 1))
	# hall spots: inside the map, on open level ground, apart from each other
	for k in spots.size():
		var at: Vector2i = spots[k]
		var bad: Array = []
		var heights := {}
		for c in _rect_cells(at, hall):
			if not g.in_map(c):
				bad.append(c)
				continue
			var i := g.idx(c)
			heights[g.height[i]] = true
			if g.solid[i] != 0 or g.water[i] == 1 or g.ramp[i] == 1 or (g.mapgen and g.mapgen.ford.size() > i and g.mapgen.ford[i] == 1):
				bad.append(c)
		if not bad.is_empty():
			_add(out, "%s stands on blocked ground (trees, rocks, water, a ramp or a cliff)." % spot_name.call(k), bad)
		elif heights.size() > 1:
			_add(out, "%s sits across the edge of high ground." % spot_name.call(k), _rect_cells(at, hall))
		for k2 in range(k + 1, spots.size()):
			if Rect2i(at, hall).grow(1).intersects(Rect2i(spots[k2], hall)):
				_add(out, "%s and %s overlap." % [spot_name.call(k), spot_name.call(k2)], _rect_cells(at, hall) + _rect_cells(spots[k2], hall))
	if starts.is_empty():
		return out
	# every start and hall spot can be walked to from the first start
	var reach := _flood(g, _centre(starts[0]))
	for k in range(1, spots.size()):
		var c := _centre(spots[k])
		if g.in_map(c) and reach[g.idx(c)] == 0:
			_add(out, "%s can't be reached on foot from start 1." % spot_name.call(k), _rect_cells(spots[k], hall))
	# each main: high ground closed by cliffs, its ways down ramps narrow enough to wall
	var groups := ramp_groups(g)
	var group_of := {}
	for gi in groups.size():
		for c in groups[gi]:
			group_of[g.idx(c)] = gi
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for k in starts.size():
		var c0 := _centre(starts[k])
		if not g.in_map(c0) or g.solid[g.idx(c0)] != 0:
			continue
		var top := _flood(g, c0, true)
		var low := false
		var tops := {}             # ramp group -> its cells touching the main
		for i in W * H:
			if top[i] == 0:
				continue
			if g.height[i] == 0:
				low = true
				break
			var c := Vector2i(i % W, i / W)
			for d in d4:
				var n: Vector2i = c + d
				if g.in_map(n) and group_of.has(g.idx(n)):
					var gi: int = group_of[g.idx(n)]
					if not tops.has(gi):
						tops[gi] = {}
					tops[gi][n] = true
		if low:
			_add(out, "Start %d isn't on high ground closed by cliffs, so it has no ramp to wall." % (k + 1), _rect_cells(starts[k], hall))
			continue
		if tops.is_empty():
			_add(out, "Start %d's high ground has no ramp down." % (k + 1), _rect_cells(starts[k], hall))
			continue
		for gi in tops:
			var w: int = (tops[gi] as Dictionary).size()
			if w > MAX_RAMP_TOP:
				_add(out, "Start %d's ramp is %d cells wide at the top: too wide to wall (at most %d)." % [k + 1, w, MAX_RAMP_TOP], groups[gi])
		if tops.size() > 2:
			_add(out, "Start %d's main has %d ramps (one or two are easier to hold)." % [k + 1, tops.size()], [], true)
	# ramps that join nothing
	var br := bad_ramps(g)
	if not br.is_empty():
		_add(out, "A ramp must join high ground to low ground (%d ramp cells don't)." % br.size(), br)
	# decorations off ramps and halls' land
	if g.mapgen:
		var near_ramp := func(c: Vector2i) -> bool:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if g.in_map(n) and g.ramp[g.idx(n)] == 1:
						return true
			return false
		for pr in g.mapgen.props:
			if pr["dead"]:
				continue
			var foot: Array = pr["cells"]
			var at: Vector2i = pr["at"]
			var cs: Array = foot if not foot.is_empty() else [at]
			var nm := String(pr["name"]).replace("_", " ")
			var on_ramp := false
			for c in cs:
				if near_ramp.call(c):
					on_ramp = true
			if on_ramp:
				_add(out, "The %s stands on or beside a ramp." % nm, cs)
				continue
			for k in spots.size():
				var hc: Vector2 = Vector2(spots[k]) + Vector2(2.5, 2.0)
				var bad := false
				for c in cs:
					if foot.is_empty():
						bad = bad or Rect2i(spots[k], hall).grow(1).has_point(c)
					else:
						bad = bad or (Vector2(c) + Vector2(0.5, 0.5)).distance_to(hc) < 9.0
				if bad:
					_add(out, "The %s stands on %s's land." % [nm, String(spot_name.call(k)).to_lower()], cs)
					break
	# room for each start's economy, and an expansion nearby
	for k in starts.size():
		var hc: Vector2 = Vector2(starts[k]) + Vector2(2.5, 2.0)
		var hgt := -1
		if g.in_map(_centre(starts[k])):
			hgt = g.height[g.idx(_centre(starts[k]))]
		var open := 0
		var r := 11
		for y in range(int(hc.y) - r, int(hc.y) + r + 1):
			for x in range(int(hc.x) - r, int(hc.x) + r + 1):
				var c := Vector2i(x, y)
				if not g.in_map(c) or Rect2i(starts[k], hall).has_point(c):
					continue
				if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(hc) > r:
					continue
				var i := g.idx(c)
				if g.solid[i] == 0 and g.water[i] == 0 and g.ramp[i] == 0 and g.height[i] == hgt \
						and not (g.mapgen and g.mapgen.ford.size() > i and g.mapgen.ford[i] == 1):
					open += 1
		if open < ECONOMY_CELLS:
			_add(out, "Start %d has little open ground for its farms and mills (%d cells, about %d needed)." % [k + 1, open, ECONOMY_CELLS], _rect_cells(starts[k], hall))
		var near := INF
		for h2 in halls:
			near = minf(near, Vector2(h2).distance_to(Vector2(starts[k])))
		if near > 45.0:
			_add(out, "Start %d has no hall spot nearby for an expansion." % (k + 1), _rect_cells(starts[k], hall), true)
	# the same ground on every side (the editor's symmetry)
	if cells != "" and mirror != "off" and cells.length() == W * H:
		var odd: Array = []
		for y in H:
			for x in W:
				var i := y * W + x
				for m in mirror_cells(Vector2i(x, y), mirror, W, H):
					var mc: Vector2i = m
					if g.in_map(mc) and cells[mc.y * W + mc.x] != cells[i]:
						odd.append(Vector2i(x, y))
						break
		if not odd.is_empty():
			_add(out, "%d cells don't match their mirror copies." % odd.size(), odd.slice(0, 600), true)
		var miss: Array = []
		for s in starts + halls:
			for m in mirror_rects(s, hall, mirror, W, H):
				var found := false
				for s2 in starts + halls:
					if (Vector2(s2) - Vector2(m)).length() <= 1.5:
						found = true
				if not found:
					miss.append_array(_rect_cells(m, hall))
		if not miss.is_empty():
			_add(out, "Some hall spots have no mirror twin (the outlined places).", miss, true)
	return out
