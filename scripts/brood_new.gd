class_name BroodNew
extends RefCounted
## THE NEW BROOD (an experiment the player picks in the skirmish setup: "The Brood (new, experiment)", docs/brood_new.md).
## The owner's redesign (docs/idea_brood_mobile_buildings.md, 2026-10-28): no buildings, only creatures. Some of them ROOT
## into the ground (armour and less damage while rooted; uprooted they walk as units).
##  - THE BROOD MOTHER (kind "brood_mother"): the losing condition (kill her and that side is out). She roots and uproots,
##    HOARDS the food (grubs bring it to her), and ONLY she lays eggs, rooted or walking (each egg drops behind her).
##  - THE ROOTMAW ("rootmaw"): roots on fresh ground (a circle of Defs.PIT_CLAIM tiles holding Defs.PIT_GROUND food; rooted
##    circles may not overlap), drinks it into its body (it swells: 6 levels) and grubs carry the food from its flank to
##    the Mother (the farther, the more a trip pays: Game.food_at, as the old Feeding Pits). UPROOT spills its food as a
##    pile on the ground (grubs still collect it, it rots slowly); HAUL uproots it full and it walks at half speed with
##    it (killed while hauling, all of it bursts out as a pile; rooted again, it keeps it).
##  - THE TYRANNOSAUR ("tyrannosaur"), a FATHER: ROOTED he is the Brood's "barracks" (the owner, 15:45): he settles on
##    a nest, head lowered, breathing fire-gold on it (his concept's FERTILISING figure). Rooted within Defs.NB
##    "father_r" of the Mother, her warrior eggs roll into his nest (they are the red eggs drawn there, counted over him
##    like a Barracks' queue); he fertilises them one at a time and they hatch there. Uprooted he walks and fights.
##    Unfertilised eggs hatch as grubs; eggs already fertilised still hatch.
##  - EGGS ("brood_egg") and FOOD PILES ("food_pile", nobody's) are units that stand still.
## The old Brood (buildings) is untouched and stays the default: everything here only runs for a side whose slot picked
## the experiment (Game.nb_teams[t]).

const QUEEN := "brood_mother"
const MAW := "rootmaw"
const TURTLE := "mound_turtle"
const FATHER := "tyrannosaur"
const EGG := "brood_egg"
const PILE := "food_pile"
const KINDS := [QUEEN, MAW, TURTLE, FATHER, EGG, PILE]
const ROOTERS := [QUEEN, MAW, TURTLE, FATHER]     # (the creatures that ROOT and UPROOT)
const SE := Vector2(0.7071, 0.7071)


static func on(g: Game, t: int) -> bool:
	return t >= 0 and t < g.nb_teams.size() and bool(g.nb_teams[t])


static func is_nb(k: String) -> bool:
	return KINDS.has(k)


## What the Mother's card offers, in order (the warriors need the father beside her).
static func hatch_list() -> Array:
	return ["grub", MAW, TURTLE, FATHER] + (Defs.NB["lines"][FATHER] as Array)


## The father a warrior needs ("" for none: grubs, Rootmaws, the Tyrannosaur itself).
static func father_of(k: String) -> String:
	for f in Defs.NB["lines"]:
		if (Defs.NB["lines"][f] as Array).has(k):
			return f
	return ""


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


static func rooted(u: Unit) -> bool:
	return u.tesla_mode == "deployed"


static func father(g: Game, t: int) -> Unit:
	for u in g.units:
		if u.team == t and u.kind == FATHER and not u.dead:
			return u
	return null


## The father rooted on his nest within his reach of the Mother (only then are her warrior eggs fertilised).
static func father_near(g: Game, t: int) -> bool:
	var f := father(g, t)
	var q := queen(g, t)
	return f != null and q != null and rooted(f) and f.position.distance_to(q.position) <= float(Defs.NB["father_r"]) * Defs.TILE


static func count_of(g: Game, t: int, k: String) -> int:
	var n := 0
	for u in g.units:
		if u.team == t and not u.dead and (u.kind == k or (u.kind == EGG and String(u.nb.get("k", "")) == k)):
			n += 1
	return n


# ------------------------------------------------------------------ the start

