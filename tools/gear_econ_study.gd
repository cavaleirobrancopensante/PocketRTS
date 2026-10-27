extends SceneTree
## THE CLOCKWORK ECONOMY STUDY (docs/clockwork_economy_study.md): headless measurements of the gear-mode economy.
##
##   godot --headless --fixed-fps 30 --script res://tools/gear_econ_study.gd -- <mode> [key=value ...]
##
## Modes:
##   ai fac=<crown|brood|clockwork> [minutes=10 map=greenhold seed=1 strat=balanced]
##       The Hard computer (balanced, or the AI strategy `strat`; peaceful: it builds its economy and army but never attacks) against an idle
##       opponent. One line a minute: what it has EARNED so far of both resources (Tension for the Clockwork),
##       workers, army value; then when its tier-2 things came.
##   bo layout=<name> [minutes=10 map=greenhold seed=1]
##       A scripted Clockwork build order (no computer) on one base layout, the same order for every layout:
##       Winders all the time (one at a time, up to the crews plus a builder), a second Cog Press, a Movement Works,
##       a Mainspring, an Escapement, a Clock Aviary, Regulators when supply runs short; then Springers and Swifts as fast
##       as cogs and Tension allow (no Clock Soldiers: the fastest tier 2 each layout allows). Layouts (where things go):
##         flower  everything meshes with the Clocktower where it fits; the Mainspring beside the Works, the
##                 Escapement and the Aviary beside the Mainspring and the Clocktower if they can
##         hub     the Mainspring on the Clocktower's ring, the Works, Escapement and Aviary all round the Mainspring
##         chain   the base strung outward: the second press hangs on the first, the Works on it, the Mainspring on the
##                 Works (away from the Clocktower: low drive), the Escapement and the Aviary round the Mainspring
##         split   an unplanned base: the Works in front of the Clocktower, the Mainspring behind it (they do not
##                 mesh); a second Works by the Mainspring once Springers need one (the Tension rule)
##         big     as flower, but the Cog Presses and the Mainspring on BIG gears with their bigger crews
##         twin    as flower, with a second Mainspring for the Aviary
##       Prints one line a minute (cogs and Tension earned, Winders, buildings, the average efficiency) and the times of
##       the Works, the Mainspring, the Escapement at work, the first Springer and the first Swift.
## Output: the lines on stdout (and a CSV row per run appended to user://gear_econ_study.csv). STUDY_DEBUG=1 in the
## environment prints why each candidate cell of the scripted placer was refused.

const DT := 1.0 / 30.0

var main: Node
var opts := {}
var wall0 := 0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _opt(k: String, def: Variant) -> Variant:
	if not opts.has(k):
		return def
	var v: String = opts[k]
	if def is int:
		return int(v)
	if def is float:
		return float(v)
	return v


func _run() -> void:
	await process_frame
	var mode := "ai"
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			var kv: PackedStringArray = a.split("=", true, 1)
			opts[kv[0]] = kv[1]
		else:
			mode = a
	wall0 = Time.get_ticks_msec()
	match mode:
		"ai":
			await _ai_run(String(_opt("fac", "clockwork")))
		"bo":
			await _bo_run(String(_opt("layout", "flower")))
		_:
			print("unknown mode ", mode)
	print("done in %.1f s wall" % ((Time.get_ticks_msec() - wall0) / 1000.0))
	quit()


## A match on a fixed map: team 0 is the Hard computer (peaceful) when `ai0`, else nobody's (the script plays it);
## team 1's computer is switched off.
func _start(fac: String, opp: String, ai0: bool) -> Game:
	var slots := [
		{"who": "hard" if ai0 else "you", "faction": fac, "colour": 0, "side": 0, "strategy": String(_opt("strat", "balanced"))},
		{"who": "hard", "faction": opp, "colour": 1, "side": 1, "strategy": "balanced"},
	]
	seed(int(_opt("seed", 1)))
	main.start({"map": String(_opt("map", "greenhold")), "slots": slots, "seed": int(_opt("seed", 1))})
	var g: Game = main.game
	for ai in g.ais:
		ai.peaceful = true
		if not (ai.team == 0 and ai0):
			ai.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	if g.hud:
		g.hud.countdown = 0.0
	paused = false               # (the start countdown holds the world: the script goes at once)
	main._save_t = -1.0e12       # (no autosaves from a study run)
	return g


