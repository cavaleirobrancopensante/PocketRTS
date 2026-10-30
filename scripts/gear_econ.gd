class_name GearEcon
extends RefCounted
## THE CLOCKWORK'S ECONOMY RULES on the gear field (gear mode; the study: docs/clockwork_economy_study.md; numbers in
## Defs.GEAR "drive" and "mainspring"; the field itself: scripts/gear.gd, which keeps `drive_of` and `spring_of` up to date).
##
## DRIVE (the building's EFFICIENCY). The Clocktower and every finished Mainspring DRIVE the gear field: a building whose ring
## meshes with one of them works at full speed; each ring farther from the nearest driver loses a share (Defs.GEAR "drive":
## 100% / 90% / 80% / 70% from the 4th ring on). An idler cog between two rings is free. Drive multiplies the work of every
## building that works (a Cog Press's cogs, a Mainspring's winding, training, research), on top of a crewed building's crew
## share; it does not touch supply (the Regulator), the Ratchet Turret's fire, building or repairing (DRIVE_FREE).
## The player reads it as one % per building: on the map over it (Game._draw_mine_labels), on its card (card_text) and on the
## placement ghost before it is placed (GearNet.draw_ghost_label, preview_steps).
##
## TENSION, a full resource. Mainsprings wind it into one pool. Every finished Mainspring STORES some (Defs.GEAR mainspring:
## small gear 200, big gear 400): winding stops when the pool holds what the Mainsprings store together (tension_cap); a
## refund may go over it, nothing unwinds. Buildings may cost Tension (a BUILDINGS `tension` price: the Clock Aviary).
## THE TENSION RULE: anything that costs Tension is made only at a building whose ring meshes with a Mainspring's ring (one
## hop; an idler between them counts): the Escapement and the Clock Aviary work only so (Defs.TENSION_USERS: idle otherwise,
## NEEDS MAINSPRING), and a Light Works makes Springers and Netters only so (the Heavy Works is a Tension user) (its Clock Soldiers need nothing):
## spend_problem.

const DRIVE_FREE := ["clocktower", "regulator", "ratchet_turret", "spring_tower"]


## Rings from the nearest driver for every connected building of the field (GearNet.solve): `list` the finished buildings,
## `linked` the connected ones, `touch` (i, j) whether their rings mesh (within the link gap, by THE LEVEL RULE). A building
## meshing with a Clocktower or a Mainspring is 1; a Mainspring counts the other drivers only (its own winding is driven by
## them). Building -> int (>= 1); a Clocktower is not in it.
static func drive_steps(list: Array, linked: Dictionary, touch: Callable) -> Dictionary:
	var n := list.size()
	var nb: Array = []
	for i in n:
		nb.append([])
	for i in n:
		if not linked.has(list[i]):
			continue
		for j in range(i + 1, n):
			if not linked.has(list[j]) or list[j].team != list[i].team:
				continue
			if touch.call(i, j):
				nb[i].append(j)
				nb[j].append(i)
	var drivers: Array = []
	for i in n:
		if linked.has(list[i]) and _drives(list[i].kind):
			drivers.append(i)
	var out := {}
	var d := _bfs(nb, drivers, -1)
	for i in n:
		if linked.has(list[i]) and list[i].kind != "clocktower" and not _drives(list[i].kind) and d[i] >= 0:
			out[list[i]] = d[i]
	# a Mainspring: rings from the other drivers (a BFS without it as a source)
	for s in drivers:
		if list[s].kind == "clocktower":
			continue
		var others: Array = drivers.filter(func(x: int) -> bool: return x != s)
		var ds := _bfs(nb, others, s)
		var best := -1
		for j in nb[s]:
			if ds[j] >= 0 and (best < 0 or ds[j] + 1 < best):
				best = ds[j] + 1
		out[list[s]] = maxi(1, best) if best >= 0 else 1
	return out


static func _drives(kind: String) -> bool:
	return kind == "clocktower" or kind == "mainspring"


## Breadth-first rings from `sources` (0 each) over `nb`, never through `skip`; -1 where it does not reach.
static func _bfs(nb: Array, sources: Array, skip: int) -> Array:
	var d: Array = []
	d.resize(nb.size())
	d.fill(-1)
	var q: Array = []
	for s in sources:
		d[s] = 0
		q.append(s)
	var qi := 0
	while qi < q.size():
		var a: int = q[qi]
		qi += 1
		for j in nb[a]:
			if j == skip or d[j] >= 0:
				continue
			d[j] = d[a] + 1
			q.append(j)
	return d


