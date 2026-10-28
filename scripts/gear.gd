class_name GearNet
extends Node2D
## THE GEAR FIELD (the Clockwork's base, docs/clockwork_gear_prototype.md; every number in Defs.GEAR).
##
## Every Clockwork building has a ring of real gears set into the ground round it (the painted ring rebuilt for its tooth
## count by GearArt, scripts/gear_art.gd, drawn flat on the ground at the 3/4 angle with a thick edge under it):
## radius = half its footprint + a pad (a SMALL or a BIG connecting gear; the Clocktower's is the biggest), rounded to a
## whole number of teeth. Rings that touch MESH: neighbours counter-rotate, a small gear spins faster than a big one and
## the teeth interlock (each gear's angle is worked out from its parent's in the connection tree with mesh_phase, so the
## mesh is exact). Two linked rings with a gap between them get an IDLER: a small free cog that meshes both (idler_for).
##
## CONNECTED: a finished building is connected if its ring touches a ring that is connected, down to a finished Clocktower
## (a Clocktower is a root: its own field). The graph is recomputed at once when anything changes and every 0.5 s.
## An unconnected building: gears stopped, `speed_mult` 0 (production, repairs, income), "UNLINKED" over it. A building
## that dies leaves its ring stopped; whatever hung on it alone is unlinked. Constructs stay wound on connected gear
## ground (Game.in_field asks here). The placement rule (placement_problem): a new building's ring must touch the
## connected field and may not cut deeper than Defs.GEAR.overlap into another ring (a Clocktower is the exception).
##
## THE LEVEL RULE (owner, 2026-10-26): rings mesh only on the same ground level. A building's level is its footprint's
## height (Game.height: 0 low ground, 1 high ground; a ramp counts as low ground and no building stands on one, so a
## footprint is on one level); two rings of buildings on different levels never link, however close (a high-ground ring
## reaching over the cliff edge, or a ring at the top of a ramp and one at its foot). And where two rings on one level meet,
## the ground is on that level too: the contact point of a direct mesh, the idler between a gap (an idler is never put
## across a cliff; of its two possible spots the one on the level is taken). joint_ok, level_ok; the placement ghost says
## NO LINK: OTHER LEVEL.
##
## THE TENSION RULE (Defs.TENSION_USERS, the Escapement): a building that uses Tension works only while it is connected AND
## its ring meshes directly with a Mainspring's ring (one hop, within the link gap: an idler between them counts). Such a
## building is linked last in the connection tree, hung on that Mainspring when there is one (so the drawn mesh and its
## idler run between the two); spring_of holds its Mainspring. Without one it is idle (speed_mult 0) and shows NEEDS
## MAINSPRING; the placement ghost says so too.

const T := Defs.TILE
const FY := Game.FIELD_Y
const PLATE_TUCK := 4.0          # px: the floor plate reaches this far under the ring's band

var game: Game
var enforce := true              # false: unconnected buildings work anyway (old tests, sandbox)
var linked := {}                 # Building -> true: connected
var parent_of := {}              # Building -> the building it hangs on in the connection tree
var order: Array = []            # connected buildings, roots first (parents before children)
var ang := {}                    # Building -> its gear's angle now
var version := 0                 # bumped when the connected set changes
var idler_of := {}               # Building -> {"pos": gear space, "n": teeth, "r": pitch radius} between it and its parent
var idler_ang := {}              # Building -> the angle of its idler now
var spring_of := {}              # a connected building (not a Mainspring) -> the Mainspring its ring meshes with (Tension rule)
var drive_of := {}               # a connected building -> rings from the nearest driver, a Clocktower or Mainspring (GearEcon)
var _field := {}                 # team -> [[centre in gear space, radius px]] of the connected rings
var _sig := -1
var _solved_at := -10.0
var _clock := 0.0
var _top: Node2D
var _top_t := 0.0
var spin_w := {}                 # Building -> its ring's turn rate now, rad/s in gear space (+ = the angle grows); 0 or absent: still
var bands: Array = []            # TURNING GEARS (scripts/gear_turn.gd): [building, centre in gear space, inner r, outer r] of each connected ring
var _band_grid := {}             # Vector2i (gear space / BAND_CELL) -> indices into bands
const BAND_CELL := 256.0
var view := false                # THE GEAR VIEW (the ` key, or GEAR VIEW on a Clockwork card): the whole network at a glance


func _ready() -> void:
	_top = Node2D.new()
	_top.z_index = 31
	_top.draw.connect(_draw_top)
	add_child(_top)


# ------------------------------------------------------------------ geometry (gear space: y is divided by FIELD_Y, so a
# ring lying flat on the ground is a circle there and an ellipse on the screen, like the old fields)

static func gpos(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y / FY)


## Teeth of a ring of this radius (px).
static func tooth_count(r: float) -> int:
	return maxi(10, int(round(TAU * r / float(Defs.GEAR["pitch"]))))


static func radius_of_teeth(n: int) -> float:
	return float(n) * float(Defs.GEAR["pitch"]) / TAU


## Kinds that only ever sit on their BIG ring (Defs.GEAR "big_only": the Heavy Works, the heavy torque): their ring is the
## big one whatever is asked, and they cannot swap.
static func big_only(kind: String) -> bool:
	return (Defs.GEAR["big_only"] as Array).has(kind)


## SIZE SETS THE TEMPO (owner, 2026-10-27): the work-speed multiplier of a `kind` on its big (or small) ring, Defs.GEAR
## "tempo" [small, big]; 1 for a kind not listed (it trades by crew, by its screw, or not at all).
static func tempo_of(kind: String, big: bool) -> float:
	var tt: Dictionary = Defs.GEAR["tempo"]
	if not Defs.gear_mode or not tt.has(kind):
		return 1.0
	return float(tt[kind][1 if big else 0])


## A building's tempo (its ring now; while its gear is swapped, the gear it had).
static func tempo(b: Building) -> float:
	return tempo_of(b.kind, b.gear_big)


## The tooth count of a building kind's ring: footprint half-extent + pad, to whole teeth.
static func ring_n(kind: String, size: Vector2i, big: bool) -> int:
	if big_only(kind):
		big = true
	var half := maxf(float(size.x) * T * 0.5, float(size.y) * T * 0.5 / FY)
	var pads: Dictionary = Defs.GEAR["pad"]
	var pad: float = pads["tower"] if kind == "clocktower" else (pads["big"] if big else pads["small"])
	return tooth_count(half + pad * T)


static func ring_r(kind: String, size: Vector2i, big: bool) -> float:
	return radius_of_teeth(ring_n(kind, size, big))


static func b_n(b: Building) -> int:
	return ring_n(b.kind, b.size, b.gear_big)


static func b_r(b: Building) -> float:
	return radius_of_teeth(b_n(b))


static func has_gear(b: Building) -> bool:
	return Defs.gear_mode and b.d["faction"] == "clockwork"


## The ring's centre in gear space.
static func b_c(b: Building) -> Vector2:
	return gpos(b.center())


## THE LEVEL RULE: the ground level of a footprint at cell c (0 low, 1 high: Game.height; a ramp is low ground). A footprint
## is on one level in play (none stands on a ramp or a cliff); a mixed one (the editor, a forced start) goes by most of its
## cells, a tie to the high ground.
static func foot_level(game: Game, c: Vector2i, size: Vector2i) -> int:
	if game == null or game.height.is_empty():
		return 0
	var n := 0
	var hi := 0
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if game.in_map(cc):
				n += 1
				if int(game.height[game.idx(cc)]) == 1:
					hi += 1
	return 1 if hi > 0 and hi * 2 >= n else 0


