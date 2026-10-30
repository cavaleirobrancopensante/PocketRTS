class_name BroodRoot
extends RefCounted
## THE BROOD'S ROOTED CREATURES ARE BUILDINGS (the owner's playtest of 0.15.13, 2026-10-28 19:19;
## docs/idea_brood_mobile_buildings.md, docs/brood_new.md "Rooted = a building"). Rooted, a creature:
##  - takes a building's FOOTPRINT on the grid (Defs.NB "fp": paths go round it, nothing walks through it, units
##    standing there when it roots are pushed out, as for a new building); uprooted, the cells are free again;
##  - is drawn in the BUILDING layer: sorted by the top of its footprint, so units round it draw over it (as round a
##    Town Hall);
##  - has a building's card (no MOVE, ATTACK, STOP, HOLD, PATROL), a RALLY point that right-click sets (it never
##    uproots: only the UPROOT button does), handed to the eggs the Mother lays and to the warriors hatching in the
##    Tyrannosaur's nest;
##  - ROOTS like a building is placed: a ghost on the grid (green, or red with the reason), the creature walks there
##    and roots on that exact spot (order "nb_root");
##  - THE STRUCTURE-UNITS come from GRUBS (DECIDED, the owner): a grub picks the Rootmaw, the Mound Turtle or the
##    Tyrannosaur on its card, walks to the ghost's spot, pays and MORPHS there into a cocoon (the old Brood's grub
##    building look) that opens rooted (order "nb_morph"). The Mother lays only grubs and warriors.

const T := Defs.TILE
const SORT := "NbSort"          # the node the rooted creature's pictures hang under (the building layer)
const COC := "NbCoc"            # the cocoon's picture (a morphing grub)
const MORPH_GRUB := 0.8         # s: the grub's own picture fading into the small case (no larva: the owner, 2026-10-29)
const COC_TEX := "res://assets/buildings/clutch_mound_construction.png"     # (the old stand-in: without the cocoon art)
const COC_ART := "brood_cocoon"  # the owner's cocoon (tools/import_brood_cocoon.py): open_se, 10 frames
const COC_GROW := 0.78          # share of the cocoon time the case grows (frames 0-3)
const COC_CRACK := 0.92         # ... to here it glows, shakes and cracks (frames 4-6); then it splits (7-8)
const COC_LEFT := 2.6           # s the empty shell (frame 9) stays on the ground after, fading over its last FADE_LEFT
const COC_FADE_LEFT := 1.2


# ------------------------------------------------------------------ footprints

## [size in tiles, the middle's offset from the feet in px] for a kind (the Mother: at her stage's scale).
static func fp(k: String, sc := 1.0) -> Array:
	var f: Array = Defs.NB["fp"].get(k, [2, 2, 0, 0])
	return [Vector2i(maxi(1, int(round(float(f[0]) * sc))), maxi(1, int(round(float(f[1]) * sc)))), Vector2(float(f[2]), float(f[3])) * sc]


static func scale_of(u: Unit) -> float:
	return float(BroodNew.stage_def(u)["scale"]) if u.kind == BroodNew.QUEEN else 1.0


## The top-left cell of the footprint of a `k` whose feet are at p.
static func cell_for(k: String, p: Vector2, sc := 1.0) -> Vector2i:
	var f := fp(k, sc)
	var c: Vector2 = p + (f[1] as Vector2) - Vector2(f[0] as Vector2i) * T * 0.5 + Vector2(T, T) * 0.5
	return Vector2i(floori(c.x / T), floori(c.y / T))


## The footprint's top-left cell when its MIDDLE is at p (the ROOT ghost under the pointer, a footprint over a ramp).
static func cell_centred(k: String, p: Vector2, sc := 1.0) -> Vector2i:
	return cell_for(k, p - (fp(k, sc)[1] as Vector2), sc)


## The feet of a `k` rooted with its footprint's top-left cell at c.
static func feet_at(k: String, c: Vector2i, sc := 1.0) -> Vector2:
	var f := fp(k, sc)
	return (Vector2(c) + Vector2(f[0] as Vector2i) * 0.5) * T - (f[1] as Vector2)


## p snapped to the grid: where a `k` roots when told to root at p.
static func snap(k: String, p: Vector2, sc := 1.0) -> Vector2:
	return feet_at(k, cell_for(k, p, sc), sc)


static func rect_for(k: String, p: Vector2, sc := 1.0) -> Rect2:
	return Rect2(Vector2(cell_for(k, p, sc)) * T, Vector2(fp(k, sc)[0] as Vector2i) * T)


static func has_fp(u: Unit) -> bool:
	return u.nb.has("fpx")


## The footprint it holds now (Unit.rect() while rooted: edge distances, reach, selection).
static func rect_of(u: Unit) -> Rect2:
	var sz: Vector2i = fp(u.kind, scale_of(u))[0]
	return Rect2(Vector2(float(u.nb["fpx"]), float(u.nb["fpy"])) * T, Vector2(sz) * T)


## It takes its ground: the footprint's free cells turn solid (as a building's), units standing there are pushed out.
static func footprint_on(g: Game, u: Unit, push := true) -> void:
	if has_fp(u):
		footprint_off(g, u)
	var sc := scale_of(u)
	var c := cell_for(u.kind, u.position, sc)
	var sz: Vector2i = fp(u.kind, sc)[0]
	u.nb["fpx"] = c.x
	u.nb["fpy"] = c.y
	var marked: Array = []
	for y in sz.y:
		for x in sz.x:
			var cc := c + Vector2i(x, y)
			if g.in_map(cc) and g.solid[g.idx(cc)] == 0:
				g._mark(cc, Vector2i.ONE, 2)
				marked.append(g.idx(cc))
				g.nb_cells[g.idx(cc)] = u.team
	u.nb["fpc"] = marked
	if not g.nb_fp.has(u):
		g.nb_fp.append(u)
	g._astar_dirty = true
	if push:
		var r := rect_of(u)
		var keep: Array = g.nb_fp.duplicate()
		for o in g.units_near(r.get_center(), r.size.length() * 0.5 + 30.0):
			if o._k_still:
				keep.append(o)          # (its eggs, a food pile: they lie where they are)
		g._push_units_out(r, keep)


## Its ground is free again (it got up, or died).
static func footprint_off(g: Game, u: Unit) -> void:
	for i in u.nb.get("fpc", []):
		var ii := int(i)
		if ii >= 0 and ii < g.solid.size() and g.solid[ii] == 2:
			g._mark(Vector2i(ii % Game.W, ii / Game.W), Vector2i.ONE, 0)
		g.nb_cells.erase(ii)
	u.nb.erase("fpx")
	u.nb.erase("fpy")
	u.nb.erase("fpc")
	g.nb_fp.erase(u)
	g._astar_dirty = true


## The walkable area round p (a rooted creature's own cells are solid: the area at its rim).
static func home_region(g: Game, p: Vector2) -> int:
	return g.region_of(g.nearest_free(g.cell_of(p), 14))


## A spot just outside a footprint for a creature that came out inside it (a hatchling in the nest): the nearest free
## cell, looked for from the footprint's edge on the side of `toward` (its rally), or the south.
static func out_of(g: Game, r: Rect2, p: Vector2, toward := Vector2.INF) -> Vector2:
	var d := Vector2.DOWN
	if toward != Vector2.INF and toward.distance_to(r.get_center()) > 4.0:
		d = (toward - r.get_center()).normalized()
	var start := r.get_center()
	# from the middle out along d to the rim, then one cell beyond
	var k := 0.0
	while r.has_point(start + d * k) and k < 600.0:
		k += 8.0
	var e := start + d * (k + T * 0.5)
	return g.cell_center(g.nearest_free(g.cell_of(e), 8))


# ------------------------------------------------------------------ walking out through its own side's creatures

## (the owner, 21:32: a Mother boxed in by her rooted creatures) A creature of her side hatched, spawned or pushed inside
## or among its own side's rooted footprints may WALK THROUGH them (only its own side's: enemies never) until it is clear
## of them; then it paths as usual, so nothing is ever stuck. Unit.nb_pass > 0 while it does (Unit's movement asks
## pass_move instead of the terrain); Unit.compute_path sends it first to the nearest open spot (exit_point).
const PASS_TIME := 8.0


## Is a cell solid only because of a rooted creature of team t?
static func own_cell(g: Game, i: int, t: int) -> bool:
	return g.solid[i] == 2 and int(g.nb_cells.get(i, -99)) == t


## Inside or among its own side's footprints (on one of their cells, or shut in a pocket between them)?
static func boxed(g: Game, u: Unit) -> bool:
	if u.is_air() or g.nb_cells.is_empty():
		return false
	var c := g.cell_of(u.position)
	if not g.in_map(c):
		return false
	if own_cell(g, g.idx(c), u.team):
		return true
	return g.sealed_in(u.position) or not g._clear_at(u.position, u.ground_r(), u.team)