func _note(g: Game) -> String:
	var w := (Time.get_ticks_msec() - wall0) / 1000.0
	return "(x%.1f)" % (g.clock / maxf(w, 0.001))


## Tension earned so far by team t: the game's statistic when it keeps one, else what this script counted.
func _tension_in(g: Game, t: int, counted: float) -> float:
	if g.stats[t].has("tension_in"):
		return float(g.stats[t]["tension_in"])
	return counted


func _built(g: Game, t: int, kind: String) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == t and not b.dead and b.built and b.kind == kind)


func _army_value(g: Game, t: int) -> int:
	var v := 0
	for u in g.army(t):
		v += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
	return v


## The average efficiency of team t's finished Clockwork buildings that show one (Building.efficiency), or -1.
func _avg_eff(g: Game, t: int) -> float:
	var s := 0.0
	var n := 0
	for b in g.buildings:
		if b.team != t or b.dead or not b.built or b.d["faction"] != "clockwork":
			continue
		var e: Array = b.efficiency()
		if not e.is_empty():
			s += float(e[0])
			n += 1
	return s / n if n > 0 else -1.0


func _csv(row: Array) -> void:
	var path := "user://gear_econ_study.csv"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(",".join(row.map(func(x) -> String: return str(x))))
	f.close()


# ------------------------------------------------------------------ mode: ai

func _ai_run(fac: String) -> void:
	var opp := "crown" if fac != "crown" else "brood"
	var minutes: int = _opt("minutes", 10)
	var g := await _start(fac, opp, true)
	var res: Array = Defs.res_names(fac)
	var counted := 0.0
	var firsts := {}
	print("== ai %s (Hard, %s, peaceful) vs idle %s on %s, %d min" % [fac, String(_opt("strat", "balanced")), opp, g.map_name, minutes])
	var marks: Array = []
	for m in minutes:
		var end := float(m + 1) * 60.0
		while g.clock < end and not g.over:
			await physics_frame
			if fac == "clockwork":
				for b in g.buildings:
					if b.team == 0 and b.kind == "mainspring" and b.built and not b.dead:
						counted += b.spring_rate() * DT
			for u in g.units:
				if u.team == 0 and not u.dead and not u.is_worker() and not firsts.has(u.kind):
					firsts[u.kind] = g.clock
			for b in g.buildings:
				if b.team == 0 and b.built and not b.dead and not firsts.has("B:" + b.kind):
					firsts["B:" + b.kind] = g.clock
		var st: Dictionary = g.stats[0]
		var r1 := int(st["gold"])
		var r2 := _tension_in(g, 0, counted) if fac == "clockwork" else float(st["res2_in"])
		var line := "  %2d:00  %s earned %5d  %s earned %6.0f  bank %d/%.0f  workers %d  army %d (value %d)  %s" % [m + 1, res[0], r1, res[1], r2,
			int(g.players[0]["gold"]), (g.tension(0) if fac == "clockwork" else float(g.players[0]["res2"])), g.workers(0).size(), g.army(0).size(), _army_value(g, 0), _note(g)]
		print(line)
		marks.append([m + 1, r1, int(r2), g.workers(0).size(), _army_value(g, 0)])
	var ks: Array = firsts.keys()
	ks.sort_custom(func(a, b) -> bool: return float(firsts[a]) < float(firsts[b]))
	var parts: Array = []
	for k in ks:
		parts.append("%s %d:%02d" % [k, int(firsts[k]) / 60, int(firsts[k]) % 60])
	print("  firsts: " + ", ".join(parts))
	if fac == "clockwork":
		_dump(g)
	for mk in marks:
		if int(mk[0]) in [3, 6, 10]:
			print("MARK ai %s %d min: %s %d, %s %d, workers %d, army value %d" % [fac, mk[0], res[0], mk[1], res[1], mk[2], mk[3], mk[4]])
			_csv(["ai", fac, mk[0], mk[1], mk[2], mk[3], mk[4]])


# ------------------------------------------------------------------ mode: bo (scripted Clockwork)

var g: Game
var tower: Building
var layout := "flower"
var steps: Array = []           # the build order still to go: [{"k", "big", "id"}]
var made := {}                  # step id -> the Building placed for it
var firsts := {}
var counted := 0.0
var _think := 0.0
var _no_spot := {}
var last_spot := Vector2i.ZERO   # (where the last _place wanted to build; x < 0 when there was no spot)