## A new-Brood side's start: the Mother where the hall would stand, one Rootmaw on fresh ground behind her, the grubs.
## Both play the end of their rooting (a cue that they are dug in).
static func start(g: Game, t: int, cell: Vector2i) -> void:
	var size: Vector2i = Defs.BUILDINGS["hive"]["size"]
	var c := (Vector2(cell) + Vector2(size) * 0.5) * Defs.TILE
	var q := g._add_unit(QUEEN, t, c)
	q.facing = SE
	q.nb["eggs"] = int(Defs.NB["start_eggs"])
	_start_rooting(q)
	var spot := _maw_start_spot(g, c)
	var m := g._add_unit(MAW, t, spot)
	m.facing = SE
	m.nb["food"] = float(Defs.NB["start_food"])       # (the first loads are ready: the grubs start at once)
	_claim(g, m)
	_start_rooting(m)
	var away := 80.0 if c.y < Game.H * Defs.TILE * 0.5 else -80.0
	for i in int(Defs.FACTIONS["brood"]["start_workers"]):
		var gr := g._add_unit("grub", t, c + Vector2(-60 + i * 30, away))
		gr.cmd_gather(m)
	g.players[t]["gold"] = Defs.START_GOLD
	recount(g, t)
	g.swamp_dirty = true


static func _start_rooting(u: Unit) -> void:
	u.tesla_mode = "deploying"
	u.tesla_t = float(Defs.NB["start_root"])
	u.nb["m"] = "deploying"


## Fresh ground beside the Mother (clear of her great body: about 8 to 10 tiles out), walkable round it, on her level,
## a little away from the map's middle (behind her, as the old starting pits were) but not off the edge of her ground.
static func _maw_start_spot(g: Game, c: Vector2) -> Vector2:
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var away := (c - mid).normalized() if c.distance_to(mid) > 1.0 else Vector2.DOWN
	var h := int(g.height[g.idx(g.cell_of(c))])
	var home := g.region_of(g.cell_of(c))
	var best := c + away * 64.0
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
			if room < 22:
				continue
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
		if u.kind == QUEEN:
			out.append([u.position / Defs.TILE, float(Defs.NB["queen_swamp"])])
		elif u.kind == TURTLE:
			out.append([u.position / Defs.TILE, float(Defs.NB["turtle_swamp"])])
	return out


## A Rootmaw roots and feeds on ANY swamp of its side (the owner, 13:40): the Mother's, a turtle's far away (a hidden
## base); it need not be joined to hers. Off the swamp (its turtle killed, the swamp shrunk back) it stops feeding.
static func on_swamp(g: Game, t: int, p: Vector2) -> bool:
	return t >= 0 and t < g.swamp.size() and g.on_swamp(t, p)


## Where the new Brood's grubs unload (food and cocoons) and creatures are offered up: the Mother.
static func dropoff(g: Game, t: int) -> Unit:
	return queen(g, t)


# ------------------------------------------------------------------ eggs

## The Mother's egg rate: every rooted Mound Turtle makes her lay 10% faster (up to 30%), as the old Clutch Mounds.
static func egg_rate(g: Game, t: int) -> float:
	var n := 0
	for u in g.units:
		if u.team == t and u.kind == TURTLE and not u.dead and rooted(u):
			n += 1
	return 1.0 + minf(float(Defs.NB["egg_rate"]) * n, float(Defs.NB["egg_rate_max"]))


