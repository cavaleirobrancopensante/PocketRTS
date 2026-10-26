class_name BuildGrid
extends RefCounted
## The planning grid shown while a building is being placed: a faint tile grid around the
## ghost, tinted by what each tile is (cliff / water / resource, building, wall, farm field),
## the one-tile-wide gaps units squeeze through, and a warning when the ghost would narrow a
## path or cut a route off. Worked out once per ghost move (and twice a second) over a small
## window, cached; drawing only loops over the cached cells.

const MARGIN := 10            # tiles of ground looked at around the ghost
const SHOW := 7               # tiles of grid drawn around the ghost
const FREE := 0
const TERRAIN := 1
const BUILDING := 2
const FIELD := 3
const WALL := 4

var org := Vector2i.ZERO      # window's top-left cell
var win := Vector2i.ZERO      # window size in cells
var cls := PackedByteArray()  # class of each window cell
var choke := PackedByteArray()        # 1: a one-tile gap right now
var choke_after := PackedByteArray()  # 1: a one-tile gap with the ghost standing
var ring := PackedByteArray()         # 1: open tile touching the ghost
var sealed := false           # the ghost would cut a route in two
var narrowed := 0             # tiles that would become one-tile gaps
var _key := ""
var _stamp := -1.0
var _lines := PackedVector2Array()
var _lines_key := ""
var fp := Rect2i()            # the ghost footprint


## What a tile is, for the grid: as you know it (another side's planned sites never show, and
## an enemy building you have never seen is open ground to you: Game.looks_free).
static func cell_class(g, c: Vector2i) -> int:
	if not g.in_map(c):
		return TERRAIN
	var i: int = g.idx(c)
	if g.side_ghost_at(g.human, c) != null:
		return BUILDING
	var v := int(g.solid[i])
	if v >= 2 and g.looks_free(g.human, c):
		return FREE
	match v:
		0:
			return FREE
		1:
			return TERRAIN
		4, 3:
			return WALL
		5:
			return FIELD
	return BUILDING


static func _open(v: int) -> bool:
	return v == FREE or v == FIELD


func update(g, kind: String, cell: Vector2i, now: float, force := false) -> void:
	var key := "%s@%s" % [kind, cell]
	if not force and key == _key and now - _stamp < 0.5:
		return
	_key = key
	_stamp = now
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	fp = Rect2i(cell, size)
	var lo := Vector2i(maxi(cell.x - MARGIN, 0), maxi(cell.y - MARGIN, 0))
	var hi := Vector2i(mini(cell.x + size.x + MARGIN, g.W), mini(cell.y + size.y + MARGIN, g.H))
	org = lo
	win = hi - lo
	var n := win.x * win.y
	if n <= 0:
		return
	cls.resize(n)
	for y in win.y:
		for x in win.x:
			cls[y * win.x + x] = cell_class(g, org + Vector2i(x, y))
	var cl2 := cls.duplicate()
	for y in size.y:
		for x in size.x:
			var w := cell + Vector2i(x, y) - org
			if w.x >= 0 and w.y >= 0 and w.x < win.x and w.y < win.y:
				cl2[w.y * win.x + w.x] = BUILDING
	choke = _chokes(cls)
	choke_after = _chokes(cl2)
	narrowed = 0
	ring.resize(n)
	ring.fill(0)
	for y in win.y:
		for x in win.x:
			var i := y * win.x + x
			if choke_after[i] == 1 and choke[i] == 0 and _open(cl2[i]):
				narrowed += 1
	# the open tiles touching the footprint; were any two joined before and parted now?
	var before := _label(cls)
	var after := _label(cl2)
	var seen := {}
	sealed = false
	var rim: Array[int] = []
	for y in range(fp.position.y - 1, fp.end.y + 1):
		for x in range(fp.position.x - 1, fp.end.x + 1):
			var inside := x >= fp.position.x and x < fp.end.x and y >= fp.position.y and y < fp.end.y
			var edge := (x < fp.position.x or x >= fp.end.x) != (y < fp.position.y or y >= fp.end.y)
			if inside or not edge:
				continue
			var w := Vector2i(x, y) - org
			if w.x < 0 or w.y < 0 or w.x >= win.x or w.y >= win.y:
				continue
			var i := w.y * win.x + w.x
			if _open(cls[i]):
				ring[i] = 1
				rim.append(i)
	for i in rim:
		var b := before[i]
		if seen.has(b):
			if seen[b] != after[i]:
				sealed = true
		else:
			seen[b] = after[i]
	if not sealed:
		ring.fill(0)
	_lines_key = ""


