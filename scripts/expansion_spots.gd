class_name ExpansionSpots
extends Node2D
## EXPANSION SPOTS (docs/expansion_spots.md; the owner, 2026-10-27: "a few tiles in a different colour in each map
## showing the best expansion places"). The best free hall spots of each side are tinted on the ground: the hall's
## footprint (5 x 4 cells), each cell a pale gold tile with a thin dark-and-gold border round the whole spot. A side's
## best spot is a little brighter than its second.
##
## How a spot is picked (rate(), once per match, from the bare map): every free base site (Game.base_sites that is
## nobody's start) belongs to the side whose main is the fewest steps away by land. It is scored by the room for an
## economy round it (open, buildable cells on the hall's own ground level within Defs.ECON_RANGE: the Crown's Farms
## and Mill, the Clockwork's gear field, which meshes only on one level), the ways in (gaps through which an army
## walks up to it), the walk from its own main, and how much nearer it is to its own main than to the enemy's. The
## two best of each side are marked. The map is turned through its middle, so twin spots score the same.
##
## Shown to a Crown or Clockwork player (the Brood rarely moves its capital: not to a Brood player), and when watching
## (spectator, replay). A spot hides once a building the viewer knows of stands on it (his own and his allies', an
## enemy's once seen), and when its lode was drawn out by a hall that fell there. Settings.expansion_spots turns them
## off. No per-frame drawing: the tiles are drawn once and redrawn only when a spot is taken or freed, or while the
## player places a hall (the spots then a touch brighter). Code-drawn (docs/art_style_inconsistency.md).

const PICKS := 2                       # spots marked per side
const GOLD := Color(1.0, 0.78, 0.32)   # warm gold: team-neutral, reads on grass, sand, snow and ash
const SHADE := Color(0.3, 0.18, 0.04)  # the brown wash under it
const EXIT_R := 12.0                   # tiles: the ring round a spot where its ways in are counted
const CHECK := 0.5                     # seconds between looks for a taken spot

var game: Game
## [{c: hall cell, team, rank (1 best, 2 next), score, room (0..1), ways, home, foe}]
var spots: Array = []
var shown: Array = []                  # the spots drawn now (tests)
var _t := 0.0
var _placing := false


func _ready() -> void:
	refresh()


## Should the spots show at all, for this viewer.
func active() -> bool:
	if not Settings.expansion_spots or game == null or game.edit_mode:
		return false
	if game.demo or game.replay != null:
		return true
	return game.human >= 0 and game.human < game.n_players() and game.faction_of(game.human) != "brood"


func _process(delta: float) -> void:
	var p := _placing_hall()
	_t -= delta
	if p != _placing or _t <= 0.0:
		_t = CHECK
		_placing = p
		refresh()


## Work out which spots show now; redraw only if that changed (or the placing look did).
func refresh() -> void:
	var now: Array = []
	if active():
		for s in spots:
			if not _taken(s["c"]):
				now.append(s)
	var key := str(_placing)
	for s in now:
		key += str(s["c"])
	if key != _key:
		_key = key
		shown = now
		queue_redraw()


var _key := "-"


func _placing_hall() -> bool:
	var ctl = game.controls if game else null
	if ctl == null or game.demo or game.human < 0:
		return false
	return String(ctl.mode) == "place" and String(ctl.place_kind) == game.faction_hall(game.human)


## A building the viewer knows of stands on the spot's footprint, or a hall fell there and drew its lode out.
func _taken(c: Vector2i) -> bool:
	var r := Rect2i(c, MapGen.HALL)
	for b in game.buildings:
		if b.dead or not Rect2i(Vector2i(b.cell), b.size).intersects(r):
			continue
		if (b.visible and not b.ghost) if game.demo else game.knows_building(game.human, b):
			return true
	for k in ["town_hall", "clocktower"]:
		if game.lode_at_spot(c, k) < 0.25:
			return true
	return false


func _draw() -> void:
	for s in shown:
		_tile(s["c"], int(s["rank"]) == 1)


func _tile(c: Vector2i, best: bool) -> void:
	var T := float(Game.T)
	var k := 1.5 if _placing else 1.0
	var fill := (0.3 if best else 0.2) * k
	var edge := (0.85 if best else 0.55) * minf(k, 1.15)
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var p := Vector2(c + Vector2i(x, y)) * T
			var cell := Rect2(p + Vector2(2, 2), Vector2(T - 4, T - 4))
			draw_rect(cell, Color(SHADE, fill * 0.6))      # (a light brown wash first: the gold then reads on snow and sand too)
			draw_rect(cell, Color(GOLD, fill))
	var r := Rect2(Vector2(c) * T, Vector2(MapGen.HALL) * T).grow(-1.0)
	draw_rect(r, Color(0, 0, 0, 0.35 * edge), false, 3.5)
	draw_rect(r, Color(GOLD, edge), false, 1.75 if best else 1.25)