## Why the Mother can't lay an egg for `k` now ("" = she can).
static func lay_problem(g: Game, q: Unit, k: String) -> String:
	if q == null or q.dead:
		return "No Brood Mother."
	if not hatch_list().has(k):
		return "Not in the new Brood yet."
	if int(q.nb.get("eggs", 0)) < 1:
		return "No eggs ready."
	var u: Dictionary = Defs.UNITS[k]
	var f := father_of(k)
	if f != "" and not father_near(g, q.team):
		return "Needs the %s rooted beside the Brood Mother." % Defs.UNITS[f]["name"]
	if k == FATHER and count_of(g, q.team, FATHER) > 0:
		return "Only one %s at a time." % u["name"]
	var price := g.unit_price(q.team, k)
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[q.team]["gold"]) < int(price[0]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[q.team]["res2"]) < float(price[1]):
		return "Not enough %s." % String(res[1]).to_lower()
	if g.supply_used(q.team) + int(u["supply"]) * int(u.get("spawn", 1)) > int(g.players[q.team]["cap"]):
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
	var p := q.position + back * (q.radius + 14.0) + side
	if rooted(q) or q.tesla_mode != "packed":
		# rooted, curled round her nest facing south-east: the eggs roll out in front of the nest's rim, south-west of her
		# middle, where they can be seen (behind her they lay under her great body)
		p = q.position + Vector2(-34.0 + float((n % 5) - 2) * 15.0, q.radius + 16.0 + float(n % 2) * 8.0)
	if not g._walkable(g.cell_of(p)):
		p = q.position + side * 0.3
	var fa: Unit = father(g, q.team) if father_of(k) != "" else null
	if fa != null and father_near(g, q.team):
		p = nest_point(fa)          # (a warrior's egg goes into the father's nest: fertilised and hatched there)
	var e := g._add_unit(EGG, q.team, p)
	e.nb = {"k": k, "t": 0.0, "fert": 1 if father_of(k) != "" else 0, "wait": 0.0, "drop": float(Defs.NB["drop"])}
	if fa == null and rooted(q):
		# LAYING in her nest (the owner, 16:24, as the Town Hall's bell; walking, the egg just drops behind her). With her
		# laying frames (brood_mother_rooted_lay_se_chatgpt.png) she lays it in the picture: the game's egg stays hidden
		# ("hold") until her last frame, appears exactly where that frame draws the new egg (LAY_EGG_AT, as big), then
		# rolls out to the nest's rim and waits; her rooted loop has no extra egg. Without them: a heave in code, her
		# clutch flaring, the egg popping out of the clutch (CLUTCH_AT).
		var drawn: bool = ArtData.UNITS[q.art]["frames"].has("lay_se")
		q.nb["lay_t"] = lay_time(q)
		var from := q.position + (LAY_EGG_AT if drawn else CLUTCH_AT) - p
		e.nb["pop_x"] = from.x
		e.nb["pop_y"] = from.y
		e.nb["pop"] = POP_TIME
		e.nb["drop"] = 0.0
		if drawn:
			e.nb["hold"] = lay_time(q)
	if fa != null and p == nest_point(fa):
		e.nb["nest"] = true
		e.nb["drop"] = 0.0
	e.facing = Vector2.DOWN
	if q.team == g.human:
		Sfx.play_any(["work/grub_deliver", "hatch"], p, -8.0)
	recount(g, q.team)
	return ""


## The rooted Mother's laying. Her sheet's 6 frames last LAY_DUR s each (the owner, 16:40: frames 3 and 4, her head
## reared high, a big jump from frame 2, held longer); the new egg in frame 6 is at LAY_EGG_AT from her feet (its
## bottom; tools/import_brood_new.py prints it), LAY_EGG_BIG times the game egg's size. Without the sheet: LAY_TIME s of
## heave in code; the egg flies from her clutch (CLUTCH_AT). Either way the egg then goes to the rim in POP_TIME s, over
## an arc POP_ARC px high.
const LAY_DUR := [0.14, 0.18, 0.3, 0.3, 0.18, 0.16]
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


## The hatching's two halves: HATCH_IN s before the creature comes out the egg cracks (the sheet's first hatch frames),
## then the creature stands on the open shell, which breaks apart and goes after HATCH_OUT s.
const HATCH_IN := 0.8
const RED_EGG := Vector3(1.75, 0.42, 0.26)      # (the shader tint of a fertilised egg: a strong red the yellow-green sheet turns into)
const HATCH_OUT := 0.9


static func _hatch(g: Game, e: Unit) -> void:
	var k := String(e.nb.get("k", "grub"))
	var t := e.team
	var at := e.position
	e.nb["out"] = 0.0          # (the shell stays a moment under the creature: egg_tick lets it go)
	e.z_index = -1
	e.selected = false
	g.selection.erase(e)
	var n := int(Defs.UNITS[k].get("spawn", 1))
	g.stats[t]["trained"] += n
	if g.mlog and not g._first_of.has("%d:%s" % [t, k]):
		g._first_of["%d:%s" % [t, k]] = true
		g.mlog.add("%s got its first %s" % [g.mlog.who(t), Defs.UNITS[k]["name"]])
	if t == g.human:
		Sfx.play("hatch", at)
		Sfx.voice(k, "select")
	for i in n:
		var off := Vector2.from_angle(TAU * i / maxf(1.0, n) + float(e.serial)) * (6.0 if n > 1 else 0.0)
		var u := g._add_unit(k, t, at + off)
		u.facing = Vector2.DOWN
		if k == "grub":
			var src := free_source(g, t, u.position)
			if src:
				u.cmd_gather(src)
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
			var was := g.unit_price(e.team, k)
			var now := g.unit_price(e.team, "grub")
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

## Where the eggs in a rooted father's nest lie (in front of his lowered head, on the nest drawn in his rooted frame,
## a little in front of his feet so a hatching shell is drawn over the nest).
const NEST_AT := Vector2(26.0, 2.0)
const NEST_LIFT := 8.0       # (an egg there is drawn this much higher: on the nest, but sorted in front of him)


static func nest_point(f: Unit) -> Vector2:
	return f.position + NEST_AT


