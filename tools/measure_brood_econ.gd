extends SceneTree
## Brood economy measurement (docs/brood_econ.md): where the Brood's biomass comes from and goes,
## every 30 game seconds, in a normal game (the Hard Brood computer against a Hard Crown or Clockwork
## computer, attacks on), and the same numbers for the opponent.
##
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_econ.gd -- opp=crown map=frostmere \
##       [swap=0] [seed=1] [minutes=12] [plan=balanced] [oplan=balanced] [peaceful=0] [perfect=0] [out=/abs/file.json]
##
## swap=1 puts the Brood on the map's second start. peaceful=1: neither computer attacks.
## perfect=1: the Brood is not played by its computer but by a scripted "perfect economy" (grubs nonstop,
## Clutch Mounds ahead of need, a new Feeding Pit as soon as the crews are full, nothing else: no army),
## and the opponent is peaceful, to see the ceiling of the Brood's economy.
## Prints one "ROW" line every 30 s and a "RESULT" json line at the end (also written to out=).
## Measurement only: no game file is changed.

var main: Node
var opts := {}
var g: Game = null
var t := 0.0
var started := false
var stop_at := 720.0
var bt := 0          # the Brood's team
var ot := 1
var rows: Array = []
var next_row := 30.0
var acc := {}                # per team: counters
var seen_units := {}         # instance id -> [team, kind, alive]
var seen_bld := {}           # instance id -> [team, kind, built]
var hall_level := {}         # instance id -> level
var last_scan := 0.0
var perfect := false
var pf_t := 0.0
var pit_life := {}
var sat_mode := false           # pit id -> {"b": built t, "s": spent t, "d": dist}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _opt(k: String, def: String) -> String:
	return String(opts.get(k, def))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and not started:
		started = true
		for a in OS.get_cmdline_user_args():
			if "=" in a:
				var kv: PackedStringArray = a.split("=", true, 1)
				opts[kv[0]] = kv[1]
		if _opt("mode", "game") == "sat":
			_sat.call_deferred()
			return false
		stop_at = float(_opt("minutes", "12")) * 60.0 + 1.0
		perfect = _opt("perfect", "0") == "1"
		seed(int(_opt("seed", "1")))
		var opp := _opt("opp", "crown")
		var swap := _opt("swap", "0") == "1"
		bt = 1 if swap else 0
		ot = 1 - bt
		var slots: Array = [{}, {}]
		slots[bt] = {"who": "hard", "faction": "brood", "colour": bt, "side": bt, "strategy": _opt("plan", "balanced")}
		slots[ot] = {"who": "hard", "faction": opp, "colour": ot, "side": ot, "strategy": _opt("oplan", "balanced")}
		main.start({"map": _opt("map", "frostmere"), "seed": int(_opt("seed", "1")), "slots": slots})
		return false
	if main.game == null or sat_mode:
		return false
	if g == null:
		g = main.game
		if g.ais.size() < 2:
			g = null
			return false
		if g.hud:
			g.hud.visible = false
			g.hud.process_mode = Node.PROCESS_MODE_DISABLED
		for ai in g.ais:
			if _opt("peaceful", "0") == "1" or perfect:
				ai.peaceful = true
			if perfect and ai.team == bt:
				ai.set_physics_process(false)
				ai.set_process(false)
				pf_helper = ai
		for tm in [bt, ot]:
			acc[tm] = {"spent": {}, "blocked_sup": 0.0, "blocked_egg": 0.0, "float": 0.0, "idle_w": 0.0,
				"w_lost": 0, "w_built": 0, "w_made": 0, "loads": 0, "load_val": 0.0, "pit_w_s": 0.0}
		print("MEASURE map=%s brood=%d opp=%s swap=%s perfect=%s version=%s" % [g.map_name, bt, g.faction_of(ot), _opt("swap", "0"), perfect,
			ProjectSettings.get_setting("application/config/version")])
	if perfect:
		_perfect_tick(delta)
	_tick(delta)
	if g.clock >= next_row:
		next_row += 30.0
		_row()
	if g.over or g.clock >= stop_at:
		_finish()
		return true
	return false


# ------------------------------------------------------------------ tracking

func _cost_of(kind: String, is_unit: bool) -> int:
	if is_unit:
		var d: Dictionary = Defs.UNITS.get(kind, {})
		return int(d.get("cost", 0)) / maxi(1, int(d.get("spawn", 1)))
	return int(Defs.BUILDINGS.get(kind, {}).get("cost", 0))


func _spend(tm: int, cat: String, v: float) -> void:
	var s: Dictionary = acc[tm]["spent"]
	s[cat] = float(s.get(cat, 0.0)) + v