func _bo_run(lay: String) -> void:
	layout = lay
	var minutes: int = _opt("minutes", 10)
	g = await _start("clockwork", "crown", false)
	g.explored.fill(1)            # (the script places like the computer: no fog in its way)
	tower = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "clocktower":
			tower = b
	var big := layout == "big"
	steps = [{"k": Defs.GEAR_PRESS, "big": big, "id": "press2"}, {"k": Defs.CW_WORKS, "big": false, "id": "works"},
		{"k": "mainspring", "big": big, "id": "spring"}, {"k": Defs.CW_TECH, "big": false, "id": "esc"},
		{"k": Defs.CW_AIR, "big": false, "id": "aviary"}]
	if layout == "twin":
		steps.insert(4, {"k": "mainspring", "big": false, "id": "spring2"})
	if big:
		for b in g.buildings:
			if b.team == 0 and b.kind == Defs.GEAR_PRESS:
				b.gear_big = true          # (the starting press too)
	print("== bo %s on %s, %d min" % [layout, g.map_name, minutes])
	for m in minutes:
		var end := float(m + 1) * 60.0
		while g.clock < end and not g.over:
			await physics_frame
			for b in g.buildings:
				if b.team == 0 and b.kind == "mainspring" and b.built and not b.dead:
					counted += b.spring_rate() * DT
			_think -= DT
			if _think <= 0.0:
				_think = 0.5
				_bot()
			_watch()
		var st: Dictionary = g.stats[0]
		var ae := _avg_eff(g, 0)
		print("  %2d:00  cogs earned %5d  Tension earned %5.0f  bank %d/%.0f  Winders %d  buildings %d  eff %s  springers %d swifts %d  %s" % [m + 1,
			int(st["gold"]), _tension_in(g, 0, counted), int(g.players[0]["gold"]), g.tension(0), g.workers(0).size(),
			g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.built).size(),
			("%d%%" % int(round(ae * 100))) if ae >= 0.0 else "-", _count(Defs.SPRINGER), _count(Defs.CUCKOO), _note(g)])
		if m + 1 in [3, 6, 10]:
			_csv(["bo", layout, m + 1, int(st["gold"]), int(_tension_in(g, 0, counted)), g.workers(0).size(), _count(Defs.SPRINGER), _count(Defs.CUCKOO), snappedf(ae, 0.01)])
	var parts: Array = []
	for k in ["works", "spring", "esc_work", "springer", "aviary", "swift", "works2", "spring2", "springw", "springe", "spring3", "full"]:
		if firsts.has(k):
			parts.append("%s %d:%02d" % [k, int(firsts[k]) / 60, int(firsts[k]) % 60])
	print("RESULT bo %s: %s" % [layout, ", ".join(parts)])
	_csv(["bo_times", layout] + [firsts.get("works", -1), firsts.get("spring", -1), firsts.get("esc_work", -1), firsts.get("springer", -1), firsts.get("swift", -1)])
	_dump(g)


## Team 0's Clockwork buildings: kind, cell, gear, efficiency, rings from a driver, whether a Mainspring meshes with it.
func _dump(gm: Game) -> void:
	for b in gm.buildings:
		if b.team == 0 and not b.dead and b.built and b.d["faction"] == "clockwork":
			var e: Array = b.efficiency()
			var net: GearNet = gm.gear_net
			print("  %-14s cell %s  %s gear  %s  %s%s" % [b.kind, str(b.cell), "big" if b.gear_big else "small", ("eff %d%%" % int(round(float(e[0]) * 100))) if not e.is_empty() else "",
				("ring %d" % int(net.drive_of.get(b, 0))) if "drive_of" in net else "", " +spring" if net.spring_for(b) != null else ""])


func _count(kind: String) -> int:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == kind).size()


func _watch() -> void:
	for id in made:
		var b: Building = made[id]
		if is_instance_valid(b) and b.built and not firsts.has(id):
			firsts[id] = g.clock
	var esc: Building = made.get("esc")
	if esc != null and is_instance_valid(esc) and esc.built and not firsts.has("esc_work") and g.gear_net.speed_mult(esc) > 0.0:
		firsts["esc_work"] = g.clock
	if not firsts.has("springer") and _count(Defs.SPRINGER) > 0:
		firsts["springer"] = g.clock
	if not firsts.has("swift") and _count(Defs.CUCKOO) > 0:
		firsts["swift"] = g.clock