## The drive share for a building this many rings from the nearest driver (Defs.GEAR "drive").
static func drive_factor(steps: int) -> float:
	var t: Array = Defs.GEAR["drive"]
	return float(t[clampi(steps - 1, 0, t.size() - 1)])


## Does drive scale this kind's work? (Not the Clocktower, supply or the static defence.)
static func uses_drive(kind: String) -> bool:
	return not DRIVE_FREE.has(kind)


## The work multiplier of a connected, working Clockwork building (GearNet.speed_mult uses it): its drive share.
static func work_mult(net: GearNet, b: Building) -> float:
	if not Defs.gear_mode or not net.enforce or not uses_drive(b.kind):
		return 1.0
	return drive_factor(int(net.drive_of.get(b, 1)))


## ---- the Mainspring and the Tension pool

## A Mainspring's numbers for its gear (Defs.GEAR "mainspring": `full` Tension a second at full crew, `crew`, `store`).
static func spring_info(big: bool) -> Dictionary:
	return Defs.GEAR["mainspring"]["big" if big else "small"]


## What player t's finished Mainsprings store together: the most Tension they wind up to.
static func tension_cap(game: Game, t: int) -> float:
	var cap := 0.0
	for b in game.buildings:
		if b.team == t and b.kind == "mainspring" and b.built and not b.dead:
			cap += float(spring_info(b.gear_big)["store"])
	return cap


## Wind `v` Tension into player t's pool (a Mainspring's crank): the income multiplier applies (Game.income_mult, the
## Brutal computer's), it stops at the springs' store, and it is counted (stats "tension_in"). Returns what went in.
static func wind(game: Game, t: int, v: float) -> float:
	if v <= 0.0:
		return 0.0
	v *= float(game.income_mult[t]) if t < game.income_mult.size() else 1.0
	var room := tension_cap(game, t) - game.tension(t)
	if room <= 0.0:
		return 0.0
	v = minf(v, room)
	game.players[t]["tension"] = game.tension(t) + v
	game.stats[t]["tension_in"] = float(game.stats[t].get("tension_in", 0.0)) + v
	return v


## A Mainspring's crank: wind `v` Tension drawn from its Clocktower's SPRING LIFE (Defs.TENSION_RESERVE, kept in the
## Clocktower's `soil`; 0.24.0, the owner: MAINSPRINGS EXHAUST): only what went into the pool is drawn (a pool that is full
## draws nothing), down to 0; spent, it still winds (spring_rate: at Defs.TENSION_FLOOR, FATIGUED) and draws nothing more.
## Returns what went in (wind).
static func wind_spring(b: Building, v: float) -> float:
	if v <= 0.0:
		return 0.0
	var got := wind(b.game, b.team, v)
	var h: Building = b.game.soil_hall(b)
	if h != null and h.kind == "clocktower" and h.soil > 0.0:
		var mult: float = float(b.game.income_mult[b.team]) if b.team < b.game.income_mult.size() else 1.0
		h.soil = maxf(0.0, h.soil - (got / mult if mult > 0.0 else got))
		b.game.spring_check(h)
	return got


## Player t's pool is full: its Mainsprings stand still.
static func tension_full(game: Game, t: int) -> bool:
	var cap := tension_cap(game, t)
	return cap > 0.0 and game.tension(t) >= cap - 0.001


## Can this kind of building make something that costs Tension (a unit it trains or a research done at it)?
static func spends_tension(kind: String) -> bool:
	if not Defs.gear_mode or not Defs.BUILDINGS.has(kind):
		return false
	if Defs.TENSION_USERS.has(kind):
		return true
	for u in Defs.BUILDINGS[kind].get("trains", []):
		if Defs.UNITS.has(u) and Defs.tension_cost(Defs.UNITS[u]) > 0:
			return true
	for r in Defs.RESEARCH:
		if String(Defs.RESEARCH[r]["at"]) == kind and Defs.tension_cost(Defs.RESEARCH[r]) > 0:
			return true
	return false