static func start_pass(g: Game, u: Unit) -> void:
	if u.is_air() or not boxed(g, u):
		return
	u.nb_pass = PASS_TIME
	if u.order == "idle" or u.order == "":
		var ex := exit_point(g, u.position, u.team)
		if ex != Vector2.INF:
			u.cmd_move(ex)
	elif u.path_goal != Vector2.INF:
		u._request_path(u.path_goal)        # (its order's path again, out through them first)


## The nearest cell of the open map (walkable, not a pocket) reached from p through free cells and its side's
## footprints only (never cliffs, trees, water, buildings or an enemy's creatures). Vector2.INF if none near.
static func exit_point(g: Game, p: Vector2, t: int) -> Vector2:
	var start := g.cell_of(p)
	if not g.in_map(start):
		return Vector2.INF
	var seen := {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size() and head < 2500:
		var c: Vector2i = q[head]
		head += 1
		var i := g.idx(c)
		if c != start and g._walkable(c) and g.in_open_map(c) and not own_cell(g, i, t):
			# (a cell with room round it: not hugging a footprint's edge)
			return g.cell_center(c)
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n) or not g.in_map(n):
				continue
			seen[n] = true
			var ni := g.idx(n)
			if g.cliff[ni] != 0 and not g._walkable(n):
				continue
			if g._walkable(n) or own_cell(g, ni, t):
				q.append(n)
	return Vector2.INF


## Its own side's footprints are open to it (as free ground); everything else as the terrain says.
static func clear_for(g: Game, p: Vector2, radius: float, t: int) -> bool:
	var r := radius * 0.6
	var ry := r * 0.6
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, ry), Vector2(0, -ry)]:
		var c := g.cell_of(p + o)
		if not g.in_map(c):
			return false
		var i := g.idx(c)
		var v := int(g.solid[i])
		if v == 0 or v == 5 or own_cell(g, i, t) or g._gate_lets(i, v, t):
			continue
		return false
	return true


## A step while walking out (Unit's movement): through its own creatures, stopped by anything else; out and clear on
## the open map, it walks as any unit again.
static func pass_move(g: Game, u: Unit, p: Vector2, before: Vector2, delta: float) -> Vector2:
	u.nb_pass = maxf(0.0, u.nb_pass - delta)
	var out := p
	if not clear_for(g, p, u.ground_r(), u.team):
		out = before
		if clear_for(g, Vector2(p.x, before.y), u.ground_r(), u.team):
			out = Vector2(p.x, before.y)
		elif clear_for(g, Vector2(before.x, p.y), u.ground_r(), u.team):
			out = Vector2(before.x, p.y)
	var c := g.cell_of(out)
	if g._clear_at(out, u.ground_r(), u.team) and g.in_open_map(c) and not own_cell(g, g.idx(c), u.team):
		u.nb_pass = 0.0           # (clear of them: a unit like any other)
	return out


# ------------------------------------------------------------------ placement

## The creature a unit is on its way to root, or to turn into (a grub): [kind, feet] or [].
static func plan_of(u: Unit) -> Array:
	if u.order == "nb_root":
		return [u.kind, u.order_point]
	if u.order == "nb_morph" and u.nb.has("mk"):
		return [String(u.nb["mk"]), u.order_point]
	return []


## Why a `k` of team t can't root with its feet at p ("" = it can): the grid (a cliff, trees, a building or another
## rooted creature, a ramp, uneven ground), another creature's plan there, and its own rules (a Rootmaw: on your swamp,
## its ground circle clear of the others'; a father: within his reach of the Mother). `me`: the one rooting
## (its own plan and body don't count). ai: the computer also keeps its ramps clear. sc: the Mother's stage scale.
static func place_problem(g: Game, t: int, k: String, p: Vector2, me: Unit = null, ai := false, sc := 1.0, swamp_rule := true) -> String:
	p = snap(k, p, sc)
	var c := cell_for(k, p, sc)
	var sz: Vector2i = fp(k, sc)[0]
	var ramp_ok := k == BroodNew.TURTLE      # (a turtle closes a ramp)
	var h := -1
	for y in sz.y:
		for x in sz.x:
			var cc := c + Vector2i(x, y)
			if not g.in_map(cc):
				return "Off the map."
			var i := g.idx(cc)
			if g.cliff[i] != 0:
				return "A cliff is in the way."
			var v := int(g.solid[i])
			if v == 1:
				return "Blocked: trees, rocks or water."
			if v != 0:
				if me != null and has_fp(me) and (me.nb.get("fpc", []) as Array).has(i):
					continue
				return "Blocked: a building or a rooted creature is in the way."
			if g.side_ghost_at(t, cc) != null:
				return "Blocked: a building is planned there."
			if g.ramp[i] == 1:
				if not ramp_ok:
					return "Not on a ramp (only a Mound Turtle roots across one)."
				if ai:
					return "Keep the ramp clear."
				continue
			if ai and not ramp_ok and g._near_ramp(cc):
				return "Keep the ramp clear."
			if h < 0:
				h = int(g.height[i])
			elif int(g.height[i]) != h and not ramp_ok:
				return "Uneven ground: it needs level ground."
	var r := Rect2(Vector2(c) * T, Vector2(sz) * T)
	for o in g.units:
		if o == me or o.dead or o.team != t:
			continue
		var pl := plan_of(o)
		if not pl.is_empty() and rect_for(String(pl[0]), pl[1], scale_of(o) if o.kind == String(pl[0]) else 1.0).intersects(r):
			return "Blocked: another creature roots there."
	match k:
		BroodNew.MAW:
			if swamp_rule and not BroodNew.on_swamp(g, t, p):
				return "No swamp here: a Rootmaw roots only on your swamp (root a Mound Turtle to spread it)."
			var rr := float(Defs.PIT_CLAIM) * T * 2.0
			for o in g.units:
				if o == me or o.dead:
					continue
				if o.kind == BroodNew.MAW and o.tesla_mode != "packed" and o.position.distance_to(p) < rr:
					return "Too close to another Rootmaw's ground: their circles may not overlap."
				var pl2 := plan_of(o)
				if o.team == t and not pl2.is_empty() and String(pl2[0]) == BroodNew.MAW and (pl2[1] as Vector2).distance_to(p) < rr:
					return "Too close to another Rootmaw's planned ground."
	if BroodNew.is_father(k):
		var q := BroodNew.queen(g, t)
		if q == null or q.position.distance_to(p) > father_reach():
			return "Out of range: he must nest within %d tiles of the Brood Mother." % int(Defs.NB["father_r"])
	return ""


static func father_reach() -> float:
	return float(Defs.NB["father_r"]) * T


# ------------------------------------------------------------------ rooting on a spot (order "nb_root")

## ROOT like BUILD: walk to p and root there, on that exact spot.
static func start_root(u: Unit, p: Vector2) -> void:
	u._reset_work()
	u.order = "nb_root"
	u.target = null
	u.order_target = null
	u.order_point = snap(u.kind, p, scale_of(u))
	u.nb["rtry"] = 0
	u.path = PackedVector2Array()
	u._request_path(u.order_point)


static func root_tick(g: Game, u: Unit, delta: float) -> Vector2:
	if u.tesla_mode != "packed":
		return Vector2.ZERO
	var p: Vector2 = u.order_point
	var d := u.position.distance_to(p)
	var done := (u.path.is_empty() or u.path_i >= u.path.size()) and not u.path_pending
	if d < 10.0 or (done and d < 48.0):
		var why := place_problem(g, u.team, u.kind, p, u, false, scale_of(u))
		if why != "":
			g.tell(u.team, "The %s can't root there: %s" % [u.d["name"], why])
			u.cmd_stop()
			return Vector2.ZERO
		u.position = p
		g.note_move(u)
		u.cmd_deploy()       # (it checks the spot again: blocked meanwhile, it says why and stays)
		if u.tesla_mode == "packed" and u.order == "nb_root":
			u.cmd_stop()
		return Vector2.ZERO
	if done or u.stuck_t > 2.5:
		u.stuck_t = 0.0
		u.nb["rtry"] = int(u.nb.get("rtry", 0)) + 1
		if int(u.nb["rtry"]) > 6:
			g.tell(u.team, "The %s can't get to that spot." % u.d["name"])
			u.cmd_stop()
			return Vector2.ZERO
		u._request_path(p)
	return u._follow(delta)


# ------------------------------------------------------------------ grubs morph (order "nb_morph")

## What a grub can turn into (the Mother lays none of them).
static func morph_list() -> Array:
	return [BroodNew.MAW, BroodNew.TURTLE] + (Defs.NB["lines"] as Dictionary).keys()