## The script's turn (twice a second): Winders, supply, the next building, then Springers and Swifts.
func _bot() -> void:
	var cogs := int(g.players[0]["gold"])
	var next: Dictionary = steps[0] if not steps.is_empty() else {}
	var next_cost := int(Defs.BUILDINGS[next["k"]]["cost"]) if not next.is_empty() else 0
	# Winders: one at a time, up to the crews of the presses and Mainsprings plus a builder
	var want := 1
	for b in g.buildings:
		if b.team == 0 and not b.dead and (b.kind == Defs.GEAR_PRESS or b.kind == "mainspring"):
			want += b.crew_max()
	for s in steps:
		if s["k"] == "mainspring":
			want += 6 if s["big"] else 3
		elif s["k"] == Defs.GEAR_PRESS:
			want += int(Defs.GEAR["press"]["big" if s["big"] else "small"]["crew"])
	var ws := g.workers(0).size()
	if tower.queue.is_empty() and ws < want and cogs >= 50 and g.supply_used(0) + 1 <= int(g.players[0]["cap"]):
		g.train(tower, "winder")
		cogs = int(g.players[0]["gold"])
	# supply: a Regulator when it runs short (before the next step)
	var pending_sup := g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and not b.built and b.kind == Defs.CW_SUPPLY).size()
	if int(g.players[0]["cap"]) - g.supply_used(0) <= 3 and pending_sup == 0 and int(g.players[0]["cap"]) < g.max_supply(0):
		if cogs >= int(Defs.BUILDINGS[Defs.CW_SUPPLY]["cost"]):
			_place({"k": Defs.CW_SUPPLY, "big": false, "id": "reg%d" % g.clock})
		return
	# tier 2: the first Springer as soon as a Works may make one, then the rest of the order; once the order is done, Springers
	# and Swifts all the time. The split layout builds a second Works by the Mainspring when its first Works may not
	# make Springers (the Tension rule: no Mainspring meshes with it) once the Escapement works.
	var works: Array = _built(g, 0, Defs.CW_WORKS)
	var stuck: bool = not next.is_empty() and _no_spot.has(String(next["id"]))
	if steps.is_empty() or _count(Defs.SPRINGER) == 0 or stuck:
		for w in works:
			if w.queue.is_empty() and g.can_train(w, Defs.SPRINGER) == "":
				g.train(w, Defs.SPRINGER)
		for av in _built(g, 0, Defs.CW_AIR):
			if av.queue.is_empty() and g.can_train(av, Defs.CUCKOO) == "":
				g.train(av, Defs.CUCKOO)
	if firsts.has("esc_work") and not works.is_empty() and not made.has("works2") and not made.has("springw") \
			and not steps.any(func(s: Dictionary) -> bool: return s["id"] == "works2" or s["id"] == "springw"):
		if works.all(func(w: Building) -> bool: return g.can_train(w, Defs.SPRINGER).contains("meshes with no Mainspring")):
			steps.push_front({"k": Defs.CW_WORKS, "big": false, "id": "works2"})
			next = steps[0]
			next_cost = int(Defs.BUILDINGS[next["k"]]["cost"])
	cogs = int(g.players[0]["gold"])
	if not next.is_empty():
		var tc := Defs.tension_cost(Defs.BUILDINGS[next["k"]])
		if cogs >= next_cost and g.tension(0) >= float(tc) and g.requirement_met(0, next["k"]):
			if _place(next):
				steps.pop_front()
			elif next["k"] == Defs.CW_AIR and not made.has("spring2") and Defs.TENSION_USERS.has(Defs.CW_AIR):
				steps.push_front({"k": "mainspring", "big": false, "id": "spring2"})      # (no room by a Mainspring: another one)
			elif next["k"] == Defs.CW_AIR and _b("spring2") != null and _b("spring2").built and not made.has("spring3") and last_spot.x < 0:
				steps.push_front({"k": "mainspring", "big": false, "id": "spring3"})      # (still none: a third, with room)
			elif next["k"] == Defs.CW_TECH and _b("spring") != null and _b("spring").built and not made.has("springe") and last_spot.x < 0:
				steps.push_front({"k": "mainspring", "big": false, "id": "springe"})      # (no room by the Mainspring: another)
			elif next["id"] == "works2" and last_spot.x < 0:
				# (no room for a Works by any Mainspring: a Mainspring by the first Works instead)
				steps.pop_front()
				if not made.has("springw"):
					steps.push_front({"k": "mainspring", "big": false, "id": "springw"})