## THE TENSION RULE at a building: "" when it may make things that cost Tension (its ring meshes with a Mainspring's), else
## the refusal (the study tool looks for "meshes with no Mainspring").
static func spend_problem(game: Game, b: Building) -> String:
	if not Defs.gear_mode or not game.gear_net.enforce or b.d["faction"] != "clockwork":
		return ""
	if game.gear_net.spring_for(b) != null:
		return ""
	return "This %s meshes with no Mainspring: anything that costs Tension is made only where a Mainspring's ring meshes with the building's." % String(b.d["name"])


## ---- what the player reads

## Building.efficiency for a gear-mode Clockwork building: [efficiency 0..1, crew at work, full crew, reserve left 0..1 (-1:
## none), reserve name]; [] for one that shows none (the Clocktower, Regulators, the Ratchet Turret). Efficiency = what it
## does now against what it does at its best: crew share (a Cog Press and a Mainspring: each Winder's share; nothing with
## nobody on it) x drive x its land (a Cog Press on spent brass, a FATIGUED Mainspring: nothing). 0 while it stands idle
## (unlinked, needing a Mainspring).
static func efficiency(b: Building) -> Array:
	if not uses_drive(b.kind) or not b.built or b.dead:
		return []
	var net: GearNet = b.game.gear_net
	var work := net.speed_mult(b) / GearNet.tempo(b)       # (drive, or 0 when idle; the ring's tempo is not efficiency)
	match b.kind:
		Defs.GEAR_PRESS:
			var gp: Dictionary = Defs.GEAR["press"]
			var cap := b.crew_max()
			var share := float(gp["base"]) + (1.0 - float(gp["base"])) * float(mini(b.working_crew(), cap)) / float(cap)
			var left := b.lode_left()
			var brass := 1.0 if left > 0.0 else Defs.LODE_SPENT
			return [share * work * brass, b.working_crew(), cap, left, "brass"]
		"mainspring":
			var info := spring_info(b.gear_big)
			var cap2 := int(info["crew"])
			var base := float(Defs.GEAR["mainspring"]["base"])
			var share2 := base + (1.0 - base) * float(mini(b.working_crew(), cap2)) / float(cap2)
			var life := b.soil_left()
			return [share2 * work * Defs.second_share(life, Defs.TENSION_FLOOR), b.working_crew(), cap2, life, "spring life"]
	return [work, 0, 0, -1.0, ""]


## The efficiency's parts in words for the building's card (gear mode's Clockwork), "" for one that shows none. The drive
## shows only when it costs something (2 rings or more from a Clocktower or Mainspring), so the card's line keeps room for
## the Tension rule's line beside it.
static func card_text(b: Building) -> String:
	var e := efficiency(b)
	if e.is_empty():
		return ""
	var net: GearNet = b.game.gear_net
	var parts: Array = []
	if int(e[2]) > 0:
		parts.append(Loc.t("%d/%d Winders") % [int(e[1]), int(e[2])])
	if net.speed_mult(b) <= 0.0:
		parts.append(Loc.t("idle"))
	else:
		var steps := int(net.drive_of.get(b, 1))
		if steps >= 2 and int(e[2]) > 0:
			parts.append(Loc.t("drive %d%%: %s") % [int(round(drive_factor(steps) * 100.0)), ring_words(steps)])
		elif steps >= 2:
			parts.append(ring_words(steps))        # (no crew: its efficiency is its drive)
	if b.kind == Defs.GEAR_PRESS and float(e[3]) <= 0.0:
		parts.append(Loc.t("brass spent"))
	if b.kind == "mainspring" and b.fatigued():
		parts.append(Loc.t("FATIGUED"))
	elif b.kind == "mainspring" and tension_full(b.game, b.team):
		parts.append(Loc.t("Tension full"))
	var head: String = Loc.t("Efficiency %d%%") % int(round(float(e[0]) * 100.0))
	return head + (": " + " · ".join(parts) if not parts.is_empty() else "")