## A building's ground level (foot_level of its footprint).
static func b_level(b: Building) -> int:
	return foot_level(b.game, b.cell, b.size)


## The ground level under a point in gear space; -1 off the map.
static func level_at(game: Game, g: Vector2) -> int:
	if game == null or game.height.is_empty():
		return 0
	var c := game.cell_of(Vector2(g.x, g.y * FY))
	if not game.in_map(c):
		return -1
	return int(game.height[game.idx(c)])


## THE LEVEL RULE where two rings on ground level `lv` meet (centres ca, cb in gear space, pitch radii ra, rb, within the link
## gap): the ground at the contact point of a direct mesh, or at one of the idler's two possible spots, is on that level too.
## So no mesh and no idler across a cliff, even between two rings on one level (two plateaus with low ground between).
static func joint_ok(game: Game, ca: Vector2, ra: float, cb: Vector2, rb: float, lv: int) -> bool:
	if game == null or game.height.is_empty():
		return true
	var d := ca.distance_to(cb)
	if d < 0.001:
		return true
	var gap := d - ra - rb
	if gap <= float(Defs.GEAR["mesh_tol"]):
		return level_at(game, ca + (cb - ca) / d * (ra + gap * 0.5)) == lv
	for pos in idler_spots(ca, ra, cb, rb):
		if level_at(game, pos) == lv:
			return true
	return false


## Would a ring of `kind` at cell c (on its big gear: `big`) mesh with b's ring by THE LEVEL RULE: the same ground level, and
## the point where they meet on it (joint_ok). The distance (the link gap) is the caller's to check.
static func level_ok(game: Game, kind: String, c: Vector2i, big: bool, b: Building) -> bool:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var lv := foot_level(game, c, size)
	if lv != b_level(b):
		return false
	return joint_ok(game, gpos(Vector2(c) * T + Vector2(size) * T * 0.5), ring_r(kind, size, big), b_c(b), b_r(b), lv)


## Which painted ring a building wears: "tower" (a Clocktower), "big" or "small".
static func ring_kind(kind: String, big: bool) -> String:
	return "tower" if kind == "clocktower" else ("big" if big else "small")


## THE MESH RULE. A ring's tooth centres sit at phase + TAU*k/n. Ring A (phase pa, na teeth) drives ring B (nb teeth) whose
## centre lies in direction phi from A's: at the contact point a tooth of one faces a gap of the other, i.e. with
## u = frac((phi - pa) * na / TAU) and v = frac((phi + PI - pb) * nb / TAU), u + v = 0.5 (mod 1). Returns B's phase. Called
## every frame from the parent's phase, so it stays exact (and B counter-rotates at na/nb of A's speed).
static func mesh_phase(pa: float, na: int, phi: float, nb: int) -> float:
	var u := (phi - pa) * float(na) / TAU
	return fposmod(phi + PI - (0.5 - u) * TAU / float(nb), TAU)


## How far two rings are from meshing at their contact point, in teeth (0: a tooth exactly in the other's gap; 0.5: tooth on
## tooth). For tests and the ghost.
static func mesh_error(pa: float, na: int, pb: float, nb: int, phi: float) -> float:
	var u := fposmod((phi - pa) * float(na) / TAU, 1.0)
	var v := fposmod((phi + PI - pb) * float(nb) / TAU, 1.0)
	var e := fposmod(u + v - 0.5, 1.0)
	return minf(e, 1.0 - e)


## An IDLER for two linked rings (centres ca, cb in gear space, pitch radii ra, rb) whose pitch circles have a gap: a free cog
## of n teeth (at least Defs.GEAR.idler_min, enough to span the gap) whose pitch circle touches both, on the line of
## centres when it just spans the gap, else beside it (the side with more room from the `others` rings, [[centre, r]]).
## {} when the rings mesh directly (gap within Defs.GEAR.mesh_tol px). {"pos", "n", "r"}.
## `game` and `lv` (THE LEVEL RULE): only a spot whose ground is on level `lv` will do (when neither is, the best of both).
static func idler_for(ca: Vector2, ra: float, cb: Vector2, rb: float, others: Array = [], game: Game = null, lv := -1) -> Dictionary:
	var d := ca.distance_to(cb)
	var gap := d - ra - rb
	if gap <= float(Defs.GEAR["mesh_tol"]) or d < 0.001:
		return {}
	var n := idler_teeth(gap)
	var ri := radius_of_teeth(n)
	var spots := idler_spots(ca, ra, cb, rb)
	if game != null and lv >= 0:
		var on_level: Array = spots.filter(func(p: Vector2) -> bool: return level_at(game, p) == lv)
		if not on_level.is_empty():
			spots = on_level
	var best: Vector2 = spots[0]
	var best_room := -INF
	for pos in spots:
		var room := 1000.0
		for o in others:
			room = minf(room, pos.distance_to(o[0]) - float(o[1]) - ri)
		room += 0.02 * pos.y          # (a tie goes to the front side, where it shows)
		if room > best_room:
			best_room = room
			best = pos
	return {"pos": best, "n": n, "r": ri}


## The idler's teeth for a gap of `gap` px between two pitch circles: at least Defs.GEAR.idler_min, enough to span it.
static func idler_teeth(gap: float) -> int:
	return maxi(int(Defs.GEAR["idler_min"]), int(ceil(PI * gap / float(Defs.GEAR["pitch"]))))


## The idler's two possible centres (gear space) for two rings with a gap: its pitch circle touching both, one each side of
## the line of centres (the same point twice when it just spans the gap). [] when they mesh directly.
static func idler_spots(ca: Vector2, ra: float, cb: Vector2, rb: float) -> Array:
	var d := ca.distance_to(cb)
	var gap := d - ra - rb
	if gap <= float(Defs.GEAR["mesh_tol"]) or d < 0.001:
		return []
	var ri := radius_of_teeth(idler_teeth(gap))
	var a := ra + ri
	var bb := rb + ri
	var x := (a * a - bb * bb + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, a * a - x * x))
	var u := (cb - ca) / d
	var perp := Vector2(-u.y, u.x)
	return [ca + u * x + perp * h, ca + u * x - perp * h]


# ------------------------------------------------------------------ the graph

func is_linked(b: Building) -> bool:
	if not enforce or not has_gear(b):
		return true
	return linked.has(b)


## Work speed of a Clockwork building: 0 while unconnected (or while its gear is being swapped, or, using Tension, while
## its ring meshes with no Mainspring), else its DRIVE share (GearEcon: 1 meshing with a Clocktower or Mainspring, less
## farther out; always 1 for the Clocktower, supply and the turret).
func speed_mult(b: Building) -> float:
	if not enforce or not Defs.gear_mode or b.d["faction"] != "clockwork" or not b.built or b.dead:
		return 1.0
	if Defs.TENSION_USERS.has(b.kind) and not spring_of.has(b):
		return 0.0
	# (its drive share, times its ring size's tempo: a small Light Works trains 15% faster, Defs.GEAR "tempo")
	return GearEcon.work_mult(self, b) * tempo(b) if linked.has(b) and b.gear_swap_t < 0.0 else 0.0


## A Tension user's Mainspring (its ring meshing with this one's), null when it has none (or is not connected).
func spring_for(b: Building) -> Building:
	var m = spring_of.get(b)
	return m if m != null and is_instance_valid(m) and not m.dead else null


## A finished Clockwork building that uses Tension and is connected but meshes with no Mainspring: idle.
func needs_spring(b: Building) -> bool:
	return enforce and Defs.gear_mode and Defs.TENSION_USERS.has(b.kind) and b.built and not b.dead and linked.has(b) and spring_for(b) == null