## The eggs in his nest, first laid first (the queue counted over him).
static func nest_eggs(g: Game, f: Unit) -> Array:
	var out: Array = []
	for u in g.units_near(nest_point(f), 12.0):
		if u.team == f.team and u.kind == EGG and not u.dead and bool(u.nb.get("nest", false)) and not u.nb.has("out"):
			out.append(u)
	out.sort_custom(func(a, b) -> bool: return a.serial < b.serial)
	return out


## The rooted father: warrior eggs within his reach roll into his nest; he fertilises them one at a time (his breath
## drawn in the frame; the egg turns red, Defs.NB "fert_time" each); fertilised, they incubate and hatch in the nest.
static func father_tick(g: Game, f: Unit, delta: float) -> void:
	var egg = f.nb.get("fe")
	var on_nest := rooted(f)
	var q := queen(g, f.team)
	var r := float(Defs.NB["father_r"]) * Defs.TILE
	var near := on_nest and q != null and f.position.distance_to(q.position) <= r
	if egg != null and (not is_instance_valid(egg) or egg.dead or int(egg.nb.get("fert", 0)) != 1 or not near):
		if is_instance_valid(egg) and int(egg.nb.get("fert", 0)) == 1:
			egg.nb["redden"] = 0.0       # (broken off: it is yellow-green again until he is back on his nest)
		f.nb.erase("fe")
		f.nb["ft"] = 0.0
		egg = null
	if not near:
		return
	if egg == null:
		f.nb["scan"] = float(f.nb.get("scan", 0.0)) - delta
		if float(f.nb["scan"]) > 0.0:
			return
		f.nb["scan"] = 0.25
		# her warrior eggs left on the ground near him (laid before he rooted) roll into the nest
		for u in g.units_near(f.position, r):
			if u.team == f.team and u.kind == EGG and not u.dead and int(u.nb.get("fert", 0)) == 1 and not bool(u.nb.get("nest", false)):
				u.nb["nest"] = true
				u.nb["drop"] = 0.0
				u.position = nest_point(f)
				g.note_move(u)
		for u in nest_eggs(g, f):
			if int(u.nb.get("fert", 0)) == 1:
				egg = u
				break
		if egg == null:
			return
		f.nb["fe"] = egg
		f.nb["ft"] = float(Defs.NB["fert_time"])
	f.nb["ft"] = float(f.nb.get("ft", 0.0)) - delta
	egg.nb["redden"] = clampf(1.0 - float(f.nb["ft"]) / float(Defs.NB["fert_time"]), 0.0, 1.0)     # (it turns red as he breathes)
	if float(f.nb["ft"]) <= 0.0:
		egg.nb["fert"] = 2
		egg.nb["t"] = 0.0
		f.nb.erase("fe")
		if f.team == g.human:
			Sfx.play_any(["roar", "combat/brute_attack"], f.position, -10.0)


## The computer's Mother (and the defence test's): rooted at home. No rooted creature attacks (the owner, 15:58, 17:14):
## when enemies reach her (strike at her, or come within MOTHER_FIGHT tiles of her body) she uproots and fights, on a
## leash (MOTHER_LEASH tiles from her nest); once nothing has been at her for MOTHER_CALM s, she goes back and roots.
## st: the caller's own state (her nest, the calm time); dt: the time since the last call.
const MOTHER_FIGHT := 3.0
const MOTHER_LEASH := 7.0
const MOTHER_CALM := 4.0


static func mother_guard(g: Game, q: Unit, st: Dictionary, dt: float) -> void:
	if not st.has("home"):
		st["home"] = q.position
		st["calm"] = 0.0
	var home: Vector2 = st["home"]
	var foe: Unit = null
	var fd := INF
	for u in g.units_near(q.position, (MOTHER_FIGHT + 6.0) * Defs.TILE):
		if not g.hostile(u.team, q.team) or u.dead or u.off_field or u.is_air():
			continue
		var at_her: bool = u.target == q or q.edge_distance(u.position) < MOTHER_FIGHT * Defs.TILE
		var dd: float = u.position.distance_to(q.position)
		if at_her and dd < fd:
			fd = dd
			foe = u
	st["calm"] = 0.0 if foe != null else float(st["calm"]) + dt
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


