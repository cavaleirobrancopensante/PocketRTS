class_name BroodNew
extends RefCounted
## THE BROOD (docs/brood_new.md; the only Brood since 0.18.0, docs/brood_replace.md: the old Brood of buildings is gone).
## The owner's redesign (docs/idea_brood_mobile_buildings.md, 2026-10-28): no buildings, only creatures. Some of them ROOT
## into the ground (armour and less damage while rooted; uprooted they walk as units).
##  - THE BROOD MOTHER (kind "brood_mother"): the losing condition (kill her and that side is out). She roots and uproots,
##    HOARDS the food (grubs bring it to her), and ONLY she lays eggs, rooted or walking (each egg drops behind her).
##  - THE ROOTMAW ("rootmaw"): roots on fresh ground (a circle of Defs.PIT_CLAIM tiles holding Defs.PIT_GROUND food; rooted
##    circles may not overlap), drinks it into its body (it swells: 6 levels) and grubs carry the food from its flank to
##    the Mother (the farther, the more a trip pays: Game.food_at). UPROOT spills its food as a
##    pile on the ground (grubs still collect it, it rots slowly); HAUL uproots it full and it walks at half speed with
##    it (killed while hauling, all of it bursts out as a pile; rooted again, it keeps it).
##  - THE FATHERS (Defs.NB "lines", the owner 2026-10-29 11:10): the TYRANNOSAUR (Raptors, Brutes; from the start),
##    the DILOPHOSAURUS (Spitters, Mist Toads; her stage 2) and the PTERODACTYL (Skywings; her stage 3, a flyer that
##    lands to root). ROOTED each is one of the Brood's "barracks" (the owner, 15:45): he settles on a nest. Rooted
##    within Defs.NB "father_r" of the Mother, the eggs of HIS LINE roll into his nest (counted over him like a
##    Barracks' queue); he fertilises them all at once and they hatch there. Uprooted he walks (or flies) and fights.
##    One of each at a time. Unfertilised eggs hatch as grubs; eggs already fertilised still hatch. No father is a
##    special case: everything below goes by the lines.
##  - EGGS ("brood_egg") and FOOD PILES ("food_pile", nobody's) are units that stand still.
## Everything here runs for every Brood side (on(g, t): factions[t] is "brood").

const QUEEN := "brood_mother"
const MAW := "rootmaw"
const TURTLE := "mound_turtle"
const FATHER := "tyrannosaur"         # (the first father: the tools' and tests' shorthand; the game goes by FATHERS)
const DILO := "dilophosaurus"
const PTERO := "pterodactyl"
const FATHERS := [FATHER, DILO, PTERO]     # (Defs.NB "lines" order)
const EGG := "brood_egg"
const PILE := "food_pile"
const KINDS := [QUEEN, MAW, TURTLE, FATHER, DILO, PTERO, EGG, PILE]
const ROOTERS := [QUEEN, MAW, TURTLE, FATHER, DILO, PTERO]     # (the creatures that ROOT and UPROOT)
const SE := Vector2(0.7071, 0.7071)


static func on(g: Game, t: int) -> bool:
	return t >= 0 and t < g.factions.size() and String(g.factions[t]) == "brood"


static func is_nb(k: String) -> bool:
	return KINDS.has(k)


## What the Mother's card offers, in order (the warriors need the father beside her). She lays only UNITS: grubs and
## warriors. The structure-units (the Rootmaw, the Mound Turtle, the fathers) come from grubs (the owner, 19:19:
## BroodRoot.morph_list).
static func hatch_list() -> Array:
	var out: Array = ["grub"]
	for f in Defs.NB["lines"]:
		out.append_array(Defs.NB["lines"][f] as Array)
	return out


## Is k a father (any of them)?
static func is_father(k: String) -> bool:
	return (Defs.NB["lines"] as Dictionary).has(k)


## The Mother's growth stage (0 = stage 1) a father needs before a grub can turn into him.
static func father_stage(k: String) -> int:
	return int((Defs.NB["father_stage"] as Dictionary).get(k, 0))


## What her stage st (0 = stage 1) unlocks (her GROW tooltip): the Sires a grub turns into, the warriors she lays.
static func unlocks_text(st: int) -> String:
	var out: Array = []
	for f in FATHERS:
		if father_stage(f) == st:
			out.append(Loc.t(String(Defs.UNITS[f]["name"])) + " " + Loc.t("(a grub's BUILD)"))
	for k in Defs.NB["unit_stage"]:
		if int(Defs.NB["unit_stage"][k]) == st:
			if BroodMature.is_mature(k):
				out.append(Loc.t(Defs.train_name(k)) + " " + Loc.t("(MATURE a %s)") % Loc.t(String(Defs.UNITS[BroodMature.young_of(k)]["name"])))
			else:
				out.append(Loc.t(Defs.train_name(k)))
	return ", ".join(out)


## The Mother's growth stage (0 = stage 1) a warrior's egg needs (the owner's tiers, 12:20), as well as its Sire.
static func unit_stage(k: String) -> int:
	return int((Defs.NB["unit_stage"] as Dictionary).get(k, 0))


## The father a warrior needs ("" for none: grubs, Rootmaws, the fathers themselves).
static func father_of(k: String) -> String:
	for f in Defs.NB["lines"]:
		if (Defs.NB["lines"][f] as Array).has(k):
			return f
	return ""


## The young an egg of `k` holds for side t: Defs "spawn" (2 for Raptors and Spitters), 3 with its BIGGER CLUTCH.
static func young(g: Game, t: int, k: String) -> int:
	if BroodResearch.clutch_key(k) != "":
		return BroodResearch.clutch(g, t, k)
	return int(Defs.UNITS[k].get("spawn", 1))


# ------------------------------------------------------------------ lookups

static func queen(g: Game, t: int) -> Unit:
	var q = g.nb_queen.get(t)
	if q != null and is_instance_valid(q) and not q.dead:
		return q
	g.nb_queen[t] = null
	for u in g.units:
		if u.team == t and u.kind == QUEEN and not u.dead:
			g.nb_queen[t] = u
			return u
	return null


## Rooted and working (a cocoon is rooted but not open yet: BroodRoot).
static func rooted(u: Unit) -> bool:
	return u.tesla_mode == "deployed" and not u.nb.has("coc")


## A side's father of kind k (one of each at a time).
static func father(g: Game, t: int, k: String = FATHER) -> Unit:
	for u in g.units:
		if u.team == t and u.kind == k and not u.dead:
			return u
	return null


## The father of kind k rooted on his nest within his reach of the Mother (only then are the eggs of his line
## fertilised).
static func father_near(g: Game, t: int, k: String = FATHER) -> bool:
	var f := father(g, t, k)
	var q := queen(g, t)
	return f != null and q != null and rooted(f) and f.position.distance_to(q.position) <= float(Defs.NB["father_r"]) * Defs.TILE


## How many `k` a side has: alive, in an egg, in a cocoon, or a grub on its way to turn into one (not `skip`).
static func count_of(g: Game, t: int, k: String, skip: Unit = null) -> int:
	var n := 0
	for u in g.units:
		if u == skip or u.team != t or u.dead:
			continue
		if u.kind == k or (u.kind == EGG and String(u.nb.get("k", "")) == k) \
				or (u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == k):
			n += 1
	return n


# ------------------------------------------------------------------ the start

## A Brood side's start: the Mother where the hall would stand (START_SIZE: a hall's footprint from the start cell), one Rootmaw on fresh ground behind her, the grubs.
## Both play the end of their rooting (a cue that they are dug in).
const START_SIZE := Vector2i(5, 4)


static func start(g: Game, t: int, cell: Vector2i) -> void:
	var c := BroodRoot.snap(QUEEN, (Vector2(cell) + Vector2(START_SIZE) * 0.5) * Defs.TILE)
	var q := g._add_unit(QUEEN, t, c)
	q.facing = SE
	q.nb["eggs"] = int(Defs.NB["start_eggs"])
	var spot := BroodRoot.snap(MAW, _maw_start_spot(g, c))      # (before her footprint is taken: her cell's region is looked at)
	_start_rooting(g, q)
	q.nb["swr"] = swamp_full(q)        # (her swamp is there in full once she has rooted at the start: her Rootmaw is on it)
	var m := g._add_unit(MAW, t, spot)
	m.facing = SE
	m.nb["food"] = float(Defs.NB["start_food"])       # (the first loads are ready: the grubs start at once)
	_claim(g, m)
	_start_rooting(g, m)
	# the grubs just outside her nest's ground, on the side away from the map's edge
	var qr := BroodRoot.rect_of(q)
	var gy := qr.end.y + 22.0 if c.y < Game.H * Defs.TILE * 0.5 else qr.position.y - 22.0
	for i in int(Defs.FACTIONS["brood"]["start_workers"]):
		var gp := Vector2(c.x - 60.0 + i * 30.0, gy)
		if not g._clear_at(gp, 8.0, t):
			gp = g.cell_center(g.nearest_free(g.cell_of(gp), 6))
		var gr := g._add_unit("grub", t, gp)
		gr.cmd_gather(m)
	g.players[t]["gold"] = Defs.START_GOLD
	recount(g, t)
	g.swamp_dirty = true


static func _start_rooting(g: Game, u: Unit) -> void:
	u.tesla_mode = "deploying"
	u.tesla_t = float(Defs.NB["start_root"])
	u.nb["m"] = "deploying"
	BroodRoot.footprint_on(g, u)


## Fresh ground beside the Mother (clear of her great body: about 8 to 10 tiles out), walkable round it, on her level,
## a little away from the map's middle (behind her, as the old starting pits were) but not off the edge of her ground.
static func _maw_start_spot(g: Game, c: Vector2) -> Vector2:
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var away := (c - mid).normalized() if c.distance_to(mid) > 1.0 else Vector2.DOWN
	var h := int(g.height[g.idx(g.cell_of(c))])
	var home := g.region_of(g.cell_of(c))
	var best := c + away * 10.0 * Defs.TILE      # (none found: out past her nest)
	var bs := -INF
	for r in [8.5, 9.5, 7.5, 10.5, 6.5]:
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			var p: Vector2 = c + dir * r * Defs.TILE
			var cc := g.cell_of(p)
			if not g._walkable(cc) or int(g.height[g.idx(cc)]) != h or g.ramp[g.idx(cc)] != 0 or g.region_of(cc) != home:
				continue
			# room round it: the cells within 2 tiles walkable and on its level
			var room := 0
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var c2 := cc + Vector2i(dx, dy)
					if g.in_map(c2) and g._walkable(c2) and int(g.height[g.idx(c2)]) == h:
						room += 1
			if room < 22 or BroodRoot.place_problem(g, -1, MAW, p, null, false, 1.0, false) != "" \
					or BroodRoot.rect_for(QUEEN, c).grow(Defs.TILE).intersects(BroodRoot.rect_for(MAW, p)):
				continue          # (its whole footprint must fit)
			var s: float = dir.dot(away) * 0.5 + room * 0.05 - absf(r - 8.5) * 0.3
			if s > bs:
				bs = s
				best = p
		if bs > -INF:
			break
	return best


# ------------------------------------------------------------------ supply, swamp, the end

## Supply: the Mother gives some, every ROOTED Rootmaw more (uprooted it gives none).
static func supply_cap(g: Game, t: int) -> int:
	if not on(g, t):
		return 0
	var cap := 0
	for u in g.units:
		if u.team != t or u.dead:
			continue
		if u.kind == QUEEN:
			cap += int(Defs.NB["queen_supply"])
		elif u.kind == TURTLE and rooted(u):
			cap += int(Defs.NB["turtle_supply"])
	return cap


static func recount(g: Game, t: int) -> void:
	g._recount_supply(t)


## The swamp the rooted Mother and Mound Turtles spread (a Rootmaw spreads none: it needs swamp to feed): [centre in tiles, radius in tiles].
static func swamp_sources(g: Game, t: int) -> Array:
	var out: Array = []
	if not on(g, t):
		return out
	for u in g.units:
		if u.team != t or u.dead or not rooted(u):
			continue
		if u.kind == QUEEN or u.kind == TURTLE:
			out.append([u.position / Defs.TILE, minf(swamp_full(u), float(u.nb.get("swr", 0.0)))])
	return out


## THE SWAMP SPREADS AT A WALK (the owner's playtest, 2026-10-31: "it should spread at a speed, 1 tile a second"): a
## swamp source's full radius in tiles (the Mother's stage, a Mound Turtle's), and nb "swr" the radius it has reached.
static func swamp_full(u: Unit) -> float:
	return float(stage_def(u)["swamp"]) if u.kind == QUEEN else float(Defs.NB["turtle_swamp"])


## Swamp is spreading toward p: within the full radius of a rooted Mother or Mound Turtle of side t, not reached yet
## (the computer picks a Rootmaw's spot there; a grub sent to morph there waits for it: BroodRoot.morph_tick).
static func swamp_coming(g: Game, t: int, p: Vector2) -> bool:
	for u in g.units:
		if u.team != t or u.dead or not (u.kind == QUEEN or u.kind == TURTLE) or not rooted(u):
			continue
		var d: Vector2 = (p - u.position) / Defs.TILE
		var full := swamp_full(u) - 0.6
		if d.x * d.x + d.y * 1.15 * d.y * 1.15 <= full * full and float(u.nb.get("swr", 0.0)) < swamp_full(u):
			return true
	return false


## Every swamp step (Game.SWAMP_STEP, 1 s; on the host): each rooted Mother and Mound Turtle's swamp grows `step` tiles
## out toward its full radius. One newly rooted starts from the swamp already round it (rooted again where its own or
## another's swamp still lies, it does not start from nothing); one up (uprooting, dead) has none (its swamp recedes:
## Game._update_swamp). True if any changed.
static func swamp_grow(g: Game, step: float) -> bool:
	var changed := false
	for u in g.units:
		if not (u.kind == QUEEN or u.kind == TURTLE) or not on(g, u.team):
			continue
		if u.dead or u.tesla_mode == "packing" or u.tesla_mode == "packed":
			if u.nb.has("swr"):
				u.nb.erase("swr")
				changed = true
			continue
		if not rooted(u):
			continue           # (still rooting, or in its cocoon: its swamp starts once it is rooted)
		var full := swamp_full(u)
		if not u.nb.has("swr"):
			u.nb["swr"] = g.swamp_cover(u.team, u.position / Defs.TILE, full)
			changed = true
		elif float(u.nb["swr"]) < full:
			u.nb["swr"] = minf(full, float(u.nb["swr"]) + step)
			changed = true
		elif float(u.nb["swr"]) > full:
			u.nb["swr"] = full
			changed = true
	return changed