## Why a grub of team t can't turn into a `k` now ("" = it can). `gr`: the grub (its own plan doesn't count; if it has
## paid already, nb "mpaid", the price is not asked again).
static func morph_problem(g: Game, t: int, k: String, gr: Unit = null) -> String:
	if not morph_list().has(k):
		return "A grub can't turn into that."
	var u: Dictionary = Defs.UNITS[k]
	if BroodNew.is_father(k):
		# each father is unlocked by the Mother's growth stage (the owner, 21:45: the Dilophosaurus at stage 2, the
		# Pterodactyl at stage 3); one of each at a time (a grub on its way and a cocoon count)
		var need := BroodNew.father_stage(k)
		var q := BroodNew.queen(g, t)
		if need > 0 and (q == null or BroodNew.stage(q) < need):
			return "Needs the Brood Mother at stage %d." % (need + 1)
		if BroodNew.count_of(g, t, k, gr) > 0:
			return "Only one %s at a time." % u["name"]
	var price := g.unit_price(t, k)
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if gr != null and gr.nb.has("mpaid"):
		price = [0, 0]          # (paid when it was ordered: PAY AT ONCE)
	if int(g.players[t]["gold"]) < int(price[0]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[t]["res2"]) < float(price[1]):
		return "Not enough %s." % String(res[1]).to_lower()
	var more := int(u["supply"]) - int(Defs.UNITS["grub"]["supply"])
	if more > 0 and g.supply_used(t) + more > int(g.players[t]["cap"]):
		return "Need more supply: root more Mound Turtles."
	return ""


## PAY AT ONCE, PAID BACK IF IT FAILS (the owner's playtest, 2026-10-30): the grub pays the creature's price the moment
## it is ordered (as a Crown or Clockwork building placed), held in nb "mpaid" [food, spoils]; killed, re-ordered,
## stopped, or unable to morph there, it is all paid back (morph_refund); in its cocoon it is spent.
static func start_morph(gr: Unit, k: String, p: Vector2) -> void:
	gr._reset_work()          # (an earlier morph order: paid back here)
	gr._leave_mine()
	var g: Game = gr.game
	var why := morph_problem(g, gr.team, k, gr)
	if why != "":
		g.tell(gr.team, "The grub can't turn into a %s: %s" % [Defs.UNITS[k]["name"], why])
		gr.cmd_stop()
		return
	var price := g.unit_price(gr.team, k)
	g.players[gr.team]["gold"] -= int(price[0])
	g.add_res2(gr.team, -float(price[1]))
	g.stats[gr.team]["spent"] += int(price[0])
	gr.nb["mpaid"] = [int(price[0]), float(price[1])]
	gr.order = "nb_morph"
	gr.target = null
	gr.order_target = null
	gr.nb["mk"] = k
	gr.nb["mtry"] = 0
	gr.order_point = snap(k, p)
	gr.path = PackedVector2Array()
	gr._request_path(rect_for(k, gr.order_point).get_center())


static func morph_tick(g: Game, gr: Unit, delta: float) -> Vector2:
	var k := String(gr.nb.get("mk", ""))
	if k == "" or not Defs.UNITS.has(k):
		gr.cmd_stop()
		return Vector2.ZERO
	var p: Vector2 = gr.order_point
	var r := rect_for(k, p)
	var done := (gr.path.is_empty() or gr.path_i >= gr.path.size()) and not gr.path_pending
	if r.grow(gr.radius + 4.0).has_point(gr.position) or (done and r.grow(40.0).has_point(gr.position)):
		var why := place_problem(g, gr.team, k, p, gr)
		if why == "":
			why = morph_problem(g, gr.team, k, gr)
		if why != "":
			g.tell(gr.team, "The grub can't turn into a %s: %s" % [Defs.UNITS[k]["name"], why])
			gr.nb.erase("mk")
			gr.cmd_stop()
			return Vector2.ZERO
		if not gr.nb.has("mpaid"):          # (not paid yet, whatever the way: it pays here)
			var price := g.unit_price(gr.team, k)
			g.players[gr.team]["gold"] -= int(price[0])
			g.add_res2(gr.team, -float(price[1]))
			g.stats[gr.team]["spent"] += int(price[0])
		gr.nb.erase("mpaid")          # (spent: its cocoon)
		cocoon(g, gr.team, k, p)
		if gr.team == g.human:
			Sfx.play_any(["burrow", "work/brood_build"], gr.position, -4.0)
		g.consume_unit(gr)
		return Vector2.ZERO
	if done or gr.stuck_t > 2.5:
		gr.stuck_t = 0.0
		gr.nb["mtry"] = int(gr.nb.get("mtry", 0)) + 1
		if int(gr.nb["mtry"]) > 6:
			g.tell(gr.team, "The grub can't get to that spot.")
			gr.nb.erase("mk")
			gr.cmd_stop()
			return Vector2.ZERO
		gr._request_path(r.get_center())
	return gr._follow(delta)


## A grub's paid morph called off (killed, stopped, given another order, or it can't morph there): all paid back.
static func morph_refund(gr: Unit) -> void:
	if not gr.nb.has("mpaid"):
		return
	var paid: Array = gr.nb["mpaid"]
	gr.nb.erase("mpaid")
	var g: Game = gr.game
	if g == null or gr.team < 0:
		return
	g.players[gr.team]["gold"] += int(paid[0])
	g.add_res2(gr.team, float(paid[1]))
	g.stats[gr.team]["spent"] -= int(paid[0])


## The grub's cocoon: the creature already there (rooted, its footprint taken, its health growing as a building's
## does) but closed in its cocoon until the morph is done (Defs.UNITS[k] "time": the old egg and hatch time).
static func cocoon(g: Game, t: int, k: String, p: Vector2) -> Unit:
	var u := g._add_unit(k, t, snap(k, p))
	u.facing = BroodNew.SE
	u.tesla_mode = "deployed"
	u.nb["m"] = "deployed"
	u.nb["coc"] = 0.0
	u.nb_mass = 1000.0
	u.hp = u.max_hp * 0.15
	footprint_on(g, u)
	if k == BroodNew.MAW:
		BroodNew._claim(g, u)
	BroodNew.set_sky(u)          # (a Pterodactyl comes out of his cocoon landed: a ground structure)
	BroodNew.recount(g, t)
	return u


static func cocoon_time(u: Unit) -> float:
	return BroodNew.egg_time(u.kind)


static func in_cocoon(u: Unit) -> bool:
	return u.nb.has("coc")


## The cocoon grows; then it opens: the creature is rooted (its supply, swamp, ground, nest start now).
static func cocoon_tick(g: Game, u: Unit, delta: float) -> void:
	var tt := cocoon_time(u)
	var was := float(u.nb["coc"])
	u.nb["coc"] = was + delta
	if BroodNew.is_father(u.kind):
		# the lure is ripe: the Sire comes (his roar: the cue, as a building's bell)
		var tg := float(lure_times(u.kind)[0])
		if was < tg and float(u.nb["coc"]) >= tg and u.team == g.human:
			Sfx.play_any(["brood/arrive_" + u.kind, "roar", "combat/brute_attack"], u.position, -6.0)     # (his own call)
	u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.85 * delta / maxf(tt, 0.1))
	if float(u.nb["coc"]) >= tt:
		u.nb.erase("coc")
		BroodNew.recount(g, u.team)
		g.swamp_dirty = true
		if u.team == g.human:
			Sfx.play_any(["brood/cocoon_split", "hatch"], u.position)
			Sfx.voice(u.kind, "select")
			if BroodNew.is_father(u.kind):
				g.tell(u.team, "The %s came to the lure and ate it: he is yours, on his nest." % u.d["name"], true)
			else:
				g.tell(u.team, "A %s has grown from its cocoon, rooted." % u.d["name"], true)
		if g.mlog and not g._first_of.has("%d:%s" % [u.team, u.kind]):
			g._first_of["%d:%s" % [u.team, u.kind]] = true
			g.mlog.add("%s got its first %s" % [g.mlog.who(u.team), u.d["name"]])
		g.stats[u.team]["trained"] += 1


# ------------------------------------------------------------------ rally points

## Rooted creatures and eggs take no orders: a right-click sets their rally point. One UPROOTING ("packing") is a
## unit already (the owner's playtest, 2026-10-30): its card has MOVE, ATTACK..., right-clicks and Shift-queued orders
## are kept and start once it is up (Unit._tesla holds it still meanwhile).
static func fixed(u) -> bool:
	return u is Unit and u._k_nb and (u.kind == BroodNew.EGG or (BroodNew.ROOTERS.has(u.kind) and u.tesla_mode != "packed" and u.tesla_mode != "packing"))


static func rally_of(u: Unit) -> Vector2:
	return Vector2(float(u.nb["rx"]), float(u.nb["ry"])) if u.nb.has("rx") else Vector2.INF


## THE MOTHER'S TWO RALLY POINTS (the owner's playtest, 2026-10-30): the WORKER rally (her grubs: nb "wx"/"wy", drawn
## gold) and the WARRIOR rally (everything else: "rx"/"ry", drawn green). Her right-clicks take turns (the owner,
## 19:33): the first sets the grubs' rally, the next the warriors', and so on (nb "rnext": what the next one sets,
## shown pressed on her card); RALLY and WORKERS set either directly.
static func worker_rally_of(u: Unit) -> Vector2:
	return Vector2(float(u.nb["wx"]), float(u.nb["wy"])) if u.nb.has("wx") else Vector2.INF