## SACRIFICE at the Mother: she turns on the creature offered up and devours it (her swipe frames).
static func devour(q: Unit, u: Unit) -> void:
	if q.dead:
		return
	q.nb["devour"] = 0.65
	# each offering gives her one egg at once, on top of the essence (the owner, 17:20; none if her clutch is full)
	if int(q.nb.get("eggs", 0)) < int(Defs.NB["eggs_max"]):
		q.nb["eggs"] = int(q.nb.get("eggs", 0)) + 1
	if u.position.distance_to(q.position) > 1.0:
		q.facing = (u.position - q.position).normalized()
	q.frame_i = 0
	q.anim_t = 0.0
	Sfx.play_any(["combat/brute_attack", "bite"], q.position, -6.0)


static func fertilising(u: Unit) -> bool:
	return u.kind == FATHER and u.nb.get("fe") != null and is_instance_valid(u.nb.get("fe"))


# ------------------------------------------------------------------ ground (the Rootmaws' circles)

## Why a Rootmaw can't root here ("" = it can): its circle may not overlap another rooted Rootmaw's.
static func root_problem(g: Game, u: Unit) -> String:
	if u.kind != MAW:
		return ""
	if not on_swamp(g, u.team, u.position):
		return "A Rootmaw roots only on your swamp: root a Mound Turtle (or the Brood Mother) to spread it."
	var r := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	for o in g.units:
		if o != u and o.kind == MAW and not o.dead and o.tesla_mode != "packed" and o.position.distance_to(u.position) < r:
			return "Too close to another Rootmaw's ground: their circles may not overlap."
	return ""


## The Rootmaw takes its circle of ground: fresh (Defs.PIT_GROUND), or what is left of old ground it overlaps (the
## least of them: rooting beside spent ground can't refresh it, as the old pits).
static func _claim(g: Game, u: Unit) -> void:
	var r := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	var left := float(Defs.PIT_GROUND)
	var gone: Array = []
	for id in g.nb_spots:
		var s: Dictionary = g.nb_spots[id]
		if (s["p"] as Vector2).distance_to(u.position) < r and int(s.get("maw", 0)) == 0:
			left = minf(left, float(s["left"]))
			gone.append(id)
	for id in gone:
		g.nb_spots.erase(id)
	g.nb_spot_next += 1
	g.nb_spots[g.nb_spot_next] = {"p": u.position, "left": left, "maw": u.serial}
	u.nb["spot"] = g.nb_spot_next


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
		return why
	u.facing = SE
	if u.kind == MAW:
		_claim(g, u)
	return ""


## UPROOT (spill = true: a Rootmaw spills its food as a pile and walks off thin) or HAUL (it keeps it, walks slow).
static func uproot(u: Unit, spill: bool) -> void:
	if u.kind == MAW:
		u.nb["spill"] = spill
	u.cmd_pack()


static func spill(g: Game, u: Unit) -> void:
	var f := float(u.nb.get("food", 0.0))
	u.nb["food"] = 0.0
	if f < 1.0:
		return
	# onto a pile already lying here, else a new one (nobody's: any new-Brood grub may collect it)
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

## Each tick of a new-Brood creature (from Unit._tick_unit, after its speed is set).
static func tick(g: Game, u: Unit, delta: float) -> void:
	var m := String(u.nb.get("m", "packed"))
	if m != u.tesla_mode:
		_mode_changed(g, u, m)
		u.nb["m"] = u.tesla_mode
		if ROOTERS.has(u.kind):
			u.nb_mass = 1000.0 if u.tesla_mode != "packed" else packed_mass(u.kind)     # (dug in: not shoved)
	if rooted(u) and u.phase == "" and u.target == null and float(u.nb.get("devour", 0.0)) <= 0.0:
		u.facing = SE          # (rooted, it settles back facing south-east after a fight)
	match u.kind:
		QUEEN:
			if float(u.nb.get("devour", 0.0)) > 0.0:
				u.nb["devour"] = maxf(0.0, float(u.nb["devour"]) - delta)
			if float(u.nb.get("lay_t", 0.0)) > 0.0:
				u.nb["lay_t"] = maxf(0.0, float(u.nb["lay_t"]) - delta)
			if int(u.nb.get("eggs", 0)) < int(Defs.NB["eggs_max"]):
				u.nb["egg_t"] = float(u.nb.get("egg_t", 0.0)) + delta * egg_rate(g, u.team)
				if float(u.nb["egg_t"]) >= float(Defs.NB["egg_time"]):
					u.nb["egg_t"] = 0.0
					u.nb["eggs"] = int(u.nb.get("eggs", 0)) + 1
			if rooted(u) and u.hp < u.max_hp:
				u.hp = minf(u.max_hp, u.hp + float(Defs.NB["queen_regen"]) * delta)
		MAW:
			var food := float(u.nb.get("food", 0.0))
			u.nb["wet_t"] = float(u.nb.get("wet_t", 0.0)) - delta
			if float(u.nb["wet_t"]) <= 0.0:
				u.nb["wet_t"] = 0.5
				u.nb["dry"] = not on_swamp(g, u.team, u.position)      # (off the swamp: it stops feeding)
			if rooted(u) and u.nb.has("spot") and not bool(u.nb.get("dry", false)):
				var id := int(u.nb["spot"])
				if g.nb_spots.has(id):
					var s: Dictionary = g.nb_spots[id]
					var take := minf(minf(float(Defs.NB["maw_fill"]) * delta, float(s["left"])), float(Defs.NB["maw_cap"]) - food)
					if take > 0.0:
						s["left"] = float(s["left"]) - take
						u.nb["food"] = food + take
			elif not rooted(u) and food > 0.5:
				u.speed *= float(Defs.NB["haul_speed"])        # HAUL: full and slow
		FATHER:
			father_tick(g, u, delta)