## A Rootmaw roots and feeds on ANY swamp of its side (the owner, 13:40): the Mother's, a turtle's far away (a hidden
## base); it need not be joined to hers. Off the swamp (its turtle killed, the swamp shrunk back) it stops feeding.
static func on_swamp(g: Game, t: int, p: Vector2) -> bool:
	return t >= 0 and t < g.swamp.size() and g.on_swamp(t, p)


## Where the Brood's grubs unload (food and cocoons) and creatures are offered up: the Mother.
static func dropoff(g: Game, t: int) -> Unit:
	return queen(g, t)


# ------------------------------------------------------------------ eggs

## THE MOTHER'S LAYING (the owner, 17:55: she is the only producer, so three levers raise it, and they STACK; the
## numbers: docs/brood_new_stages.md): her growth STAGE sets the base (x1, x1.3, x1.7 of one egg every 6 s), then each
## FATHER within his reach of her adds father_rate (his pheromones), and each Mound Turtle rooted on NEW GROUND adds
## expansion_rate (its chimneys pump the scent of new territory into the swamp water). x her stage's rate x (1 + the
## levers).
static func stage(q: Unit) -> int:
	return clampi(int(q.nb.get("stage", 0)), 0, (Defs.NB["stages"] as Array).size() - 1)


static func stage_def(q: Unit) -> Dictionary:
	return Defs.NB["stages"][stage(q)]


static func eggs_max(q: Unit) -> int:
	return int(stage_def(q)["eggs"])


## The fathers near her (any father kind, rooted or not: away from her or dead, they give nothing).
static func fathers_near(g: Game, q: Unit) -> int:
	return fathers_near_list(g, q).size()


static func fathers_near_list(g: Game, q: Unit) -> Array:
	var out: Array = []
	var r := float(Defs.NB["father_r"]) * Defs.TILE
	for u in g.units:
		if u.team == q.team and not u.dead and is_father(u.kind) and not u.nb.has("coc") and u.position.distance_to(q.position) <= r:
			out.append(u)
	return out


## The Mound Turtles that count as EXPANSIONS: rooted at least expansion_tiles from her and from every other one that
## already counts (the oldest first), up to expansion_max. Turtles at home give supply and swamp, no eggs.
static func expansions(g: Game, q: Unit) -> Array:
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	var cands: Array = []
	for u in g.units:
		if u.team == q.team and u.kind == TURTLE and not u.dead and rooted(u) and u.position.distance_to(q.position) >= far:
			cands.append(u)
	cands.sort_custom(func(a, b) -> bool: return a.serial < b.serial)
	var out: Array = []
	for u in cands:
		if out.size() >= int(Defs.NB["expansion_max"]):
			break
		if out.all(func(o) -> bool: return o.position.distance_to(u.position) >= far):
			out.append(u)
	return out


## Her laying rate (x one egg every egg_time s), with what makes it: [rate, stage x, fathers, expansions].
static func lay_rate(g: Game, q: Unit) -> Array:
	var sx := float(stage_def(q)["rate"])
	var nf := fathers_near(g, q)
	var ne := expansions(g, q).size()
	var hv := hvet(q)
	return [sx * (1.0 + float(Defs.NB["father_rate"]) * nf + float(Defs.NB["expansion_rate"]) * ne + float(Defs.NB["hvet_rate"]) * hv), sx, nf, ne, hv]


## HER VETERANCY FROM HARVEST (the owner, 2026-10-30 08:39): 1 for each harvest a grub delivers to her, up to
## Defs.NB "hvet_max"; each is +1% laying (lay_rate). Kept on her (nb "hvet": saved, sent online).
static func hvet(q: Unit) -> int:
	return int(q.nb.get("hvet", 0)) if q else 0


static func add_hvet(q: Unit) -> void:
	if q == null or q.dead or q.kind != QUEEN:
		return
	q.nb["hvet"] = mini(hvet(q) + 1, int(Defs.NB["hvet_max"]))


static func egg_rate(g: Game, t: int) -> float:
	var q := queen(g, t)
	return float(lay_rate(g, q)[0]) if q else 1.0


## "Laying +X%: stage 2, Tyrannosaur near, 2 expansions" (her card).
static func levers_text(g: Game, q: Unit) -> String:
	var lr := lay_rate(g, q)
	var parts: Array = []
	if stage(q) > 0:
		parts.append(Loc.t("stage %d") % (stage(q) + 1))
	if int(lr[2]) > 0:
		parts.append(Loc.t("%s near") % (Loc.t(String(fathers_near_list(g, q)[0].d["name"])) if int(lr[2]) == 1 else Loc.t("%d fathers") % int(lr[2])))
	if int(lr[3]) > 0:
		parts.append(Loc.t("1 expansion") if int(lr[3]) == 1 else Loc.t("%d expansions") % int(lr[3]))
	if int(lr[4]) > 0:
		parts.append(Loc.t("veterancy %d") % int(lr[4]))
	var pct := int(round((float(lr[0]) - 1.0) * 100.0))
	return Loc.t("Laying +%d%%: %s") % [pct, ", ".join(parts)] if not parts.is_empty() else Loc.t("Laying: no lever yet")