func _signature() -> int:
	var s := 0
	for b in game.buildings:
		if is_instance_valid(b) and b.d["faction"] == "clockwork":
			s += b.serial % 9973 + (3 if b.built else 0) + (5 if b.dead else 0) + (7 if b.gear_big else 0) + (11 if b.ghost else 0)
	return s


## Recompute which buildings are connected (rings touching rings, from the Clocktowers).
func solve() -> void:
	_solved_at = _clock
	var was := linked.size()
	var old_set := linked
	linked = {}
	parent_of = {}
	order = []
	_field = {}
	spring_of = {}
	drive_of = {}
	bands = []
	_band_grid = {}
	if not Defs.gear_mode or game == null:
		return
	var list: Array = []
	var gp: Array = []
	var rr: Array = []
	var lv: Array = []
	for b in game.buildings:
		if is_instance_valid(b) and not b.dead and not b.ghost and b.built and b.d["faction"] == "clockwork":
			list.append(b)
			gp.append(b_c(b))
			rr.append(b_r(b))
			lv.append(b_level(b))
	var slack := float(Defs.GEAR["slack"]) * T
	var g0 := game
	# (rings touch within the link gap, on the same ground level, meeting on it: THE LEVEL RULE)
	var touch := func(a: int, j: int) -> bool:
		if (gp[a] as Vector2).distance_to(gp[j]) > float(rr[a]) + float(rr[j]) + slack:
			return false
		return int(lv[a]) == int(lv[j]) and joint_ok(g0, gp[a], rr[a], gp[j], rr[j], int(lv[a]))
	var q: Array = []
	for i in list.size():
		if list[i].kind == "clocktower":
			linked[list[i]] = true
			q.append(i)
	# Tension users wait until everything else reachable is linked, then each hangs on a linked Mainspring its ring
	# touches if there is one (else on whatever found it first), and the search goes on from them
	var deferred := {}          # index -> the index that found it first
	var qi := 0
	while true:
		while qi < q.size():
			var a: int = q[qi]
			qi += 1
			var ta: int = list[a].team
			for j in list.size():
				var bj: Building = list[j]
				if bj.team != ta or linked.has(bj) or deferred.has(j):
					continue
				if touch.call(a, j):
					if Defs.TENSION_USERS.has(bj.kind):
						deferred[j] = a
						continue
					linked[bj] = true
					parent_of[bj] = list[a]
					q.append(j)
		if deferred.is_empty():
			break
		for j in deferred.keys():
			var par: int = deferred[j]
			for k in q:
				if list[k].kind == "mainspring" and list[k].team == list[j].team and touch.call(k, j):
					par = k
					break
			linked[list[j]] = true
			parent_of[list[j]] = list[par]
			q.append(j)
		deferred.clear()
	# the Tension rule: each connected building's Mainspring (its parent, or one hanging on it): a Tension user works only
	# with one, and anything that costs Tension is made only at a building that has one (GearEcon.spend_problem)
	spring_of = {}
	for j in q:
		if list[j].kind == "mainspring":
			continue
		for k in q:
			if list[k].kind == "mainspring" and list[k].team == list[j].team and touch.call(k, j):
				spring_of[list[j]] = list[k]
				if parent_of.get(list[j]) == list[k]:
					break
	drive_of = GearEcon.drive_steps(list, linked, touch)      # (the efficiency: rings from a Clocktower or Mainspring)
	idler_of = {}
	for i in q:
		var b: Building = list[i]
		order.append(b)
		var p: Building = parent_of.get(b)
		if p != null:
			var others: Array = []
			for k in q:
				if k != i and list[k] != p:
					others.append([gp[k], rr[k]])
			var idl := idler_for(b_c(p), b_r(p), gp[i], rr[i], others, game, int(lv[i]))
			if not idl.is_empty():
				idler_of[b] = idl
		if not _field.has(b.team):
			_field[b.team] = []
		_field[b.team].append([gp[i], rr[i]])
	if old_set.size() != was or linked.size() != old_set.size() or not _same(old_set):
		version += 1
	_build_bands()
	_dirty_view()


func _same(a: Dictionary) -> bool:
	for k in linked:
		if not a.has(k):
			return false
	return true


func _dirty_view() -> void:
	if _top:
		_top.queue_redraw()


## Is p (world px) on connected gear ground of team t: inside a connected building's ring?
func in_field(t: int, p: Vector2) -> bool:
	var g := gpos(p)
	for r in _field.get(t, []):
		var rad: float = r[1]
		if g.distance_squared_to(r[0]) <= rad * rad:
			return true
	return false


# ------------------------------------------------------------------ TURNING GEARS (the owner's experiment, 2026-10-28;
# scripts/gear_turn.gd, docs/gear_turn.md): the toothed BAND of every connected ring (from the hole's edge, where the
# still floor plate starts, out to the tooth tips) carries what stands on it round with the teeth.

## The bands of the connected rings, and a coarse grid over them (rebuilt by solve()).
func _build_bands() -> void:
	bands = []
	_band_grid = {}
	var pitch := float(Defs.GEAR["pitch"])
	for b in order:
		var n := b_n(b)
		var kind := ring_kind(b.kind, b.gear_big)
		var r_out := GearArt.tip_r(radius_of_teeth(n), pitch)
		var r_in := GearArt.hole_r(kind, n)
		var c := b_c(b)
		var i := bands.size()
		bands.append([b, c, r_in, r_out])
		var lo := Vector2i(floori((c.x - r_out) / BAND_CELL), floori((c.y - r_out) / BAND_CELL))
		var hi := Vector2i(floori((c.x + r_out) / BAND_CELL), floori((c.y + r_out) / BAND_CELL))
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var k := Vector2i(x, y)
				if not _band_grid.has(k):
					_band_grid[k] = []
				_band_grid[k].append(i)


## The band under world point p: its index in `bands` (the one p is deepest in, where two rings' teeth meet), -1 if none.
## `grow` widens every band by that many px both ways (the step-off target keeps clear of them).
func band_at(p: Vector2, grow := 0.0) -> int:
	if bands.is_empty():
		return -1
	var g := gpos(p)
	var cell := Vector2i(floori(g.x / BAND_CELL), floori(g.y / BAND_CELL))
	var best := -1
	var bk := INF
	for i in _band_grid.get(cell, []):
		var bd: Array = bands[i]
		var d := g.distance_to(bd[1])
		var r_in: float = float(bd[2]) - grow
		var r_out: float = float(bd[3]) + grow
		if d < r_in or d > r_out:
			continue
		var k := d / r_out
		if k < bk:
			bk = k
			best = i
	return best


## Is the band at index i turning now (its ring connected and not stopped for a gear swap)?
func band_turning(i: int) -> bool:
	var b: Building = bands[i][0]
	return is_instance_valid(b) and not b.dead and absf(float(spin_w.get(b, 0.0))) > 0.0001


## The ground's velocity at world point p (world px/s): the teeth's speed there, round the ring's centre, the way it turns
## (in gear space the ring is a circle: speed = turn rate x distance; back to the screen, y x FIELD_Y). Zero off a band or
## on a still one.
func carry_at(p: Vector2) -> Vector2:
	var i := band_at(p)
	if i < 0:
		return Vector2.ZERO
	var bd: Array = bands[i]
	var b: Building = bd[0]
	if not is_instance_valid(b) or b.dead:
		return Vector2.ZERO
	var w := float(spin_w.get(b, 0.0))
	if w == 0.0:
		return Vector2.ZERO
	var r := gpos(p) - Vector2(bd[1])
	var v := Vector2(-r.y, r.x) * w
	return Vector2(v.x, v.y * FY)