## How hard a walking (uprooted) creature is to shove (Game.separation): the Mother a great deal; the Tyrannosaur and
## the Mound Turtle, huge heavy beasts, enough that the grubs streaming to the Mother flow round them instead of washing
## them back; the others as anyone.
static func packed_mass(k: String) -> float:
	return 30.0 if k == QUEEN else (8.0 if k == FATHER or k == TURTLE else 1.0)


static func _mode_changed(g: Game, u: Unit, was: String) -> void:
	match u.tesla_mode:
		"packing":
			if u.kind == FATHER:
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
			if u.kind == TURTLE:
				u.radius = float(Defs.NB["turtle_rooted_r"])       # (sunk into the mud, wide: it closes a ramp)
				if not g.nb_walls.has(u):
					g.nb_walls.append(u)
			if was == "packed" and u.kind == MAW and not u.nb.has("spot"):
				_claim(g, u)      # (rooted by any way other than the button: still takes its ground)
		"packed":
			if u.kind == TURTLE:
				u.radius = float(u.d["radius"])
				g.nb_walls.erase(u)
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
		p = g.resolve_terrain(out, before, u.radius, u.team)
		if p.distance_to(w.position) < r - 0.5:
			p = before
	return p


## Less damage while rooted (dug in): the root armour first, then a share off.
static func incoming(u: Unit, amount: float) -> float:
	if rooted(u) and ROOTERS.has(u.kind) and amount >= 1.0:
		return maxf(1.0, amount - float(Defs.NB["root_armor"])) * float(Defs.NB["root_taken"])
	return amount


static func on_death(g: Game, u: Unit) -> void:
	if u.kind == MAW:
		u.nb["dfood"] = float(u.nb.get("food", 0.0))      # (its death: swollen or thin)
		spill(g, u)        # (its food bursts out: hauling or rooted)
		_release(g, u)
	if u.kind == EGG:
		g.corpses.erase(u)
	g.nb_walls.erase(u)
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


