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
## Shown to a Crown or Clockwork player (the old Brood rarely moves its capital: not to an old-Brood player; the NEW
## Brood sees its best Mound Turtle spots, nb_pick), with a small label (_label), and when watching
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
var all: Array = []                    # every free base site rated (rate_all), for the computer
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
	if game.human < 0 or game.human >= game.n_players():
		return false
	# the old Brood rarely moves its capital: none; the NEW Brood expands with Mound Turtles: its turtle spots (nb_pick)
	return game.faction_of(game.human) != "brood" or BroodNew.on(game, game.human)


## The viewer plays the new Brood: its spots are the best TURTLE spots (nb_pick), not hall spots.
func _nb_view() -> bool:
	return not game.demo and game.replay == null and game.human >= 0 and BroodNew.on(game, game.human)


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
		if _nb_view():
			now = nb_pick(game, game.human, self)
		else:
			for s in spots:
				if not _taken(s["c"]):
					now.append(s)
	var key := str(_placing)
	for s in now:
		key += str(s["c"]) + str(s.get("tc", "")) + str(s["rank"])
	if key != _key:
		_key = key
		shown = now
		queue_redraw()


var _key := "-"


func _placing_hall() -> bool:
	var ctl = game.controls if game else null
	if ctl == null or game.demo or game.human < 0:
		return false
	if String(ctl.mode) == "nb_root" and String(ctl.place_kind) == BroodNew.TURTLE:
		return true           # (the new Brood placing a Mound Turtle)
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
		if s.has("tc"):
			_tile(s["tc"], int(s["rank"]) == 1, BroodRoot.fp(BroodNew.TURTLE)[0])      # (a Mound Turtle's footprint)
			if _placing:
				# while placing a turtle: how far its swamp would reach (a faint gold ring)
				var T := float(Game.T)
				var mid := (Vector2(s["tc"]) + Vector2(BroodRoot.fp(BroodNew.TURTLE)[0]) * 0.5) * T
				draw_arc(mid, float(Defs.NB["turtle_swamp"]) * T, 0, TAU, 72, Color(GOLD, 0.45 if int(s["rank"]) == 1 else 0.3), 2.0)
		else:
			_tile(s["c"], int(s["rank"]) == 1)


func _tile(c: Vector2i, best: bool, size: Vector2i = MapGen.HALL) -> void:
	var T := float(Game.T)
	var k := 1.5 if _placing else 1.0
	var fill := (0.3 if best else 0.2) * k
	var edge := (0.85 if best else 0.55) * minf(k, 1.15)
	for y in size.y:
		for x in size.x:
			var p := Vector2(c + Vector2i(x, y)) * T
			var cell := Rect2(p + Vector2(2, 2), Vector2(T - 4, T - 4))
			draw_rect(cell, Color(SHADE, fill * 0.6))      # (a light brown wash first: the gold then reads on snow and sand too)
			draw_rect(cell, Color(GOLD, fill))
	var r := Rect2(Vector2(c) * T, Vector2(size) * T).grow(-1.0)
	draw_rect(r, Color(0, 0, 0, 0.35 * edge), false, 3.5)
	draw_rect(r, Color(GOLD, edge), false, 1.75 if best else 1.25)


## THE LABEL (the owner, 22:09: the spots must READ as such): "OPTIMAL EXPANSION SPOT" on the best, "EXPANSION SPOT"
## on the next, small, on the tinted ground near its bottom edge. Shown while the camera is zoomed in to a normal view
## or nearer (LABEL_ZOOM; zoomed out the gold squares speak for themselves and words would clutter), and always while
## placing a hall or a Mound Turtle. Its size follows the zoom so it stays about LABEL_PX on screen.
const LABEL_ZOOM := 0.85
const LABEL_PX := 13.0


## The label's font size in map pixels now (0: not shown).
func _label_size() -> int:
	if game == null or game.camera == null:
		return 0
	var z := game.camera.zoom.x
	if z < LABEL_ZOOM and not _placing:
		return 0
	return clampi(int(round(LABEL_PX / maxf(z, 0.3))), 7, 20)