## Where a unit of this radius standing on band i at p steps off to: just outside the ring (radially, else turned a little
## either way), on clear ground and off every band; failing that just inside the hole (the still floor plate) if that is
## clear; else INF.
func step_off_point(i: int, p: Vector2, radius: float, team: int) -> Vector2:
	var bd: Array = bands[i]
	var c: Vector2 = bd[1]
	var g := gpos(p)
	var dir := (g - c).normalized() if g.distance_to(c) > 0.5 else Vector2.RIGHT
	var margin := radius + float(Defs.GEAR_TURN["margin"])
	for rr: float in [float(bd[3]) + margin, float(bd[3]) + margin + 14.0, float(bd[2]) - margin]:
		for a: float in [0.0, 0.35, -0.35, 0.7, -0.7, 1.1, -1.1]:
			var q := c + dir.rotated(a) * rr
			var w := Vector2(q.x, q.y * FY)
			if not game.in_map(game.cell_of(w)) or not game._clear_at(w, radius, team):
				continue
			if band_at(w, radius * 0.5) >= 0:
				continue
			return w
	return Vector2.INF


# ------------------------------------------------------------------ THE TURRET CIRCLE (owner, 2026-10-27; docs/gear_rules.md)
# Each Ratchet Turret claims a circle of ground Defs.TURRET "claim" tiles round its centre (like the Brood's Feeding Pits:
# Game.pit_circles_overlap), and two turrets' circles of one side may not overlap. Lore: a turret's spring draws every bit
# of force from the gears under it; a second turret inside the circle would starve both and jam. Only new placements are
# checked: an old save with turrets closer than that keeps them.

## The circle's radius, world px.
static func turret_claim() -> float:
	return float(Defs.TURRET["claim"]) * T


## Where a Ratchet Turret placed at cell c has its centre (world px).
static func turret_mid(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(Defs.BUILDINGS[Defs.CW_TURRET]["size"]) * 0.5) * T