## Where a grub stands to take food: by the Rootmaw's flank (its left side as it faces south-east), spread out.
static func flank_point(g: Game, src: Unit, gr: Unit) -> Vector2:
	var i := (gr.serial % 7) - 3
	var base := src.position + Vector2(-src.radius - 6.0, -2.0) if src.kind == MAW else src.position
	return base + Vector2(float(i) * 2.0, float(i) * 5.0)


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
				gr.work = "to_hall"
				gr.path = PackedVector2Array()
			return Vector2.ZERO
		"to_hall":
			var q := queen(g, gr.team)
			if q == null:
				return Vector2.ZERO
			if q.edge_distance(gr.position) < gr.radius + 17.0:
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
				gr._request_path(q.position + (gr.position - q.position).normalized() * (q.radius + 6.0))
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
		QUEEN, MAW, TURTLE, FATHER:
			var fr: Dictionary = ArtData.UNITS[u.art]["frames"]
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
	if u.dead:
		return
	match u.anim:
		"root", "uproot":
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
		# an egg in the father's nest is one of the red eggs drawn there: it shows itself only to hatch
		s.visible = (not bool(u.nb.get("nest", false)) or u.anim == "hatch") and float(u.nb.get("hold", 0.0)) <= 0.0
		var dr := float(u.nb.get("drop", 0.0))
		s.position = Vector2(0.0, -46.0 * pow(dr / float(Defs.NB["drop"]), 2.0)) if dr > 0.0 else Vector2.ZERO
		if bool(u.nb.get("nest", false)):
			s.position.y -= NEST_LIFT
		var pp := float(u.nb.get("pop", 0.0))
		if pp > 0.0:
			var k2 := pp / POP_TIME          # (1 at her clutch .. 0 on the rim)
			s.position = Vector2(float(u.nb.get("pop_x", 0.0)), float(u.nb.get("pop_y", 0.0))) * k2 + Vector2(0.0, -POP_ARC * sin(PI * k2))
			if u.nb.has("hold"):
				s.scale = Vector2.ONE * lerpf(1.0, LAY_EGG_BIG, k2)       # (as big as her frame drew it, shrinking as it rolls out)
		elif u.nb.has("hold"):
			s.scale = Vector2.ONE
		# a fertilised egg glows red-gold (code; the sheet's egg is the waiting yellow-green one)
		# (it reddens under the father's breath, then stays red until it hatches)
		var red := 0.0 if u.nb.has("out") else (1.0 if int(u.nb.get("fert", 0)) == 2 else float(u.nb.get("redden", 0.0)))
		if absf(red - float(u.nb.get("tinted", 0.0))) > 0.04:
			u.nb["tinted"] = red
			(s.material as ShaderMaterial).set_shader_parameter("tint", Vector3.ONE.lerp(RED_EGG, red))
	# HAUL without its own sheet yet: the walk, the body swollen (code; docs/art_style_inconsistency.md)
	if u.kind == MAW and u.tesla_mode == "packed" and not ArtData.UNITS[MAW]["frames"].has("haul_se"):
		var f3 := clampf(float(u.nb.get("food", 0.0)) / float(Defs.NB["maw_cap"]), 0.0, 1.0)
		var sx := 1.0 + 0.22 * f3
		s.scale = Vector2(sx * signf(s.scale.x) if s.scale.x != 0.0 else sx, 1.0 + 0.3 * f3)
	elif u.kind == MAW:
		s.scale = Vector2(signf(s.scale.x) if s.scale.x != 0.0 else 1.0, 1.0)
	if ROOTERS.has(u.kind):
		_rooted_look(u, n)


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
	if a.begins_with("fill") and a != "fill" and n > 1:
		s.frame = int(clk * 2.5) % n         # (a Rootmaw's drawn breathing at its food stage: a slow loop)
	if still:
		var b := sin(clk * TAU / float(BREATH["period"]))
		s.scale = Vector2(sx * (1.0 - float(BREATH["rise"]) * 0.3 * b), 1.0 + float(BREATH["rise"]) * b)
	var lay := 0.0
	if u.kind == QUEEN and a == "rooted" and float(u.nb.get("lay_t", 0.0)) > 0.0:
		# laying, in code (no laying frames): a heave (up, then pressed down as the egg comes out, then settling) about the nest
		var lp := 1.0 - float(u.nb["lay_t"]) / LAY_TIME
		lay = sin(PI * lp)
		var hv := sin(TAU * lp) * (1.0 - lp)
		s.scale = Vector2(sx * (1.0 - 0.025 * hv), 1.0 + 0.06 * hv)
	# the glow over its food, eggs or breath
	var gk := "glow_%s_%s" % [a, u.anim_dir]
	var glow := u.get_node_or_null("Glow") as Sprite2D
	var has_glow: bool = ArtData.UNITS[u.art]["frames"].has(gk) and u.tesla_mode != "packed"
	if has_glow:
		if glow == null:
			glow = Sprite2D.new()
			glow.name = "Glow"
			glow.centered = false
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = cm
			u.add_child(glow)
		var tx := Game.tex("res://assets/units/%s/%s.png" % [u.art, gk])
		if glow.texture != tx:
			glow.texture = tx
			glow.hframes = int(ArtData.UNITS[u.art]["frames"][gk])
		glow.offset = s.offset
		glow.scale = s.scale
		glow.position = s.position
		glow.frame = clampi(s.frame, 0, glow.hframes - 1)
		var pulse := 0.5 + 0.5 * sin(clk * TAU / 2.2)
		var lo := 0.18
		var hi := 0.42
		if u.kind == FATHER:
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
	var xf := u.get_node_or_null("Xf") as Sprite2D
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
			u.add_child(xf)
			u.move_child(xf, s.get_index() + 1)
		xf.visible = true
		xf.self_modulate.a = 1.0 - shown
		s.self_modulate.a = shown
	else:
		if xf != null:
			xf.visible = false
		if s.self_modulate.a < 1.0:
			s.self_modulate.a = 1.0