## Drawn on the game's overlay (Game._draw_mine_labels, as the workers' counts): over the map's lighting, so it reads
## on dark maps too; only the spots on screen.
func draw_labels(ci: CanvasItem) -> void:
	var fs := _label_size()
	if fs <= 0:
		return
	for s in shown:
		var sz: Vector2i = BroodRoot.fp(BroodNew.TURTLE)[0] if s.has("tc") else MapGen.HALL
		var c: Vector2i = Vector2i(s["tc"]) if s.has("tc") else Vector2i(s["c"])
		if game.view_rect.grow(200.0).has_point((Vector2(c) + Vector2(sz) * 0.5) * float(Game.T)):
			_label(ci, c, sz, int(s["rank"]) == 1, fs)


func _label(ci: CanvasItem, c: Vector2i, size: Vector2i, best: bool, fs: int) -> void:
	var T := float(Game.T)
	var font := UiStyle.bold_font()
	var txt := Loc.t("OPTIMAL EXPANSION SPOT" if best else "EXPANSION SPOT")
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(c) * T, Vector2(size) * T)
	var p := Vector2(r.get_center().x - w * 0.5, r.end.y - float(fs) * 0.45)
	var a := 1.0 if _placing else (0.95 if best else 0.8)
	# a dark pill under it (the ground under the tint is often dark and busy), then the words in gold
	var pad := float(fs) * 0.35
	var pill := Rect2(p + Vector2(-pad, -float(fs) * 0.85), Vector2(w + pad * 2.0, float(fs) * 1.15))
	ci.draw_rect(pill, Color(0.08, 0.05, 0.0, 0.62 * a))
	ci.draw_rect(pill, Color(GOLD, 0.55 * a), false, maxf(1.0, float(fs) / 12.0))
	ci.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD.lightened(0.4 if best else 0.2), a))


## The minimap's marks (hud.gd draws them): small gold squares on the spots shown now.
func draw_on_minimap(ci: CanvasItem, m: Rect2) -> void:
	var k := m.size / Vector2(Game.W, Game.H)
	for s in shown:
		var mid := m.position + ((Vector2(s["tc"]) + Vector2(BroodRoot.fp(BroodNew.TURTLE)[0]) * 0.5) if s.has("tc") else (Vector2(s["c"]) + Vector2(MapGen.HALL) * 0.5)) * k
		var h := 2.5 if int(s["rank"]) == 1 else 2.0
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(0, 0, 0, 0.6), false, 2.0)
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(GOLD, 0.95 if int(s["rank"]) == 1 else 0.7), false, 1.0)


# ------------------------------------------------------------------ the new Brood's turtle spots

## THE NEW BROOD (the owner, 21:28: "no expansion spots shown for the new Brood"): it expands by rooting a MOUND TURTLE
## on new ground (its swamp lets Rootmaws root there; 15+ tiles from the Mother and from the turtles that already count,
## it makes her lay faster: BroodNew.expansions). Its spots are its side's free base sites (rated as the hall spots:
## room, ways in, walk, safety: rate_all), each with the turtle's 3x3 footprint placed in it (nb_rate) and scored up for
## the Rootmaw circles that fit round it on its level, inside the turtle's swamp. Shown now (nb_pick): the PICKS best
## that are fresh ground, at least expansion_tiles from the Mother and from every turtle that already counts, and not
## taken (a building or a rooted creature on the spot, a turtle of the side rooted there, its Rootmaw ground spent).
var nb_cands := {}          # team -> [{c, team, tc (the turtle's top-left cell), maws, score, ...}], best first


## The side's candidate turtle spots, rated once (from the base sites' hall ratings and the ground).
static func nb_rate(g: Game, t: int, all_sites: Array) -> Array:
	var out: Array = []
	var fs: Vector2i = BroodRoot.fp(BroodNew.TURTLE)[0]
	for s in all_sites:
		if int(s["team"]) != t:
			continue
		var c: Vector2i = s["c"]
		var mid := Vector2(c) + Vector2(MapGen.HALL) * 0.5
		var tc := Vector2i(-1, -1)
		# the turtle's footprint in the hall spot (its middle first, then round it): level, open ground, no ramp
		for r in 4:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if tc.x >= 0 or (absi(dx) != r and absi(dy) != r):
						continue
					var cc := Vector2i(int(mid.x - fs.x * 0.5), int(mid.y - fs.y * 0.5)) + Vector2i(dx, dy)
					if _ground_ok(g, cc, fs):
						tc = cc
		if tc.x < 0:
			continue
		var maws := _maw_room(g, tc, fs)
		if maws < 2:
			continue           # (room for a turtle and SEVERAL Rootmaw circles)
		var e: Dictionary = s.duplicate()
		e["tc"] = tc
		e["maws"] = maws
		e["score"] = float(s["score"]) + 12.0 * float(maws)
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["score"]) - float(b["score"])) > 0.001:
			return float(a["score"]) > float(b["score"])
		return float(a["home"]) < float(b["home"]))
	return out