## own: the player set it on this egg himself (a nest's father's rally does not replace it).
## which (the Mother only): "auto" = a right-click: the one whose turn it is (rally_next), then the other's turn;
## "worker" (her WORKERS button) the grubs' rally; "army" (RALLY) the warriors'.
static func set_rally(u: Unit, p: Vector2, own := true, which := "army") -> void:
	if u.kind == BroodNew.QUEEN and u.game != null:
		if which == "auto":
			which = rally_next(u)
			u.nb["rnext"] = "army" if which == "worker" else "worker"
		if which == "worker":
			if p == Vector2.INF:
				u.nb.erase("wx")
				u.nb.erase("wy")
			else:
				u.nb["wx"] = p.x
				u.nb["wy"] = p.y
			return
	if p == Vector2.INF:
		u.nb.erase("rx")
		u.nb.erase("ry")
		return
	u.nb["rx"] = p.x
	u.nb["ry"] = p.y
	if u.kind == BroodNew.EGG and own:
		u.nb["ro"] = true


## What the Mother's next right-click sets: "worker" (her grubs' rally; the first) or "army".
static func rally_next(q: Unit) -> String:
	return String(q.nb.get("rnext", "worker"))


## A grubs' food source at p (an own Rootmaw or any food pile), or null.
static func source_at(g: Game, t: int, p: Vector2) -> Unit:
	for o in g.units_near(p, 90.0):
		if BroodNew.is_source(o) and not o.dead and (o.kind == BroodNew.PILE or o.team == t) and (o.rect().grow(24.0).has_point(p) or o.position.distance_to(p) < 30.0):
			return o
	return null


## Where a hatchling goes. The player's own rally on that egg first; then THE MOTHER'S, ALWAYS (the owner, 2026-10-30:
## hers have priority, also for the warriors hatching in a Sire's nest): a grub to her worker rally, the others to her
## warrior rally; then, if she has none, a nest's father's rally; then the rally the egg got when laid.
static func hatch_rally(g: Game, e: Unit) -> Vector2:
	if e.nb.has("ro"):
		return rally_of(e)
	var q := BroodNew.queen(g, e.team)
	if q != null:
		var mine := worker_rally_of(q) if String(e.nb.get("k", "grub")) == "grub" else rally_of(q)
		if mine != Vector2.INF:
			return mine
		if String(e.nb.get("k", "grub")) == "grub":
			return Vector2.INF          # (no worker rally: the grub finds work by itself)
	var rp := rally_of(e)
	if bool(e.nb.get("nest", false)):
		var f := BroodNew.father(g, e.team, BroodNew.father_of(String(e.nb.get("k", ""))))
		if f != null and rally_of(f) != Vector2.INF:
			rp = rally_of(f)
	return rp


## A new creature goes to its rally: a grub to the Rootmaw (or pile) there, the others walk there.
static func send(g: Game, u: Unit, rp: Vector2, i := 0) -> bool:
	if rp == Vector2.INF:
		return false
	if u.kind == "grub":
		var src := source_at(g, u.team, rp)
		if src != null:
			u.cmd_gather(src)
			return true
	u.cmd_move(rp + (Vector2.from_angle(float(i) * 2.1) * 12.0 if i > 0 else Vector2.ZERO))
	return true


# ------------------------------------------------------------------ the building layer

## Rooted (and in its cocoon) its pictures hang under a node at the TOP of its footprint: y-sorted there, the creature
## is drawn behind everything standing round it (as a building is). Uprooted it is a unit again.
static func layer(u: Unit) -> void:
	var want: bool = not u.dead and BroodNew.ROOTERS.has(u.kind) and u.tesla_mode != "packed" and has_fp(u)
	var srt := u.get_node_or_null(SORT) as Node2D
	if want:
		var dy := rect_of(u).position.y + 2.0 - u.position.y
		if srt == null:
			srt = Node2D.new()
			srt.name = SORT
			u.add_child(srt)
			u.move_child(srt, u.sprite.get_index())
			u.y_sort_enabled = true
			# its selection and hover frame, drawn UNDER its pictures (as a building's): only the parts outside the art show
			var fpn := Node2D.new()
			fpn.name = FP_NODE
			fpn.draw.connect(_draw_frame.bind(u, fpn))
			srt.add_child(fpn)
		srt.position = Vector2(0.0, dy)
		for n in [u.sprite, u.get_node_or_null("Glow"), u.get_node_or_null("Xf"), u.get_node_or_null(COC), u.get_node_or_null(COC_GRUB), u.get_node_or_null(PUFF), u.get_node_or_null(FLY)]:
			if n != null and n.get_parent() != srt:
				n.reparent(srt, false)
		u.sprite.position.y -= dy        # (Unit._animate put it at the feet: under the node it is drawn there again)
		var fpn2 := srt.get_node_or_null(FP_NODE) as Node2D
		if fpn2 != null:
			srt.move_child(fpn2, 0)
			var hov: bool = u.game != null and u.game.hover_target == u
			var key := "%s|%s|%s" % [u.selected, hov, str(rect_of(u))]
			if hov or String(fpn2.get_meta("k", "")) != key:
				fpn2.set_meta("k", key)
				fpn2.position = Vector2(0.0, -dy)        # (in the creature's own space again: its feet at the origin)
				fpn2.queue_redraw()
	elif srt != null:
		var at := srt.get_index()
		for n in srt.get_children():
			if n.name == FP_NODE:
				continue
			n.reparent(u, false)
			u.move_child(n, at)
			at += 1
		srt.queue_free()
		u.remove_child(srt)
		u.y_sort_enabled = false
	# THE ROOTED ART ON ITS FOOTPRINT (the owner, 2026-10-29): rooted, its pictures are drawn lower, the bottom of the
	# nest on the footprint's bottom edge (eased in and out over the rooting and uprooting frames; a dead creature keeps it)
	var sh := art_dy(u)
	if not u.dead:
		u.nb["ady"] = sh
	u.sprite.position.y += sh


const FP_NODE := "NbFrame"


## How much lower than its feet a rooted creature's pictures are drawn now: its full drop rooted (and in its cocoon),
## eased over the rooting / uprooting frames (no jump where the walking picture and the rooted one meet), 0 walking.
static func art_dy(u: Unit) -> float:
	if not BroodNew.ROOTERS.has(u.kind):
		return 0.0
	if u.dead:
		return float(u.nb.get("ady", 0.0))
	if not has_fp(u) or u.tesla_mode == "packed":
		return 0.0
	var full := drop(u)
	if u.tesla_mode == "deploying" or u.tesla_mode == "packing":
		var p := clampf(1.0 - u.tesla_t / maxf(u.switch_time(), 0.01), 0.0, 1.0)
		p = p * p * (3.0 - 2.0 * p)          # (eased)
		return full * (p if u.tesla_mode == "deploying" else 1.0 - p)
	return full


## A rooted creature's full drop: from its feet to where the bottom of its rooted art meets its footprint's bottom edge.
static func drop(u: Unit) -> float:
	if not has_fp(u):
		return 0.0
	return rect_of(u).end.y - u.position.y - nest_y(u.kind, scale_of(u))


## The same for a `k` rooted on the grid (snapped feet: the ROOT ghost).
static func drop_for(k: String, sc := 1.0) -> float:
	var f := fp(k, sc)
	return (f[1] as Vector2).y + float((f[0] as Vector2i).y) * T * 0.5 - nest_y(k, sc)


## Where the bottom of a `k`'s rooted picture lies from its feet, as drawn (her stage's scale, the art scale).
static func nest_y(k: String, sc := 1.0) -> float:
	var ak := k
	if k == BroodNew.QUEEN:
		ak = BroodMature.stage_art(BroodMature.stage_of_scale(sc))        # (her own art at each stage)
	return float(Defs.NB["nest_y"].get(ak, Defs.NB["nest_y"].get(k, 0))) * sc * float(Defs.UNITS[k].get("art_scale", 1.0))


## The selection frame round its footprint (a building's green rectangle) and the hover corners, under its pictures.
static func _draw_frame(u: Unit, n: Node2D) -> void:
	if not is_instance_valid(u) or u.dead or not has_fp(u):
		return
	var r := rect_of(u)
	var lr := Rect2(r.position - u.position, r.size)
	if u.selected:
		n.draw_rect(lr.grow(3), Color(0.4, 1.0, 0.4, 0.8), false, 2.0)
	var g := u.game
	if g != null and g.hover_target == u:
		var col := Color(0.4, 1.0, 0.4)
		if u.team >= 0 and g.hostile(g.human, u.team):
			col = Color(1.0, 0.3, 0.25)
		var pulse := 0.75 + 0.25 * sin(g.clock * 8.0)
		var rc := lr.grow(4)
		var L := 12.0
		for c in [[rc.position, Vector2(1, 0), Vector2(0, 1)], [rc.position + Vector2(rc.size.x, 0), Vector2(-1, 0), Vector2(0, 1)],
				[rc.position + Vector2(0, rc.size.y), Vector2(1, 0), Vector2(0, -1)], [rc.end, Vector2(-1, 0), Vector2(0, -1)]]:
			var p0: Vector2 = c[0]
			n.draw_polyline(PackedVector2Array([p0 + c[1] * L, p0, p0 + c[2] * L]), Color(0, 0, 0, 0.6), 5.0)
			n.draw_polyline(PackedVector2Array([p0 + c[1] * L, p0, p0 + c[2] * L]), Color(col, pulse), 2.5)