## Place this step's building where the layout says, with the nearest Winder not building. True when placed.
func _place(step: Dictionary) -> bool:
	var k: String = step["k"]
	var c := _where(step)
	last_spot = c
	if c.x < 0:
		var key: String = "reg" if k == Defs.CW_SUPPLY else String(step["id"])
		if k == Defs.CW_SUPPLY and not firsts.has("full"):
			firsts["full"] = g.clock      # (the plateau is full: no room for a Regulator)
		if not _no_spot.has(key):
			_no_spot[key] = true
			print("  (no spot for %s at %d:%02d)" % [step["id"], int(g.clock) / 60, int(g.clock) % 60])
		return false
	var best: Unit = null
	var bd := INF
	for u in g.workers(0):
		if u.order == "build":
			continue
		var d: float = u.position.distance_to(tower.center()) + tower.center().distance_to(Vector2(c) * Defs.TILE)
		if d < bd:
			bd = d
			best = u
	if best == null:
		return false
	var b := g.place_building(0, k, c, [best])
	if b == null:
		return false
	b.gear_big = bool(step["big"])
	made[step["id"]] = b
	print("  %d:%02d  placed %s at %s" % [int(g.clock) / 60, int(g.clock) % 60, step["id"], str(c)])
	return true


func _b(id: String) -> Building:
	var b: Building = made.get(id)
	return b if b != null and is_instance_valid(b) and not b.dead else null


## Screen degrees from the Clocktower: "behind" (away from the map's middle) and "front" (toward it).
func _deg(front: bool, turn := 0.0) -> float:
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var a := (mid - tower.center()).angle()
	if not front:
		a += PI
	return rad_to_deg(a) + turn


## Where a step's building goes in this layout: [rings it must mesh with], [rings it must not touch], a direction, and
## the kinds that must still find room round it later (a Mainspring keeps room for its Tension users).
func _where(step: Dictionary) -> Vector2i:
	var k: String = step["k"]
	var c := _where_raw(step) if not (k == Defs.CW_AIR and _b("spring2") != null and layout != "twin") else Vector2i(-1, -1)
	if c.x >= 0:
		return c
	if k == Defs.CW_TECH or k == Defs.CW_AIR:
		# (no room in its layout's spot: by any built Mainspring with room, as the computer looks (GearEcon.room_spot))
		for m in _springs():
			var cr := GearEcon.room_spot(g, 0, k, [m], [Defs.CW_AIR] if k == Defs.CW_TECH else [], m.center(), true, 30)
			if cr.x >= 0:
				return cr
	if step["id"] == "springe" or step["id"] == "spring3":
		# (a spare Mainspring for the Escapement or the Aviary that found no room: on a Clocktower's ring with room for it,
		# else by any building with room)
		var users2: Array = [Defs.CW_TECH, Defs.CW_AIR] if step["id"] == "springe" else [Defs.CW_AIR]
		var rn: Array = GearEcon.room_spot_n(g, 0, k, [tower], users2, tower.center(), true, 30)
		if int(rn[1]) >= 1:
			return rn[0]
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.built and GearNet.has_gear(b) and b.kind != "clocktower":
				var rb: Array = GearEcon.room_spot_n(g, 0, k, [b], users2, b.center(), true, 14)
				if int(rb[1]) >= 1:
					return rb[0]
		return Vector2i(-1, -1)
	if c.x == -1 and k != Defs.CW_AIR:
		return c              # (its layout's spot is not there yet: try again later)
	if k == Defs.CW_AIR:
		# (no room in its layout: an Aviary goes by any Mainspring with room; with THE TENSION RULE it must, else the order
		# asks for a second Mainspring first, _bot)
		for m in [_b("spring2"), _b("spring")]:
			if m != null:
				var c3 := _spot(k, false, [m], [], _deg(true))
				if c3.x >= 0:
					return c3
		return Vector2i(-1, -1) if Defs.TENSION_USERS.has(Defs.CW_AIR) else _spot_any(k)
	if step["id"] == "works2":
		# (a second Works where a Mainspring meshes with it: by any Mainspring with room; else -1 and _bot builds a
		# Mainspring by the first Works instead)
		for m in [_b("spring"), _b("spring2")]:
			if m != null:
				var c6 := _spot(k, false, [m], [], _deg(true))
				if c6.x >= 0:
					return c6
		for m in _springs():
			var c7 := GearEcon.room_spot(g, 0, k, [m], [], m.center(), true, 30)
			if c7.x >= 0:
				return c7
		return Vector2i(-1, -1)
	if step["id"] == "springw":
		var w := _b("works")
		if w == null:
			return Vector2i(-1, -1)
		return _first([_spot(k, false, [w], [], _deg(true), [Defs.CW_AIR]), _spot(k, false, [w], [], 0.0), GearEcon.room_spot(g, 0, k, [w], [Defs.CW_AIR], w.center(), true, 30)])
	if step["id"] == "spring2" and layout != "twin":
		# (a second Mainspring for the Aviary: on the Clocktower's ring with room for it, else by any building with room)
		var c4 := _spot(k, false, [tower], [], _deg(true, -60.0), [Defs.CW_AIR])
		if c4.x >= 0:
			return c4
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.built and GearNet.has_gear(b) and b.kind != "clocktower":
				var c5 := _spot(k, false, [b], [], 0.0, [Defs.CW_AIR])
				if c5.x >= 0 and _room(k, c5, false, [Defs.CW_AIR]) >= 1:
					return c5
	return _spot_any(k)