## Two turret circles overlap when their centres are closer than two radii (exactly two radii apart is fine).
static func turret_circles_overlap(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 2.0 * turret_claim() - 0.5


## Team t's living Ratchet Turrets (planned, being built or built) whose circle overlaps a turret circle at p (world px).
static func turret_overlaps(game: Game, t: int, p: Vector2, skip: Building = null) -> Array:
	var out: Array = []
	if game == null:
		return out
	for b in game.buildings:
		if is_instance_valid(b) and b.kind == Defs.CW_TURRET and b.team == t and not b.dead and b != skip \
				and turret_circles_overlap(b.center(), p):
			out.append(b)
	return out


## Why a Ratchet Turret can't go at cell c for team t because of the circles ("" when it can).
static func turret_problem(game: Game, t: int, c: Vector2i) -> String:
	if not Defs.gear_mode or turret_overlaps(game, t, turret_mid(c)).is_empty():
		return ""
	return "Too near a Ratchet Turret: each turret's spring draws all the force from the gears in its circle (4 tiles round it), and two turrets' circles may not overlap."


## The cell for a building of `kind` whose ring meshes with `around`'s ring nearest to direction `deg` (screen degrees,
## 0 = right, clockwise) from it: placeable, its ring links, the pitch-circle gap as small as possible (a direct mesh) and
## the angle close. (-1, -1) when none. The Lab's showcase and the computer's Escapement (by its Mainspring) use it;
## `unseen`: the computer's placement rules (placement_problem's `ai`: the Lab's setup, the computer).
static func ring_spot(game: Game, t: int, kind: String, around: Building, deg: float, unseen := false) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hc := b_c(around)
	var hr := b_r(around)
	var r := ring_r(kind, size, false)
	var want := deg_to_rad(deg)
	var best := Vector2i(-1, -1)
	var bs := INF
	var h0 := game.cell_of(around.center())
	for y in range(h0.y - 14, h0.y + 15):
		for x in range(h0.x - 14, h0.x + 15):
			var c := Vector2i(x, y)
			if not game.in_map(c):
				continue
			var g := gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
			var gap := g.distance_to(hc) - hr - r
			if gap < -float(Defs.GEAR["overlap"]) * T or gap > float(Defs.GEAR["slack"]) * T:
				continue
			var da := absf(angle_difference(want, (g - hc).angle()))
			var score := absf(gap) + (0.0 if absf(gap) <= float(Defs.GEAR["mesh_tol"]) else 12.0) + da * 60.0
			if score >= bs:
				continue
			if not level_ok(game, kind, c, false, around):
				continue          # (THE LEVEL RULE: on around's level, meeting it there)
			if game.placement_problem(t, kind, c, unseen) != "" or not game.margin_free(c, size):
				continue
			best = c
			bs = score
	return best


## "" if a building of kind k may go at cell c for team t, else why not: its ring must touch the connected field and
## not cut into another ring (a Clocktower starts a field of its own).
func placement_problem(t: int, k: String, c: Vector2i, big := false) -> String:
	var st := candidate(t, k, c, big)
	match st["state"]:
		"clash":
			return "Its gear ring would clash with a %s's ring: leave room for the gears to mesh." % String(Defs.BUILDINGS[st["with"].kind]["name"])
		"far":
			if st.get("level", false):
				return "Gears mesh only on the same ground level: its ring would touch your field only across a cliff or a ramp."
			return "Its gear ring must touch your gear field: mesh it with a linked building's ring."
		"turret":
			return turret_problem(game, t, c)
	return ""


## {"state": "ok" | "clash" | "turret" | "far" | "tower", "with": the building it clashes with (a "turret": the Ratchet
## Turret whose circle a new turret's would overlap), or the linked one its ring would hang on}; a Tension user (Defs.TENSION_USERS) that links also gets "spring": the finished Mainspring its ring would mesh with
## (null: none, it would stand idle) and hangs on that one when it is linked.
func candidate(t: int, k: String, c: Vector2i, big := false) -> Dictionary:
	if not enforce or not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork" or k == "clocktower":
		return {"state": "ok" if k != "clocktower" else "tower"}
	if _signature() != _sig:
		_sig = _signature()
		solve()
	big = big or big_only(k)
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var g := gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
	var r := ring_r(k, size, big)
	var lv := foot_level(game, c, size)
	var touch: Building = null
	var best := INF
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	var tension := GearEcon.spends_tension(k)          # (a Tension user, or a Light Works for its Springers and Netters)
	var spring: Building = null
	var sbest := INF
	var across := false             # (a linked ring in reach, but on the other level: THE LEVEL RULE)
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or b.team != t or b.d["faction"] != "clockwork":
			continue
		var gap := g.distance_to(b_c(b)) - (r + b_r(b))
		if gap < -over:
			return {"state": "clash", "with": b}
		if gap > slack:
			continue
		var meets := b_level(b) == lv and joint_ok(game, g, r, b_c(b), b_r(b), lv)
		if not meets:
			across = across or linked.has(b)
			continue
		if linked.has(b) and gap < best:
			touch = b
			best = gap
		if tension and b.kind == "mainspring" and b.built and not b.ghost and gap < sbest:
			spring = b
			sbest = gap
	if k == Defs.CW_TURRET:
		var near := turret_overlaps(game, t, turret_mid(c))      # (THE TURRET CIRCLE: no two turrets' circles overlap)
		if not near.is_empty():
			return {"state": "turret", "with": near[0]}
	if touch == null:
		return {"state": "far", "level": across}
	var out := {"state": "ok", "with": touch}
	if tension:
		out["spring"] = spring
		if spring != null and linked.has(spring):
			out["with"] = spring        # (the ghost turns meshed with the Mainspring: that is the mesh that counts)
	return out


## "" when a Tension user placed at c would mesh with a Mainspring (or the kind needs none), else why it would stand idle.
func spring_problem(t: int, k: String, c: Vector2i, big := false) -> String:
	if not Defs.TENSION_USERS.has(k) or not enforce or not Defs.gear_mode:
		return ""
	var st := candidate(t, k, c, big)
	if st["state"] == "ok" and st.get("spring") == null:
		return "Its ring meshes with no Mainspring: it will stand idle. Place it right beside a Mainspring."
	return ""


# ------------------------------------------------------------------ ticking and drawing

var _held_view := Rect2()       # held(): the view the rings were last drawn for


## The game is held paused (the 3-2-1 countdown, an online start waiting for the other player): tick() doesn't run yet,
## so solve and draw the rings as they stand, else they'd pop in at GO. Cheap while nothing changes (HUD._countdown).
func held() -> void:
	if game == null or not Defs.gear_mode:
		return
	var s := _signature()
	if s == _sig and game.view_rect == _held_view:
		return
	_held_view = game.view_rect
	if s != _sig:
		_sig = s
		solve()
		_spin(0.0)
	queue_redraw()
	if _top:
		_top.queue_redraw()


func tick(delta: float) -> void:
	_clock += delta
	if game == null:
		return
	if not game.puppet:
		for b in game.buildings:
			if is_instance_valid(b) and b.gear_swap_t >= 0.0 and not b.dead:
				b.gear_swap_t -= delta
				if b.gear_swap_t <= 0.0:
					b.gear_swap_t = -1.0
					b.gear_big = b.gear_swap_to
					if game.hud != null and b.team == game.human and not game.demo:
						game.float_text(b.center() + Vector2(0, -40), "big gear" if b.gear_big else "small gear", Color(0.95, 0.85, 0.5))
	var s := _signature()
	if s != _sig or _clock - _solved_at >= float(Defs.GEAR["solve"]):
		_sig = s
		solve()
	_spin(delta)
	for b in ang.keys():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			ang.erase(b)
			idler_ang.erase(b)
	if Defs.gear_mode:
		queue_redraw()
	_top_t -= delta
	if _top_t <= 0.0:
		_top_t = 0.25
		_top.queue_redraw()


## Turn the gears: a root turns by itself, every other connected gear (and the idler before it) is placed from its parent by
## the mesh rule (mesh_phase), so the teeth interlock exactly.
func _spin(delta: float) -> void:
	var rate := float(Defs.GEAR["teeth_rate"])
	spin_w = {}
	for b in order:
		if b.gear_swap_t >= 0.0:
			spin_w[b] = 0.0          # (its gear is being swapped: stopped, and so is everything hanging on it)
			continue
		var p: Building = parent_of.get(b)
		var nb := b_n(b)
		if p == null:
			spin_w[b] = TAU * rate / float(nb)
			ang[b] = fposmod(float(ang.get(b, 0.0)) + TAU * rate / float(nb) * delta, TAU)
			continue
		var pa := float(ang.get(p, 0.0))
		var np := b_n(p)
		var idl: Dictionary = idler_of.get(b, {})
		# (its turn rate, rad/s: the same rim speed as its parent's, the other way round when they mesh directly, the
		# same way through an idler; mesh_phase's d/dpa is -np/nb)
		spin_w[b] = float(spin_w.get(p, 0.0)) * float(np) / float(nb) * (-1.0 if idl.is_empty() else 1.0)
		if idl.is_empty():
			ang[b] = mesh_phase(pa, np, (b_c(b) - b_c(p)).angle(), nb)
		else:
			var ia := mesh_phase(pa, np, (Vector2(idl["pos"]) - b_c(p)).angle(), int(idl["n"]))
			idler_ang[b] = ia
			ang[b] = mesh_phase(ia, int(idl["n"]), (b_c(b) - Vector2(idl["pos"])).angle(), nb)


## The rings on the ground (this node sits under the buildings and units): every Clockwork building's ring and the idlers
## between linked rings; first all the thick edges, then all the faces, so a neighbour's edge never covers a face.
func _draw() -> void:
	if game == null or not Defs.gear_mode:
		return
	var ft := game.fog_team()
	var all := game.sees_all()
	var items: Array = []
	var cols: Dictionary = Defs.GEAR["col"]
	for b in game.buildings:
		if not is_instance_valid(b) or not has_gear(b):
			continue
		if b.dead and b.rubble_t > 24.0:
			continue
		if not all and ft >= 0 and not game.allied(ft, b.team) and not b.visible:
			continue        # (an enemy building whose side's eyes you look through haven't seen it: watching computers too)
		var c: Vector2 = b.center()
		var n: int = b_n(b)
		var rp := radius_of_teeth(n)
		if not game.view_rect.grow(rp + 60.0).has_point(c):
			continue
		var s := 1.0
		if b.gear_swap_t >= 0.0:
			# the ring visibly changes size while the gear is swapped: from the old radius to the new one
			var total := float(Defs.GEAR["swap_time"])
			var k := clampf(1.0 - b.gear_swap_t / total, 0.0, 1.0)
			var r_new := ring_r(b.kind, b.size, b.gear_swap_to)
			s = lerpf(rp, r_new, k * k * (3.0 - 2.0 * k)) / rp
		# state colours: connected (full), unlinked (dull red), a site (faint), dead (dark)
		var m := Color(1, 1, 1, 1)
		if b.dead:
			m = Color(cols["dead"].r * 1.4, cols["dead"].g * 1.4, cols["dead"].b * 1.4, 0.7)
		elif not b.built or b.ghost:
			m = Color(1, 1, 1, 0.45)
		elif enforce and not linked.has(b):
			m = Color(1.0, 0.6, 0.52, 0.85)
		items.append([ring_kind(b.kind, b.gear_big), n, c, float(ang.get(b, 0.0)), s, m, brass_plate(b.kind)])
		var idl: Dictionary = idler_of.get(b, {})
		if not idl.is_empty() and linked.has(b):
			var ip: Vector2 = idl["pos"]
			items.append(["idler", int(idl["n"]), Vector2(ip.x, ip.y * FY), float(idler_ang.get(b, 0.0)), 1.0, m])
	# the floor plates first: the fixed decks the rings turn round (under the ring's edge and the building)
	for it in items:
		if it[0] != "idler":
			draw_plate(self, it[0], it[1], it[2], it[4], it[5], it[6])
	for it in items:
		draw_ring(self, it[0], it[1], it[2], it[3], it[4], it[5], true, false)
	for it in items:
		draw_ring(self, it[0], it[1], it[2], it[3], it[4], it[5], false, true)
	var ctl = game.controls
	var placing: String = ctl.place_kind if ctl and ctl.mode == "place" and Defs.BUILDINGS.has(ctl.place_kind) else ""
	if view:
		_draw_view()
	if Defs.gear_turn and not bands.is_empty():
		_draw_turning()          # (over the gear view's wash, so its chevrons read)
	# THE TURRET CIRCLES: while a turret is placed (or in the gear view), every turret's circle of ground
	if placing == Defs.CW_TURRET or view:
		_draw_turret_circles(placing == Defs.CW_TURRET and ctl.ghost_cell.x >= 0, ctl.ghost_cell if ctl else Vector2i(-1, -1))
	# the placement ghost's ring, over the others so a clash reads
	if placing != "" and Defs.BUILDINGS[placing]["faction"] == "clockwork":
		draw_ghost(self, game.human, placing, ctl.ghost_cell)
	draw_set_transform(Vector2.ZERO)


## TURNING GEARS, made readable (docs/gear_turn.md; code-drawn: docs/art_style_inconsistency.md): little dust puffs kicked
## up behind every unit riding a band, and, on the band under the mouse (or every band in the GEAR VIEW), faint chevrons
## running round it the way it turns. Worked out from positions alone, so an online guest and a replay show them too.
func _draw_turning() -> void:
	draw_set_transform(Vector2.ZERO)
	var vr := game.view_rect
	var tk := float(Time.get_ticks_msec()) * 0.001
	# the dust at carried units' feet
	for u in game.units:
		if not is_instance_valid(u) or u.dead or not u.visible or not vr.has_point(u.position):
			continue
		if not game.puppet and u.gt_carry == Vector2.ZERO:
			continue
		if game.puppet and not GearTurn.carriable(u):
			continue
		var v: Vector2 = u.gt_carry if not game.puppet else carry_at(u.position)
		if v.length_squared() < 4.0:
			continue
		var back := -v.normalized()
		var seed_ := float(int(u.get_instance_id()) % 97) * 0.37
		for j in 3:
			var ph := fposmod(tk / float(Defs.GEAR_TURN["dust"]) * 0.33 + seed_ + float(j) / 3.0, 1.0)
			var p: Vector2 = u.position + back * (4.0 + ph * 16.0) + Vector2((float(j) - 1.0) * 4.0, 2.0 - ph * 5.0)
			draw_circle(p, 1.5 + ph * 3.5, Color(0.55, 0.47, 0.34, 0.42 * (1.0 - ph)))
	# the chevrons: the band under the mouse, or all of them in the gear view
	var mouse := get_global_mouse_position()
	var hover := band_at(mouse)
	var ft := game.fog_team()
	var all := game.sees_all()
	for i in bands.size():
		if not view and i != hover:
			continue
		var bd: Array = bands[i]
		var b: Building = bd[0]
		if not is_instance_valid(b) or b.dead or not band_turning(i):
			continue
		if not all and ft >= 0 and not game.allied(ft, b.team) and not b.visible:
			continue
		var c: Vector2 = bd[1]
		var rm := (float(bd[2]) + float(bd[3])) * 0.5
		if not vr.grow(rm).has_point(Vector2(c.x, c.y * FY)):
			continue
		var w := float(spin_w.get(b, 0.0))
		var sgn := 1.0 if w > 0.0 else -1.0
		var n := maxi(6, int(TAU * rm / 70.0))
		var off := float(ang.get(b, 0.0))
		for k in n:
			var a := off + TAU * float(k) / float(n)
			var pc := c + Vector2.from_angle(a) * rm
			var tg := Vector2.from_angle(a + PI * 0.5) * sgn          # (the way the band moves there)
			var nr := Vector2.from_angle(a)
			var tip := pc + tg * 7.0
			var pts := PackedVector2Array([pc - tg * 3.0 + nr * 7.0, tip, pc - tg * 3.0 - nr * 7.0])
			for q in pts.size():
				pts[q] = Vector2(pts[q].x, pts[q].y * FY)
			draw_polyline(pts, Color(0.05, 0.04, 0.02, 0.8), 5.0, true)
			draw_polyline(pts, Color(1.0, 0.86, 0.45, 0.85), 2.2, true)


## One painted ring on `ci` in world space: centre `c` (world px), turned by `rot` and squashed onto the ground (rotate the
## flat ring, then FIELD_Y vertically, in one transform), scaled by `s`, tinted `mod`. `edge`: the thick edge under it (the
## ring's silhouette drawn Defs.GEAR.edge times, each 1 px lower, darkening downward); `face`: the ring itself.
## Does this kind stand on the BRASS floor plate (it uses Tension: Defs.GEAR "brass_plate"), else the iron one?
static func brass_plate(kind: String) -> bool:
	return (Defs.GEAR["brass_plate"] as Array).has(kind)


static func draw_ring(ci: CanvasItem, kind: String, n: int, c: Vector2, rot: float, s: float, mod: Color, edge := true, face := true, glow := Color(0, 0, 0, 0)) -> void:
	var art := GearArt.ring(kind, n)
	var cs := cos(rot) * s
	var sn := sin(rot) * s
	var xa := Vector2(cs, sn * FY)
	var ya := Vector2(-sn, cs * FY)
	if art.is_empty():
		# (no strips: the old code-drawn ring)
		if face:
			ci.draw_set_transform_matrix(Transform2D(xa, ya, c))
			draw_gear(ci, n, radius_of_teeth(n), Color(Defs.GEAR["col"]["brass"]) * mod, Defs.GEAR["col"]["edge"], Color(0, 0, 0, 0))
		return
	var half: float = art[3]
	var rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	if edge:
		var depth := int(Defs.GEAR["edge"])
		var ec: Color = Defs.GEAR["col"]["rim"]
		for k in range(depth, 0, -1):
			var t := 1.0 - float(k) / float(depth)
			var col := Color(ec.r * (0.55 + 0.45 * t), ec.g * (0.55 + 0.45 * t), ec.b * (0.55 + 0.45 * t), mod.a)
			ci.draw_set_transform_matrix(Transform2D(xa, ya, c + Vector2(0, float(k))))
			ci.draw_texture_rect(art[1], rect, false, col)
	if face:
		ci.draw_set_transform_matrix(Transform2D(xa, ya, c))
		ci.draw_texture_rect(art[0], rect, false, mod)
		if glow.a > 0.0:
			ci.draw_texture_rect(art[1], rect, false, glow)       # (a wash of colour over it: the ghost's verdict)


## The FLOOR PLATE in a ring's hole (GearArt.plate): a flat round iron deck, a few px wider than the hole so it tucks under
## the band, squashed onto the ground like the ring but never turned (it is bolted down; the ring turns round it).
## `brass`: the polished brass deck of a building that uses Tension (brass_plate).
static func draw_plate(ci: CanvasItem, kind: String, n: int, c: Vector2, s: float, mod: Color, brass := false) -> void:
	var r := (GearArt.hole_r(kind, n) + float(PLATE_TUCK)) * s
	var tex := GearArt.plate(int(round(r * 2.0)), brass)
	if tex == null:
		return
	ci.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, FY), c))
	ci.draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, mod)