## SELECTING A ROOTER BY ITS BODY (the owner, 21:28: the Mother was hard to pick): an ellipse over what its current
## frame draws (the frame's painted pixels, as placed on the map: her stage's scale, a mirrored view, the building
## layer), a little generous. Walking or rooted, every growth stage.
static var _used := {}          # [texture rid, hframes, frame] -> the frame's painted rect (in the frame)


static func body_rect(u: Unit) -> Rect2:
	var s := u.sprite
	if s == null or s.texture == null or not s.visible:
		return Rect2()
	var fr := s.get_rect()                        # (the whole frame cell, local)
	var key := [s.texture.get_rid(), s.hframes, s.vframes, s.frame]
	var ur: Rect2
	if _used.has(key):
		ur = _used[key]
	else:
		ur = Rect2(Vector2(fr.size.x * 0.12, fr.size.y * 0.2), fr.size * Vector2(0.76, 0.75))      # (no picture data: most of the cell)
		var img := s.texture.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var fw := img.get_width() / maxi(1, s.hframes)
			var fh := img.get_height() / maxi(1, s.vframes)
			var cell := Rect2i((s.frame % maxi(1, s.hframes)) * fw, (s.frame / maxi(1, s.hframes)) * fh, fw, fh)
			var ui := img.get_region(cell).get_used_rect()
			if ui.size.x > 0:
				ur = Rect2(ui.position, ui.size)
		_used[key] = ur
	var xf := s.get_global_transform()
	var a: Vector2 = xf * (fr.position + ur.position)
	var b: Vector2 = xf * (fr.position + ur.end)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


static func body_hit(u: Unit, p: Vector2) -> bool:
	var r := body_rect(u)
	if r.size.x < 2.0:
		return false
	var c := r.get_center()
	var h := r.size * 0.5 + Vector2(8.0, 8.0)        # (generous: the ellipse a little past the drawn body)
	var d := (p - c) / h
	return d.length_squared() <= 1.0


## Which of two bodies is drawn in front (rooted: sorted at its footprint's top, BroodRoot.layer; walking: its feet).
static func sort_y(u: Unit) -> float:
	if has_fp(u) and u.tesla_mode != "packed":
		return rect_of(u).position.y
	return u.position.y


static func sort_dy(u: Unit) -> float:
	var srt := u.get_node_or_null(SORT) as Node2D
	return srt.position.y if srt != null else 0.0


## Its picture's parent (the Glow, Xf and cocoon sprites go beside the creature's sprite).
static func pic_parent(u: Unit) -> Node:
	return u.sprite.get_parent()


## THE COCOON (the owner's ChatGPT sheet, tools/import_brood_cocoon.py; docs/brood_anims.md): the grub's own picture
## fades into the small scaly case on the earth (MORPH_GRUB s); the case grows to full size (frames 0-3, to COC_GROW of
## the time), glows, shakes and cracks (4-6, to COC_CRACK), splits open as the creature comes out of it (7-8: the creature
## fades in over the shell, the shell drawn behind it); the empty broken shell (9) stays a moment and fades (COC_LEFT s:
## a picture only, its clock on the node). Sized by the footprint's width (the art's earth is 3 tiles wide) times
## Defs.NB "cocoon_scale". Without the art: the old stand-in (the old Brood's construction mound, growing).
static func cocoon_look(u: Unit) -> void:
	if BroodNew.is_father(u.kind):
		lure_look(u)          # (a Sire: his lure, then his arrival)
		return
	var s := u.sprite
	var cs := _pic(u, COC) as Sprite2D
	var gs := _pic(u, COC_GRUB) as Sprite2D
	if not in_cocoon(u):
		if gs != null:
			gs.queue_free()
			gs.get_parent().remove_child(gs)
		if cs != null:
			var left := float(cs.get_meta("left", -1.0))
			if left < 0.0 and ArtData.UNITS.has(COC_ART) and not u.dead:
				left = Time.get_ticks_msec() / 1000.0
				cs.set_meta("left", left)
				cs.frame = cs.hframes - 1
			var el := Time.get_ticks_msec() / 1000.0 - left
			if left < 0.0 or u.dead or el >= COC_LEFT:
				cs.queue_free()
				cs.get_parent().remove_child(cs)
			else:
				cs.self_modulate.a = 1.0 - clampf((el - (COC_LEFT - COC_FADE_LEFT)) / COC_FADE_LEFT, 0.0, 1.0)
			s.self_modulate.a = 1.0
		return
	if not ArtData.UNITS.has(COC_ART):
		_cocoon_old(u)
		return
	if cs == null:
		cs = Sprite2D.new()
		cs.name = COC
		cs.centered = false
		cs.material = _plain_team(s)
		pic_parent(u).add_child(cs)
		var st := _strip_of(COC_ART, "open_se")
		cs.texture = st[0]
		cs.hframes = int(st[1])
		cs.offset = st[2]
	var el := float(u.nb["coc"])
	var tt := cocoon_time(u)
	var p := clampf(el / maxf(tt, 0.1), 0.0, 1.0)
	var r := rect_of(u)
	var at := s.position - Vector2(0.0, art_dy(u))        # (the feet in the picture's space: not the rooted art's drop)
	var base := Vector2(r.get_center().x, r.end.y - 6.0) - u.position + at      # (the footprint's front, in the picture's space)
	var k := r.size.x / float(Defs.TILE * 3) * float((Defs.NB["cocoon_scale"] as Dictionary).get(u.kind, 1.0))
	cs.position = base
	var fi := 0
	var sc := 1.0
	var a := 1.0
	var out := 0.0           # the creature coming out
	var g0 := clampf(el / MORPH_GRUB, 0.0, 1.0)
	if p < COC_GROW:
		fi = clampi(int(p / COC_GROW * 4.0), 0, 3)
		if el < MORPH_GRUB:
			sc = lerpf(0.55, 1.0, g0 * g0 * (3.0 - 2.0 * g0))
			a = g0
	elif p < COC_CRACK:
		var c := (p - COC_GROW) / (COC_CRACK - COC_GROW)
		fi = 4 + clampi(int(c * 3.0), 0, 2)
		cs.position.x += roundf(sin(el * 41.0) * (0.5 + 1.5 * c))       # (it shakes, harder as it cracks)
	else:
		var e := (p - COC_CRACK) / (1.0 - COC_CRACK)
		fi = 7 if e < 0.5 else 8
		out = clampf((e - 0.25) / 0.75, 0.0, 1.0)
	cs.frame = clampi(fi, 0, cs.hframes - 1)
	cs.scale = Vector2.ONE * k * sc
	cs.self_modulate = Color(1, 1, 1, a)
	# split open: the shell behind the creature, which fades in over it
	if (out <= 0.0) == (cs.get_index() < s.get_index()):
		pic_parent(u).move_child(cs, s.get_index())       # (after it while closed; before it once it splits)
	s.self_modulate.a = out
	# the grub fading into the small case (its own south-east picture, on the case's ground)
	if el < MORPH_GRUB:
		if gs == null:
			gs = Sprite2D.new()
			gs.name = COC_GRUB
			gs.centered = false
			gs.material = _plain_team(s)
			pic_parent(u).add_child(gs)
			var gt := _strip_of("grub", "idle_se")
			gs.texture = gt[0]
			gs.hframes = int(gt[1])
			gs.offset = gt[2]
		pic_parent(u).move_child(gs, cs.get_index() + 1)
		gs.position = base + Vector2(0.0, -2.0)
		gs.self_modulate.a = 1.0 - g0
		gs.scale = Vector2(1.0, 1.0 - 0.15 * g0)
	elif gs != null:
		gs.queue_free()
		gs.get_parent().remove_child(gs)


const COC_GRUB := "NbCocGrub"


## A copy of its team shader with its own strip's masks off (veterancy, venom belly: they don't fit other pictures).
static func _plain_team(s: Sprite2D) -> Material:
	var sm := s.material as ShaderMaterial
	if sm == null:
		return s.material
	var lm := sm.duplicate() as ShaderMaterial
	lm.set_shader_parameter("vet_style", 0)
	lm.set_shader_parameter("venom_swap", false)
	lm.set_shader_parameter("vet_mask", null)
	lm.set_shader_parameter("venom_mask", null)
	lm.set_shader_parameter("wash", Color(1, 1, 1, 0))
	return lm


## [texture, frames, offset] of an art key's strip (its anchor on the node's origin).
static func _strip_of(art: String, key: String) -> Array:
	var info: Dictionary = ArtData.UNITS[art]
	var tx := Game.tex("res://assets/units/%s/%s.png" % [art, key])
	var cell: Vector2i = info["cell"]
	var anc: Vector2 = info["anchor"]
	return [tx, int((info["frames"] as Dictionary).get(key, 1)), -anc - Vector2(0, tx.get_height() - cell.y)]