## Over the creature (Unit._draw_unit, its own space): the Mother's eggs, a Rootmaw's food and ground, an egg's
## incubation, the father's reach when picked.
static func draw(u: Unit, top: float) -> void:
	var g := u.game
	var mine := u.team == g.human or g.demo or g.spectating()
	if u.kind == QUEEN and mine:
		var font := ThemeDB.fallback_font
		var txt := "%d/%d" % [int(u.nb.get("eggs", 0)), int(Defs.NB["eggs_max"])]
		u.draw_string_outline(font, Vector2(-14, top - 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
		u.draw_string(font, Vector2(-14, top - 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 1.0, 0.55) if int(u.nb.get("eggs", 0)) > 0 else Color(1.0, 0.55, 0.45))
	if u.kind == MAW and mine:
		var bw := u.radius * 2.4
		var f := clampf(float(u.nb.get("food", 0.0)) / float(Defs.NB["maw_cap"]), 0.0, 1.0)
		var y := top + 6.0
		u.draw_rect(Rect2(-bw * 0.5, y, bw, 3).grow(0.5), Color(0, 0, 0, 0.6))
		u.draw_rect(Rect2(-bw * 0.5, y, bw * f, 3), Color(0.75, 0.9, 0.25))
		if rooted(u) and bool(u.nb.get("dry", false)):
			var font := ThemeDB.fallback_font
			u.draw_string_outline(font, Vector2(-14, y + 16), "dry", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
			u.draw_string(font, Vector2(-14, y + 16), "dry", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.6, 0.4))
		if u.selected and rooted(u):
			var gl := ground_left(g, u) / float(Defs.PIT_GROUND)
			u.draw_rect(Rect2(-bw * 0.5, y + 4.5, bw, 2).grow(0.5), Color(0, 0, 0, 0.6))
			u.draw_rect(Rect2(-bw * 0.5, y + 4.5, bw * gl, 2), Color(0.55, 0.4, 0.25))
	if u.selected and u.kind == MAW and u.team == g.human:
		u.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		u.draw_arc(Vector2.ZERO, float(Defs.PIT_CLAIM) * Defs.TILE, 0, TAU, 48, Color(0.75, 0.9, 0.3, 0.45), 1.5)
		u.draw_set_transform(Vector2.ZERO)
	if u.selected and (u.kind == FATHER or u.kind == QUEEN) and u.team == g.human:
		u.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		u.draw_arc(Vector2.ZERO, float(Defs.NB["father_r"]) * Defs.TILE, 0, TAU, 56, Color(1.0, 0.55, 0.3, 0.45), 1.5)
		u.draw_set_transform(Vector2.ZERO)
	if u.kind == FATHER and mine and rooted(u):
		# his nest's queue, as a Barracks': the eggs in it, the first one's breath or incubation
		var eggs := nest_eggs(g, u)
		var font2 := ThemeDB.fallback_font
		var near := father_near(g, u.team)
		var txt2 := ("%d eggs" % eggs.size()) if near else "too far from the Mother"
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
	match u.kind:
		EGG:
			return int(u.nb.get("fert", 0)) * 1000 + int(float(u.nb.get("t", 0.0)) * 4.0) + int(float(u.nb.get("wait", 0.0)) * 4.0) * 7
		MAW:
			return int(float(u.nb.get("food", 0.0)) / 6.0) + (100000 if u.nb.has("spot") else 0)
		QUEEN:
			return int(u.nb.get("eggs", 0))
		FATHER:
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
	for k in ["spot", "fert", "eggs", "laid"]:
		if u.nb.has(k):
			u.nb[k] = int(u.nb[k])
	u.nb["m"] = u.tesla_mode
	u.nb.erase("tinted")          # (a fresh sprite: the egg's red is put on again)
	u.nb.erase("redden")
	if u.kind == TURTLE and u.tesla_mode != "packed":
		u.radius = float(Defs.NB["turtle_rooted_r"])
		if not u.game.nb_walls.has(u):
			u.game.nb_walls.append(u)
	if ROOTERS.has(u.kind):
		u.nb_mass = 1000.0 if u.tesla_mode != "packed" else packed_mass(u.kind)


static func save(g: Game) -> Dictionary:
	var spots := []
	for id in g.nb_spots:
		var s: Dictionary = g.nb_spots[id]
		spots.append([int(id), (s["p"] as Vector2).x, (s["p"] as Vector2).y, float(s["left"]), int(s.get("maw", 0))])
	return {"spots": spots, "next": g.nb_spot_next}


static func load(g: Game, d: Dictionary) -> void:
	g.nb_spots.clear()
	for s in d.get("spots", []):
		g.nb_spots[int(s[0])] = {"p": Vector2(float(s[1]), float(s[2])), "left": float(s[3]), "maw": int(s[4])}
	g.nb_spot_next = int(d.get("next", 0))
	g.nb_queen.clear()