## The minimap's marks (hud.gd draws them): small gold squares on the spots shown now.
func draw_on_minimap(ci: CanvasItem, m: Rect2) -> void:
	var k := m.size / Vector2(Game.W, Game.H)
	for s in shown:
		var mid := m.position + (Vector2(s["c"]) + Vector2(MapGen.HALL) * 0.5) * k
		var h := 2.5 if int(s["rank"]) == 1 else 2.0
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(0, 0, 0, 0.6), false, 2.0)
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(GOLD, 0.95 if int(s["rank"]) == 1 else 0.7), false, 1.0)


# ------------------------------------------------------------------ rating

## Rate every free base site from the bare map (call before any building stands) and keep each side's best.
static func rate(g: Game) -> Array:
	var out: Array = []
	var n := g.n_players()
	if n < 1 or g.starts.size() < n:
		return out
	var dist: Array = []
	for t in n:
		dist.append(_steps(g, g.starts[t]))
	var mine := {}               # team -> [{c, ...}]
	for c in g.base_sites:
		if g.starts.slice(0, n).has(c):
			continue
		var best_t := -1
		var bd := INF
		var tie := false
		for t in n:
			var d := _foot_d(g, dist[t], c)
			if d < bd:
				bd = d
				best_t = t
				tie = false
			elif d == bd:
				tie = tie or not g.allied(t, best_t)
		if best_t < 0 or tie or bd == INF:
			continue
		var foe := INF
		for o in n:
			if g.hostile(o, best_t):
				foe = minf(foe, _foot_d(g, dist[o], c))
		var room := _room(g, c)
		var ways := _ways(g, c)
		var safe := clampf((foe - bd) if foe < INF else 60.0, -40.0, 60.0)
		var score := 100.0 * room - bd + 0.5 * safe - 6.0 * maxf(0.0, float(ways[0]) - 1.0) - 0.25 * maxf(0.0, float(ways[1]) - 8.0)
		if not mine.has(best_t):
			mine[best_t] = []
		mine[best_t].append({"c": c, "team": best_t, "score": score, "room": room, "ways": int(ways[0]),
			"gap": int(ways[1]), "home": bd, "foe": foe})
	for t in mine:
		var list: Array = mine[t]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if absf(float(a["score"]) - float(b["score"])) > 0.001:
				return float(a["score"]) > float(b["score"])
			return float(a["home"]) < float(b["home"]))
		for i in mini(PICKS, list.size()):
			var s: Dictionary = list[i]
			s["rank"] = i + 1
			out.append(s)
	return out


## Steps by land (4 ways) from round a hall at `c` to every cell (INF: none).
static func _steps(g: Game, c: Vector2i) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(Game.W * Game.H)
	d.fill(INF)
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			if g.in_map(cc):
				d[g.idx(cc)] = 0.0
				q.append(cc)
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		var nd := d[g.idx(p)] + 1.0
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if g.in_map(n2) and d[g.idx(n2)] == INF and _open(g, n2):
				d[g.idx(n2)] = nd
				q.append(n2)
	return d


## Land an army walks over (the bare map: no buildings yet).
static func _open(g: Game, c: Vector2i) -> bool:
	var i := g.idx(c)
	return g.solid[i] != 1 and g.cliff[i] == 0


static func _foot_d(g: Game, d: PackedFloat32Array, c: Vector2i) -> float:
	var best := INF
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			if g.in_map(cc):
				best = minf(best, d[g.idx(cc)])
	return best


static func _mid(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(MapGen.HALL) * 0.5


## 0..1: the open, buildable ground on the spot's own level, joined to it, within a hall's economy reach.
static func _room(g: Game, c: Vector2i) -> float:
	var mid := _mid(c)
	var lv := int(g.height[g.idx(c + Vector2i(2, 2))]) if g.height.size() == Game.W * Game.H else 0
	var reach := float(Defs.ECON_RANGE)
	var seen := {}
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			seen[cc] = true
			q.append(cc)
	var head := 0
	var count := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		count += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2):
				continue
			var i := g.idx(n2)
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > reach:
				continue
			if g.solid[i] != 0 or g.ramp[i] != 0 or g.cliff[i] != 0 or (lv >= 0 and g.height.size() > i and int(g.height[i]) != lv):
				continue
			seen[n2] = true
			q.append(n2)
	return clampf(float(count) / (PI * reach * reach), 0.0, 1.0)


## [ways in, cells of gap]: the separate openings (8-joined runs of open land) just outside EXIT_R that the land
## round the spot (walked from it within EXIT_R) leads out through.
static func _ways(g: Game, c: Vector2i) -> Array:
	var mid := _mid(c)
	var seen := {}
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			seen[cc] = true
			q.append(cc)
	var exits := {}
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2) or not _open(g, n2):
				continue
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > EXIT_R:
				exits[n2] = true
				continue
			seen[n2] = true
			q.append(n2)
	# group the exit cells
	var groups := 0
	var done := {}
	for e in exits:
		if done.has(e):
			continue
		groups += 1
		var st: Array = [e]
		done[e] = true
		while not st.is_empty():
			var p: Vector2i = st.pop_back()
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n2 := p + Vector2i(dx, dy)
					if exits.has(n2) and not done.has(n2):
						done[n2] = true
						st.append(n2)
	return [groups, exits.size()]