## GROW (her card): why she can't grow now ("" = she can).
static func grow_problem(g: Game, q: Unit) -> String:
	if q == null or q.dead:
		return "No Brood Mother."
	if stage(q) >= (Defs.NB["stages"] as Array).size() - 1:
		return "She is fully grown."
	if float(q.nb.get("grow_t", 0.0)) > 0.0:
		return "She is growing."
	if BroodResearch.busy(q):
		return "She is researching."
	if q.tesla_mode != "deployed":
		return "She must be rooted to grow."
	var nx: Dictionary = Defs.NB["stages"][stage(q) + 1]
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[q.team]["gold"]) < int(nx["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[q.team]["res2"]) < float(nx["cost2"]):
		return "Not enough %s." % String(res[1]).to_lower()
	return ""


## She grows to her next stage: paid now, grow_t s rooted, laying nothing meanwhile (as a Town Hall's upgrade).
## Uprooting stops it and pays it all back. She never shrinks.
static func grow(g: Game, q: Unit) -> String:
	var why := grow_problem(g, q)
	if why != "":
		return why
	var nx: Dictionary = Defs.NB["stages"][stage(q) + 1]
	g.players[q.team]["gold"] -= int(nx["cost"])
	g.add_res2(q.team, -float(nx["cost2"]))
	g.stats[q.team]["spent"] += int(nx["cost"])
	q.nb["grow_t"] = float(nx["time"])
	if q.team == g.human:
		Sfx.play_any(["research", "work/grub_deliver"], q.position, -6.0)
	return ""


## up: she got up (UPROOT); else STOP GROWING on her card.
static func _grow_cancel(g: Game, q: Unit, up := true) -> void:
	if float(q.nb.get("grow_t", 0.0)) <= 0.0:
		return
	var nx: Dictionary = Defs.NB["stages"][stage(q) + 1]
	g.players[q.team]["gold"] += int(nx["cost"])
	g.add_res2(q.team, float(nx["cost2"]))
	q.nb["grow_t"] = 0.0
	if q.team == g.human:
		g.tell(q.team, "The Brood Mother got up: her growing stopped (paid back)." if up else "Growing stopped: paid back.", true)


## PROGRESS (the owner, 21:41: her growing showed no bar): what a Brood creature is working at, shown as a building's
## upgrade or a unit in training is: a bar over it in the world (draw) and on its card (the HUD's queue corner):
## {label, f (0..1), left (s), icon, col} or {} for nothing. Her growing, a cocoon morphing, rooting and uprooting, an
## egg hatching or waiting for the father, the first egg in the father's nest.
const BAR_GROW := Color(0.75, 0.55, 1.0)       # (violet: a hall's upgrade)
const BAR_MORPH := Color(0.85, 0.75, 0.35)     # (gold: a building going up)
const BAR_ROOT := Color(0.55, 0.85, 0.4)
const BAR_HATCH := Color(0.4, 0.75, 1.0)       # (blue: a unit in training)
const BAR_WAIT := Color(1.0, 0.6, 0.35)


## The bar and label drawn over a rooted creature in the world for this viewer ({} for none): her growing, rooting and
## uprooting to its own side (and spectators); RESEARCHING to its own side, its allies and spectators, never to an enemy
## (the owner, 2026-10-29 20:09: an enemy sees only the Sire's production loop, not what he researches).
static func bar_over(g: Game, u: Unit) -> Dictionary:
	if not ROOTERS.has(u.kind) or u.nb.has("coc"):
		return {}
	var mine := u.team == g.human or g.demo or g.spectating()
	var pg := progress(g, u)
	if pg.is_empty():
		return {}
	if pg["col"] == BroodResearch.BAR:
		return pg if BroodResearch.shown_to(g, u) else {}
	if mine and (pg["col"] == BAR_GROW or pg["col"] == BAR_ROOT):
		return pg
	return {}


static func progress(g: Game, u: Unit) -> Dictionary:
	if u.dead:
		return {}
	if u.nb.has("coc"):
		var ct := BroodRoot.cocoon_time(u)
		if is_father(u.kind):
			# his lure ripening, then his arrival (BroodRoot.lure_look)
			return {"label": "THE SIRE ARRIVES" if BroodRoot.sire_come(u) else "LURE RIPENING", "f": clampf(float(u.nb["coc"]) / maxf(ct, 0.1), 0.0, 1.0),
				"left": maxf(0.0, ct - float(u.nb["coc"])), "icon": u.kind, "col": BAR_MORPH}
		return {"label": "MORPHING", "f": clampf(float(u.nb["coc"]) / maxf(ct, 0.1), 0.0, 1.0), "left": maxf(0.0, ct - float(u.nb["coc"])), "icon": u.kind, "col": BAR_MORPH}
	if u.kind == QUEEN and float(u.nb.get("grow_t", 0.0)) > 0.0 and stage(u) < (Defs.NB["stages"] as Array).size() - 1:
		var tt := float(Defs.NB["stages"][stage(u) + 1]["time"])
		var left := float(u.nb["grow_t"])
		return {"label": "GROWING · STAGE %d" % (stage(u) + 2), "f": clampf(1.0 - left / maxf(tt, 0.1), 0.0, 1.0), "left": left, "icon": "broodmound", "col": BAR_GROW}
	if BroodResearch.busy(u):
		return BroodResearch.progress(u)       # (RESEARCHING: on a Sire's card in place of his eggs)
	if ROOTERS.has(u.kind) and (u.tesla_mode == "deploying" or u.tesla_mode == "packing"):
		var sw := u.switch_time()
		return {"label": "ROOTING" if u.tesla_mode == "deploying" else "UPROOTING", "f": clampf(1.0 - u.tesla_t / maxf(sw, 0.01), 0.0, 1.0), "left": maxf(0.0, u.tesla_t),
			"icon": "ab_nb_root" if u.tesla_mode == "deploying" else "ab_uproot", "col": BAR_ROOT}
	var e: Unit = u if u.kind == EGG else null
	if is_father(u.kind) and rooted(u):
		var ne := nest_eggs(g, u)
		e = ne[0] if not ne.is_empty() else null
	if e != null and not e.nb.has("out"):
		var k := String(e.nb.get("k", "grub"))
		if int(e.nb.get("fert", 0)) == 1:
			if is_father(u.kind):
				return {"label": "FERTILISING", "f": clampf(float(e.nb.get("redden", 0.0)), 0.0, 1.0), "left": float(Defs.NB["fert_time"]) * (1.0 - clampf(float(e.nb.get("redden", 0.0)), 0.0, 1.0)), "icon": k, "col": BAR_WAIT}
			return {"label": "WAITING FOR THE FATHER", "f": clampf(float(e.nb.get("wait", 0.0)) / float(Defs.NB["fert_wait"]), 0.0, 1.0), "left": maxf(0.0, float(Defs.NB["fert_wait"]) - float(e.nb.get("wait", 0.0))), "icon": k, "col": BAR_WAIT}
		return {"label": "HATCHING", "f": clampf(float(e.nb.get("t", 0.0)) / maxf(egg_time(k), 0.1), 0.0, 1.0), "left": maxf(0.0, egg_time(k) - float(e.nb.get("t", 0.0))), "icon": k, "col": BAR_HATCH}
	return {}


## HER BODY AND HER PICTURE (the owner, 2026-10-30 07:43): her picture grows with her stage (x1.0 / x1.15 / x1.3:
## drawn_r 40 / 46 / 52); her body does not. Her radius (how units keep apart from her, her path's margin) stays at most
## BODY_R at every stage, and the ground she walks with is smaller still (GROUND_R, below), so she goes up and down every
## ramp at every stage. Her bigger picture keeps its own size where it is seen and felt: others reach her from her
## drawn edge (Unit.rect), she reaches from it (Unit._range), a click anywhere on her picture picks her
## (BroodRoot.body_hit), and her ring, shadow, bars and eggs go by drawn_r.
const BODY_R := 40.0
## The body the big rooting creatures (her, the Sires, the Mound Turtle) WALK THE GROUND with (Unit.ground_r): at most
## this. Its footprint (0.6 of it each side, 29 px across) fits any lane of the narrowest ramp (2 tiles: each lane's
## middle is 16 px from the rail), so wherever the path runs on a ramp she can stand on it.
const GROUND_R := 24.0


## Her drawn size as a radius: her kind's radius x her stage's scale.
static func drawn_r(q: Unit) -> float:
	return float(q.d["radius"]) * float(stage_def(q)["scale"])


## The radius to draw a creature's ring, shadow and bars by: the Mother's drawn size, else its body.
static func look_r(u: Unit) -> float:
	return drawn_r(u) if u.kind == QUEEN else u.radius


## Her size follows her stage: her sprite (_rooted_look) and her drawn size (drawn_r); her walking body is capped
## (BODY_R).
static func apply_stage(q: Unit) -> void:
	q.radius = minf(drawn_r(q), BODY_R)
	# her own picture at each stage (the owner's stage-2 and stage-3 sheets, brought to her stage-1 body by
	# tools/import_brood_mature.py; the stage's scale below still makes her x1.15 and x1.3)
	var a := BroodMature.stage_art(stage(q))
	if a != q.art:
		q.art = a
		if q.sprite:
			q._set_anim(q.anim if q.anim != "" else "idle", true)


## Why the Mother can't lay an egg for `k` now ("" = she can).
static func lay_problem(g: Game, q: Unit, k: String) -> String:
	if q == null or q.dead:
		return "No Brood Mother."
	if not hatch_list().has(k):
		if BroodRoot.morph_list().has(k):
			return "A grub turns into it now: pick it on a grub's card."
		return "Not in the Brood yet."
	if float(q.nb.get("grow_t", 0.0)) > 0.0:
		return "She is growing: no eggs meanwhile."
	if int(q.nb.get("eggs", 0)) < 1:
		return "No eggs ready."
	var u: Dictionary = Defs.UNITS[k]
	if stage(q) < unit_stage(k):
		return "Needs the Brood Mother at stage %d." % (unit_stage(k) + 1)       # (the tiers, the owner 12:20)
	var f := father_of(k)
	if f != "" and not father_near(g, q.team, f):
		return "Needs the %s rooted beside the Brood Mother." % Defs.UNITS[f]["name"]
	if f != "" and BroodResearch.line_busy(g, q.team, f):
		return "The %s is researching: no eggs of his line until he is done." % Defs.UNITS[f]["name"]
	var price := g.unit_price(q.team, k)
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[q.team]["gold"]) < int(price[0]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[q.team]["res2"]) < float(price[1]):
		return "Not enough %s." % String(res[1]).to_lower()
	if g.supply_used(q.team) + int(u["supply"]) * young(g, q.team, k) > int(g.players[q.team]["cap"]):
		if int(g.players[q.team]["cap"]) >= g.max_supply(q.team):
			return "Supply is maxed out."
		return "Need more supply: root more Mound Turtles."
	return ""


## The Mother lays an egg for `k` (paid now): it drops behind her, where she is, walking or rooted. A warrior's egg
## waits for the father's breath (fertilised: it incubates; never fertilised in time: it hatches as a grub).
static func lay(g: Game, q: Unit, k: String) -> String:
	var why := lay_problem(g, q, k)
	if why != "":
		return why
	var price := g.unit_price(q.team, k)
	g.players[q.team]["gold"] -= int(price[0])
	g.add_res2(q.team, -float(price[1]))
	g.stats[q.team]["spent"] += int(price[0])
	q.nb["eggs"] = int(q.nb["eggs"]) - 1
	var back := -q.facing.normalized() if q.facing.length() > 0.1 else Vector2.UP
	# eggs fall in a little fan behind her (the n-th egg of the clutch a little to one side)
	var n := int(q.nb.get("laid", 0))
	q.nb["laid"] = n + 1
	var side := back.orthogonal() * float((n % 5) - 2) * 11.0
	var p := q.position + back * (drawn_r(q) + 14.0) + side
	if rooted(q) or q.tesla_mode != "packed":
		# rooted, curled round her nest facing south-east: the eggs roll out in front of the nest's rim, south-west of her
		# middle, where they can be seen (behind her they lay under her great body)
		p = q.position + Vector2(-34.0 + float((n % 5) - 2) * 15.0, drawn_r(q) + 16.0 + float(n % 2) * 8.0)
	var fk := father_of(k)
	var fa: Unit = father(g, q.team, fk) if fk != "" else null
	var on_top := false
	var in_nest := false
	if fa != null and father_near(g, q.team, fk):
		p = nest_spot(g, fa)        # (a warrior's egg goes into the father's nest, in front of him: fertilised and hatched there)
		in_nest = true
	else:
		# EGG PLACEMENT (the owner, 21:32): the nearest EMPTY spot round her (not on a rooted footprint, a cliff, water or
		# another egg), looked for outward from her rim, her front and sides first; boxed in, ON the structure there
		var es := egg_spot(g, q, p)
		p = es[0]
		on_top = bool(es[1])
	var e := g._add_unit(EGG, q.team, p)
	e.nb = {"k": k, "t": 0.0, "fert": 1 if father_of(k) != "" else 0, "wait": 0.0, "drop": float(Defs.NB["drop"])}
	var ny := young(g, q.team, k)
	if ny != int(Defs.UNITS[k].get("spawn", 1)):
		e.nb["n"] = ny          # (a BIGGER CLUTCH: its young, fixed when laid and paid)
	e.z_index = EGG_Z          # (eggs are always seen: drawn over rooted creatures)
	if on_top:
		e.nb["top"] = true
	if fa == null and rooted(q):
		# LAYING in her nest (the owner, 16:24, as the Town Hall's bell; walking, the egg just drops behind her). With her
		# laying frames (brood_mother_rooted_lay_se_chatgpt.png) she lays it in the picture: the game's egg stays hidden
		# ("hold") until her last frame, appears exactly where that frame draws the new egg (LAY_EGG_AT, as big), then
		# rolls out to the nest's rim and waits; her rooted loop has no extra egg. Without them: a heave in code, her
		# clutch flaring, the egg popping out of the clutch (CLUTCH_AT).
		var drawn: bool = ArtData.UNITS[q.art]["frames"].has("lay_se")
		var busy := float(q.nb.get("lay_t", 0.0))       # (already laying: this egg comes out at the end of that show)
		if busy <= 0.0:
			q.nb["lay_t"] = lay_time(q)
		var from := q.position + (BroodMature.lay_egg_at(q.art) if drawn else CLUTCH_AT) * float(stage_def(q)["scale"]) + Vector2(0.0, BroodRoot.drop(q)) - p     # (her rooted art is drawn BroodRoot.drop lower)
		e.nb["pop_x"] = from.x
		e.nb["pop_y"] = from.y
		e.nb["pop"] = POP_TIME
		e.nb["drop"] = 0.0
		if drawn:
			e.nb["hold"] = busy if busy > 0.0 else lay_time(q)
			e.nb["big"] = float(stage_def(q)["scale"])
	if in_nest:
		e.nb["nest"] = true
		e.nb["drop"] = 0.0
	e.facing = Vector2.DOWN
	BroodRoot.set_rally(e, BroodRoot.rally_of(q), false)       # (her rally goes to each egg she lays)
	if q.team == g.human:
		Sfx.play_any(["brood/lay_egg", "work/grub_deliver", "hatch"], p, -6.0)
	recount(g, q.team)
	return ""


## Eggs are drawn on top of the rooted creatures (the owner, 21:32: a Tyrannosaur rooted under the Mother hid them).
const EGG_Z := 2
## How far beyond her rim an egg may roll before it is laid on a creature instead (tiles).
const EGG_REACH := 3.0


## Is p an empty spot for an egg: walkable ground (not a rooted footprint, a building, a cliff, trees or water) and no
## other egg on it.
static func egg_free(g: Game, p: Vector2, t: int) -> bool:
	var c := g.cell_of(p)
	if not g._walkable(c) or not g._clear_at(p, 9.0, t):
		return false
	for o in g.units_near(p, 20.0):
		if o.kind == EGG and not o.dead and not o.nb.has("out") and o.position.distance_to(p) < 18.0:
			return false
	return true


## Where her egg goes: `pref` if it is empty, else the nearest empty spot round her (outward from her rim up to
## EGG_REACH tiles; her front and sides first: rooted she faces south-east and her front is the nest's south, walking
## the side the egg would drop on); none: ON the creature at the nearest point past her rim. [spot, on a structure].
static func egg_spot(g: Game, q: Unit, pref: Vector2) -> Array:
	if egg_free(g, pref, q.team):
		return [pref, false]
	var rooted_q := BroodRoot.has_fp(q) and q.tesla_mode != "packed"
	var r := BroodRoot.rect_of(q) if rooted_q else q.rect()
	var c := r.get_center()
	var want := (pref - c).normalized() if pref.distance_to(c) > 1.0 else Vector2.DOWN
	if rooted_q:
		want = Vector2(0.0, 1.0)          # (her front: the nest's south side)
	var best := Vector2.INF
	var bs := INF
	var steps := int((EGG_REACH - 0.4) * 2.0)         # (from 0.4 to just under EGG_REACH tiles past her rim, half a tile at a time)
	for di in range(0, steps + 1):
		var dd := (0.4 + di * 0.5) * Defs.TILE
		for ai in 32:
			var dir := Vector2.from_angle(TAU * ai / 32.0)
			var pt := _rim(r, dir) + dir * dd
			var front := dir.dot(want)          # 1 front, 0 the sides, -1 behind
			var sc := dd / Defs.TILE + (1.0 - front) * 0.7 + (1.5 if front < -0.5 else 0.0)
			if sc >= bs:
				continue
			if egg_free(g, pt, q.team):
				bs = sc
				best = pt
	if best != Vector2.INF:
		return [best, false]
	# boxed in: on the creature at her front, just past her rim (side by side along it: not on another egg)
	var lim := Vector2(Game.W, Game.H) * Defs.TILE - Vector2(8, 8)
	var top := (_rim(r, want) + want * 0.6 * Defs.TILE).clamp(Vector2(8, 8), lim)
	for i in 24:
		var sx := float((i + 1) / 2) * 20.0 * (1.0 if i % 2 == 0 else -1.0)
		var pt := (top + want.orthogonal() * sx).clamp(Vector2(8, 8), lim)
		var lone := true
		for o in g.units_near(pt, 20.0):
			if o.kind == EGG and not o.dead and not o.nb.has("out") and o.position.distance_to(pt) < 18.0:
				lone = false
		if lone:
			return [pt, true]
	return [top, true]


## Where a ray from the rect's centre along dir leaves it.
static func _rim(r: Rect2, dir: Vector2) -> Vector2:
	var c := r.get_center()
	var h := r.size * 0.5
	var tx := h.x / absf(dir.x) if absf(dir.x) > 0.001 else INF
	var ty := h.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
	return c + dir * minf(tx, ty)


## The rooted Mother's laying. Her sheet's 6 frames last LAY_DUR s each (the owner, 16:40: frames 3 and 4, her head
## reared high, a big jump from frame 2, held longer; 21:28: the whole show longer, about 2.5-3 s; only the show: an egg
## laid while she is still laying the one before comes out with it, at the end of the same show); the new egg in frame 6 is at LAY_EGG_AT from her feet (its
## bottom; tools/import_brood_new.py prints it), LAY_EGG_BIG times the game egg's size. Without the sheet: LAY_TIME s of
## heave in code; the egg flies from her clutch (CLUTCH_AT). Either way the egg then goes to the rim in POP_TIME s, over
## an arc POP_ARC px high.
const LAY_DUR := [0.28, 0.38, 0.7, 0.7, 0.38, 0.32]      # (2.76 s in all: the owner, 21:28, "too fast"; her laying RATE is not slowed)
const LAY_EGG_AT := Vector2(14.0, -57.0)
const LAY_EGG_BIG := 1.6
const LAY_TIME := 1.0
const POP_TIME := 0.55
const POP_ARC := 34.0
const CLUTCH_AT := Vector2(0.0, -120.0)


static func lay_time(q: Unit) -> float:
	if ArtData.UNITS[q.art]["frames"].has("lay_se"):
		var t := 0.0
		for d in LAY_DUR:
			t += float(d)
		return t
	return LAY_TIME


static func egg_time(k: String) -> float:
	return float(Defs.UNITS[k]["time"])


## THE SIRES' EGGS (the owner, 2026-10-29 20:09): how much of his lure's faint colour an egg wears, 0..1: an egg of a
## Sire's line takes it as he breathes on it (fertilised: all of it, until it hatches), and lying in his nest at least
## Defs.NB "egg_nest" of it; a grub egg, or a warrior egg not yet in his nest, keeps its own colour (0). The hatching
## shell is plain again.
static func egg_tint(e: Unit) -> float:
	if e.nb.has("out"):
		return 0.0
	var fe := int(e.nb.get("fert", 0))
	if fe == 0 or father_of(String(e.nb.get("k", "grub"))) == "":
		return 0.0
	if fe == 2:
		return 1.0
	var r := clampf(float(e.nb.get("redden", 0.0)), 0.0, 1.0)
	if bool(e.nb.get("nest", false)):
		r = maxf(r, float(Defs.NB["egg_nest"]))
	return r


## The faint colour of a young kind's Sire line's eggs (Defs.NB "egg_col"; white for a kind with no Sire).
static func egg_col(k: String) -> Color:
	var a: Array = (Defs.NB["egg_col"] as Dictionary).get(father_of(k), [1.0, 1.0, 1.0])
	return Color(float(a[0]), float(a[1]), float(a[2]))


## The hatching's two halves: HATCH_IN s before the creature comes out the egg cracks (the sheet's first hatch frames),
## then the creature stands on the open shell, which breaks apart and goes after HATCH_OUT s.
const HATCH_IN := 0.8
const HATCH_OUT := 0.9


static func _hatch(g: Game, e: Unit) -> void:
	var k := String(e.nb.get("k", "grub"))
	var t := e.team
	var at := e.position
	e.nb["out"] = 0.0          # (the shell stays a moment under the creature: egg_tick lets it go)
	e.z_index = -1
	var n := int(e.nb.get("n", Defs.UNITS[k].get("spawn", 1)))      # (2 young, 3 if laid with BIGGER CLUTCH)
	var rp := BroodRoot.hatch_rally(g, e)
	# hatched inside or among its side's rooted creatures (the father's nest, an egg laid on a creature when she was
	# boxed in): it walks out through them (BroodRoot.start_pass, the owner, 21:32), then on to its rally
	g.stats[t]["trained"] += n
	if g.mlog and not g._first_of.has("%d:%s" % [t, k]):
		g._first_of["%d:%s" % [t, k]] = true
		g.mlog.add("%s got its first %s" % [g.mlog.who(t), Defs.UNITS[k]["name"]])
	if t == g.human:
		Sfx.play_any(["brood/hatch", "hatch"], at)
		Sfx.voice(k, "select")
	var young: Array = []
	for i in n:
		var off := Vector2.from_angle(TAU * i / maxf(1.0, n) + float(e.serial)) * (6.0 if n > 1 else 0.0)
		var u := g._add_unit(k, t, at + off)
		u.facing = Vector2.DOWN
		young.append(u)
		if e.net_id != 0:
			u.nb["hof"] = e.net_id         # (online: the guest hands its selection of the egg on to them too, NetSnapshot)
		if n > 1:
			u.clutch_n = n          # (its share of the egg, for SACRIFICE: devour)
		if bool(e.nb.get("sac", false)):
			u.cmd_sacrifice()          # (offered up while still an egg: straight to the Mother)
		elif not BroodRoot.send(g, u, rp, i) and k == "grub":     # (to the rally: the Mother's, the egg's own, or the father's for his nest)
			var src := free_source(g, t, u.position)
			if src:
				u.cmd_gather(src)
		BroodRoot.start_pass(g, u)
	g.hand_on(e, young)          # (a selected egg: its young are selected now, and join its control groups)
	e.selected = false
	g.selection.erase(e)
	recount(g, t)


static func egg_tick(g: Game, e: Unit, delta: float) -> void:
	if e.nb.has("out"):
		e.nb["out"] = float(e.nb["out"]) + delta
		if float(e.nb["out"]) >= HATCH_OUT:
			g.consume_unit(e)
		return
	if float(e.nb.get("drop", 0.0)) > 0.0:
		e.nb["drop"] = maxf(0.0, float(e.nb["drop"]) - delta)
	if float(e.nb.get("hold", 0.0)) > 0.0:
		e.nb["hold"] = maxf(0.0, float(e.nb["hold"]) - delta)      # (still in her laying frames)
	elif float(e.nb.get("pop", 0.0)) > 0.0:
		e.nb["pop"] = maxf(0.0, float(e.nb["pop"]) - delta)
	var k := String(e.nb.get("k", "grub"))
	if int(e.nb.get("fert", 0)) == 1:
		# waiting for the father's breath; not fertilised in time: a grub after all (the difference paid back)
		e.nb["wait"] = float(e.nb.get("wait", 0.0)) + delta
		if float(e.nb["wait"]) >= float(Defs.NB["fert_wait"]):
			var was := BroodResearch.egg_price(k, int(e.nb.get("n", Defs.UNITS[k].get("spawn", 1))))      # (what was paid for it)
			var now := g.unit_price(e.team, "grub")
			e.nb.erase("n")
			g.players[e.team]["gold"] += maxi(0, int(was[0]) - int(now[0]))
			g.add_res2(e.team, float(maxi(0, int(was[1]) - int(now[1]))))
			e.nb["k"] = "grub"
			e.nb["fert"] = 0
			e.nb["t"] = 0.0
			if e.team == g.human:
				g.tell(e.team, "An egg wasn't fertilised in time: it hatches as a grub (paid back the difference).", true)
			recount(g, e.team)
		return
	e.nb["t"] = float(e.nb.get("t", 0.0)) + delta
	if float(e.nb["t"]) >= egg_time(k):
		_hatch(g, e)


# ------------------------------------------------------------------ fertilising

## THE SIRE'S EGGS IN FRONT (the owner, 2026-10-29 18:31): the eggs of his line he fertilises lie IN FRONT of his
## footprint (south of it, on the ground; drawn on the top layer as the Mother's, EGG_Z), not inside his nest picture,
## while he keeps his production animation. "His nest" in the code is that row of eggs: NEST_ROW eggs a row, NEST_GAP
## px apart, NEST_FRONT px past the footprint's front edge, further rows further south. (Before 0.19.0 they lay hidden
## on the nest drawn in his rooted frame, Defs.NB "nest_at", and showed only to hatch.)
const NEST_FRONT := 22.0     # (the egg drawn whole below the nest picture, which reaches the footprint's edge)
const NEST_GAP := 14.0
const NEST_ROW := 5
const NEST_REACH := 70.0       # (px from the row's middle: his eggs are looked for this far)


static func nest_at(k: String) -> Vector2:
	var a: Array = (Defs.NB["nest_at"] as Dictionary).get(k, [26, 2])
	return Vector2(float(a[0]), float(a[1]))


## The middle of the first row of his eggs, just in front of his footprint (not rooted: in front of his nest's place).
static func nest_point(f: Unit) -> Vector2:
	if BroodRoot.has_fp(f):
		var r := BroodRoot.rect_of(f)
		return Vector2(r.get_center().x, r.end.y + NEST_FRONT)
	return f.position + nest_at(f.kind) + Vector2(0.0, BroodRoot.drop(f) + NEST_FRONT)


## The i-th place in his row of eggs (from the middle out, left and right; then the next row).
static func nest_slot(f: Unit, i: int) -> Vector2:
	var row := i / NEST_ROW
	var k := i % NEST_ROW
	var side := float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)
	return nest_point(f) + Vector2(side * NEST_GAP + (NEST_GAP * 0.5 if row % 2 == 1 else 0.0), float(row) * 12.0)