func _where_raw(step: Dictionary) -> Vector2i:
	var k: String = step["k"]
	var id: String = step["id"]
	var big: bool = step["big"]
	var sp := _b("spring")
	var works := _b("works")
	var press1: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS and not b.dead and b != _b("press2"):
			press1 = b
	var users: Array = [Defs.CW_TECH, Defs.CW_AIR]       # (what a Mainspring must keep room for)
	if k == Defs.CW_SUPPLY:
		# Regulators: tucked behind, on the Clocktower's ring if there is room, else anywhere linked
		# (a planner keeps the Regulators off the rings of the Works and the Mainspring while their neighbours are still to
		# come: the room by them is for the Mainspring, the Escapement and the Aviary)
		var keep: Array = []
		var rdeg := _deg(false, 70.0)
		var wk := _b("works")
		if wk != null and (_b("spring") == null or _b("aviary") == null):
			keep = [wk, _b("spring")]
			rdeg = rad_to_deg((tower.center() - wk.center()).angle())     # (the far side of the Clocktower from the Works)
		var c := _first([_spot(k, false, [tower], keep, rdeg), _spot(k, false, [tower], [], rdeg)])
		return c if c.x >= 0 else _spot_any(k)
	match layout:
		"flower", "big", "twin":
			match id:
				"press2":
					return _first([_spot(k, big, [tower], [], _deg(false, -40.0))])
				"works":
					# (room beside it for the Mainspring to come: a big one in the big layout)
					return _first([_spot(k, big, [tower], [], _deg(true), [["mainspring", layout == "big"]])])
				"spring":
					var u: Array = [Defs.CW_TECH] if layout == "twin" else users
					return _first([_spot(k, big, [tower, works], [], _deg(true, 60.0), u), _spot(k, big, [works], [], _deg(true, 60.0), u),
						_spot(k, big, [tower], [], _deg(true, 60.0), u)])
				"esc":
					return _first([_spot(k, big, [sp, tower], [], _deg(true, 90.0), [] if layout == "twin" else [Defs.CW_AIR]), _spot(k, big, [sp], [], _deg(true, 90.0))])
				"spring2":
					return _first([_spot(k, big, [tower], [], _deg(true, -60.0), [Defs.CW_AIR]), _spot(k, big, [sp], [], _deg(true, -60.0), [Defs.CW_AIR])])
				"aviary":
					var s2 := _b("spring2") if layout == "twin" else sp
					return _first([_spot(k, big, [s2, tower], [], _deg(true, -90.0)), _spot(k, big, [s2], [], _deg(true, -90.0))])
		"hub":
			match id:
				"press2":
					return _first([_spot(k, big, [tower], [], _deg(false, -40.0))])
				"works":
					return _first([_spot(k, big, [tower], [], _deg(true), [["mainspring", big]])])
				"spring":
					return _first([_spot(k, big, [works], [tower], _deg(true, 30.0), users), _spot(k, big, [works], [], _deg(true, 30.0), users)])
				"esc", "aviary":
					return _first([_spot(k, big, [sp], [tower], _deg(true, 30.0 if id == "esc" else -30.0), [Defs.CW_AIR] if id == "esc" else []), _spot(k, big, [sp], [], _deg(true))])
		"chain":
			# strung outward: the second press hangs on the first, the Works on the second press, the Mainspring on the
			# Works (each away from the Clocktower), the Escapement and the Aviary round the Mainspring
			match id:
				"press2":
					return _first([_spot(k, big, [press1], [tower], _deg(true, 60.0)), _spot(k, big, [press1], [], _deg(true, 60.0))])
				"works":
					var p2 := _b("press2")
					return _first([_spot(k, big, [p2], [tower, press1], _deg(true, 30.0), [["mainspring", false]]), _spot(k, big, [p2], [tower], _deg(true, 30.0)), _spot(k, big, [p2], [], _deg(true))])
				"spring":
					return _first([_spot(k, big, [works], [tower, _b("press2")], _deg(true, 0.0), users), _spot(k, big, [works], [tower], _deg(true, 0.0), users), _spot(k, big, [works], [], _deg(true), users)])
				"esc":
					return _first([_spot(k, big, [sp], [tower], _deg(true, 40.0), [Defs.CW_AIR]), _spot(k, big, [sp], [], _deg(true, 40.0))])
				"aviary":
					return _first([_spot(k, big, [sp], [tower], _deg(true, -40.0)), _spot(k, big, [sp], [], _deg(true))])
		"split":
			match id:
				"press2":
					return _first([_spot(k, big, [tower], [], _deg(true, 90.0))])
				"works":
					return _first([_spot(k, big, [tower], [], _deg(true))])
				"spring":
					var u2: Array = [Defs.CW_TECH, Defs.CW_AIR, Defs.CW_WORKS]
					return _first([_spot(k, big, [tower], [works], _deg(false), u2), _spot(k, big, [tower], [works], _deg(false, 90.0), u2), _spot_any(k)])
				"esc", "aviary":
					return _first([_spot(k, big, [sp], [works], _deg(false, 40.0 if id == "esc" else -40.0), [Defs.CW_AIR, Defs.CW_WORKS] if id == "esc" else [Defs.CW_WORKS]), _spot(k, big, [sp], [], _deg(false))])
				"works2":
					return _first([_spot(k, big, [sp], [], _deg(false, 90.0)), _spot(k, big, [sp], [], _deg(false))])
	return Vector2i(-2, -2)          # (a step this layout has no rule for)