## The old stand-in (no cocoon art): the old Brood's construction mound, growing; the creature fades in at the end.
static func _cocoon_old(u: Unit) -> void:
	var s := u.sprite
	var cs := _pic(u, COC) as Sprite2D
	if cs == null:
		cs = Sprite2D.new()
		cs.name = COC
		cs.centered = false
		cs.material = s.material
		pic_parent(u).add_child(cs)
		pic_parent(u).move_child(cs, s.get_index() + 1)
	var el := float(u.nb["coc"])
	var tt := cocoon_time(u)
	var p := clampf(el / maxf(tt, 0.1), 0.0, 1.0)
	var r := rect_of(u)
	var at := s.position - Vector2(0.0, art_dy(u))
	var base := Vector2(r.get_center().x, r.end.y - 6.0) - u.position + at
	var ct := Game.tex(COC_TEX)
	if cs.texture != ct:
		cs.texture = ct
		cs.hframes = 1
		cs.frame = 0
	var w := r.size.x * 0.95
	var grow := lerpf(0.45, 1.0, clampf(el / maxf(tt * 0.3, 0.1), 0.0, 1.0))
	var pulse := 1.0 + 0.03 * sin(el * TAU / 1.4)
	var k := w / float(ct.get_width()) * grow
	cs.scale = Vector2(k, k * pulse * minf(1.0, r.size.y / r.size.x + 0.55))
	cs.offset = Vector2(-ct.get_width() * 0.5, -ct.get_height())
	cs.position = base
	var out := clampf((p - 0.75) / 0.25, 0.0, 1.0)
	cs.self_modulate.a = 1.0 - out
	s.self_modulate.a = out


# ------------------------------------------------------------------ the Sire lures

## THE SIRE LURES (the owner, 2026-10-29 18:03-18:31; docs/sire_lure.md): a grub must not turn into a grown Sire. It
## roots and swells into a LURE, a living pheromone gland (one kind per Sire: the Tyrant's red and spiked, the Venom's
## yellow-green, the Storm's with a crest-fin and a storm-cloud white haze: no blue, the owner 20:09). Ripe, the Sire ARRIVES as part of its animation (in the
## lore from the wild pack; in the game no walk across the map), EATS it and is yours, nesting where it was.
## The game's side is the cocoon's (the Sire is there from the start, in_cocoon, his footprint taken, his health growing,
## "coc" counting up to his own time): so the one-of-each limit, the Mother's stage, saves, replays and the online
## snapshot carry a lure as they carried a cocoon. Only the pictures differ (lure_look), in three phases of his time:
##   grow    the lure: the concept's 4 steps (from about a grub's size, swelling), then the ripe lure pulsing, its haze
##           puffing (code) - RIPE_AT of the grow;
##   arrive  his 12 arrival frames (Defs.NB "lure_arrive" s): he comes in from the top left, eats the lure, stands;
##   settle  his own rooting frames (Defs.NB "lure_settle" s, from "lure_settle_from"), cross-faded from his last
##           arrival frame (the Tyrant's arrival ends facing south): then he is rooted on his nest.
## Killed as a lure: no refund (as a cocoon, or a building shot down while it goes up); the lure bursts (lure_dead).
const PUFF := "NbPuff"
const RIPE_AT := 0.72         # share of the grow spent swelling (the 4 steps); the rest ripe, pulsing
const FADE := 0.3             # share of the settle cross-faded from his last arrival frame


static func is_lure(u: Unit) -> bool:
	return in_cocoon(u) and BroodNew.is_father(u.kind)


## [grow, arrive, settle] s of a Sire's lure: together his own time (Defs.UNITS[k] "time", the cocoon's).
static func lure_times(k: String) -> Array:
	var tt := BroodNew.egg_time(k)
	var ar := minf(float(Defs.NB["lure_arrive"]), tt * 0.3) + fly_time(k)
	var se := minf(float(Defs.NB["lure_settle"]), tt * 0.15)
	return [maxf(0.0, tt - ar - se), ar, se]


## THE STORM SIRE FLIES IN (the owner, 2026-10-29 20:09): the seconds of flight at the start of his arrival (Defs.NB
## "lure_fly"; 0 for a Sire who walks in), taken out of the ripe lure's pulsing (his total time stays his own).
static func fly_time(k: String) -> float:
	var f: Dictionary = (Defs.NB["lure_fly"] as Dictionary).get(k, {})
	return minf(float(f.get("time", 0.0)), BroodNew.egg_time(k) * 0.1) if not f.is_empty() else 0.0


## Is he still in the air, flying in to his lure (his own flying frames, before the arrival sheet's dive)?
static func flying_in(u: Unit) -> bool:
	if lure_phase(u) != "arrive":
		return false
	return float(u.nb["coc"]) - float(lure_times(u.kind)[0]) < fly_time(u.kind)


## "grow", "arrive", "settle", or "" (not a lure).
static func lure_phase(u: Unit) -> String:
	if not is_lure(u):
		return ""
	var lt := lure_times(u.kind)
	var el := float(u.nb["coc"])
	if el < float(lt[0]):
		return "grow"
	if el < float(lt[0]) + float(lt[1]):
		return "arrive"
	return "settle"


## Has the Sire come yet (his arrival begun)? Before that it is only the lure.
static func sire_come(u: Unit) -> bool:
	var ph := lure_phase(u)
	return ph == "arrive" or ph == "settle"


## 0..1 through the settle (his rooting frames).
static func settle_f(u: Unit) -> float:
	var lt := lure_times(u.kind)
	return clampf((float(u.nb.get("coc", 0.0)) - float(lt[0]) - float(lt[1])) / maxf(float(lt[2]), 0.01), 0.0, 1.0)


## The lure's name on the card and in messages ("Tyrant Lure": the Sire's first word).
static func lure_name(k: String) -> String:
	return String(Defs.UNITS[k]["name"]).split(" ")[0] + " Lure"


static func lure_at(k: String) -> Vector2:
	var a: Array = (Defs.NB["lure_at"] as Dictionary).get(k, [0, 20, 60])
	return Vector2(float(a[0]), float(a[1]))


static func lure_w(k: String) -> float:
	return float(((Defs.NB["lure_at"] as Dictionary).get(k, [0, 20, 60]) as Array)[2])


static func lure_col(k: String) -> Color:
	var a: Array = (Defs.NB["lure_col"] as Dictionary).get(k, [0.75, 0.9, 0.2])
	return Color(float(a[0]), float(a[1]), float(a[2]))


static func _pic(u: Unit, nm: String) -> Node:
	var n := u.get_node_or_null(nm)
	return n if n != null else u.get_node_or_null(SORT + "/" + nm)