## A footprint of `sz` at `c` on open, level ground with no ramp (the terrain only).
static func _ground_ok(g: Game, c: Vector2i, sz: Vector2i) -> bool:
	var lv := -999
	for y in sz.y:
		for x in sz.x:
			var cc := c + Vector2i(x, y)
			if not g.in_map(cc):
				return false
			var i := g.idx(cc)
			if g.solid[i] == 1 or g.cliff[i] != 0 or g.ramp[i] != 0:
				return false
			if lv == -999:
				lv = int(g.height[i])
			elif int(g.height[i]) != lv:
				return false
	return true


## How many Rootmaw circles fit round a turtle at `tc` (greedy, their middles PIT_CLAIM x 2 tiles apart, inside its
## swamp, on its level, clear of its footprint).
static func _maw_room(g: Game, tc: Vector2i, fs: Vector2i) -> int:
	var mid := Vector2(tc) + Vector2(fs) * 0.5
	var lv := int(g.height[g.idx(tc)])
	var ms: Vector2i = BroodRoot.fp(BroodNew.MAW)[0]
	var apart := float(Defs.PIT_CLAIM) * 2.0
	var reach := float(Defs.NB["turtle_swamp"]) - 1.5
	var got: Array = []
	var trect := Rect2i(tc, fs).grow(1)
	for ring in [3.5, 5.5, 7.5]:
		if ring > reach:
			break
		for i in 16:
			var p: Vector2 = mid + Vector2.from_angle(TAU * i / 16.0 + ring * 0.3) * ring
			var mc := Vector2i(int(p.x - ms.x * 0.5), int(p.y - ms.y * 0.5))
			if Rect2i(mc, ms).intersects(trect) or not _ground_ok(g, mc, ms) or int(g.height[g.idx(mc)]) != lv:
				continue
			if got.all(func(o: Vector2) -> bool: return o.distance_to(p) >= apart):
				got.append(p)
	return got.size()


## The turtle spots shown now for side t (the PICKS best still good), ranked 1, 2.
static func nb_pick(g: Game, t: int, es: ExpansionSpots) -> Array:
	if not es.nb_cands.has(t):
		es.nb_cands[t] = nb_rate(g, t, es.all)
	var q := BroodNew.queen(g, t)
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	var counted: Array = BroodNew.expansions(g, q) if q != null else []
	var out: Array = []
	for s in es.nb_cands[t]:
		if out.size() >= PICKS:
			break
		var feet := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if q != null and q.position.distance_to(feet) < far:
			continue
		if counted.any(func(o: Unit) -> bool: return o.position.distance_to(feet) < far):
			continue
		var taken := false
		for u in g.units_near(feet, 7.0 * Defs.TILE):
			if u.team == t and u.kind == BroodNew.TURTLE and not u.dead and u.tesla_mode != "packed":
				taken = true          # (a turtle of the side already rooted there)
		if taken or es._taken(s["c"]) or BroodRoot.place_problem(g, t, BroodNew.TURTLE, feet).begins_with("Blocked"):
			continue
		var spent := false
		for id in g.nb_spots:
			var sp: Dictionary = g.nb_spots[id]
			if (sp["p"] as Vector2).distance_to(feet) < float(Defs.NB["turtle_swamp"]) * Defs.TILE and float(sp["left"]) < float(Defs.PIT_GROUND) * 0.5:
				spent = true           # (not fresh ground: Rootmaws drew it out)
		if spent:
			continue
		var e: Dictionary = s.duplicate()
		e["rank"] = out.size() + 1
		out.append(e)
	return out


# ------------------------------------------------------------------ rating

## Rate every free base site from the bare map (call before any building stands) and keep each side's best.
static func rate(g: Game) -> Array:
	return rate_all(g).filter(func(s: Dictionary) -> bool: return int(s["rank"]) > 0)


## Every free base site rated, each side's best PICKS ranked 1, 2 (the rest rank 0): the computer's hall choice uses all of
## them (AI._site_bonus, docs/ai_round6.md).
static func rate_all(g: Game) -> Array:
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
		for i in list.size():
			var s: Dictionary = list[i]
			s["rank"] = i + 1 if i < PICKS else 0
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