func _draw_top() -> void:
	if game == null or not Defs.gear_mode:
		return
	var font := ThemeDB.fallback_font
	var me := game.controlled_team()
	var ft := game.fog_team()
	var all := game.sees_all()
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or not b.built or not has_gear(b) or not game.view_rect.intersects(b.rect()):
			continue
		if me >= 0 and not game.allied(me, b.team):
			continue
		if not all and ft >= 0 and not game.allied(ft, b.team) and not b.visible:
			continue        # (watching computers through one side's eyes: a building it hasn't seen)
		if b.kind != "mainspring" and spring_for(b) != null and linked.has(b):
			_spring_mark(b.rect().get_center() + Vector2(b.rect().size.x * 0.5 - 4.0, -b.rect().size.y * 0.5 - 4.0))
		var txt := ""
		var col := Color(0.95, 0.35, 0.28)
		if enforce and not linked.has(b):
			txt = "UNLINKED"
		elif b.gear_swap_t >= 0.0:
			txt = "SWAPPING"
			col = Color(0.95, 0.8, 0.4)
		elif needs_spring(b):
			txt = "NEEDS MAINSPRING"
			col = Color(1.0, 0.72, 0.3)
		if txt == "":
			continue
		_badge(font, b.rect().get_center() + Vector2(0, -b.rect().size.y * 0.5 - 14.0), txt, col)