## One-tile gaps: an open tile with something solid on both sides of it, either way.
func _chokes(c: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(c.size())
	for y in range(1, win.y - 1):
		for x in range(1, win.x - 1):
			var i := y * win.x + x
			if not _open(c[i]):
				continue
			if (not _open(c[i - 1]) and not _open(c[i + 1])) or (not _open(c[i - win.x]) and not _open(c[i + win.x])):
				out[i] = 1
	return out


## Connected-area label of every open tile (4-way; 0 = not open).
func _label(c: PackedByteArray) -> PackedInt32Array:
	var lab := PackedInt32Array()
	lab.resize(c.size())
	var next := 1
	var stack: Array[int] = []
	for s in c.size():
		if lab[s] != 0 or not _open(c[s]):
			continue
		lab[s] = next
		stack.append(s)
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % win.x
			var y := i / win.x
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= win.x or ny >= win.y:
					continue
				var j: int = ny * win.x + nx
				if lab[j] == 0 and _open(c[j]):
					lab[j] = next
					stack.append(j)
		next += 1
	return lab


## Draws the grid into `ci` (a CanvasItem): `view` is the visible world rect.
func draw(ci: CanvasItem, g, view: Rect2) -> void:
	if win.x <= 0:
		return
	var T: float = g.T
	var lo := Vector2i(maxi(fp.position.x - SHOW, org.x), maxi(fp.position.y - SHOW, org.y))
	var hi := Vector2i(mini(fp.end.x + SHOW, org.x + win.x), mini(fp.end.y + SHOW, org.y + win.y))
	var vlo := Vector2i((view.position / T).floor()) - Vector2i.ONE
	var vhi := Vector2i((view.end / T).ceil()) + Vector2i.ONE
	lo = Vector2i(maxi(lo.x, vlo.x), maxi(lo.y, vlo.y))
	hi = Vector2i(mini(hi.x, vhi.x), mini(hi.y, vhi.y))
	if hi.x <= lo.x or hi.y <= lo.y:
		return
	var ctr := Vector2(fp.position) + Vector2(fp.size) * 0.5
	var reach := float(maxi(fp.size.x, fp.size.y)) * 0.5 + SHOW
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var i := (y - org.y) * win.x + (x - org.x)
			var v := int(cls[i])
			# fades out towards the edge of the grid
			var f := clampf(1.0 - (Vector2(x + 0.5, y + 0.5).distance_to(ctr) - 2.0) / reach, 0.25, 1.0)
			var col := Color(0, 0, 0, 0)
			if v == TERRAIN:
				col = Color(0.35, 0.3, 0.3, 0.22)
			elif v == BUILDING:
				col = Color(0.9, 0.35, 0.3, 0.2)
			elif v == WALL:
				col = Color(0.9, 0.5, 0.3, 0.22)
			elif v == FIELD:
				col = Color(0.95, 0.85, 0.3, 0.14)
			elif choke[i] == 1:
				col = Color(1.0, 0.75, 0.2, 0.30)      # a gap units already squeeze through
			elif choke_after[i] == 1 and not fp.has_point(Vector2i(x, y)):
				col = Color(1.0, 0.55, 0.1, 0.42)      # a gap the ghost would make
			elif ring[i] == 1:
				col = Color(1.0, 0.2, 0.2, 0.38)       # the ghost would cut the route here
			elif v == FREE:
				col = Color(0.5, 1.0, 0.6, 0.05)
			if col.a > 0.0:
				col.a *= f
				ci.draw_rect(Rect2(Vector2(x, y) * T, Vector2(T, T)), col)
	var lk := "%s%s%s" % [lo, hi, fp]
	if lk != _lines_key:
		_lines_key = lk
		_lines.clear()
		for y in range(lo.y, hi.y + 1):
			_lines.append(Vector2(lo.x, y) * T)
			_lines.append(Vector2(hi.x, y) * T)
		for x in range(lo.x, hi.x + 1):
			_lines.append(Vector2(x, lo.y) * T)
			_lines.append(Vector2(x, hi.y) * T)
	ci.draw_multiline(_lines, Color(1, 1, 1, 0.10), 1.0)
	if sealed or narrowed > 0:
		var txt := Loc.t("Cuts off a route") if sealed else Loc.t("Narrows a path")
		var col2 := Color(1.0, 0.35, 0.3, 0.95) if sealed else Color(1.0, 0.75, 0.25, 0.95)
		var font := ThemeDB.fallback_font
		var pos := Vector2(fp.position.x + fp.size.x * 0.5, fp.position.y) * T + Vector2(-60, -8)
		ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 3, Color(0, 0, 0, 0.8))
		ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, col2)