## The first free place in his row for a new egg.
static func nest_spot(g: Game, f: Unit) -> Vector2:
	# (every egg of his row, the ones laid this very tick too: the unit grid has not seen them yet)
	var taken: Array = []
	var np := nest_point(f)
	for u in g.units:
		if u.team == f.team and u.kind == EGG and not u.dead and bool(u.nb.get("nest", false)) and not u.nb.has("out") and u.position.distance_to(np) < NEST_REACH:
			taken.append(u)
	for i in NEST_ROW * 4:
		var p := nest_slot(f, i)
		var free := true
		for e in taken:
			if (e as Unit).position.distance_to(p) < NEST_GAP * 0.5:
				free = false
				break
		if free:
			return p
	return nest_slot(f, taken.size() % (NEST_ROW * 4))


## The eggs in his nest (the row in front of him), first laid first (the queue counted over him).
static func nest_eggs(g: Game, f: Unit) -> Array:
	var out: Array = []
	for u in g.units_near(nest_point(f), NEST_REACH):
		if u.team == f.team and u.kind == EGG and not u.dead and bool(u.nb.get("nest", false)) and not u.nb.has("out") \
				and father_of(String(u.nb.get("k", ""))) == f.kind:
			out.append(u)
	out.sort_custom(func(a, b) -> bool: return a.serial < b.serial)
	return out


## The rooted father: warrior eggs within his reach roll into his nest; he fertilises them ALL AT ONCE (the owner,
## 22:42: a queue of 10 Raptor eggs is fathered together, the same for every father): his breath drawn in the frame,
## each egg turns red over Defs.NB "fert_time" (its own timer, "fb"); fertilised, they incubate and hatch in the nest.
## "fe" points at one egg he is breathing on (his loop, fertilising(), the net snapshot), not a queue.
static func father_tick(g: Game, f: Unit, delta: float) -> void:
	var on_nest := rooted(f)
	var q := queen(g, f.team)
	var r := float(Defs.NB["father_r"]) * Defs.TILE
	var near := on_nest and q != null and f.position.distance_to(q.position) <= r
	var ft := float(Defs.NB["fert_time"])
	if not near:
		if f.nb.has("fe"):
			for u in nest_eggs(g, f):
				if int(u.nb.get("fert", 0)) == 1:
					u.nb["redden"] = 0.0       # (broken off: yellow-green again until he is back on his nest)
					u.nb.erase("fb")
			f.nb.erase("fe")
		f.nb["ft"] = 0.0
		return
	if BroodResearch.busy(f):
		# RESEARCHING (the owner, 18:31): he fathers no eggs meanwhile; those in his nest wait for him (their count holds)
		for u in nest_eggs(g, f):
			if int(u.nb.get("fert", 0)) == 1:
				u.nb["wait"] = maxf(0.0, float(u.nb.get("wait", 0.0)) - delta)
		f.nb.erase("fe")
		f.nb["ft"] = 0.0
		return
	f.nb["scan"] = float(f.nb.get("scan", 0.0)) - delta
	if float(f.nb["scan"]) <= 0.0:
		f.nb["scan"] = 0.25
		# her warrior eggs left on the ground near him (laid before he rooted) roll into the nest
		for u in g.units_near(f.position, r):
			if u.team == f.team and u.kind == EGG and not u.dead and int(u.nb.get("fert", 0)) == 1 and not bool(u.nb.get("nest", false)) \
					and father_of(String(u.nb.get("k", ""))) == f.kind:       # (only the eggs of his line)
				u.position = nest_spot(g, f)
				u.nb["nest"] = true
				u.nb["drop"] = 0.0
				u.z_index = EGG_Z
				g.note_move(u)
	var any = null
	var roared := false
	for u in nest_eggs(g, f):
		if int(u.nb.get("fert", 0)) != 1:
			continue
		var left := float(u.nb.get("fb", ft)) - delta
		u.nb["fb"] = left
		u.nb["redden"] = clampf(1.0 - left / ft, 0.0, 1.0)     # (it turns red as he breathes)
		if left <= 0.0:
			u.nb["fert"] = 2
			u.nb["t"] = 0.0
			u.nb.erase("fb")
			if f.team == g.human and not roared:
				roared = true
				Sfx.play_any(["brood/breath_" + f.kind, "roar", "combat/brute_attack"], f.position, -10.0)
		elif any == null:
			any = u
	if any != null:
		f.nb["fe"] = any
		f.nb["ft"] = float(any.nb.get("fb", ft))
	else:
		f.nb.erase("fe")
		f.nb["ft"] = 0.0


## The computer's Mother (and the defence test's): rooted at home. No rooted creature attacks (the owner, 15:58, 17:14):
## when enemies reach her (strike at her, or come within MOTHER_FIGHT tiles of her body) she uproots and fights, on a
## leash (MOTHER_LEASH tiles from her nest). She STAYS UP while any enemy is near (MOTHER_NEAR tiles of her body, or one
## aiming at her from farther), and roots again only after MOTHER_CALM s of real calm, counted only once she is fully
## up (round 2 of the coached games, docs/brood_new_play_2.md: a shooter aiming at her from range woke her, her calm
## time kept counting while she got up, and she rooted again at once: five times in 90 s, her swamp, Rootmaws and GROW
## lost each time). Only the computer calls this, for its own Mother: the player's Mother never roots or uproots by
## herself. st: the caller's own state (her nest, the calm time); dt: the time since the last call.
const MOTHER_FIGHT := 3.0
const MOTHER_LEASH := 7.0
const MOTHER_CALM := 9.0
const MOTHER_NEAR := 10.0


static func mother_guard(g: Game, q: Unit, st: Dictionary, dt: float) -> void:
	q.nb["leash"] = 1             # (the computer's Mother: she never chases, Unit._engage, mother_chases)
	if not st.has("home"):
		st["home"] = q.position
		st["calm"] = 0.0
	var home: Vector2 = st["home"]
	var foe: Unit = null           # (one at her: she gets up for it and fights it)
	var fd := INF
	var near := false              # (any enemy about: she stays up)
	for u in g.units_near(q.position, (MOTHER_NEAR + 5.0) * Defs.TILE):
		if not g.hostile(u.team, q.team) or u.dead or u.off_field or u.is_air():
			continue
		var ed := q.edge_distance(u.position)
		if u.target == q or ed < MOTHER_NEAR * Defs.TILE:
			near = true
		var at_her: bool = u.target == q or ed < MOTHER_FIGHT * Defs.TILE
		var dd: float = u.position.distance_to(q.position)
		if at_her and dd < fd:
			fd = dd
			foe = u
	if foe != null or near or q.tesla_mode != "packed":
		st["calm"] = 0.0          # (the calm counts only while she is fully up and nobody is about)
	else:
		st["calm"] = float(st["calm"]) + dt
	match q.tesla_mode:
		"deployed":
			if foe != null:
				q.cmd_uproot(false)       # (to fight she must get up)
		"packed":
			if foe != null:
				if q.position.distance_to(home) > MOTHER_LEASH * Defs.TILE:
					q.cmd_move(home)
				elif q.target == null or q.order == "idle":
					q.cmd_attack(foe)
			elif float(st["calm"]) >= MOTHER_CALM and q.target == null:
				if q.position.distance_to(home) > Defs.TILE:
					if q.order != "move":
						q.cmd_move(home)
				elif q.order == "idle" or q.order == "move":
					q.cmd_deploy()


## Does the uprooted Mother chase her target out of her reach (Unit._engage)? Only on the player's own orders: ATTACK
## (the target she was told to hit) and ATTACK-MOVE. She stands her ground against what she picks for herself (idle, on
## HOLD) and always on the computer's leash (mother_guard). Before 0.22.1 she never chased: sent at a gate on a ramp she
## stood at the ramp's foot (docs/brood_fixes.md).
static func mother_chases(q: Unit) -> bool:
	if int(q.nb.get("leash", 0)) == 1:
		return false
	return (q.order == "attack" and q.target == q.order_target) or q.order == "amove"


## SACRIFICE's egg back, in parts of an egg: EGG_PARTS make one (12: a half, a third and a quarter are whole numbers).
const EGG_PARTS := 12


## The parts of an egg a creature offered up gives back: its egg's share (a Raptor of a two-egg clutch 6, of a BIGGER
## CLUTCH 4; one hatched alone, a Brute, a Challenger, 12: a whole egg).
static func egg_share(u: Unit) -> int:
	var n := u.clutch_n if u.clutch_n > 0 else int(Defs.UNITS[u.kind].get("spawn", 1))
	return EGG_PARTS / clampi(n, 1, EGG_PARTS)


## SACRIFICE at the Mother: she turns on the creature offered up and devours it (her swipe frames).
static func devour(q: Unit, u: Unit) -> void:
	if q.dead:
		return
	q.nb["devour"] = 0.65
	# an offering gives her back its share of an EGG (the owner, 2026-10-30: the young of one egg together give ONE egg,
	# not one each): egg_share parts of EGG_PARTS, kept on her ("eggp", whole numbers: deterministic and saved) until
	# they make a whole egg, which she gets at once (none if her clutch is full: that egg is lost, as before)
	var parts := int(q.nb.get("eggp", 0)) + egg_share(u)
	if parts >= EGG_PARTS:
		parts -= EGG_PARTS
		if int(q.nb.get("eggs", 0)) < eggs_max(q):
			q.nb["eggs"] = int(q.nb.get("eggs", 0)) + 1
	q.nb["eggp"] = parts
	if u.position.distance_to(q.position) > 1.0:
		q.facing = (u.position - q.position).normalized()
	q.frame_i = 0
	q.anim_t = 0.0
	Sfx.play_any(["combat/brood_mother_devour", "combat/brute_attack", "bite"], q.position, -6.0)