## THE SPRING MARK (owner, 2026-10-27): a little brass coil over a building fed by a Mainspring (its ring meshes with one:
## it may make what costs Tension). Code-drawn: docs/art_style_inconsistency.md.
func _spring_mark(p: Vector2) -> void:
	var r := Rect2(p + Vector2(-9, -11), Vector2(18, 22))
	_top.draw_rect(r, Color(0.05, 0.05, 0.07, 0.75))
	_top.draw_rect(r, Color(0.95, 0.78, 0.35, 0.9), false, 1.0)
	var pts := PackedVector2Array()
	for i in 41:
		var k := float(i) / 40.0
		pts.append(p + Vector2(5.0 * sin(k * TAU * 3.5), -8.0 + 16.0 * k))       # (a coil seen from the side)
	_top.draw_polyline(pts, Color(0.2, 0.12, 0.04), 3.4, true)
	_top.draw_polyline(pts, Color(1.0, 0.82, 0.4), 1.7, true)


func _badge(font: Font, p: Vector2, txt: String, col: Color) -> void:
	txt = Loc.t(txt)
	var sz := 12
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var r := Rect2(p + Vector2(-w * 0.5 - 14.0, -9.0), Vector2(w + 22.0, 17.0))
	_top.draw_rect(r, Color(0.05, 0.05, 0.07, 0.82))
	_top.draw_rect(r, col, false, 1.5)
	var dc := r.position + Vector2(9.0, 8.5)
	_top.draw_arc(dc, 4.5, 0.0, TAU, 12, col, 1.5)
	_top.draw_circle(dc, 1.6, col)
	_top.draw_string(font, r.position + Vector2(18.0, 13.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


## The placement ghost's ring (Game._draw_fields): drawn on `ci` in world space, tinted green when it links (then it already
## turns meshed with the ring it would hang on, with the idler it would get), orange when it is too far from the field, red
## when it clashes with another ring.
func draw_ghost(ci: CanvasItem, t: int, k: String, c: Vector2i, big := false) -> void:
	if not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork":
		return
	big = big or big_only(k)
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var centre := Vector2(c) * T + Vector2(size) * T * 0.5
	var st := candidate(t, k, c, big)
	var col: Color = ghost_colour(st["state"])
	if st["state"] == "ok" and Defs.TENSION_USERS.has(k) and st.get("spring") == null:
		col = ghost_colour("far")         # (it links, but no Mainspring: it would stand idle)
	var n := ring_n(k, size, big)
	var k_tint := 0.85 if st["state"] == "clash" else 0.55
	var tint := Color(lerpf(1.0, col.r, k_tint), lerpf(1.0, col.g, k_tint), lerpf(1.0, col.b, k_tint), 0.8)
	var rot := float(_clock) * 0.3
	var p: Building = st.get("with") if st["state"] == "ok" else null
	if p != null and is_instance_valid(p):
		var g := gpos(centre)
		var others: Array = []
		var idl := idler_for(b_c(p), b_r(p), g, radius_of_teeth(n), others, game, foot_level(game, c, size))
		var pa := float(ang.get(p, 0.0))
		if idl.is_empty():
			rot = mesh_phase(pa, b_n(p), (g - b_c(p)).angle(), n)
		else:
			var ip: Vector2 = idl["pos"]
			var ia := mesh_phase(pa, b_n(p), (ip - b_c(p)).angle(), int(idl["n"]))
			rot = mesh_phase(ia, int(idl["n"]), (g - ip).angle(), n)
			draw_ring(ci, "idler", int(idl["n"]), Vector2(ip.x, ip.y * FY), ia, 1.0, tint)
	draw_plate(ci, ring_kind(k, big), n, centre, 1.0, Color(tint.r, tint.g, tint.b, 0.6), brass_plate(k))
	draw_ring(ci, ring_kind(k, big), n, centre, rot, 1.0, tint, true, true, Color(col.r, col.g, col.b, 0.38 if st["state"] == "clash" else 0.18))
	ci.draw_set_transform(Vector2.ZERO)
	draw_contacts(ci, t, k, c, big)


## READABILITY (owner, 2026-10-27): on the placing ghost, the TEETH where its ring would mesh glow green (on both rings,
## at the point where they meet; a gap an idler would fill too), and where it would clash red. World space on `ci`.
func draw_contacts(ci: CanvasItem, t: int, k: String, c: Vector2i, big := false) -> void:
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var g := gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
	var r := ring_r(k, size, big)
	var lv := foot_level(game, c, size)
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	var cols: Dictionary = Defs.GEAR["col"]
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or b.team != t or b.d["faction"] != "clockwork":
			continue
		var gb := b_c(b)
		var rb := b_r(b)
		var dd := g.distance_to(gb)
		if dd < 0.001:
			continue
		var gap := dd - r - rb
		var col: Color
		if gap < -over:
			col = cols["clash"]
		elif gap <= slack and linked.has(b) and b_level(b) == lv and joint_ok(game, g, r, gb, rb, lv):
			col = cols["ok"]
		else:
			continue
		var phi := (gb - g).angle()
		_teeth_arc(ci, g, r, phi, col)
		_teeth_arc(ci, gb, rb, phi + PI, col)


## A short glowing arc of a ring's teeth (gear space centre g, pitch radius r) round direction phi, drawn on the ground.
static func _teeth_arc(ci: CanvasItem, g: Vector2, r: float, phi: float, col: Color) -> void:
	var da := clampf(38.0 / maxf(r, 1.0), 0.12, 0.6)
	var pts := PackedVector2Array()
	for i in 9:
		var a := phi - da + 2.0 * da * float(i) / 8.0
		var p := g + Vector2.from_angle(a) * r
		pts.append(Vector2(p.x, p.y * FY))
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.45), 9.0, true)
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.95), 3.5, true)


## THE GEAR VIEW (owner, 2026-10-27): over the rings, the whole network. The drivers (Clocktowers, Mainsprings) glow bright
## gold; every other ring is washed by how well it works (full green, 90% yellow, 80% orange, 70% red-orange; idle or
## unlinked red); each Mainspring's REACH (where a ring must reach to mesh with it, for the Tension rule) is outlined dashed.
## The controlled side's buildings (or everyone's when watching).
func _draw_view() -> void:
	var me := game.controlled_team()
	var slack := float(Defs.GEAR["slack"]) * T
	# (the ground dims a little so the rings read)
	draw_rect(game.view_rect.grow(40.0), Color(0.02, 0.03, 0.06, 0.32))
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or not has_gear(b) or not b.built:
			continue
		if me >= 0 and not game.allied(me, b.team):
			continue
		var c: Vector2 = b.center()
		var n := b_n(b)
		var rp := radius_of_teeth(n)
		if not game.view_rect.grow(rp + slack + 60.0).has_point(c):
			continue
		var w := view_colour(b)
		draw_ring(self, ring_kind(b.kind, b.gear_big), n, c, float(ang.get(b, 0.0)), 1.0, Color(1, 1, 1, 1), false, true, w)
		if b.kind == "mainspring" and linked.has(b):
			_dashed_ellipse(c, rp + slack, Color(1.0, 0.82, 0.35, 0.85), 2.5)
	draw_set_transform(Vector2.ZERO)


## The gear view's wash for a building's ring: a driver bright gold, else by how well it works.
func view_colour(b: Building) -> Color:
	if b.kind == "clocktower" or (b.kind == "mainspring" and linked.has(b)):
		return Color(1.0, 0.97, 0.78, 0.7)          # (a driver: bright white gold)
	var m := speed_mult(b) / maxf(tempo(b), 0.01)
	if enforce and (not linked.has(b) or m <= 0.0):
		return Color(1.0, 0.2, 0.18, 0.6)
	if m >= 0.99:
		return Color(0.3, 1.0, 0.4, 0.5)
	if m >= 0.89:
		return Color(0.85, 1.0, 0.25, 0.5)
	if m >= 0.79:
		return Color(1.0, 0.62, 0.15, 0.55)
	return Color(1.0, 0.38, 0.18, 0.6)