## The card's info line for the Tension rule and the store (gear mode's Clockwork), "" when there is nothing to add: a
## building that makes something costing Tension but is no Tension user (the Light Works: its Springers), the Clock Aviary,
## the Mainspring. (The Escapement's line is the HUD's own.)
static func card_info(b: Building) -> String:
	var net: GearNet = b.game.gear_net
	if not net.is_linked(b):
		return ""
	if b.kind == "mainspring":
		# (its Clocktower's spring life, then what it stores of the side's whole store; a full pool shows on the efficiency
		# line: "Tension full", card_text)
		var store := Loc.t("Stores %d of your %d Tension") % [int(spring_info(b.gear_big)["store"]), int(tension_cap(b.game, b.team))]
		if b.fatigued():
			return Loc.t("FATIGUED: the spring has taken a set (its Clocktower's spring life is spent): it winds at %d%%. A Mainspring by a new Clocktower winds at full strength.") % int(round(Defs.TENSION_FLOOR * 100.0)) + "  ·  " + store
		var h: Building = b.game.soil_hall(b)
		var life := Loc.t("Spring life %d / %d") % [int(ceil(h.soil)), int(h.reserve())] if h != null else ""
		return life + "  ·  " + store
	if b.kind == Defs.CW_TECH:
		return ""
	if Defs.TENSION_USERS.has(b.kind):
		if net.needs_spring(b):
			return Loc.t("NEEDS MAINSPRING: its ring meshes with no Mainspring, so it stands idle. Build a Mainspring right beside it.")
		return Loc.t("Working: its ring meshes with a Mainspring.")
	if spends_tension(b.kind):
		var names: Array = []
		for u in b.d.get("trains", []):
			if Defs.UNITS.has(u) and Defs.tension_cost(Defs.UNITS[u]) > 0:
				names.append(Loc.t(String(Defs.UNITS[u]["name"])))
		var what := ", ".join(names)
		if net.spring_for(b) != null:
			return Loc.t("Meshes with a Mainspring: it can make what costs Tension (%s).") % what
		return Loc.t("No Mainspring meshes with it: no %s until a Mainspring's ring meshes with its ring (they cost Tension).") % what
	return ""


## The SPRING MARK's tooltip (GearNet.has_spring_mark): {title, body}, already in the player's language.
static func spring_tip(b: Building) -> Dictionary:
	if b == null or not is_instance_valid(b) or b.dead:
		return {}
	var body := Loc.t("A Mainspring's ring meshes with this building's, so it is fed Tension: it can work and make what costs Tension. Without a Mainspring beside it, it could not.")
	return {"title": Loc.t("Fed by a Mainspring"), "body": body}


## SIZE SETS THE TEMPO (owner, 2026-10-27): what a `kind` on its ring trades, in one line for its card ("Small gear: works
## 15% faster."), translated; "" for a kind whose ring changes nothing but reach.
static func trade_line(kind: String, big: bool) -> String:
	if not Defs.gear_mode:
		return ""
	if GearNet.big_only(kind):
		return Loc.t("Big gear only: slow and strong, the heavy torque.")
	var tt: Dictionary = Defs.GEAR["tempo"]
	if tt.has(kind):
		var pct := int(round(absf(GearNet.tempo_of(kind, big) - 1.0) * 100.0))
		return (Loc.t("Big gear: works %d%% slower, reaches farther.") if big else Loc.t("Small gear: works %d%% faster.")) % pct
	match kind:
		Defs.CW_TURRET:
			var sw: Dictionary = Defs.TURRET["big" if big else "small"]
			if big:
				return Loc.t("Big gear: slow heavy screws, %d every %.1f s: better against armour.") % [int(sw["damage"]), float(sw["cooldown"])]
			return Loc.t("Small gear: quick light screws, %d every %.1f s.") % [int(sw["damage"]), float(sw["cooldown"])]
		Defs.GEAR_PRESS:
			var gp: Dictionary = Defs.GEAR["press"]["big" if big else "small"]
			return (Loc.t("Big gear: up to %d Winders, %.1f cogs a second at full crew.") if big else Loc.t("Small gear: up to %d Winders, %.1f cogs a second at full crew.")) % [int(gp["crew"]), float(gp["full"])]
		"mainspring":
			var gm := spring_info(big)
			return (Loc.t("Big gear: up to %d Winders, stores %d Tension.") if big else Loc.t("Small gear: up to %d Winders, stores %d Tension.")) % [int(gm["crew"]), int(gm["store"])]
	return ""


## "meshes with a driver" / "2 rings from a driver" ... for the card and the tooltip.
static func ring_words(steps: int) -> String:
	if steps <= 1:
		return Loc.t("meshes with a Clocktower or Mainspring")
	return Loc.t("%d rings from a Clocktower or Mainspring") % steps