func _cat_unit(k: String) -> String:
	return "workers" if k in ["grub", "labourer", "winder"] else "army"


func _tick(delta: float) -> void:
	# per frame: blocked states
	for tm in [bt, ot]:
		var a: Dictionary = acc[tm]
		var gold := int(g.players[tm]["gold"])
		var free := int(g.players[tm]["cap"]) - g.supply_used(tm)
		var capped := int(g.players[tm]["cap"]) >= g.max_supply(tm)
		if free < 1 and not capped and gold >= 50:
			a["blocked_sup"] += delta
		if gold >= 400:
			a["float"] += delta
		if tm == bt:
			var eggs := 0
			for h in g.buildings:
				if h.team == bt and h.built and not h.dead and h.kind == "hive":
					eggs += h.eggs
			if eggs == 0 and gold >= 75 and free >= 3:
				a["blocked_egg"] += delta
	last_scan += delta
	if last_scan < 0.5:
		return
	last_scan = 0.0
	var alive := {}
	for u in g.units:
		if u.dead or not (u.team in [bt, ot]):
			continue
		var id: int = u.get_instance_id()
		alive[id] = true
		if seen_units.has(id):
			seen_units[id][2] = u.order
		else:
			seen_units[id] = [u.team, u.kind, u.order]
			if g.clock > 1.0:
				_spend(u.team, _cat_unit(u.kind), _cost_of(u.kind, true))
				if u.is_worker():
					acc[u.team]["w_made"] += 1
		if u.is_worker():
			var busy: bool = u.order in ["gather", "build", "harvest", "repair"]
			if not busy:
				acc[u.team]["idle_w"] += 0.5
			if u.team == bt and u.order == "gather" and u.home_mine is Building and (u.home_mine as Building).kind == "feeding_pit":
				acc[bt]["pit_w_s"] += 0.5
	var new_bld := 0
	for b in g.buildings:
		if b.dead or not (b.team in [bt, ot]):
			continue
		var id: int = b.get_instance_id()
		if not seen_bld.has(id):
			seen_bld[id] = [b.team, b.kind]
			if g.clock > 1.0:
				_spend(b.team, "buildings", _cost_of(b.kind, false))
				_spend(b.team, "b:" + b.kind, 1)
				if b.team == bt and b.kind != "spore_vent":
					new_bld += 1
		if b.kind == "hive":
			var lv := int(b.level)
			var old := int(hall_level.get(id, 1 if g.clock > 1.0 else lv))
			if lv > old:
				for l in range(old + 1, lv + 1):
					_spend(b.team, "upgrades", float(Defs.HALL_LEVELS[l - 1].get("cost", 0)))
			hall_level[id] = lv
		if b.team == bt and b.kind == "feeding_pit" and b.built:
			if not pit_life.has(id):
				pit_life[id] = {"b": g.clock, "s": -1.0, "d": snappedf(g.capital_dist(bt, b.center()), 0.1), "x": -1.0}
			if float(pit_life[id]["s"]) < 0.0 and b.soil_left() <= 0.0:
				pit_life[id]["s"] = g.clock
	for id in pit_life:
		if not seen_bld.has(id) or float(pit_life[id]["x"]) >= 0.0:
			continue
		var still := false
		for b in g.buildings:
			if b.get_instance_id() == id and not b.dead:
				still = true
				break
		if not still:
			pit_life[id]["x"] = g.clock
	# grubs that vanished: turned into a building, or killed
	for id in seen_units.keys():
		var e: Array = seen_units[id]
		if e.size() < 4 and not alive.has(id):
			e.append(false)
			if e[1] in ["grub", "labourer", "winder"]:
				if int(e[0]) == bt and String(e[2]) == "build":
					acc[bt]["w_built"] += 1
				else:
					acc[e[0]]["w_lost"] += 1
	# research / other spending: whatever stats.spent shows beyond what we saw
	# (kept as "other" in the row)


func _econ(tm: int) -> Dictionary:
	var fac := g.faction_of(tm)
	var kinds: Array = {"brood": ["feeding_pit"], "crown": ["farm", "powder_mill"], "clockwork": ["cog_press", "mainspring"]}[fac]
	var n := 0
	var crew := 0
	var cap := 0
	var ground := 0.0
	var fresh := 0
	var vals: Array = []
	var dists: Array = []
	for b in g.buildings:
		if b.team != tm or b.dead or not b.built or not (b.kind in kinds):
			continue
		if b.kind != kinds[0]:
			continue
		n += 1
		crew += b.crew.size()
		cap += b.crew_max()
		var sl: float = b.soil_left()
		if sl > 0.0:
			fresh += 1
		if fac == "brood":
			ground += b.soil
			vals.append(snappedf(g.food_value(b), 0.1))
			dists.append(snappedf(g.capital_dist(tm, b.center()), 0.1))
	return {"n": n, "fresh": fresh, "crew": crew, "cap": cap, "ground": int(ground), "vals": vals, "dists": dists}