## Team 0's built Mainsprings, the layout's own first.
func _springs() -> Array:
	var out: Array = []
	for id in ["spring", "spring2", "springw", "springe", "spring3"]:
		var m := _b(id)
		if m != null and m.built:
			out.append(m)
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.built and b.kind == "mainspring" and not out.has(b):
			out.append(b)
	return out


func _first(cands: Array) -> Vector2i:
	for c in cands:
		if c.x >= 0:
			return c
	return Vector2i(-1, -1)


## Any cell where a building of kind k links (the computer's own search, near the Clocktower).
func _spot_any(k: String) -> Vector2i:
	return g.find_spot(0, k, tower, 3, 20, "near", true)


## The cell for a building of kind k (small or big gear) whose ring meshes with every ring in `must` (within the link
## gap), touches none of `avoid`, links, is placeable, and lies nearest direction `deg` (screen degrees) from must[0],
## with the smallest gaps; when `room` lists kinds (or [kind, big]) that must mesh with it later, the cells that leave
## room for all of them come first. (-1, -1) when none.
func _spot(k: String, big: bool, must: Array, avoid: Array, deg: float, room: Array = []) -> Vector2i:
	for m in must:
		if m == null or not is_instance_valid(m) or m.dead:
			return Vector2i(-1, -1)
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var r := GearNet.ring_r(k, size, big)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var over := float(Defs.GEAR["overlap"]) * Defs.TILE
	var a0: Building = must[0]
	var h0 := g.cell_of(a0.center())
	var want := deg_to_rad(deg)
	var cands: Array = []
	for y in range(h0.y - 15, h0.y + 16):
		for x in range(h0.x - 15, h0.x + 16):
			var c := Vector2i(x, y)
			if not g.in_map(c):
				continue
			var gp := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var score := 0.0
			var ok := true
			for m in must:
				var gap: float = gp.distance_to(GearNet.b_c(m)) - r - GearNet.b_r(m)
				if gap < -over or gap > slack or not GearNet.level_ok(g, k, c, big, m):
					ok = false          # (out of reach, or on the other ground level: no mesh)
					break
				score += absf(gap)
			if not ok:
				continue
			for a in avoid:
				if a == null or not is_instance_valid(a) or a.dead:
					continue
				if gp.distance_to(GearNet.b_c(a)) - r - GearNet.b_r(a) <= slack and GearNet.level_ok(g, k, c, big, a):
					ok = false
					break
			if not ok:
				continue
			score += absf(angle_difference(want, (gp - GearNet.b_c(a0)).angle())) * 60.0
			if g.placement_problem(0, k, c, true) != "" or not g.margin_free(c, size):
				if OS.has_environment("STUDY_DEBUG"):
					print("    dbg %s %s: %s / margin %s" % [k, str(c), g.placement_problem(0, k, c, true), str(g.margin_free(c, size))])
				continue
			if g.gear_net.candidate(0, k, c, big)["state"] != "ok":
				if OS.has_environment("STUDY_DEBUG"):
					print("    dbg %s %s: gear %s" % [k, str(c), str(g.gear_net.candidate(0, k, c, big))])
				continue
			cands.append([score, c])
	if cands.is_empty():
		return Vector2i(-1, -1)
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if room.is_empty():
		return cands[0][1]
	var best := Vector2i(-1, -1)
	var bs := INF
	for i in mini(cands.size(), 30):
		var c: Vector2i = cands[i][1]
		var short := room.size() - _room(k, c, big, room)
		var s2: float = float(cands[i][0]) + 1000.0 * short
		if s2 < bs:
			bs = s2
			best = c
	return best