## Any warrior egg in his nest (fertilised or not, until it hatches) or lying near him waiting for his breath.
static func father_busy(g: Game, f: Unit) -> bool:
	if not rooted(f):
		return false
	if not nest_eggs(g, f).is_empty():
		return true
	for u in g.units_near(f.position, float(Defs.NB["father_r"]) * Defs.TILE):
		if u.team == f.team and u.kind == EGG and not u.dead and int(u.nb.get("fert", 0)) == 1 and not u.nb.has("out") \
				and father_of(String(u.nb.get("k", ""))) == f.kind:
			return true
	return false


static func fertilising(u: Unit) -> bool:
	return is_father(u.kind) and u.nb.get("fe") != null and is_instance_valid(u.nb.get("fe"))


# ------------------------------------------------------------------ ground (the Rootmaws' circles)

## Why it can't root where it stands ("" = it can): the ROOT placement rules (BroodRoot.place_problem: its footprint on
## the grid, a Rootmaw on swamp with its circle clear, the Tyrannosaur in the father's range).
static func root_problem(g: Game, u: Unit) -> String:
	return BroodRoot.place_problem(g, u.team, u.kind, u.position, u, false, BroodRoot.scale_of(u))


## The Rootmaw takes its circle of ground: what ground_at says is there. The old free circles it covers half or more of
## are merged into it (their spent share is counted in its own now); one it only touches stays, for the ground beside it.
static func _claim(g: Game, u: Unit) -> void:
	var left := ground_at(g, u.position)
	var gone: Array = []
	for id in g.nb_spots:
		var s: Dictionary = g.nb_spots[id]
		if int(s.get("maw", 0)) == 0 and overlap((s["p"] as Vector2).distance_to(u.position)) >= 0.5:
			gone.append(id)
	for id in gone:
		g.nb_spots.erase(id)
	g.nb_spot_next += 1
	while g.nb_spots.has(g.nb_spot_next):
		g.nb_spot_next += 1         # (never over a spot still there: another Rootmaw's ground would be taken)
	g.nb_spots[g.nb_spot_next] = {"p": u.position, "left": left, "maw": u.serial}
	u.nb["spot"] = g.nb_spot_next
	u.nb["gw"] = 0          # (its ground warnings start again on its new ground)


## The food a Rootmaw rooted at p would have in its ground (_claim's rule; the ROOT ghost shows it: the owner, 2026-10-30
## 19:36): PIT_GROUND, less what was drunk from each old free circle it overlaps, by the share of that circle it covers
## (rooting on or beside spent ground can't refresh it; a fresh circle that only touches an old one keeps nearly all its
## food: until 0.25.2 the least of the circles it touched was taken, so a circle a tile into a spent one's edge had 0).
static func ground_at(g: Game, p: Vector2) -> float:
	var left := float(Defs.PIT_GROUND)
	for id in g.nb_spots:
		var s: Dictionary = g.nb_spots[id]
		if int(s.get("maw", 0)) != 0:
			continue
		var k := overlap((s["p"] as Vector2).distance_to(p))
		if k > 0.0:
			left -= maxf(0.0, float(Defs.PIT_GROUND) - float(s["left"])) * k
	return clampf(left, 0.0, float(Defs.PIT_GROUND))


## The share of a Rootmaw's circle of ground (radius PIT_CLAIM tiles) that another one d px away covers (1 on the same
## spot, 0 when they don't touch).
static func overlap(d: float) -> float:
	var r := float(Defs.PIT_CLAIM) * Defs.TILE
	if d >= 2.0 * r:
		return 0.0
	if d <= 0.0:
		return 1.0
	var lens := 2.0 * r * r * acos(d / (2.0 * r)) - 0.5 * d * sqrt(4.0 * r * r - d * d)
	return clampf(lens / (PI * r * r), 0.0, 1.0)


static func _release(g: Game, u: Unit) -> void:
	var id := int(u.nb.get("spot", 0))
	if g.nb_spots.has(id):
		g.nb_spots[id]["maw"] = 0
	u.nb.erase("spot")


static func ground_left(g: Game, u: Unit) -> float:
	var id := int(u.nb.get("spot", 0))
	return float(g.nb_spots[id]["left"]) if g.nb_spots.has(id) else 0.0


## ROOT (cmd_deploy): the Mother and the Rootmaw always root facing south-east.
static func on_root(g: Game, u: Unit) -> String:
	var why := root_problem(g, u)
	if why != "":
		# (rooted where it stands: a tile to one side may be clear, as its feet are seldom on the grid's line)
		var sc := BroodRoot.scale_of(u)
		for off in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var p2: Vector2 = u.position + off * Defs.TILE
			if g._walkable(g.cell_of(p2)) and BroodRoot.place_problem(g, u.team, u.kind, p2, u, false, sc) == "":
				u.position = BroodRoot.snap(u.kind, p2, sc)
				why = ""
				break
	if why != "":
		return why
	u.facing = SE
	u.position = BroodRoot.snap(u.kind, u.position, BroodRoot.scale_of(u))     # (on the grid: its footprint, as a building's)
	g.note_move(u)
	BroodRoot.footprint_on(g, u)
	if u.kind == MAW:
		_claim(g, u)
	Sfx.play("brood/root", u.position, -4.0)       # (it sinks into the ground: a squelch, where your side sees)
	return ""


## UPROOT (spill = true: a Rootmaw spills its food as a pile and walks off thin) or HAUL (it keeps it, walks slow).
static func uproot(u: Unit, spill: bool) -> void:
	if u.kind == QUEEN:
		_grow_cancel(u.game, u)
	if BroodResearch.busy(u):
		BroodResearch.stop(u.game, u, "up")     # (got up: its research stops, paid back)
	if u.kind == MAW:
		u.nb["spill"] = spill
	Sfx.play("brood/uproot", u.position, -4.0)     # (it pulls itself out of the ground)
	u.cmd_pack()


static func spill(g: Game, u: Unit) -> void:
	var f := float(u.nb.get("food", 0.0))
	u.nb["food"] = 0.0
	if f < 1.0:
		return
	# onto a pile already lying here, else a new one (nobody's: any Brood grub may collect it)
	for o in g.units_near(u.position, 40.0):
		if o.kind == PILE and not o.dead:
			o.nb["food"] = float(o.nb.get("food", 0.0)) + f
			o.nb["start"] = float(o.nb.get("start", 0.0)) + f
			return
	var p := g._add_unit(PILE, -1, u.position + Vector2(-u.radius * 0.6, 4))
	p.nb = {"food": f, "start": f, "rot": 0.0}
	if u.team == g.human:
		Sfx.play_any(["acid", "work/grub_deliver"], u.position, -6.0)


# ------------------------------------------------------------------ ticks

## Each tick of a Brood creature (from Unit._tick_unit, after its speed is set).
static func tick(g: Game, u: Unit, delta: float) -> void:
	if u.nb.has("coc"):
		BroodRoot.cocoon_tick(g, u, delta)      # (a grub's cocoon: nothing else until it opens)
		return
	var m := String(u.nb.get("m", "packed"))
	if m != u.tesla_mode:
		_mode_changed(g, u, m)
		u.nb["m"] = u.tesla_mode
		if ROOTERS.has(u.kind):
			u.nb_mass = 1000.0 if u.tesla_mode != "packed" else packed_mass(u.kind)     # (dug in: not shoved)
		set_sky(u)
	if rooted(u) and u.phase == "" and u.target == null and float(u.nb.get("devour", 0.0)) <= 0.0:
		u.facing = SE          # (rooted, it settles back facing south-east after a fight)
	if u.nb.has("rs"):
		BroodResearch.tick(g, u, delta)        # (its research: scripts/brood_research.gd)
	match u.kind:
		QUEEN:
			if float(u.nb.get("devour", 0.0)) > 0.0:
				u.nb["devour"] = maxf(0.0, float(u.nb["devour"]) - delta)
			if float(u.nb.get("lay_t", 0.0)) > 0.0:
				u.nb["lay_t"] = maxf(0.0, float(u.nb["lay_t"]) - delta)
			u.speed *= float(stage_def(u)["speed"])         # (bigger, a bit slower)
			if float(u.nb.get("grow_t", 0.0)) > 0.0:
				# GROWING: no eggs meanwhile; then her next stage
				u.nb["grow_t"] = float(u.nb["grow_t"]) - delta
				if float(u.nb["grow_t"]) <= 0.0:
					u.nb["grow_t"] = 0.0
					u.nb["stage"] = stage(u) + 1
					apply_stage(u)
					if BroodRoot.has_fp(u):
						BroodRoot.footprint_on(g, u)      # (bigger: her nest's ground grows)
					recount(g, u.team)
					g.swamp_dirty = true
					if u.team == g.human:
						g.tell(u.team, "The Brood Mother has grown (stage %d): up to %d eggs, laying faster." % [stage(u) + 1, eggs_max(u)], true)
			elif int(u.nb.get("eggs", 0)) < eggs_max(u):
				u.nb["rate_t"] = float(u.nb.get("rate_t", 0.0)) - delta
				if float(u.nb["rate_t"]) <= 0.0:
					u.nb["rate_t"] = 0.5
					u.nb["rate"] = float(lay_rate(g, u)[0])       # (the levers, looked at twice a second)
				u.nb["egg_t"] = float(u.nb.get("egg_t", 0.0)) + delta * float(u.nb.get("rate", 1.0))
				if float(u.nb["egg_t"]) >= float(Defs.NB["egg_time"]):
					u.nb["egg_t"] = 0.0
					u.nb["eggs"] = int(u.nb.get("eggs", 0)) + 1
			if rooted(u) and u.hp < u.max_hp and g.clock - u.hit_clock >= float(Defs.NB["regen_calm"]):
				u.hp = minf(u.max_hp, u.hp + float(Defs.NB["queen_regen"]) * delta)     # (out of the fight only)
		MAW:
			var food := float(u.nb.get("food", 0.0))
			u.nb["wet_t"] = float(u.nb.get("wet_t", 0.0)) - delta
			if float(u.nb["wet_t"]) <= 0.0:
				u.nb["wet_t"] = 0.5
				u.nb["dry"] = not on_swamp(g, u.team, u.position)      # (off the swamp: it stops feeding)
				# NO SWAMP, NO ROOTS (the owner's playtest, 2026-10-31): a rooted Rootmaw whose swamp is gone (its turtle up or
				# dead, the swamp receded) uproots by itself, keeping its food (as HAUL); its ground keeps what is left
				# (Game.nb_spots). DRY_GRACE: the swamp is worked out once a second, so a moment's gap is not a loss.
				if rooted(u) and bool(u.nb["dry"]):
					u.nb["dry_t"] = float(u.nb.get("dry_t", 0.0)) + 0.5
					if float(u.nb["dry_t"]) >= DRY_GRACE:
						u.nb.erase("dry_t")
						_lost_swamp(g, u)
				else:
					u.nb.erase("dry_t")
			if rooted(u) and u.nb.has("spot") and not bool(u.nb.get("dry", false)):
				var id := int(u.nb["spot"])
				if g.nb_spots.has(id):
					var s: Dictionary = g.nb_spots[id]
					var qm := queen(g, u.team)        # (a far Rootmaw drinks faster: Game.food_mult, 0.24.22)
					var fill := float(Defs.NB["maw_fill"]) * (maxf(1.0, Game.food_mult(qm.position.distance_to(u.position) / Defs.TILE)) if qm else 1.0)
					var take := minf(minf(fill * delta, float(s["left"])), float(Defs.NB["maw_cap"]) - food)
					if take > 0.0:
						s["left"] = float(s["left"]) - take
						u.nb["food"] = food + take
					_ground_warn(g, u, float(s["left"]) / float(Defs.PIT_GROUND))
			elif not rooted(u) and food > 0.5:
				u.speed *= float(Defs.NB["haul_speed"])        # HAUL: full and slow
		FATHER, DILO, PTERO:
			father_tick(g, u, delta)


const DRY_GRACE := 2.0


static func _lost_swamp(g: Game, u: Unit) -> void:
	uproot(u, false)
	if g.mlog:
		g.mlog.add("%s: a Rootmaw lost its swamp and uprooted" % g.mlog.who(u.team))
	if u.team == g.human and not g.demo and g.hud:
		g.hud.toast("A Rootmaw lost its swamp and uprooted.", false)
		g._ping(u.position, Color(1.0, 0.55, 0.3))


