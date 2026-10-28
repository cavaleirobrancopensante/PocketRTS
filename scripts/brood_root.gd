class_name BroodRoot
extends RefCounted
## THE NEW BROOD'S ROOTED CREATURES ARE BUILDINGS (the owner's playtest of 0.15.13, 2026-10-28 19:19;
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
const MORPH_GRUB := 1.6         # s: the grub's own morph strip (the old Brood's), then the cocoon
const COC_TEX := "res://assets/buildings/clutch_mound_construction.png"     # (the old Brood's grub-building look)


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
## its ground circle clear of the others'; the Tyrannosaur: within his reach of the Mother). `me`: the one rooting
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
		BroodNew.FATHER:
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


## Why a grub of team t can't turn into a `k` now ("" = it can). `gr`: the grub (its own plan doesn't count).
static func morph_problem(g: Game, t: int, k: String, gr: Unit = null) -> String:
	if not morph_list().has(k):
		return "A grub can't turn into that."
	var u: Dictionary = Defs.UNITS[k]
	if (Defs.NB["lines"] as Dictionary).has(k) and BroodNew.count_of(g, t, k, gr) > 0:
		return "Only one %s at a time." % u["name"]
	var price := g.unit_price(t, k)
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[t]["gold"]) < int(price[0]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[t]["res2"]) < float(price[1]):
		return "Not enough %s." % String(res[1]).to_lower()
	var more := int(u["supply"]) - int(Defs.UNITS["grub"]["supply"])
	if more > 0 and g.supply_used(t) + more > int(g.players[t]["cap"]):
		return "Need more supply: root more Mound Turtles."
	return ""


static func start_morph(gr: Unit, k: String, p: Vector2) -> void:
	gr._reset_work()
	gr._leave_mine()
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
		var price := g.unit_price(gr.team, k)
		g.players[gr.team]["gold"] -= int(price[0])
		g.add_res2(gr.team, -float(price[1]))
		g.stats[gr.team]["spent"] += int(price[0])
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
	u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.85 * delta / maxf(tt, 0.1))
	if float(u.nb["coc"]) >= tt:
		u.nb.erase("coc")
		BroodNew.recount(g, u.team)
		g.swamp_dirty = true
		if u.team == g.human:
			Sfx.play("hatch", u.position)
			Sfx.voice(u.kind, "select")
			g.tell(u.team, "A %s has grown from its cocoon, rooted." % u.d["name"], true)
		if g.mlog and not g._first_of.has("%d:%s" % [u.team, u.kind]):
			g._first_of["%d:%s" % [u.team, u.kind]] = true
			g.mlog.add("%s got its first %s" % [g.mlog.who(u.team), u.d["name"]])
		g.stats[u.team]["trained"] += 1


# ------------------------------------------------------------------ rally points

## Rooted creatures and eggs take no orders: a right-click sets their rally point.
static func fixed(u) -> bool:
	return u is Unit and u._k_nb and (u.kind == BroodNew.EGG or (BroodNew.ROOTERS.has(u.kind) and u.tesla_mode != "packed"))


static func rally_of(u: Unit) -> Vector2:
	return Vector2(float(u.nb["rx"]), float(u.nb["ry"])) if u.nb.has("rx") else Vector2.INF


## own: the player set it on this egg himself (a nest's father's rally does not replace it).
static func set_rally(u: Unit, p: Vector2, own := true) -> void:
	if p == Vector2.INF:
		u.nb.erase("rx")
		u.nb.erase("ry")
		return
	u.nb["rx"] = p.x
	u.nb["ry"] = p.y
	if u.kind == BroodNew.EGG and own:
		u.nb["ro"] = true


## Where a hatchling goes: the egg's own rally; in the father's nest, his rally (unless the player gave the egg its own).
static func hatch_rally(g: Game, e: Unit) -> Vector2:
	var rp := rally_of(e)
	if bool(e.nb.get("nest", false)) and not e.nb.has("ro"):
		var f := BroodNew.father(g, e.team)
		if f != null and rally_of(f) != Vector2.INF:
			rp = rally_of(f)
	return rp


## A new creature goes to its rally: a grub to the Rootmaw (or pile) there, the others walk there.
static func send(g: Game, u: Unit, rp: Vector2, i := 0) -> bool:
	if rp == Vector2.INF:
		return false
	if u.kind == "grub":
		for o in g.units_near(rp, 90.0):
			if BroodNew.is_source(o) and not o.dead and (o.kind == BroodNew.PILE or o.team == u.team) and (o.rect().grow(24.0).has_point(rp) or o.position.distance_to(rp) < 30.0):
				u.cmd_gather(o)
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
		srt.position = Vector2(0.0, dy)
		for n in [u.sprite, u.get_node_or_null("Glow"), u.get_node_or_null("Xf"), u.get_node_or_null(COC)]:
			if n != null and n.get_parent() != srt:
				n.reparent(srt, false)
		u.sprite.position.y -= dy        # (Unit._animate put it at the feet: under the node it is drawn there again)
	elif srt != null:
		var at := srt.get_index()
		for n in srt.get_children():
			n.reparent(u, false)
			u.move_child(n, at)
			at += 1
		srt.queue_free()
		u.remove_child(srt)
		u.y_sort_enabled = false