func _row() -> void:
	for tm in [bt, ot]:
		var a: Dictionary = acc[tm]
		var ws := g.workers(tm)
		var by := {}
		for u in ws:
			var k: String = u.order
			if u.order == "gather" and u.home_mine is Building:
				k = "at:" + (u.home_mine as Building).kind
			by[k] = int(by.get(k, 0)) + 1
		var eggs := 0
		var hatching := 0
		var halls := 0
		for h in g.buildings:
			if h.team == tm and h.built and not h.dead and h.uses_eggs():
				eggs += h.eggs
				hatching += h.queue.size()
				halls += 1
		var r := {"t": int(round(g.clock)), "team": tm, "fac": g.faction_of(tm), "earned": int(g.stats[tm]["gold"]),
			"spent_total": int(g.stats[tm]["spent"]), "bank": int(g.players[tm]["gold"]), "res2": snappedf(float(g.players[tm]["res2"]), 0.1),
			"res2_in": snappedf(float(g.stats[tm].get("res2_in", 0.0)), 0.1),
			"workers": ws.size(), "jobs": by, "army": g.army_value(tm), "supply": g.supply_used(tm), "cap": int(g.players[tm]["cap"]),
			"eggs": eggs, "hatching": hatching, "halls": halls, "econ": _econ(tm), "spent": (a["spent"] as Dictionary).duplicate(),
			"blocked_sup": snappedf(a["blocked_sup"], 0.1), "blocked_egg": snappedf(a["blocked_egg"], 0.1), "float400": snappedf(a["float"], 0.1),
			"idle_w_s": a["idle_w"], "w_lost": a["w_lost"], "w_built": a["w_built"], "w_made": a["w_made"], "pit_w_s": a["pit_w_s"]}
		rows.append(r)
		print("ROW ", JSON.stringify(r))


func _finish() -> void:
	_row()
	var res := {"map": g.map_name, "brood_team": bt, "opp": g.faction_of(ot), "swap": _opt("swap", "0"), "seed": int(_opt("seed", "1")),
		"perfect": perfect, "peaceful": _opt("peaceful", "0"), "winner": g.winner if g.over else -1, "end": int(g.clock),
		"version": ProjectSettings.get_setting("application/config/version"), "pits": pit_life.values(), "rows": rows}
	var s := JSON.stringify(res)
	print("RESULT ", s)
	var out := _opt("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(s)
			f.close()


# ------------------------------------------------------------------ the scripted "perfect" Brood economy

var pf_helper: AI = null


func _perfect_tick(delta: float) -> void:
	pf_t += delta
	if pf_t < 0.5:
		return
	pf_t = 0.0
	var gold := int(g.players[bt]["gold"])
	var cap := int(g.players[bt]["cap"])
	var free := cap - g.supply_used(bt)
	# supply: a Clutch Mound when 4 or less free (and none building)
	var going := 0
	for b in g.buildings:
		if b.team == bt and not b.dead and not b.built and b.kind in ["clutch_mound", "feeding_pit", "hive"]:
			going += 1
	var mounds_going := g.buildings.filter(func(b: Building) -> bool: return b.team == bt and not b.dead and not b.built and b.kind == "clutch_mound").size()
	if free <= 4 + 2 * _halls().size() and mounds_going == 0 and cap < g.max_supply(bt) and gold >= 75:
		var spot: Vector2i = pf_helper._mound_spot()
		if spot.x >= 0 and _build("clutch_mound", spot):
			gold -= 75
	# pits: a new one once the crews are nearly full
	var e := _econ(bt)
	var pits_going := g.buildings.filter(func(b: Building) -> bool: return b.team == bt and not b.dead and not b.built and b.kind == "feeding_pit").size()
	var grubs := g.workers(bt).size()
	if pits_going == 0 and grubs + 2 >= int(e["cap"]) and gold >= 75:
		var spot2: Vector2i = pf_helper._econ_spot("feeding_pit")
		if spot2.x >= 0 and _build("feeding_pit", spot2):
			gold -= 75
	# a second Burrow when every egg is taken for long (eggs, not biomass, hold the grubs back)
	if gold >= 350 + 50 and _halls().size() < 2 and g.clock > 180.0 and float(acc[bt]["blocked_egg"]) > 20.0:
		pf_helper._more_halls(true)
	# grubs from every egg
	for h in _halls():
		while h.eggs > 0 and int(g.players[bt]["gold"]) >= 50 and g.can_train(h, "grub") == "":
			g.train(h, "grub")
	# idle grubs to work
	for u in g.workers(bt):
		if u.order == "idle":
			var site := g.free_site(bt, u.position)
			if site:
				u.cmd_gather(site)


func _halls() -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == bt and not b.dead and b.built and b.kind == "hive")