## How many of `users` (kinds, or [kind, big]) could still be placed, one after another, each meshing with a ring of kind k
## put at cell c: a greedy count that keeps the new rings off each other, off the real rings and off the footprints.
func _room(k: String, c: Vector2i, big: bool, users: Array) -> int:
	var T := float(Defs.TILE)
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var gc := GearNet.gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
	var r := GearNet.ring_r(k, size, big)
	var placed: Array = [[gc, r, Rect2i(c, size)]]
	var real: Array = []
	for b in g.buildings:
		if b.team == 0 and not b.dead and GearNet.has_gear(b):
			real.append([GearNet.b_c(b), GearNet.b_r(b)])
	var n := 0
	g._gear_relax = true
	for u in users:
		var uk: String = u[0] if u is Array else u
		var ub: bool = bool(u[1]) if u is Array else false
		var us: Vector2i = Defs.BUILDINGS[uk]["size"]
		var ur := GearNet.ring_r(uk, us, ub)
		var found := false
		for y in range(c.y - 10, c.y + 11):
			if found:
				break
			for x in range(c.x - 10, c.x + 11):
				var c2 := Vector2i(x, y)
				if not g.in_map(c2):
					continue
				var g2 := GearNet.gpos(Vector2(c2) * T + Vector2(us) * T * 0.5)
				var gap := g2.distance_to(gc) - ur - r
				if gap < -over or gap > slack:
					continue
				var bad := false
				for p in placed:
					if g2.distance_to(p[0]) - ur - float(p[1]) < -over or Rect2i(c2, us).grow(1).intersects(p[2]):
						bad = true
						break
				if not bad:
					for q in real:
						if g2.distance_to(q[0]) - ur - float(q[1]) < -over:
							bad = true
							break
				if bad or g.placement_problem(0, uk, c2, true) != "" or not g.margin_free(c2, us):
					continue
				if GearNet.foot_level(g, c2, us) != GearNet.foot_level(g, c, size) or not GearNet.joint_ok(g, g2, ur, gc, r, GearNet.foot_level(g, c, size)):
					continue          # (gears mesh only on the same ground level)
				placed.append([g2, ur, Rect2i(c2, us)])
				n += 1
				found = true
				break
	g._gear_relax = false
	return n