## A Rootmaw's ground running low or spent: it warns for itself (the owner, 21:28: the Brood's alerts in its own
## words), once per level (nb "gw").
static func _ground_warn(g: Game, u: Unit, left: float) -> void:
	var level := 2 if left <= 0.0 else (1 if left < Defs.SOIL_LOW else 0)
	if level <= int(u.nb.get("gw", 0)):
		return
	u.nb["gw"] = level
	if g.mlog:
		g.mlog.add("%s: the ground of a Rootmaw %s" % [g.mlog.who(u.team), "is spent (it drinks nothing more)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
	if u.team == g.human and not g.demo and g.hud:
		g.hud.toast("A Rootmaw's ground is spent: UPROOT it and root it on fresh ground, outside the old circles." if level == 2
			else "A Rootmaw's ground is running low (%d%% left): plan fresh ground for it." % int(round(left * 100)), false)


## THE PTERODACTYL FLIES UPROOTED AND IS A GROUND STRUCTURE ROOTED (the owner, 2026-10-29): from the moment he starts
## to land on his nest (ROOT) until he has taken off again (UPROOT done), he is on the ground: not a flyer (anything that
## hits the ground hits him; his footprint is a building's), drawn in the building layer; up, he is a flyer again. As a
## landed Skywing, his kind's entry is swapped for a grounded copy (Unit.d: is_air() follows it). Any other kind: nothing.
static var _ptero_ground := {}


static func grounded_d() -> Dictionary:
	if _ptero_ground.is_empty():
		_ptero_ground = (Defs.UNITS[PTERO] as Dictionary).duplicate(true)
		_ptero_ground["air"] = false
	return _ptero_ground


static func set_sky(u: Unit) -> void:
	if u.kind != PTERO:
		return
	var up := u.tesla_mode == "packed" and not u.nb.has("coc") and not u.dead
	if up == bool(u.d.get("air", false)):
		return
	u.d = Defs.UNITS[PTERO] if up else grounded_d()
	u.z_index = 3 if u.is_air() else 0
	if u.game:
		u.game.note_move(u)


## How hard a walking (uprooted) creature is to shove (Game.separation): the Mother a great deal; the Tyrannosaur and
## the Mound Turtle, huge heavy beasts, enough that the grubs streaming to the Mother flow round them instead of washing
## them back; the others as anyone.
static func packed_mass(k: String) -> float:
	return 30.0 if k == QUEEN else (8.0 if is_father(k) or k == TURTLE else 1.0)


static func _mode_changed(g: Game, u: Unit, was: String) -> void:
	match u.tesla_mode:
		"packing":
			if is_father(u.kind):
				for e in nest_eggs(g, u):
					e.nb.erase("nest")      # (he gets up: the eggs in his nest lie on the ground, waiting)
					e.nb["redden"] = 0.0
			if u.kind == MAW:
				if bool(u.nb.get("spill", false)):
					spill(g, u)
				u.nb["spill"] = false
				_release(g, u)
			recount(g, u.team)
			g.swamp_dirty = true
		"deployed":
			recount(g, u.team)
			g.swamp_dirty = true
		"deploying":
			if not BroodRoot.has_fp(u):
				BroodRoot.footprint_on(g, u)      # (rooted by any way other than the button: still takes its ground)
			if was == "packed" and u.kind == MAW and not u.nb.has("spot"):
				_claim(g, u)
		"packed":
			BroodRoot.footprint_off(g, u)        # (up: a unit again, its ground free)
			recount(g, u.team)


## Eggs and piles: they stand where they are (no orders, no walking).
static func still_tick(g: Game, u: Unit, delta: float) -> void:
	if u.kind == EGG:
		egg_tick(g, u, delta)
	elif u.kind == PILE:
		var rot := minf(float(Defs.NB["pile_rot"]) * delta, float(u.nb.get("food", 0.0)))
		var f := float(u.nb.get("food", 0.0)) - rot
		u.nb["food"] = f
		u.nb["rot"] = float(u.nb.get("rot", 0.0)) + rot
		if f <= 0.0:
			g.consume_unit(u)


## A ROOTED Mound Turtle is a wall of shell (the owner, 13:34: it closes a ramp like the Crown's wall): a ground unit of
## another side can't walk into its body; it is put back on its edge (it may slide round it where there is room). Its own
## side's creatures climb over the shell (as friends pass a gate). Flyers pass over.
static func push_out(g: Game, u: Unit, p: Vector2, before: Vector2) -> Vector2:
	if u.is_air() or u.kind == TURTLE:
		return p
	for w in g.nb_walls:
		if not is_instance_valid(w) or w.dead or w.team == u.team or g.allied(w.team, u.team):
			continue
		var r: float = w.radius + u.radius
		var d: Vector2 = p - w.position
		var dl := d.length()
		if dl >= r:
			continue
		if dl < 0.01:
			d = before - w.position
			dl = maxf(d.length(), 0.01)
		var out: Vector2 = w.position + d / dl * r
		# (put back on the rim; if that is in a cliff or a building, stay where it was)
		p = g.resolve_terrain(out, before, u.ground_r(), u.team)
		if p.distance_to(w.position) < r - 0.5:
			p = before
	return p


## Less damage while rooted (dug in): the root armour first, then a share off.
static func incoming(u: Unit, amount: float) -> float:
	if rooted(u) and ROOTERS.has(u.kind) and amount >= 1.0:
		return maxf(1.0, amount - float(Defs.NB["root_armor"])) * float(Defs.NB["root_taken"])
	return amount


static func on_death(g: Game, u: Unit) -> void:
	if u.nb.has("rs"):          # (dead already: busy() says no)
		BroodResearch.stop(g, u, "dead")     # (killed mid-research: lost, paid back as a building's queue)
	if u.kind == MAW:
		u.nb["dfood"] = float(u.nb.get("food", 0.0))      # (its death: swollen or thin)
		spill(g, u)        # (its food bursts out: hauling or rooted)
		_release(g, u)
	if u.kind == EGG:
		g.corpses.erase(u)
	g.nb_walls.erase(u)
	if BroodRoot.has_fp(u):
		BroodRoot.footprint_off(g, u)
	if u.team >= 0:
		recount(g, u.team)
		g.swamp_dirty = true
	if u.kind == QUEEN and g.mlog:
		g.mlog.add("%s's Brood Mother has fallen" % g.mlog.who(u.team))


# ------------------------------------------------------------------ grubs

## The food a grub can take: an own ROOTED Rootmaw with food in it or in its ground and room in its crew, or a pile.
static func free_source(g: Game, t: int, p: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in g.units:
		if u.dead:
			continue
		var ok := false
		if u.kind == MAW and u.team == t and rooted(u) and (float(u.nb.get("food", 0.0)) >= 1.0 or ground_left(g, u) >= 1.0):
			ok = true
		elif u.kind == PILE and float(u.nb.get("food", 0.0)) >= 1.0:
			ok = true
		if not ok or crew(g, u) >= crew_max(g, u):
			continue
		var dd: float = u.position.distance_to(p) + crew(g, u) * 40.0
		if dd < bd:
			bd = dd
			best = u
	return best


static func is_source(u: Entity) -> bool:
	return u is Unit and (u.kind == MAW or u.kind == PILE)


static func crew(g: Game, src: Unit) -> int:
	var n := 0
	for u in g.units:
		if u.kind == "grub" and not u.dead and u.order == "gather" and u.home_mine == src:
			n += 1
	return n


## A Rootmaw's crew grows with its distance from the Mother (as the old pits: +1 every PIT_CREW_STEP tiles beyond
## FOOD_NEAR, up to PIT_CREW_MAX); a pile takes a few.
static func crew_max(g: Game, src: Unit) -> int:
	if src.kind == PILE:
		return int(Defs.NB["pile_crew"])
	var q := queen(g, src.team)
	var dt := q.position.distance_to(src.position) / Defs.TILE if q else 0.0
	return mini(int(Defs.NB["maw_crew"]) + int(maxf(0.0, dt - Defs.FOOD_NEAR) / Defs.PIT_CREW_STEP), Defs.PIT_CREW_MAX)


## What a load from `src` is worth (Game.food_at: by the distance to the Mother and the ground between them).
static func load_value(g: Game, src: Unit, t: int) -> float:
	var q := queen(g, t)
	if q == null:
		return 0.0
	var dt := q.position.distance_to(src.position) / Defs.TILE
	var gap := maxf(0.0, dt - (q.radius + src.radius) / Defs.TILE)
	return Game.food_at(dt, gap)


## WORKER COUNT (the owner, 21:28): over each of your rooted Rootmaws (and each food pile, nobody's, while you play the
## Brood) "GRUBS 4/6": drawn with the other workers' labels (WorkerLabels, scripts/worker_labels.gd).
## "4/6": its grubs at work / the most it takes ("spent" when its ground and body are empty and nobody is on it).
static func crew_label(g: Game, u: Unit) -> String:
	var have := crew(g, u)
	if have == 0 and float(u.nb.get("food", 0.0)) < 1.0 and (u.kind == PILE or ground_left(g, u) < 1.0):
		return Loc.t("spent")
	return "%d/%d" % [have, crew_max(g, u)]


## Where its health bar sits, from its feet (Unit._draw_unit's `top`).
static func label_top(u: Unit) -> float:
	if u._nb_top > -9000.0:
		return u._nb_top          # (over its body as drawn: Unit._draw)
	return -float(ArtData.UNITS[u.art]["anchor"].y) * float(u.d.get("art_scale", 1.0)) - 4.0


## Where a grub stands to take food: by the Rootmaw's flank (its left side as it faces south-east), spread out.
static func flank_point(g: Game, src: Unit, gr: Unit) -> Vector2:
	var i := (gr.serial % 7) - 3
	var base := src.position + Vector2(-src.radius - 6.0, -2.0) if src.kind == MAW else src.position
	if src.kind == MAW and BroodRoot.has_fp(src):
		var r := BroodRoot.rect_of(src)
		base = Vector2(r.position.x - 7.0, r.get_center().y + 6.0)       # (rooted: just outside its footprint, at its flank)
	return base + Vector2(float(i) * 2.0, float(i) * 5.0)


## Where a grub carrying food walks to: the NEAREST point of the Mother (the owner, 2026-10-30: her back or any side,
## not round to her front). Rooted: just outside the nearest edge of her footprint; up: her body's rim on its side.
static func deposit_point(q: Unit, gr: Unit) -> Vector2:
	if BroodRoot.has_fp(q):
		return q.game.approach_point(q, gr.position)       # (a free cell on her footprint's ring, the nearest)
	return q.position + (gr.position - q.position).normalized() * (q.radius + 6.0)


## A grub on a Rootmaw or a pile (Unit._gather): take a load at the flank, carry it to the Mother, back.
static func grub_tick(g: Game, gr: Unit, delta: float) -> Vector2:
	var src = gr.home_mine
	var bad: bool = src == null or not is_instance_valid(src) or src.dead or (src.kind == MAW and not rooted(src))
	if not bad and gr.carrying == 0 and float(src.nb.get("food", 0.0)) < 1.0 and (src.kind == PILE or ground_left(g, src) < 1.0):
		bad = true          # (spent: nothing in it and nothing left in its ground)
	if bad and gr.carrying == 0:
		gr._leave_mine()
		var alt := free_source(g, gr.team, gr.position)
		if alt:
			gr.cmd_gather(alt)
		else:
			gr.cmd_stop()
		return Vector2.ZERO
	match gr.work:
		"feeding":
			gr.facing = (src.position - gr.position).normalized()
			src.nb["hv"] = g.clock          # (being harvested: it moves, BroodNew.producing)
			gr.work_t -= delta
			if gr.work_t <= 0.0:
				var v := load_value(g, src, gr.team)
				var have := float(src.nb.get("food", 0.0))
				if have < minf(v, 1.0):
					gr.work_t = 0.5          # (the Rootmaw is drinking: wait for it to fill)
					return Vector2.ZERO
				var take := minf(v, have)
				src.nb["food"] = have - take
				gr.load_f = take
				gr.carrying = maxi(1, int(round(take)))
				if gr.team == g.human:
					Sfx.play("brood/grub_take", gr.position, -8.0)     # (a small squish: all game long, so quiet)
				gr.work = "to_hall"
				gr.path = PackedVector2Array()
			return Vector2.ZERO
		"to_hall":
			var q := queen(g, gr.team)
			if q == null:
				return Vector2.ZERO
			# (or at the end of a path that could get no nearer, close to her: the nearest edge it can reach, the owner
			# 2026-10-31, her rim shut off by the creatures rooted round her)
			var ended: bool = not gr.path_pending and not gr.path.is_empty() and gr.path_i >= gr.path.size() \
					and q.edge_distance(gr.position) < 3.0 * Defs.TILE
			if q.edge_distance(gr.position) < gr.radius + 17.0 or ended:
				g.add_gold_f(gr.team, gr.load_f)
				if gr.carrying > 0:
					g.own_float(gr.team, gr.position + Vector2(0, -26), "+%d" % gr.carrying, Color(0.75, 1.0, 0.4))
				if gr.team == g.human and gr.carrying > 0:
					Sfx.play("work/grub_deliver", gr.position, -6.0)
				gr.carrying = 0
				gr.load_f = 0.0
				gr.work = "to_site"
				gr.path = PackedVector2Array()
				if bad:
					gr._leave_mine()
					gr.cmd_stop()
				return Vector2.ZERO
			if (gr.path.is_empty() or gr.path_i >= gr.path.size()) and not gr.path_pending:
				gr._request_path(deposit_point(q, gr))
			return gr._follow(delta)
	gr.work = "to_site"
	var at := flank_point(g, src, gr)
	if gr.position.distance_to(at) < 10.0 or src.edge_distance(gr.position) < gr.radius + 8.0:
		gr.work = "feeding"
		gr.work_t = Defs.PIT_TIME
		gr.path = PackedVector2Array()
		return Vector2.ZERO
	if (gr.path.is_empty() or gr.path_i >= gr.path.size()) and not gr.path_pending:
		gr._request_path(at)
	return gr._follow(delta)


# ------------------------------------------------------------------ pictures

static func anim(u: Unit, moving: bool) -> String:
	match u.kind:
		EGG:
			if u.nb.has("out") or (int(u.nb.get("fert", 0)) != 1 and egg_time(String(u.nb.get("k", "grub"))) - float(u.nb.get("t", 0.0)) <= HATCH_IN):
				return "hatch"
			return "idle"
		PILE:
			return "idle"
		QUEEN, MAW, TURTLE, FATHER, DILO, PTERO:
			var fr: Dictionary = ArtData.UNITS[u.art]["frames"]
			if u.nb.has("coc"):
				if BroodRoot.lure_phase(u) == "settle" and fr.has("root_se"):
					return "root"           # (a Sire just come to his lure: he settles on his nest, BroodRoot.lure_look)
				return "fill1" if fr.has("fill1_se") else "rooted"        # (in its cocoon: BroodRoot.cocoon_look)
			if u.kind == QUEEN and float(u.nb.get("devour", 0.0)) > 0.0:
				return "attack"         # (SACRIFICE: she devours the creature offered up)
			if u.tesla_mode == "deploying":
				return "root" if fr.has("root_se") else "rooted"      # (no rooting frames: the rooted frame, cross-faded: animate)
			if u.tesla_mode == "packing":
				return "uproot" if fr.has("uproot_se") else "rooted"
			if u.tesla_mode == "deployed":
				if u.kind == QUEEN and float(u.nb.get("lay_t", 0.0)) > 0.0 and fr.has("lay_se"):
					return "lay"
				if u.kind == MAW:
					var lv := "fill%d" % maw_level(u)
					return lv if fr.has(lv + "_se") else "fill"
				return "rooted"
			if u.phase != "":
				return "attack"
			if u.kind == MAW and float(u.nb.get("food", 0.0)) > 0.5:
				return ("haul" if ArtData.UNITS[MAW]["frames"].has("haul_se") else "walk") if moving else ("haul" if ArtData.UNITS[MAW]["frames"].has("haul_se") else "idle")
			return "walk" if moving else "idle"
	return "walk" if moving else "idle"


static func death_anim(u: Unit) -> String:
	if u.kind == MAW and float(u.nb.get("food", 0.0)) + float(u.nb.get("dfood", 0.0)) > float(Defs.NB["maw_cap"]) * 0.4:
		return "death_full"
	return "death"


## After Unit._animate picked the strip and stepped the frame: frames that follow the state, not the clock.
static func animate(u: Unit, n: int) -> void:
	var s := u.sprite
	if ROOTERS.has(u.kind):
		BroodRoot.layer(u)        # (rooted: the building layer; up, or dead: a unit again)
	if u.dead:
		if is_father(u.kind):
			BroodRoot.lure_dead(u)       # (a lure killed: it bursts)
		return
	match u.anim:
		"root", "uproot":
			if BroodRoot.is_lure(u):
				# come to his lure, he settles on his nest: his rooting frames from Defs.NB "lure_settle_from"
				var f0 := int((Defs.NB["lure_settle_from"] as Dictionary).get(u.kind, 0))
				s.frame = clampi(f0 + int(BroodRoot.settle_f(u) * float(n - f0)), 0, n - 1)
			else:
				var sw := u.switch_time()
				var p := clampf(1.0 - u.tesla_t / maxf(sw, 0.01), 0.0, 1.0)
				s.frame = clampi(int(p * n), 0, n - 1)
		"lay":
			var el := lay_time(u) - float(u.nb.get("lay_t", 0.0))
			var fi := 0
			while fi < n - 1 and fi < LAY_DUR.size() and el >= float(LAY_DUR[fi]):
				el -= float(LAY_DUR[fi])
				fi += 1
			s.frame = fi
		"fill":
			# the Rootmaw's 6 food levels
			s.frame = clampi(maw_level(u) - 1, 0, n - 1)
		"idle":
			if u.kind == PILE:
				# fresh to rotted: by the share taken or rotted away, the rot counting more (it darkens the pile)
				var start := maxf(float(u.nb.get("start", u.nb.get("food", 1.0))), 1.0)
				var gone := 1.0 - clampf(float(u.nb.get("food", 0.0)) / start, 0.0, 1.0)
				var rotted := clampf(float(u.nb.get("rot", 0.0)) / start, 0.0, 1.0)
				s.frame = clampi(int(gone * float(n) + rotted * 1.5), 0, n - 1)
		"hatch":
			# cracking before the creature is out, the open shell breaking apart after
			var k := String(u.nb.get("k", "grub"))
			var p2: float
			if u.nb.has("out"):
				p2 = 0.4 + 0.6 * clampf(float(u.nb["out"]) / HATCH_OUT, 0.0, 1.0)
			else:
				p2 = 0.4 * clampf(1.0 - (egg_time(k) - float(u.nb.get("t", 0.0))) / HATCH_IN, 0.0, 1.0)
			s.frame = clampi(int(p2 * n), 0, n - 1)
	if u.kind == EGG:
		# (the father's eggs lie in front of him, seen as the Mother's: the owner, 18:31)
		s.visible = float(u.nb.get("hold", 0.0)) <= 0.0
		var dr := float(u.nb.get("drop", 0.0))
		s.position = Vector2(0.0, -46.0 * pow(dr / float(Defs.NB["drop"]), 2.0)) if dr > 0.0 else Vector2.ZERO
		var pp := float(u.nb.get("pop", 0.0))
		if pp > 0.0:
			var k2 := pp / POP_TIME          # (1 at her clutch .. 0 on the rim)
			s.position = Vector2(float(u.nb.get("pop_x", 0.0)), float(u.nb.get("pop_y", 0.0))) * k2 + Vector2(0.0, -POP_ARC * sin(PI * k2))
			if u.nb.has("hold"):
				s.scale = Vector2.ONE * lerpf(1.0, LAY_EGG_BIG * float(u.nb.get("big", 1.0)), k2)       # (as big as her frame drew it, shrinking as it rolls out)
		elif u.nb.has("hold"):
			s.scale = Vector2.ONE
		# A SIRE'S EGG TAKES HIS LURE'S COLOUR, FAINTLY (the owner, 20:09; code, the sheet's egg is the plain
		# yellow-green one): it takes it as he breathes on it, and keeps it until it hatches (egg_tint)
		var red := egg_tint(u)
		if absf(red - float(u.nb.get("tinted", 0.0))) > 0.04 or (red == 0.0) != (float(u.nb.get("tinted", 0.0)) == 0.0):
			u.nb["tinted"] = red
			var ec := egg_col(String(u.nb.get("k", "grub")))
			(s.material as ShaderMaterial).set_shader_parameter("wash", Color(ec, float(Defs.NB["egg_wash"]) * red))
	# HAUL without its own sheet yet: the walk, the body swollen (code; docs/art_style_inconsistency.md)
	if u.kind == MAW and u.tesla_mode == "packed" and not ArtData.UNITS[MAW]["frames"].has("haul_se"):
		var f3 := clampf(float(u.nb.get("food", 0.0)) / float(Defs.NB["maw_cap"]), 0.0, 1.0)
		var sx := 1.0 + 0.22 * f3
		s.scale = Vector2(sx * signf(s.scale.x) if s.scale.x != 0.0 else sx, 1.0 + 0.3 * f3)
	elif u.kind == MAW:
		s.scale = Vector2(signf(s.scale.x) if s.scale.x != 0.0 else 1.0, 1.0)
	if ROOTERS.has(u.kind):
		_rooted_look(u, n)
		BroodRoot.cocoon_look(u)


## Rooted, is it working (the owner, 19:19: a rooted creature animates only while producing or being harvested; else
## it holds its loop's first frame)? The Mother laying, growing, or her laying timer running with room in the clutch;
## the Tyrannosaur fertilising; a Rootmaw drinking its ground or being harvested at its flank; the turtle never.
static func producing(g: Game, u: Unit) -> bool:
	match u.kind:
		QUEEN:
			return float(u.nb.get("lay_t", 0.0)) > 0.0 or float(u.nb.get("grow_t", 0.0)) > 0.0 or int(u.nb.get("eggs", 0)) < eggs_max(u)
		FATHER, DILO, PTERO:
			# (the owner, 21:28: he keeps his fertilising loop while any warrior egg is in his nest or near him waiting for
			# him, until the last one has hatched; only then still)
			return fertilising(u) or father_busy(g, u) or BroodResearch.busy(u)      # (researching: his loop keeps playing)
		MAW:
			if g.clock - float(u.nb.get("hv", -99.0)) < 1.5:
				return true
			return rooted(u) and not bool(u.nb.get("dry", false)) and ground_left(g, u) >= 1.0 and float(u.nb.get("food", 0.0)) < float(Defs.NB["maw_cap"]) - 0.5
	return false


## A Rootmaw's food level, 1 (thin) to 6 (full): the frame of its fill strip, or its breathing strip fill1..fill6.
static func maw_level(u: Unit) -> int:
	var f := clampf(float(u.nb.get("food", 0.0)) / float(Defs.NB["maw_cap"]), 0.0, 1.0)
	return 1 + clampi(int(round(f * 5.0)), 0, 5)


## A rooted creature is a building, and every building moves (the owner, 15:45). Until each has its own drawn loop:
##  - BREATHING: a still rooted frame (the Tyrannosaur's nest, a Rootmaw's food levels) rises and falls slowly, a small
##    vertical squash and stretch about the feet (BREATH: period s, height share);
##  - GLOW: the food, eggs and breath (glow_<strip>, the importer's mask of the frame's glowing pixels) pulse, added on
##    (the Tyrannosaur's fire flickers);
##  - a creature without rooting frames (the Tyrannosaur until his nest sheet comes) cross-fades from standing to
##    rooted and back.
## (code: docs/art_style_inconsistency.md)
const BREATH := {"period": 2.6, "rise": 0.022}


static func _rooted_look(u: Unit, n: int) -> void:
	var s := u.sprite
	var clk: float = u._bob_t + float(u.serial % 17) * 0.37
	var a := u.anim
	var still := (a == "rooted" or a == "fill") and n <= 1 or a == "fill"
	var sx := signf(s.scale.x) if s.scale.x != 0.0 else 1.0
	# IDLE STILLNESS (the owner, 19:19): rooted and not producing (BroodNew.producing), it holds its loop's first frame:
	# no breathing, no pulse
	var idle: bool = (u.tesla_mode == "deployed" and (a == "rooted" or a.begins_with("fill")) and (u.nb.has("coc") or not producing(u.game, u)))
	if a.begins_with("fill") and a != "fill" and n > 1:
		s.frame = 0 if idle else int(clk * 2.5) % n         # (a Rootmaw's drawn breathing at its food stage: a slow loop)
	elif idle and a == "rooted":
		s.frame = 0
	if still and not idle:
		var b := sin(clk * TAU / float(BREATH["period"]))
		s.scale = Vector2(sx * (1.0 - float(BREATH["rise"]) * 0.3 * b), 1.0 + float(BREATH["rise"]) * b)
	var lay := 0.0
	if u.kind == QUEEN and a == "rooted" and float(u.nb.get("lay_t", 0.0)) > 0.0:
		# laying, in code (no laying frames): a heave (up, then pressed down as the egg comes out, then settling) about the nest
		var lp := 1.0 - float(u.nb["lay_t"]) / LAY_TIME
		lay = sin(PI * lp)
		var hv := sin(TAU * lp) * (1.0 - lp)
		s.scale = Vector2(sx * (1.0 - 0.025 * hv), 1.0 + 0.06 * hv)
	if u.kind == QUEEN:
		# her growth stage: the sprite that much bigger, about her feet (until her stages are drawn)
		var k := float(stage_def(u)["scale"])
		var hx := absf(s.scale.x) if (still or lay > 0.0) else 1.0
		var hy := s.scale.y if (still or lay > 0.0) else 1.0
		s.scale = Vector2(sx * k * hx, k * hy)
	# the glow over its food, eggs or breath
	var gk := "glow_%s_%s" % [a, u.anim_dir]
	var glow := BroodRoot.pic_parent(u).get_node_or_null("Glow") as Sprite2D
	var has_glow: bool = ArtData.UNITS[u.art]["frames"].has(gk) and u.tesla_mode != "packed"
	if has_glow:
		if glow == null:
			glow = Sprite2D.new()
			glow.name = "Glow"
			glow.centered = false
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = cm
			BroodRoot.pic_parent(u).add_child(glow)
		var tx := Game.tex("res://assets/units/%s/%s.png" % [u.art, gk])
		if glow.texture != tx:
			glow.texture = tx
			glow.hframes = int(ArtData.UNITS[u.art]["frames"][gk])
		glow.offset = s.offset
		glow.scale = s.scale
		glow.position = s.position
		glow.frame = clampi(s.frame, 0, glow.hframes - 1)
		var pulse := 0.0 if idle else 0.5 + 0.5 * sin(clk * TAU / 2.2)
		var lo := 0.18
		var hi := 0.42
		if is_father(u.kind):
			if not idle:
				pulse = clampf(pulse * 0.75 + 0.25 * absf(sin(clk * 11.0 + sin(clk * 3.7) * 2.0)), 0.0, 1.0)     # (fire flickers)
			lo = 0.1          # (light: his fertilising loop is drawn, its six frames hardly differ)
			hi = 0.3
		elif a == "lay":
			lo = 0.08         # (her laying frames draw the clutch's glow themselves)
			hi = 0.2
		glow.modulate = Color(1, 1, 1, minf(1.0, (lo + hi * pulse + 0.6 * lay) * s.self_modulate.a))     # (laying: her clutch flares)
		glow.visible = true
	elif glow != null:
		glow.visible = false
	# standing to rooted (and back) without rooting frames: the two pictures cross-faded
	var xf := BroodRoot.pic_parent(u).get_node_or_null("Xf") as Sprite2D
	var fading := a == "rooted" and (u.tesla_mode == "deploying" or u.tesla_mode == "packing")
	if fading:
		var p := clampf(1.0 - u.tesla_t / maxf(u.switch_time(), 0.01), 0.0, 1.0)
		var shown := p if u.tesla_mode == "deploying" else 1.0 - p
		if xf == null:
			xf = Sprite2D.new()
			xf.name = "Xf"
			xf.centered = false
			xf.material = s.material
			var stx := Game.tex("res://assets/units/%s/idle_se.png" % u.art)
			xf.texture = stx
			var cell: Vector2i = ArtData.UNITS[u.art]["cell"]
			xf.offset = -Vector2(ArtData.UNITS[u.art]["anchor"]) - Vector2(0, stx.get_height() - cell.y)
			BroodRoot.pic_parent(u).add_child(xf)
			BroodRoot.pic_parent(u).move_child(xf, s.get_index() + 1)
		xf.visible = true
		xf.position = s.position
		xf.self_modulate.a = 1.0 - shown
		s.self_modulate.a = shown
	else:
		if xf != null:
			xf.visible = false
		if s.self_modulate.a < 1.0:
			s.self_modulate.a = 1.0


## Seconds to her next egg at her laying rate now (-1: none coming, her clutch is full or she is growing).
static func next_egg_in(q: Unit) -> float:
	if float(q.nb.get("grow_t", 0.0)) > 0.0 or int(q.nb.get("eggs", 0)) >= eggs_max(q):
		return -1.0
	var rate := maxf(float(q.nb.get("rate", 1.0)), 0.01)
	return maxf(0.0, (float(Defs.NB["egg_time"]) - float(q.nb.get("egg_t", 0.0))) / rate)


## Seconds until her clutch is full at her laying rate now (-1: none coming: full, or growing).
static func full_in(q: Unit) -> float:
	var nl := next_egg_in(q)
	if nl < 0.0:
		return -1.0
	var left := eggs_max(q) - int(q.nb.get("eggs", 0)) - 1          # (eggs after the next one)
	return nl + float(left) * float(Defs.NB["egg_time"]) / maxf(float(q.nb.get("rate", 1.0)), 0.01)


## mm:ss, or (short = true, under 10 s) tenths of a second: "3.5s".
static func clock_text(t: float, short: bool) -> String:
	if short and t < 10.0:
		return "%.1fs" % maxf(t, 0.0)
	var sec := int(ceil(t))
	return "%02d:%02d" % [sec / 60, sec % 60]


## Over the creature (Unit._draw_unit, its own space): the Mother's eggs, a Rootmaw's food and ground, an egg's
## incubation, the father's reach when picked.
static func draw(u: Unit, top: float) -> void:
	var g := u.game
	var mine := u.team == g.human or g.demo or g.spectating()
	if u.kind == QUEEN and mine:
		var font := ThemeDB.fallback_font
		# and the countdown to her next egg (the owner, 2026-10-30): none when her clutch is full or she is growing
		# (the owner, 09:27: always the time to her FULL clutch too, at any rate; her next egg in tenths of a second
		# once it comes within 10 s: "4/10  3.5s · 00:36"). The text and where it is: EggTip (its hover tooltip).
		var txt := EggTip.label_text(u)
		u.draw_string_outline(font, Vector2(EggTip.X, top - 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, EggTip.SIZE, 4, Color(0, 0, 0, 0.8))
		u.draw_string(font, Vector2(EggTip.X, top - 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, EggTip.SIZE, Color(0.85, 1.0, 0.55) if int(u.nb.get("eggs", 0)) > 0 else Color(1.0, 0.55, 0.45))
	if u.kind == MAW and mine:
		var bw := u.radius * 2.4
		var f := clampf(float(u.nb.get("food", 0.0)) / float(Defs.NB["maw_cap"]), 0.0, 1.0)
		var y := top + 6.0
		u.draw_rect(Rect2(-bw * 0.5, y, bw, 3).grow(0.5), Color(0, 0, 0, 0.6))
		u.draw_rect(Rect2(-bw * 0.5, y, bw * f, 3), Color(0.75, 0.9, 0.25))
		if rooted(u) and bool(u.nb.get("dry", false)):
			var font := ThemeDB.fallback_font
			u.draw_string_outline(font, Vector2(-14, y + 16), Loc.t("dry"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
			u.draw_string(font, Vector2(-14, y + 16), Loc.t("dry"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.6, 0.4))
		if u.selected and rooted(u):
			var gl := ground_left(g, u) / float(Defs.PIT_GROUND)
			u.draw_rect(Rect2(-bw * 0.5, y + 4.5, bw, 2).grow(0.5), Color(0, 0, 0, 0.6))
			u.draw_rect(Rect2(-bw * 0.5, y + 4.5, bw * gl, 2), Color(0.55, 0.4, 0.25))
	if u.selected and u.kind == MAW and u.team == g.human:
		u.draw_arc(Vector2.ZERO, float(Defs.PIT_CLAIM) * Defs.TILE, 0, TAU, 48, Color(0.75, 0.9, 0.3, 0.45), 1.5)
	# (the father's range round the Mother: the game's overlay draws it, BroodRoot.draw_overlay)
	# (rooted = a building: its footprint outlined when selected, as a building's, UNDER its pictures: BroodRoot._draw_frame)
	if u.selected and mine and u.kind == QUEEN and BroodRoot.fixed(u):
		var wp := BroodRoot.worker_rally_of(u)
		if wp != Vector2.INF:
			# her WORKER rally (gold, as a Hive's worker rally)
			u.draw_dashed_line(Vector2(0, -12), wp - u.position, Color(1, 0.85, 0.3, 0.6), 2.0, 6.0)
			u.draw_circle(wp - u.position, 4.5, Color(1, 0.85, 0.3, 0.95))
	if u.selected and mine and (BroodRoot.fixed(u)):
		var rp := BroodRoot.rally_of(u)
		if u.kind == EGG and bool(u.nb.get("nest", false)) and not u.nb.has("ro"):
			rp = BroodRoot.hatch_rally(g, u)
		if rp != Vector2.INF:
			# its RALLY POINT (as a building's: a dashed line and a dot)
			u.draw_dashed_line(Vector2(0, -12), rp - u.position, Color(0.4, 1, 0.4, 0.65), 2.0, 8.0)
			u.draw_circle(rp - u.position, 4.5, Color(0.4, 1, 0.4, 0.95))
			u.draw_line(rp - u.position, rp - u.position + Vector2(0, -18), Color(0.4, 1, 0.4, 0.95), 2.0)
			u.draw_colored_polygon(PackedVector2Array([rp - u.position + Vector2(0, -18), rp - u.position + Vector2(11, -14), rp - u.position + Vector2(0, -10)]), Color(0.4, 1, 0.4, 0.95))
	if ROOTERS.has(u.kind) and not u.nb.has("coc"):
		# her GROWING (as a hall's upgrade: a violet bar and its label), ROOTING / UPROOTING: a bar over it; RESEARCHING
		# only to its own side and allies (an enemy sees only his loop: the owner, 20:09)
		var pg := bar_over(g, u)
		if not pg.is_empty():      # (the father's nest and the eggs have their own)
			var font3 := ThemeDB.fallback_font
			var bw3 := maxf(60.0, look_r(u) * 2.0)
			var y3 := top - 26.0 if u.kind == QUEEN else top - 10.0
			u.draw_rect(Rect2(-bw3 * 0.5, y3, bw3, 5).grow(1.0), Color(0, 0, 0, 0.7))
			u.draw_rect(Rect2(-bw3 * 0.5, y3, bw3 * float(pg["f"]), 5), pg["col"])
			var lt := Loc.t(String(pg["label"]))
			var lw := font3.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			u.draw_string_outline(font3, Vector2(-lw * 0.5, y3 - 4.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
			u.draw_string(font3, Vector2(-lw * 0.5, y3 - 4.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, (pg["col"] as Color).lightened(0.3))
	if u.nb.has("coc") and mine:
		# the cocoon's morph, as a building going up
		var cp := clampf(float(u.nb["coc"]) / maxf(BroodRoot.cocoon_time(u), 0.1), 0.0, 1.0)
		var cr := BroodRoot.rect_of(u)
		var by := cr.end.y - u.position.y + 6.0
		var cw := cr.size.x * 0.7
		u.draw_rect(Rect2(-cw * 0.5 + cr.get_center().x - u.position.x, by, cw, 4).grow(0.5), Color(0, 0, 0, 0.6))
		u.draw_rect(Rect2(-cw * 0.5 + cr.get_center().x - u.position.x, by, cw * cp, 4), Color(0.85, 0.75, 0.35))
	if is_father(u.kind) and mine and rooted(u) and not BroodResearch.busy(u):
		# his nest's queue, as a Barracks': the eggs in it, the first one's breath or incubation (researching: its bar)
		var eggs := nest_eggs(g, u)
		var font2 := ThemeDB.fallback_font
		var near := father_near(g, u.team, u.kind)
		var txt2 := (Loc.t("%d eggs") % eggs.size()) if near else Loc.t("too far from the Mother")
		u.draw_string_outline(font2, Vector2(-30, top - 6), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		u.draw_string(font2, Vector2(-30, top - 6), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.45) if near else Color(1.0, 0.5, 0.4))
		if not eggs.is_empty():
			var e0: Unit = eggs[0]
			var fr2 := 0.0
			if int(e0.nb.get("fert", 0)) == 1:
				fr2 = float(e0.nb.get("redden", 0.0))
			else:
				fr2 = float(e0.nb.get("t", 0.0)) / egg_time(String(e0.nb.get("k", "grub")))
			u.draw_rect(Rect2(-30, top - 2, 60, 3).grow(0.5), Color(0, 0, 0, 0.6))
			u.draw_rect(Rect2(-30, top - 2, 60 * clampf(fr2, 0.0, 1.0), 3), Color(1.0, 0.45, 0.3))
	if u.kind == EGG and mine and not bool(u.nb.get("nest", false)):
		var k := String(u.nb.get("k", "grub"))
		var fr := 0.0
		var col := Color(0.85, 1.0, 0.45)
		if int(u.nb.get("fert", 0)) == 1:
			fr = float(u.nb.get("wait", 0.0)) / float(Defs.NB["fert_wait"])
			col = Color(1.0, 0.6, 0.35)       # (waiting for the father: a grub when this runs out)
		else:
			fr = float(u.nb.get("t", 0.0)) / egg_time(k)
		u.draw_rect(Rect2(-9, -24, 18, 2).grow(0.5), Color(0, 0, 0, 0.6))
		u.draw_rect(Rect2(-9, -24, 18 * clampf(fr, 0.0, 1.0), 2), col)


## The key the egg's picture changes on (Unit._draw_key): progress and state.
static func draw_key(u: Unit) -> int:
	var x := 0
	if u.nb.has("rx"):
		x += (int(float(u.nb["rx"])) * 7 + int(float(u.nb["ry"])) * 13) % 997 + 1      # (its rally moved)
	if u.nb.has("wx"):
		x += (int(float(u.nb["wx"])) * 11 + int(float(u.nb["wy"])) * 5) % 991 + 3      # (her worker rally moved)
	if u.nb.has("coc"):
		x += (int(float(u.nb["coc"]) * 2.0) % 200) * 1009          # (the cocoon's bar)
	if u.tesla_mode == "deploying" or u.tesla_mode == "packing":
		x += int(u.tesla_t * 8.0) * 4099             # (the rooting bar)
	if float(u.nb.get("grow_t", 0.0)) > 0.0:
		x += int(float(u.nb["grow_t"]) * 4.0) * 7919         # (her growing bar)
	if u.nb.has("rs"):
		x += int(float(u.nb.get("rs_t", 0.0)) * 4.0) * 6007 + 13         # (its research bar)
	return x + _draw_key2(u)


static func _draw_key2(u: Unit) -> int:
	match u.kind:
		EGG:
			return int(u.nb.get("fert", 0)) * 1000 + int(float(u.nb.get("t", 0.0)) * 4.0) + int(float(u.nb.get("wait", 0.0)) * 4.0) * 7
		MAW:
			return int(float(u.nb.get("food", 0.0)) / 6.0) + (100000 if u.nb.has("spot") else 0)
		QUEEN:
			return int(u.nb.get("eggs", 0)) + int(float(u.nb.get("grow_t", 0.0))) * 31
		FATHER, DILO, PTERO:
			return int(u.game.clock * 4.0) if rooted(u) else 0       # (his nest's queue and its progress)
	return 0


# ------------------------------------------------------------------ saved games

## A creature's own state as plain values (the father's egg in hand is not kept: he looks again).
static func unit_save(u: Unit) -> Dictionary:
	var out := {}
	for k in u.nb:
		var v = u.nb[k]
		if v is Object:
			continue
		out[k] = v
	return out


static func unit_load(u: Unit, d: Dictionary) -> void:
	u.nb = d.duplicate()
	for k in ["spot", "fert", "eggs", "laid", "eggp", "hvet"]:
		if u.nb.has(k):
			u.nb[k] = int(u.nb[k])
	u.nb["m"] = u.tesla_mode
	u.nb.erase("tinted")          # (a fresh sprite: the egg's red is put on again)
	u.nb.erase("redden")
	for k in ["fpx", "fpy"]:
		if u.nb.has(k):
			u.nb[k] = int(u.nb[k])
	if ROOTERS.has(u.kind) and u.tesla_mode != "packed":
		BroodRoot.footprint_on(u.game, u, false)      # (its ground on the grid again; an older save's rooted creature takes it now)
	if ROOTERS.has(u.kind):
		u.nb_mass = 1000.0 if u.tesla_mode != "packed" else packed_mass(u.kind)
	for k in ["stage"]:
		if u.nb.has(k):
			u.nb[k] = int(u.nb[k])
	if u.kind == QUEEN:
		apply_stage(u)
	if u.nb.has("swr"):
		u.nb["swr"] = float(u.nb["swr"])
	elif (u.kind == QUEEN or u.kind == TURTLE) and rooted(u):
		u.nb["swr"] = swamp_full(u)         # (an older save: its swamp was there in full)
	set_sky(u)          # (a Pterodactyl landed on his nest is on the ground)
	if u.kind == EGG and not u.nb.has("out"):
		u.z_index = EGG_Z
	if u.kind == EGG and RETIRED_EGGS.has(String(u.nb.get("k", ""))):
		# an older save's egg of a retired kind (0.21.0: the Skywing, the Storm Sire's stand-in) holds that line's young
		# now (its price was paid; the young it holds is fixed when laid: a plain clutch)
		u.nb["k"] = RETIRED_EGGS[String(u.nb["k"])]
		u.nb.erase("n")


## Eggs of a kind no longer laid hatch as this (docs/storm_line.md): the Storm Sire's Skywing stand-in -> his Hatchlings.
const RETIRED_EGGS := {"skywing": "hatchlings"}


static func save(g: Game) -> Dictionary:
	var spots := []
	for id in g.nb_spots:
		var s: Dictionary = g.nb_spots[id]
		spots.append([int(id), (s["p"] as Vector2).x, (s["p"] as Vector2).y, float(s["left"]), int(s.get("maw", 0))])
	# the swamp as it lies (a receding one keeps receding after a load; the growing radii are each source's nb "swr")
	var sw := []
	for t in g.swamp.size():
		var grid: PackedByteArray = g.swamp[t]
		sw.append(Marshalls.raw_to_base64(grid.compress(FileAccess.COMPRESSION_DEFLATE)) if grid.find(1) >= 0 else "")
	return {"spots": spots, "next": g.nb_spot_next, "swamp": sw}


static func load(g: Game, d: Dictionary) -> void:
	g.nb_spots.clear()
	for s in d.get("spots", []):
		g.nb_spots[int(s[0])] = {"p": Vector2(float(s[1]), float(s[2])), "left": float(s[3]), "maw": int(s[4])}
	g.nb_spot_next = int(d.get("next", 0))
	var sw: Array = d.get("swamp", []) if d.get("swamp") is Array else []
	for t in mini(sw.size(), g.swamp.size()):
		if String(sw[t]) == "":
			continue
		var grid: PackedByteArray = Marshalls.base64_to_raw(String(sw[t])).decompress(Game.W * Game.H, FileAccess.COMPRESSION_DEFLATE)
		if grid.size() == Game.W * Game.H:
			g.swamp[t] = grid
	g.nb_queen.clear()