func _build(kind: String, spot: Vector2i) -> bool:
	var n := g.buildings.size()
	pf_helper._construct(kind, spot)
	return g.buildings.size() > n


# ------------------------------------------------------------------ mode=sat: one economy building, its full crew

## One economy building of each faction with its full crew (the starting Feeding Pit, Farm and Cog Press of
## each faction's start on the map, or a pit placed `d` tiles out), steady income after a warm-up.
##   mode=sat fac=<brood|crown|clockwork> map=<id> [n=<workers>] [d=<tiles, brood: a pit that far>] [warm=40] [measure=240]
func _sat() -> void:
	sat_mode = true
	var fac := _opt("fac", "brood")
	var other := "crown" if fac != "crown" else "brood"
	seed(1)
	main.start({"map": _opt("map", "frostmere"), "seed": 1, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": int(_opt("side", "0"))},
		{"who": "hard", "faction": other, "colour": 1, "side": 1 - int(_opt("side", "0")), "strategy": "balanced"}]})
	g = main.game
	for ai in g.ais:
		ai.peaceful = true
		ai.set_physics_process(false)
	await physics_frame
	await physics_frame
	var tm := 0
	var kinds := {"brood": "feeding_pit", "crown": "farm", "clockwork": "cog_press"}
	var kind: String = kinds[fac]
	var site: Building = null
	for b in g.buildings:
		if b.team == tm and not b.dead and b.kind == kind:
			site = b
	var hall: Building = null
	for b in g.buildings:
		if b.team == tm and not b.dead and b.kind == g.faction_hall(tm):
			hall = b
	if fac == "brood" and _opt("d", "") != "":
		# a pit d tiles out instead (econ_bench's spot finder), the start pit removed
		var eb = load("res://tools/econ_bench.gd").new()
		var spot: Vector2i = eb._spot_at(g, "feeding_pit", hall, float(_opt("d", "12")))
		if site:
			site.die()
		site = g._add_building("feeding_pit", tm, spot, true)
		g._update_swamp()
	for u in g.workers(tm):
		g.consume_unit(u)
	var n := int(_opt("n", str(site.crew_max())))
	var hc := hall.rect().get_center()
	var ws: Array = []
	for i in n:
		var p := hc + Vector2(-90 + (i % 7) * 30, 90 + 26 * (i / 7))
		p = g.cell_center(g.nearest_free(g.cell_of(p), 8))
		var u := g._add_unit(Defs.FACTIONS[fac]["worker"], tm, p)
		u.cmd_gather(site)
		ws.append(u)
	var warm := float(_opt("warm", "40"))
	var meas := float(_opt("measure", "240"))
	var t0 := g.clock
	while g.clock < t0 + warm:
		await physics_frame
	var e0 := float(g.stats[tm]["gold"])
	var c0 := g.clock
	var crew_s := 0.0
	while g.clock < c0 + meas:
		await physics_frame
		crew_s += site.crew.size() / 30.0
	var mins := (g.clock - c0) / 60.0
	var inc := (float(g.stats[tm]["gold"]) - e0) / mins
	var bcost := int(Defs.BUILDINGS[kind]["cost"])
	var wcost := int(Defs.UNITS[Defs.FACTIONS[fac]["worker"]]["cost"])
	var invest := bcost + n * wcost + (wcost if fac == "brood" else 0)     # (a Brood building eats its grub)
	var dist := site.center().distance_to(hall.center()) / Game.T
	var r := {"fac": fac, "map": g.map_name, "kind": kind, "n": n, "crew_avg": snappedf(crew_s / (meas), 0.01), "dist": snappedf(dist, 0.1),
		"income_min": int(inc), "per_worker_min": snappedf(inc / n, 0.1), "invest": invest, "payback_min": snappedf(invest / maxf(inc, 0.01), 0.1),
		"load_value": snappedf(g.food_value(site), 0.1) if fac == "brood" else 0.0}
	print("SAT ", JSON.stringify(r))
	quit()