## The lure's pictures (and the Sire's arrival), drawn by a sprite beside his own: his own sprite stays hidden until
## his rooting frames take over.
static func lure_look(u: Unit) -> void:
	var s := u.sprite
	var cs := _pic(u, COC) as Sprite2D
	var pf := _pic(u, PUFF) as Node2D
	if not is_lure(u):
		if cs != null:
			cs.queue_free()
			cs.get_parent().remove_child(cs)
			s.self_modulate.a = 1.0
		if pf != null:
			pf.queue_free()
			pf.get_parent().remove_child(pf)
		var fl := _pic(u, FLY)
		if fl != null:
			fl.queue_free()
			fl.get_parent().remove_child(fl)
		return
	if cs == null:
		cs = Sprite2D.new()
		cs.name = COC
		cs.centered = false
		# (its own copy of his team shader: his strip's veterancy and venom-belly masks don't fit the lure's frames)
		var sm := s.material as ShaderMaterial
		if sm != null:
			var lm := sm.duplicate() as ShaderMaterial
			lm.set_shader_parameter("vet_style", 0)
			lm.set_shader_parameter("venom_swap", false)
			lm.set_shader_parameter("vet_mask", null)
			lm.set_shader_parameter("venom_mask", null)
			cs.material = lm
		else:
			cs.material = s.material
		pic_parent(u).add_child(cs)
		pic_parent(u).move_child(cs, s.get_index() + 1)
	if pf == null:
		pf = Node2D.new()
		pf.name = PUFF
		pf.draw.connect(_draw_puffs.bind(u, pf))
		pic_parent(u).add_child(pf)
		pic_parent(u).move_child(pf, cs.get_index() + 1)
	var art := "lure_" + u.kind
	var info: Dictionary = ArtData.UNITS[art]
	var anc: Vector2 = info["anchor"]
	var lt := lure_times(u.kind)
	var el := float(u.nb["coc"])
	var ph := lure_phase(u)
	var ask := float(u.d.get("art_scale", 1.0))
	var la := lure_at(u.kind) * ask
	# THE LURE LIES ON THE FOOTPRINT: its ground in the footprint's middle, just inside its front edge (the picture's
	# space: his feet as drawn are s.position less his rooted art's drop). His arrival art is shifted with it, and eased
	# back onto his own feet while he stands up (the second row), so his rooting frames take over where it ends.
	var at := s.position - Vector2(0.0, art_dy(u))
	var r := rect_of(u)
	var ground := Vector2(r.get_center().x, r.end.y - 6.0) - u.position + at
	var ks := 1.0
	var g := Vector2.ONE           # (the lure's own scale about its ground: swelling, breathing)
	var tex := "ripe_se"
	var fi := 0
	var bright := 1.0
	var puff := 0.0
	var flying := ph == "arrive" and flying_in(u)
	var fly_f := -1.0          # (0..1 through his flight in; -1: not flying)
	var sh_f := -1.0           # (his air shadow in the sheet's dive frames: 0 at frame 3 .. 1 landed)
	if flying:
		fly_f = clampf((el - float(lt[0])) / maxf(fly_time(u.kind), 0.01), 0.0, 1.0)
		ph = "grow"            # (the lure below him still ripe and pulsing)
	match ph:
		"grow":
			var gf := el / maxf(float(lt[0]), 0.01) if not flying else 1.0
			if gf < RIPE_AT:
				tex = "grow_se"
				var sf := gf / RIPE_AT
				fi = clampi(int(sf * 4.0), 0, 3)
				g = Vector2.ONE * lerpf(0.45, 1.0, clampf(sf * 1.25, 0.0, 1.0))      # (from about a grub's size)
				puff = clampf((sf - 0.5) * 2.0, 0.0, 1.0) * 0.6
			else:
				var ck := el - (float(lt[0]) * RIPE_AT if not flying else 0.0)
				var b := sin(ck * TAU / 1.6)
				g = Vector2(1.0 - 0.015 * b, 1.0 + 0.035 * b)        # (ripe: it breathes)
				bright = 1.0 + 0.14 * maxf(0.0, b)
				puff = 1.0
		"arrive":
			tex = "arrive_se"
			# (the Storm Sire: after his flight, the sheet from its frame 3: dive, brake, land, eat, stand)
			var f0 := int((Defs.NB["lure_arrive_from"] as Dictionary).get(u.kind, 0))
			var fl := fly_time(u.kind)
			var af := (el - float(lt[0]) - fl) / maxf(float(lt[1]) - fl, 0.01)
			fi = clampi(f0 + int(af * float(12 - f0)), f0, 11)
			if fl > 0.0 and fi <= 5:
				sh_f = clampf(af * float(12 - f0) / float(6 - f0), 0.0, 1.0)
			if fi >= 6:
				ks = 1.0 - float(fi - 5) / 6.0
			puff = clampf(1.0 - float(fi - f0) / 3.0, 0.0, 1.0)
		"settle":
			tex = "arrive_se"
			fi = 11
			ks = 0.0
	var tx := Game.tex("res://assets/units/%s/%s.png" % [art, tex])
	if cs.texture != tx:
		cs.texture = tx
		cs.hframes = int(info["frames"][tex])
	cs.frame = clampi(fi, 0, cs.hframes - 1)
	cs.offset = -anc - Vector2(0.0, tx.get_height() - (info["cell"] as Vector2i).y)
	cs.scale = g * ask
	cs.position = s.position.lerp(ground - la * g, ks)
	cs.self_modulate = Color(bright, bright, bright, 1.0)
	cs.set_meta("dy", sort_dy(u))
	var sa := 0.0
	if ph == "settle":
		sa = clampf(settle_f(u) / FADE, 0.0, 1.0)
		cs.self_modulate.a = 1.0 - sa
	s.self_modulate.a = sa
	pf.visible = puff > 0.01
	if pf.visible:
		pf.set_meta("g", ground)
		pf.set_meta("p", puff)
		pf.queue_redraw()
	_fly_look(u, cs, ground, fly_f, sh_f)


## THE STORM SIRE FLIES IN (the owner, 2026-10-29 20:09; Defs.NB "lure_fly"): before the arrival sheet's dive he is
## drawn in the air with his own flying frames (walk_se) and his air shadow, gliding down from a few tiles away (up and
## to the left, as the sheet's frame 3 has him) to where the sheet's frame 3 draws him; then the sheet's frames 3-6
## (dive, brake, land) take over, his shadow sliding in under him and fading as he lands. A child of the creature,
## so the fog hides it with him.
const FLY := "NbFly"


static func _fly_look(u: Unit, cs: Sprite2D, ground: Vector2, fly_f: float, sh_f: float) -> void:
	var fn := _pic(u, FLY) as Node2D
	if fly_f < 0.0 and sh_f < 0.0:
		if fn != null:
			fn.visible = false
		return
	var info: Dictionary = (Defs.NB["lure_fly"] as Dictionary)[u.kind]
	if fn == null:
		fn = Node2D.new()
		fn.name = FLY
		fn.draw.connect(_draw_fly_shadow.bind(fn))         # (his shadow, on the ground under the lure's picture)
		var bs := Sprite2D.new()
		bs.name = "Body"
		bs.centered = false
		bs.z_index = 3          # (his body over the lure, the eggs and the creatures by it: he is in the air)
		bs.material = cs.material           # (the lure's copy of his team shader: no strip masks)
		fn.add_child(bs)
		pic_parent(u).add_child(fn)
		pic_parent(u).move_child(fn, cs.get_index())
	fn.visible = true
	var bs := fn.get_node("Body") as Sprite2D
	var ask := float(u.d.get("art_scale", 1.0))
	var sh_end := ground + _v2(info["shadow"]) * ask
	var sh := sh_end
	var a := 1.0
	if fly_f >= 0.0:
		# in the air: a glide easing out (slowing as he comes down), sinking from "alt" to the sheet's frame 3
		var e := 1.0 - pow(1.0 - fly_f, 2.0)
		var anc_end := cs.position + _v2(info["to"]) * ask       # (the sheet's anchor: where frame 3 draws him)
		var alt_end := sh_end.y - anc_end.y
		sh = sh_end + _v2(info["from"]) * ask * (1.0 - e)
		var alt := lerpf(float(info["alt"]) * ask, alt_end, e)
		var k := lerpf(1.0, float(info["k"]), e) * ask
		var bt := Game.tex("res://assets/units/%s/walk_se.png" % u.kind)
		if bs.texture != bt:
			bs.texture = bt
			bs.hframes = int(ArtData.UNITS[u.kind]["frames"].get("walk_se", 1))
		var ai: Dictionary = ArtData.UNITS[u.kind]
		bs.offset = -(ai["anchor"] as Vector2)
		bs.frame = int(u._bob_t * 7.0 * (1.2 - 0.6 * e)) % bs.hframes       # (his wingbeats, slowing into the glide)
		bs.scale = Vector2.ONE * k
		bs.position = Vector2(sh.x + (anc_end.x - sh_end.x), sh.y - alt)
		bs.visible = true
		a = 0.25 + 0.3 * (1.0 - clampf((alt - 20.0) / 160.0, 0.0, 0.6))
	else:
		# the sheet's dive, brake and land: only his shadow here, sliding in under him and fading as he lands
		bs.visible = false
		sh = sh_end.lerp(ground, sh_f)
		a = 0.4 * (1.0 - sh_f)
	fn.set_meta("sh", sh)
	fn.set_meta("a", a)
	fn.set_meta("r", float(BroodNew.look_r(u) + 2.0) * (1.0 - 0.35 * (1.0 - clampf(sh_f if sh_f >= 0.0 else fly_f, 0.0, 1.0))) * ask)
	fn.queue_redraw()


static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _draw_fly_shadow(n: Node2D) -> void:
	var sh: Vector2 = n.get_meta("sh", Vector2.ZERO)
	n.draw_set_transform(sh, 0.0, Vector2(1.0, 0.45))
	n.draw_circle(Vector2.ZERO, float(n.get_meta("r", 20.0)), Color(0, 0, 0, float(n.get_meta("a", 0.3))))
	n.draw_set_transform(Vector2.ZERO)


## The lure's haze in code (as well as the sheet's): soft puffs in its colour rising from its top and fading.
static func _draw_puffs(u: Unit, n: Node2D) -> void:
	if not is_instance_valid(u) or u.dead or not is_lure(u):
		return
	var gp: Vector2 = n.get_meta("g", Vector2.ZERO)
	var st := float(n.get_meta("p", 0.0))
	var w := lure_w(u.kind) * float(u.d.get("art_scale", 1.0))
	var col := lure_col(u.kind)
	var clk: float = u._bob_t + float(u.serial % 13) * 0.41
	for i in 6:
		var ph := fmod(clk * 0.32 + float(i) / 6.0, 1.0)
		var p := gp + Vector2(sin(float(i) * 2.3 + ph * 3.0) * w * 0.22, -w * 0.45 - ph * w * 1.2)
		var rad := w * (0.09 + 0.17 * ph)
		var a := 0.32 * sin(PI * ph) * st
		n.draw_circle(p, rad, Color(col, a * 0.6))
		n.draw_circle(p, rad * 0.6, Color(col.lightened(0.25), a))


## A lure killed (before or as the Sire came): it bursts and shrinks into the ground over LURE_BURST s (his own death
## frames stay hidden: no Sire was there yet).
const LURE_BURST := 0.9