## A dashed ellipse on the ground: a circle of radius r in gear space round world point c.
func _dashed_ellipse(c: Vector2, r: float, col: Color, w: float) -> void:
	draw_set_transform(Vector2.ZERO)
	var n := maxi(32, int(r / 6.0))
	for i in range(0, n, 2):
		var pts := PackedVector2Array()
		for k in 5:
			var a := TAU * (float(i) + float(k) / 4.0) / float(n)
			var p := Vector2.from_angle(a) * r
			pts.append(c + Vector2(p.x, p.y * FY))
		draw_polyline(pts, col, w, true)


## THE TURRET CIRCLES on the ground (true circles, like the Brood's pit circles): every turret of the controlled side, and
## while one is placed (`ghost`, at cell gc) the ghost's own circle, green when it is free, red where it overlaps another
## turret's (whose circle turns red too).
func _draw_turret_circles(ghost: bool, gc: Vector2i) -> void:
	draw_set_transform(Vector2.ZERO)
	var me := game.controlled_team()
	var r := turret_claim()
	var gp := turret_mid(gc) if ghost else Vector2.INF
	var hits: Array = turret_overlaps(game, game.human, gp) if ghost else []
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or b.kind != Defs.CW_TURRET:
			continue
		if me >= 0 and not game.allied(me, b.team):
			continue
		if not game.view_rect.grow(r + 20.0).has_point(b.center()):
			continue
		var bad := hits.has(b)
		var col := Color(1.0, 0.35, 0.3) if bad else Color(0.95, 0.78, 0.4)
		draw_circle(b.center(), r, Color(col.r, col.g, col.b, 0.12 if bad else 0.06))
		draw_arc(b.center(), r, 0.0, TAU, 72, Color(col.r, col.g, col.b, 0.85), 2.0, true)
	if ghost:
		var ok := hits.is_empty()
		var gcol := Color(0.45, 1.0, 0.45) if ok else Color(1.0, 0.35, 0.3)
		draw_circle(gp, r, Color(gcol.r, gcol.g, gcol.b, 0.12))
		draw_arc(gp, r, 0.0, TAU, 72, Color(gcol.r, gcol.g, gcol.b, 0.9), 2.5, true)


func ghost_colour(state: String) -> Color:
	var cols: Dictionary = Defs.GEAR["col"]
	return cols["clash"] if state == "clash" or state == "turret" else (cols["far"] if state == "far" else cols["ok"])


## The ghost's verdict over it (LINKS / NO LINK / CLASH / NEW FIELD), drawn on the overlay above the buildings.
func draw_ghost_label(ci: CanvasItem, t: int, k: String, c: Vector2i, big := false) -> void:
	if not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork":
		return
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var centre := Vector2(c) * T + Vector2(size) * T * 0.5
	var gt := ghost_text(t, k, c, big)
	var label: String = gt[0]
	var col: Color = gt[1]
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at := centre + Vector2(-w * 0.5, -float(size.y) * T * 0.5 - 34.0)
	ci.draw_rect(Rect2(at + Vector2(-6, -14), Vector2(w + 12, 20)), Color(0.05, 0.05, 0.07, 0.85))
	ci.draw_rect(Rect2(at + Vector2(-6, -14), Vector2(w + 12, 20)), col, false, 1.5)
	ci.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


## The ghost's verdict for kind k at cell c, translated, and its colour: [text, Color]. LINKS (with the % it would work at:
## GearEcon.ghost_note), NO LINK, NO LINK: OTHER LEVEL (THE LEVEL RULE), CLASH, NEW FIELD; a Tension user NEEDS MAINSPRING
## or MESHES MAINSPRING.
func ghost_text(t: int, k: String, c: Vector2i, big := false) -> Array:
	var st := candidate(t, k, c, big)
	var state: String = st["state"]
	var label: String = {"far": "NO LINK", "clash": "CLASH", "tower": "NEW FIELD", "turret": "TOO NEAR A TURRET"}.get(state, "LINKS")
	if state == "far" and st.get("level", false):
		label = "NO LINK: OTHER LEVEL"        # (THE LEVEL RULE: it reaches the field only across a cliff or a ramp)
	# (a refusal, or a building that would stand idle, reads red: one line, the reason; owner 2026-10-27)
	var col := ghost_colour("clash") if state == "far" or state == "clash" or state == "turret" else ghost_colour(state)
	if state == "ok" and Defs.TENSION_USERS.has(k):
		# a Tension user: it links, but works only meshed with a Mainspring
		if st.get("spring") == null:
			label = "NEEDS MAINSPRING"
			col = ghost_colour("clash")
		else:
			label = "MESHES MAINSPRING"
	elif state == "ok" and st.get("spring") != null:
		label = "MESHES MAINSPRING"        # (a Light Works: its Springers may be made here)
	label = Loc.t(label)
	if state == "ok" and not (Defs.TENSION_USERS.has(k) and st.get("spring") == null):
		label += GearEcon.ghost_note(self, t, k, c, big)     # (its efficiency before it is placed; what a Mainspring feeds)
	return [label, col]


## One toothed ring in gear space about the origin: n teeth, pitch radius r. `rot`: its angle (the caller of a node
## turns the node instead and passes 0). Light: a translucent disc, a band, thin spokes, dark-edged brass teeth.
static func draw_gear(ci: CanvasItem, n: int, r: float, tone: Color, edge: Color, team_col: Color, fill := 0.14, rot := 0.0) -> void:
	var step := TAU / float(n)
	var pitch := TAU * r / float(n)
	var h := pitch * 0.55
	var pts := PackedVector2Array()
	for k in n:
		var a := step * float(k) + rot
		pts.append(Vector2.from_angle(a - step * 0.30) * (r - h * 0.5))
		pts.append(Vector2.from_angle(a - step * 0.16) * (r + h * 0.5))
		pts.append(Vector2.from_angle(a + step * 0.16) * (r + h * 0.5))
		pts.append(Vector2.from_angle(a + step * 0.30) * (r - h * 0.5))
	var ri := r - h * 0.5 - pitch * 0.8
	ci.draw_colored_polygon(pts, Color(tone.r, tone.g, tone.b, fill))
	ci.draw_arc(Vector2.ZERO, (ri + r - h * 0.5) * 0.5, 0.0, TAU, 64, Color(team_col.r, team_col.g, team_col.b, 0.30), pitch * 0.8)
	# spokes and a hub: thin, so units and ground still read through them
	var spokes := 6 if r < 120.0 else 10
	var hub := minf(r * 0.16, 26.0)
	for i in spokes:
		var a := TAU * float(i) / float(spokes) + rot
		ci.draw_line(Vector2.from_angle(a) * hub, Vector2.from_angle(a) * ri, Color(tone.r, tone.g, tone.b, 0.34), 2.0)
	ci.draw_arc(Vector2.ZERO, hub, 0.0, TAU, 20, Color(edge.r, edge.g, edge.b, 0.55), 3.0)
	ci.draw_arc(Vector2.ZERO, hub, 0.0, TAU, 20, tone, 1.4)
	ci.draw_arc(Vector2.ZERO, ri, 0.0, TAU, 64, Color(edge.r, edge.g, edge.b, 0.55), 3.0)
	ci.draw_arc(Vector2.ZERO, ri, 0.0, TAU, 64, tone, 1.4)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(edge.r, edge.g, edge.b, 0.75), 3.6, true)
	ci.draw_polyline(loop, tone, 1.8, true)