## The rings from the nearest driver a building of `kind` placed at cell c (team t) would have: 1 + the least of the
## connected rings its ring would touch (0 for a Clocktower or a Mainspring among them); -1 when it would not link.
static func preview_steps(net: GearNet, t: int, kind: String, c: Vector2i, big := false) -> int:
	if kind == "clocktower":
		return 0
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var g := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
	var r := GearNet.ring_r(kind, size, big)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var best := -1
	for b in net.linked:
		if not is_instance_valid(b) or b.dead or b.team != t:
			continue
		if g.distance_to(GearNet.b_c(b)) - r - GearNet.b_r(b) > slack:
			continue
		if not GearNet.level_ok(net.game, kind, c, big, b):
			continue          # (THE LEVEL RULE: a ring on the other level is no mesh)
		var s := 1 if _drives(b.kind) else int(net.drive_of.get(b, 1)) + 1
		if best < 0 or s < best:
			best = s
	return best


## ---- placing with room to spare (the computer, the Lab)

## A cell for a building of `kind` (team t) whose ring meshes with the ring of every building in `must` (within the link gap),
## that links and is placeable, nearest `near` (a world point; else must[0]), and that leaves ROOM round its own ring for
## `users` (kinds that must mesh with it later, e.g. a Mainspring's Escapement and Clock Aviary): the first of the closest
## `tries` cells that keeps room for all of them, else the one that keeps room for most. (-1, -1) when none.
## `unseen`: ground not explored yet will do (the computer).
static func room_spot(game: Game, t: int, kind: String, must: Array, users: Array = [], near := Vector2.INF, unseen := true, tries := 14) -> Vector2i:
	return room_spot_n(game, t, kind, must, users, near, unseen, tries)[0]


## room_spot, and how many of `users` its cell keeps room for: [cell, room].
static func room_spot_n(game: Game, t: int, kind: String, must: Array, users: Array = [], near := Vector2.INF, unseen := true, tries := 14) -> Array:
	if must.is_empty():
		return [Vector2i(-1, -1), 0]
	for m in must:
		if m == null or not is_instance_valid(m) or m.dead:
			return [Vector2i(-1, -1), 0]
	var T := float(Defs.TILE)
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var big := game.gear_big_for(t, kind)          # (GEAR PICK: the ring this side would place it on)
	var r := GearNet.ring_r(kind, size, big)
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	var a0: Building = must[0]
	var at: Vector2 = a0.center() if near == Vector2.INF else near
	var h0 := game.cell_of(a0.center())
	var cands: Array = []
	for y in range(h0.y - 14, h0.y + 15):
		for x in range(h0.x - 14, h0.x + 15):
			var c := Vector2i(x, y)
			if not game.in_map(c):
				continue
			var gc := GearNet.gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
			var ok := true
			var gaps := 0.0
			for m in must:
				var gap: float = gc.distance_to(GearNet.b_c(m)) - r - GearNet.b_r(m)
				if gap < -over or gap > slack or not GearNet.level_ok(game, kind, c, big, m):
					ok = false          # (out of reach, or on the other ground level: THE LEVEL RULE)
					break
				gaps += absf(gap)
			if ok:
				cands.append([(Vector2(c) * T + Vector2(size) * T * 0.5).distance_to(at) / T + gaps / T, c])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best := Vector2i(-1, -1)
	var best_room := -1
	var tried := 0
	for cd in cands:
		var c: Vector2i = cd[1]
		if game.placement_problem(t, kind, c, unseen) != "" or not game.margin_free(c, size):
			continue
		if game.gear_net.candidate(t, kind, c)["state"] != "ok":
			continue
		if users.is_empty():
			return [c, 0]
		var room := _room(game, t, kind, c, users)
		if room >= users.size():
			return [c, room]
		if room > best_room:
			best_room = room
			best = c
		tried += 1
		if tried >= tries:
			break
	return [best, maxi(best_room, 0)]


## How many of `users` (kinds, placed one after another) could still mesh with a ring of `kind` put at cell c: a greedy count
## that keeps the new rings off each other, off the field's rings and off the footprints (ground checks only).
static func _room(game: Game, t: int, kind: String, c: Vector2i, users: Array) -> int:
	return room_cells(game, t, kind, c, users).size()