static func lure_dead(u: Unit) -> void:
	var cs := _pic(u, COC) as Sprite2D
	var pf := _pic(u, PUFF) as Node2D
	if pf != null:
		pf.visible = false
	var fl := _pic(u, FLY) as Node2D
	if fl != null:
		fl.visible = false          # (shot down as he flew in: the lure bursts, he is gone)
	if cs == null:
		return
	if lure_phase(u) == "grow":
		u.sprite.visible = false          # (no Sire had come: none to die)
	if not cs.has_meta("d0"):
		cs.set_meta("d0", Time.get_ticks_msec())
		if cs.get_parent() == u:
			cs.position.y += float(cs.get_meta("dy", 0.0))       # (out of the building layer's node: drawn where it was)
		cs.set_meta("s0", cs.scale)
	var f := clampf(float(Time.get_ticks_msec() - int(cs.get_meta("d0"))) / 1000.0 / LURE_BURST, 0.0, 1.0)
	var s0: Vector2 = cs.get_meta("s0")
	cs.scale = Vector2(s0.x * (1.0 + 0.25 * f), s0.y * (1.0 - 0.75 * f))
	cs.self_modulate = Color(1.0 + 0.5 * (1.0 - f), 1.0, 1.0, 1.0 - f)
	if f >= 1.0:
		cs.visible = false


# ------------------------------------------------------------------ the ghost and the father's ring (Game overlay)

## The overlay draws something for the Brood now (a ROOT ghost, the father's ring).
static func overlay_wanted(g: Game) -> bool:
	if g.controls and String(g.controls.mode) == "nb_root":
		return true
	return ring_wanted(g)


## The father's range round the Mother: while a father (or a grub turning into one) is selected or placing his
## root, and while the Mother is selected.
static func ring_wanted(g: Game) -> bool:
	if not BroodNew.on(g, g.human):
		return false
	if g.controls and String(g.controls.mode) == "nb_root" and (Defs.NB["lines"] as Dictionary).has(String(g.controls.place_kind)):
		return true
	for e in g.selection:
		if e is Unit and is_instance_valid(e) and not e.dead and e.team == g.human:
			if e.kind == BroodNew.QUEEN or (Defs.NB["lines"] as Dictionary).has(e.kind):
				return true
			if e.kind == "grub" and e.order == "nb_morph" and (Defs.NB["lines"] as Dictionary).has(String(e.nb.get("mk", ""))):
				return true
	return false


static func draw_overlay(g: Game, ov: Node2D) -> void:
	if ring_wanted(g):
		var q := BroodNew.queen(g, g.human)
		if q != null:
			var rr := father_reach()
			ov.draw_circle(q.position, rr, Color(1.0, 0.55, 0.25, 0.07))
			ov.draw_arc(q.position, rr, 0, TAU, 96, Color(1.0, 0.6, 0.3, 0.85), 2.5)
			var font := ThemeDB.fallback_font
			# (just inside the ring's bottom, far from her body: over its top the label ran across her, the owner 2026-10-29)
			var lt := Loc.t("FATHER RANGE")
			var lp := q.position + Vector2(-font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, rr - 10.0)
			ov.draw_string_outline(font, lp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			ov.draw_string(font, lp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.75, 0.45))
	if g.controls and String(g.controls.mode) == "nb_root" and g.controls.ghost_cell.x >= 0:
		draw_ghost(g, ov, String(g.controls.place_kind), g.controls.ghost_cell, g.controls.nb_sc)


## The ROOT ghost (point 8): the footprint's cells green or red, the creature's rooted picture, and why not.
static func draw_ghost(g: Game, ov: Node2D, k: String, c: Vector2i, sc := 1.0) -> void:
	var p := feet_at(k, c, sc)
	var mover: Unit = g.controls.nb_actor() if g.controls else null
	var why := place_problem(g, g.human, k, p, mover, false, sc)
	var ok := why == ""
	var sz: Vector2i = fp(k, sc)[0]
	for y in sz.y:
		for x in sz.x:
			var cc := c + Vector2i(x, y)
			var free := g.in_map(cc) and g.cliff[g.idx(cc)] == 0 and g.solid[g.idx(cc)] == 0 and (k == BroodNew.TURTLE or g.ramp[g.idx(cc)] == 0)
			ov.draw_rect(Rect2(Vector2(cc) * T, Vector2(T, T)).grow(-1), Color(0.3, 1, 0.3, 0.3) if free and ok else (Color(0.3, 1, 0.3, 0.18) if free else Color(1, 0.3, 0.3, 0.45)))
	var r := Rect2(Vector2(c) * T, Vector2(sz) * T)
	ov.draw_rect(r, Color(0.4, 1.0, 0.4, 0.9) if ok else Color(1.0, 0.35, 0.3, 0.9), false, 2.0)
	if k == BroodNew.MAW:
		var cr := float(Defs.PIT_CLAIM) * T
		ov.draw_arc(p, cr, 0, TAU, 64, Color(0.75, 0.9, 0.3, 0.7), 2.0)
		for o in g.units:
			if o.kind == BroodNew.MAW and not o.dead and o.tesla_mode != "packed" and o.position.distance_to(p) < cr * 3.0:
				ov.draw_arc(o.position, cr, 0, TAU, 48, Color(0.75, 0.9, 0.3, 0.35), 1.5)
	# its rooted picture (frame 0 of its rooted loop)
	var art := BroodMature.stage_art(BroodMature.stage_of_scale(sc)) if k == BroodNew.QUEEN else k
	var frames: Dictionary = ArtData.UNITS[art]["frames"]
	var strip := ""
	for s in ["rooted_se", "fill1_se", "fill_se", "idle_se"]:
		if frames.has(s):
			strip = s
			break
	if BroodNew.is_father(k) and (mover == null or mover.kind == "grub") and ArtData.UNITS.has("lure_" + k):
		# a grub's BUILD: his ripe LURE on the footprint (lure_look's place), not the Sire himself
		var li: Dictionary = ArtData.UNITS["lure_" + k]
		var ltx := Game.tex("res://assets/units/lure_%s/ripe_se.png" % k)
		var lsk := float(Defs.UNITS[k].get("art_scale", 1.0))
		var lg := Vector2(r.get_center().x, r.end.y - 6.0) - lure_at(k) * lsk
		var lcell: Vector2i = li["cell"]
		ov.draw_texture_rect(ltx, Rect2(lg - Vector2(li["anchor"]) * lsk - Vector2(0, ltx.get_height() - lcell.y) * lsk, Vector2(ltx.get_size()) * lsk),
			false, Color(1, 1, 1, 0.6) if ok else Color(1, 0.5, 0.5, 0.5))
		strip = ""
	if strip != "":
		var tx := Game.tex("res://assets/units/%s/%s.png" % [art, strip])
		var n := int(frames[strip])
		var fw := tx.get_width() / n
		var cell: Vector2i = ArtData.UNITS[art]["cell"]
		var anc: Vector2 = ArtData.UNITS[art]["anchor"]
		var sk := sc * float(Defs.UNITS[k].get("art_scale", 1.0))
		var off := (-anc - Vector2(0, tx.get_height() - cell.y)) * sk
		off.y += drop_for(k, sc)        # (rooted, its art sits on the footprint: BroodRoot.drop)
		var region := Rect2(0, 0, fw, tx.get_height())
		var dst := Rect2(p + off, Vector2(fw, tx.get_height()) * sk)
		ov.draw_texture_rect_region(tx, dst, region, Color(1, 1, 1, 0.55) if ok else Color(1, 0.5, 0.5, 0.5))
	var font := ThemeDB.fallback_font
	var lines: Array = []
	if (Defs.NB["lines"] as Dictionary).has(k):
		var q := BroodNew.queen(g, g.human)
		var inr := q != null and q.position.distance_to(p) <= father_reach()
		lines.append(["IN RANGE" if inr else "OUT OF RANGE", Color(0.55, 1.0, 0.5) if inr else Color(1.0, 0.45, 0.4)])
	if not ok and not why.begins_with("Out of range"):
		lines.append([why, Color(1.0, 0.5, 0.45)])
	elif ok:
		lines.append(["ROOT HERE", Color(0.6, 1.0, 0.55)])
	if k == BroodNew.MAW:
		# the food in the ground there (fresh, partly spent, or spent: BroodNew._claim's rule)
		var gl := BroodNew.ground_at(g, p)
		lines.append([Loc.t("%d food in the ground") % int(gl), Color(0.95, 0.85, 0.35) if gl >= 1.0 else Color(1.0, 0.45, 0.4), true])
	var y0 := r.position.y - 8.0 - 18.0 * float(lines.size() - 1)       # (over the ghost: the card covers the screen's bottom)
	for ln in lines:
		var txt := String(ln[0]) if ln.size() > 2 else Loc.t(String(ln[0]))       # (a third field: already in the player's words)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var lp := Vector2(r.get_center().x - w * 0.5, y0)
		ov.draw_string_outline(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.85))
		ov.draw_string(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ln[1])
		y0 += 18.0