static func sort_dy(u: Unit) -> float:
	var srt := u.get_node_or_null(SORT) as Node2D
	return srt.position.y if srt != null else 0.0


## Its picture's parent (the Glow, Xf and cocoon sprites go beside the creature's sprite).
static func pic_parent(u: Unit) -> Node:
	return u.sprite.get_parent()


## The cocoon: the grub's morph strip for MORPH_GRUB s, then the old Brood's grub-building mound, growing; the creature
## fades in over it at the end (code: docs/art_style_inconsistency.md).
static func cocoon_look(u: Unit) -> void:
	var s := u.sprite
	var cs := u.get_node_or_null(COC) as Sprite2D
	if cs == null:
		cs = u.get_node_or_null(SORT + "/" + COC) as Sprite2D
	if not in_cocoon(u):
		if cs != null:
			cs.queue_free()
			cs.get_parent().remove_child(cs)
			s.self_modulate.a = 1.0
		return
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
	var base := Vector2(r.get_center().x, r.end.y - 6.0) - u.position + s.position      # (the footprint's front, in the picture's space)
	if el < MORPH_GRUB:
		# the grub curls into its cocoon (the old Brood's morph strip)
		var gt := Game.tex("res://assets/units/grub/morph_e.png")
		cs.texture = gt
		cs.hframes = int(ArtData.UNITS["grub"]["frames"].get("morph_e", 7))
		cs.frame = clampi(int(el / MORPH_GRUB * cs.hframes), 0, cs.hframes - 1)
		var anc: Vector2 = ArtData.UNITS["grub"]["anchor"]
		cs.offset = -anc
		cs.scale = Vector2.ONE * 1.4
		cs.position = r.get_center() - u.position + s.position + Vector2(0, 10)
		cs.self_modulate.a = 1.0
		s.self_modulate.a = 0.0
		return
	var ct := Game.tex(COC_TEX)
	if cs.texture != ct:
		cs.texture = ct
		cs.hframes = 1
		cs.frame = 0
	var w := r.size.x * 0.95
	var grow := lerpf(0.45, 1.0, clampf((el - MORPH_GRUB) / maxf(tt * 0.3, 0.1), 0.0, 1.0))
	var pulse := 1.0 + 0.03 * sin(el * TAU / 1.4)
	var k := w / float(ct.get_width()) * grow
	cs.scale = Vector2(k, k * pulse * minf(1.0, r.size.y / r.size.x + 0.55))
	cs.offset = Vector2(-ct.get_width() * 0.5, -ct.get_height())
	cs.position = base
	# the last quarter: the creature comes out of it
	var out := clampf((p - 0.75) / 0.25, 0.0, 1.0)
	cs.self_modulate.a = 1.0 - out
	s.self_modulate.a = out


# ------------------------------------------------------------------ the ghost and the father's ring (Game overlay)

## The overlay draws something for the new Brood now (a ROOT ghost, the father's ring).
static func overlay_wanted(g: Game) -> bool:
	if g.controls and String(g.controls.mode) == "nb_root":
		return true
	return ring_wanted(g)


## The father's range round the Mother: while a Tyrannosaur (or a grub turning into one) is selected or placing his
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
			var lp := q.position + Vector2(-58.0, -rr - 8.0)
			ov.draw_string_outline(font, lp, "FATHER RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			ov.draw_string(font, lp, "FATHER RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.75, 0.45))
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
	var art := k
	var frames: Dictionary = ArtData.UNITS[art]["frames"]
	var strip := ""
	for s in ["rooted_se", "fill1_se", "fill_se", "idle_se"]:
		if frames.has(s):
			strip = s
			break
	if strip != "":
		var tx := Game.tex("res://assets/units/%s/%s.png" % [art, strip])
		var n := int(frames[strip])
		var fw := tx.get_width() / n
		var cell: Vector2i = ArtData.UNITS[art]["cell"]
		var anc: Vector2 = ArtData.UNITS[art]["anchor"]
		var sk := sc * float(Defs.UNITS[k].get("art_scale", 1.0))
		var off := (-anc - Vector2(0, tx.get_height() - cell.y)) * sk
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
	var y0 := r.position.y - 8.0 - 18.0 * float(lines.size() - 1)       # (over the ghost: the card covers the screen's bottom)
	for ln in lines:
		var txt := String(ln[0])
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var lp := Vector2(r.get_center().x - w * 0.5, y0)
		ov.draw_string_outline(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.85))
		ov.draw_string(font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ln[1])
		y0 += 18.0