## _room's greedy placing, the cells it found: [[user kind, cell], ...] in the order of `users` (the computer keeps the Heavy
## Works' cell for it: Game.ai_keep).
static func room_cells(game: Game, t: int, kind: String, c: Vector2i, users: Array) -> Array:
	var T := float(Defs.TILE)
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var gc := GearNet.gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
	var r := GearNet.ring_r(kind, size, game.gear_big_for(t, kind))
	var lv := GearNet.foot_level(game, c, size)
	var placed: Array = [[gc, r, Rect2i(c, size)]]
	var rings: Array = []
	for b in game.buildings:
		if not b.dead and GearNet.has_gear(b):
			rings.append([GearNet.b_c(b), GearNet.b_r(b)])
	var out: Array = []
	for uk in users:
		var us: Vector2i = Defs.BUILDINGS[uk]["size"]
		var ur := GearNet.ring_r(uk, us, game.gear_big_for(t, uk))
		var found := false
		for y in range(c.y - 9, c.y + 10):
			if found:
				break
			for x in range(c.x - 9, c.x + 10):
				var c2 := Vector2i(x, y)
				var g2 := GearNet.gpos(Vector2(c2) * T + Vector2(us) * T * 0.5)
				var gap := g2.distance_to(gc) - ur - r
				if gap < -over or gap > slack:
					continue
				var bad := false
				for p in placed:
					if g2.distance_to(p[0]) - ur - float(p[1]) < -over or Rect2i(c2, us).grow(1).intersects(p[2]):
						bad = true
						break
				if bad:
					continue
				for q in rings:
					if g2.distance_to(q[0]) - ur - float(q[1]) < -over:
						bad = true
						break
				if bad or not _ground_ok(game, c2, us):
					continue
				if GearNet.foot_level(game, c2, us) != lv or not GearNet.joint_ok(game, g2, ur, gc, r, lv):
					continue          # (THE LEVEL RULE: it would mesh only on the same ground level)
				placed.append([g2, ur, Rect2i(c2, us)])
				out.append([uk, c2])
				found = true
				break
	return out


## The footprint's ground is free, off ramps and clear of them (the computer keeps its ramps clear), and its margin clear (no gear
## check: the caller does the rings).
static func _ground_ok(game: Game, c: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if not game.in_map(cc) or not game.is_free(cc) or game.ramp[game.idx(cc)] == 1:
				return false
			if game._near_ramp(cc):
				return false          # (the computer keeps its ramps clear: Game.placement_problem's `ai` rule)
	return game.margin_free(c, size)


## What the placement ghost adds after its verdict (GearNet.draw_ghost_label): the efficiency the building would have there
## ("  90%"; none for the kinds drive does not touch) and, for a Mainspring, how many buildings that make things costing
## Tension it would feed ("  ·  FEEDS 2").
static func ghost_note(net: GearNet, t: int, kind: String, c: Vector2i, big := false) -> String:
	var out := ""
	if uses_drive(kind):
		var steps := preview_steps(net, t, kind, c, big)
		if steps > 0:
			# (the % it would work at: its drive, times its ring size's tempo, Defs.GEAR "tempo")
			out += "  %d%%" % int(round(drive_factor(steps) * GearNet.tempo_of(kind, big or GearNet.big_only(kind)) * 100.0))
	if kind == "mainspring":
		var fed := would_feed(net, t, c, big)
		if not fed.is_empty():
			out += "  ·  " + Loc.t("FEEDS %d") % fed.size()
	return out


## The connected buildings a Mainspring placed at cell c would feed: those whose ring it would touch and that make things
## costing Tension (spends_tension) but mesh with no Mainspring yet are listed first, then the others.
static func would_feed(net: GearNet, t: int, c: Vector2i, big := false) -> Array:
	var size: Vector2i = Defs.BUILDINGS["mainspring"]["size"]
	var g := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
	var r := GearNet.ring_r("mainspring", size, big)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var fresh: Array = []
	var more: Array = []
	for b in net.linked:
		if not is_instance_valid(b) or b.dead or b.team != t or not spends_tension(b.kind):
			continue
		if g.distance_to(GearNet.b_c(b)) - r - GearNet.b_r(b) <= slack and GearNet.level_ok(net.game, "mainspring", c, big, b):
			if net.spring_for(b) == null:
				fresh.append(b)
			else:
				more.append(b)
	return fresh + more
