extends SceneTree
## ECONOMY MEASURED (docs/cw_economy_study.md): one match of two computers (or one computer against a passive dummy), to
## `secs`, with every source of income counted for the Crown and the Clockwork, a line a minute and one RESULT line (JSON)
## at the end that tools/study/cw_economy_report.py combines into tables and charts.
##
##   godot --headless --fixed-fps 30 --script res://tools/measure_economy.gd -- \
##       [map:greenhold] [seed:1] [a:crown] [b:clockwork] [wa:hard] [wb:hard|idle] [secs:900] [ms:0|1|2] [tag:x]
##
## a / b: the factions of side 0 and side 1. wa / wb: "hard" (the Hard computer, Balanced), "idle" (a passive dummy: the
## human slot, nobody plays it). With an idle side the computer is PEACEFUL (AI.peaceful: it builds its economy and army
## but never attacks): pure economy. ms: the TEST-ONLY cap on Mainsprings per Clocktower (Defs.econ_test; 0 = no cap, as
## in the game today). Gameplay code is untouched by this tool; Defs.econ_test is empty in every real match.
##
## What it counts, per side, cumulative (the live economy only, gear mode):
##   Clockwork cogs: each Cog Press (Building.press_paid), the Great Winder's SWEEP (its "gw_cogs"), and "other" (any cogs
##     earned that neither explains: should be 0; anything else would be retired code still paying).
##   Clockwork Tension: each Mainspring (its spring_rate() summed every tick, scaled to the side's "tension_in"), seconds
##     with the pool full (springs standing still), the store (cap).
##   Crown gold: Farm harvests (every gold earned comes from Game.harvest; "other" checks it), powder from Powder Mills
##     ("res2_in"), soil and saltpetre left.
##   Spending: units trained (cost, cost2 / Tension), buildings placed, the rest (research, repair, gear swaps) as a residual.
##   Army value: what the living army cost (cost + powder or Tension), every minute.
var main: Node
var g
var t := 0.0
var opt := {"map": "greenhold", "seed": "1", "a": "crown", "b": "clockwork", "wa": "hard", "wb": "hard", "secs": "900", "ms": "0", "tag": ""}
var next_min := 60.0
var res := {}
var side := [{}, {}]             # per side: trackers
var started := false


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			opt[kv[0]] = kv[1]
	var ms := int(opt["ms"])
	if ms > 0:
		Defs.econ_test = {"clockwork": {"mainspring": ms}}      # (test-only: Defs.econ_per_hall)
	res = {"tag": opt["tag"], "map": opt["map"], "seed": int(opt["seed"]), "a": opt["a"], "b": opt["b"], "wa": opt["wa"], "wb": opt["wb"],
		"ms": ms, "version": ProjectSettings.get_setting("application/config/version", "dev"), "min": [], "winner": -1, "end": 0}


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opt["seed"]))
		var slots := []
		for i in 2:
			var w: String = opt["wa"] if i == 0 else opt["wb"]
			slots.append({"who": "hard" if w == "hard" else "you", "faction": opt["a"] if i == 0 else opt["b"], "colour": i, "side": i, "strategy": "balanced"})
		main.start({"map": opt["map"], "seed": int(opt["seed"]), "slots": slots})
		g = main.game
		var idle: bool = opt["wa"] == "idle" or opt["wb"] == "idle"
		for ai in g.ais:
			if idle:
				ai.peaceful = true
		for i in 2:
			side[i] = {"press": {}, "press_order": [], "spring": {}, "spring_order": [], "spring_born": {}, "gw": {}, "full_s": 0.0,
				"units_seen": {}, "bld_seen": {}, "spend_units": 0.0, "spend_workers": 0.0, "spend_bld": 0.0, "spend_t_units": 0.0,
				"spend_t_bld": 0.0, "spend_powder_units": 0.0, "trained": {}, "built": {}, "firsts": {}, "farm_order": [], "farm": {},
				"mill": {}, "lode_gone": -1, "soil_gone": -1}
		started = true
		return false
	if not started or g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for i in 2:
		_tick(i, delta)
	if g.clock >= next_min:
		next_min += 60.0
		var row := [_snap(0), _snap(1)]
		res["min"].append(row)
		for i in 2:
			print(_line(i, row[i]))
	if g.clock >= float(opt["secs"]) or g.over:
		res["winner"] = g.winner if g.over else -1
		res["end"] = int(g.clock)
		if g.over:
			res["min"].append([_snap(0), _snap(1)])
		for i in 2:
			res["firsts%d" % i] = side[i]["firsts"]
			res["trained%d" % i] = side[i]["trained"]
			res["built%d" % i] = side[i]["built"]
		print("RESULT " + JSON.stringify(res))
		quit()
	return false


func _fac(i: int) -> String:
	return g.faction_of(i)


func _unit_value(u) -> float:
	var d: Dictionary = u.d
	return float(d.get("cost", 0)) / maxf(1.0, float(d.get("spawn", 1))) + float(d.get("cost2", 0)) + float(Defs.tension_cost(d))


## Every tick: per-building income, new units and buildings (what was spent), the Tension pool standing full.
func _tick(i: int, delta: float) -> void:
	var s: Dictionary = side[i]
	var fac := _fac(i)
	for b in g.buildings:
		if b.team != i:
			continue
		var id: int = b.get_instance_id()
		# counted once FINISHED (a site cancelled is refunded: not spent); "firsts" is when the first one was finished
		if b.built and not s["bld_seen"].has(id):
			s["bld_seen"][id] = true
			if g.clock > 1.0:          # (the start buildings were not bought)
				s["spend_bld"] += float(b.d.get("cost", 0))
				s["spend_t_bld"] += float(Defs.tension_cost(b.d))
				s["built"][b.kind] = int(s["built"].get(b.kind, 0)) + 1
			if not s["firsts"].has(b.kind):
				s["firsts"][b.kind] = int(g.clock)
		if b.dead:
			continue
		match b.kind:
			"cog_press":
				if not s["press"].has(id):
					s["press_order"].append(id)
				s["press"][id] = float(b.press_paid)
			"mainspring":
				if not s["spring"].has(id):
					s["spring_order"].append(id)
					s["spring"][id] = 0.0
				s["spring"][id] += b.spring_rate() * delta
			"farm":
				if not s["farm"].has(id):
					s["farm_order"].append(id)
					s["farm"][id] = 0
	if fac == "clockwork" and GearEcon.tension_full(g, i):
		s["full_s"] += delta
	for u in g.units:
		if u.team != i:
			continue
		var uid: int = u.get_instance_id()
		if s["units_seen"].has(uid):
			if u.kind == Defs.GREAT_WINDER_KIND:
				s["gw"][uid] = int(u.get_meta("gw_cogs", 0))
			continue
		s["units_seen"][uid] = true
		if g.clock <= 1.0:
			continue          # (the start workers)
		var d: Dictionary = u.d
		if u.kind == "dismounted":
			d = {}             # (a Cuirassier off his horse: nothing bought)
		elif u.kind == Defs.OWL:
			d = Defs.OWL_MORPH     # (a Swift rebuilt: MORPH TO OWL's price)
		var c := float(d.get("cost", 0)) / maxf(1.0, float(d.get("spawn", 1)))
		if u.is_worker():
			s["spend_workers"] += c
		else:
			s["spend_units"] += c
			s["spend_powder_units"] += float(d.get("cost2", 0))
		s["spend_t_units"] += float(Defs.tension_cost(d))
		s["trained"][u.kind] = int(s["trained"].get(u.kind, 0)) + 1
		if not s["firsts"].has(u.kind):
			s["firsts"][u.kind] = int(g.clock)


func _snap(i: int) -> Dictionary:
	var s: Dictionary = side[i]
	var fac := _fac(i)
	var p: Dictionary = g.players[i]
	var st: Dictionary = g.stats[i]
	var army := 0.0
	var army_n := 0
	for u in g.army(i):
		if u.kind == "horse":
			continue
		army += _unit_value(u)
		army_n += 1
	var r := {"m": int(round(g.clock / 60.0)), "fac": fac, "earned": int(st["gold"]), "bank": int(p["gold"]), "workers": g.workers(i).size(),
		"supply": g.supply_used(i), "cap": int(p.get("cap", 0)), "army": int(army), "army_n": army_n, "halls": g.halls_of(i).size(),
		"spend_units": int(s["spend_units"]), "spend_workers": int(s["spend_workers"]), "spend_bld": int(s["spend_bld"]),
		"lost": int(st["lost"]), "killed": int(st["value_killed"]), "repair": int(st.get("repair", 0.0)), "spent_stat": int(st.get("spent", 0))}
	var hl := []
	for h in g.halls_of(i, false):
		hl.append([int(h.soil) if fac == "crown" else 0, int(h.lode), 1 if h.built else 0])
	r["hall_list"] = hl
	if fac == "clockwork":
		var presses := []
		var ptot := 0.0
		for id in s["press_order"]:
			presses.append(int(s["press"][id]))
			ptot += float(s["press"][id])
		var gw := 0
		for id in s["gw"]:
			gw += int(s["gw"][id])
		var tin := float(st.get("tension_in", 0.0))
		var raw := 0.0
		for id in s["spring_order"]:
			raw += float(s["spring"][id])
		var springs := []
		for id in s["spring_order"]:
			springs.append(int(round(float(s["spring"][id]) * (tin / raw if raw > 0.0 else 0.0))))
		var lode := 0.0
		var lode_full := 0.0
		for h in g.halls_of(i):
			lode += h.lode
			lode_full += h.lode_full()
		var np := 0
		var npb := 0
		var crew_p := 0
		var ns := 0
		var crew_s := 0
		var rate_p := 0.0
		var rate_s := 0.0
		for b in g.buildings:
			if b.team != i or b.dead or not b.built:
				continue
			if b.kind == "cog_press":
				np += 1
				npb += 1 if b.gear_big else 0
				crew_p += b.working_crew()
				rate_p += b.press_rate()
			elif b.kind == "mainspring":
				ns += 1
				crew_s += b.working_crew()
				rate_s += b.spring_rate()
		r.merge({"press": int(ptot), "presses": presses, "sweep": gw, "other": int(st["gold"]) - int(round(ptot)) - gw,
			"tension_in": int(tin), "springs": springs, "tension": int(g.tension(i)), "tension_cap": int(GearEcon.tension_cap(g, i)),
			"full_s": int(s["full_s"]), "spend_t_units": int(s["spend_t_units"]), "spend_t_bld": int(s["spend_t_bld"]),
			"lode": int(lode), "lode_full": int(lode_full), "n_press": np, "n_press_big": npb, "crew_press": crew_p, "n_spring": ns,
			"crew_spring": crew_s, "rate_press": snappedf(rate_p, 0.01), "rate_spring": snappedf(rate_s, 0.01)})
	elif fac == "brood":
		# the Brood (no halls): its grubs, rooted Rootmaws and the ground they still hold, the spoils it took in
		var maws := 0
		var ground := 0.0
		var md: Array = []          # (each rooted Rootmaw's distance from the Mother, tiles, and its ground left)
		var q0 := BroodNew.queen(g, i)
		for u in g.units:
			if u.team == i and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
				maws += 1
				ground += BroodNew.ground_left(g, u)
				if q0:
					md.append("%d:%d" % [int(round(q0.position.distance_to(u.position) / Defs.TILE)), int(BroodNew.ground_left(g, u))])
		r["maws"] = " ".join(md)
		var grubs := 0
		for u in g.workers(i):
			grubs += 1
		var turtles := 0
		var far := 0
		var q := BroodNew.queen(g, i)
		for u in g.units:
			if u.team == i and not u.dead and u.kind == BroodNew.TURTLE and BroodNew.rooted(u):
				turtles += 1
				if q != null and u.position.distance_to(q.position) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE:
					far += 1
		r.merge({"turtles": turtles, "far": far})
		r.merge({"powder_in": int(st["res2_in"]), "powder": int(p["res2"]), "soil": int(ground), "salt": 0, "n_farm": maws,
			"crew_farm": grubs, "n_mill": 0, "crew_mill": 0, "spend_powder_units": int(s["spend_powder_units"])})
	else:
		var soil := 0.0
		var salt := 0.0
		for h in g.halls_of(i):
			soil += h.soil
			salt += h.lode
		var nf := 0
		var crew_f := 0
		var nm := 0
		var crew_m := 0
		for b in g.buildings:
			if b.team != i or b.dead or not b.built:
				continue
			if b.kind == "farm":
				nf += 1
				crew_f += b.working_crew()
			elif b.kind == "powder_mill":
				nm += 1
				crew_m += b.working_crew()
		r.merge({"powder_in": int(st["res2_in"]), "powder": int(p["res2"]), "soil": int(soil), "salt": int(salt), "n_farm": nf,
			"crew_farm": crew_f, "n_mill": nm, "crew_mill": crew_m, "spend_powder_units": int(s["spend_powder_units"])})
	return r


func _line(i: int, r: Dictionary) -> String:
	if r["fac"] == "clockwork":
		return "%2d:00 t%d CW earned %d (press %d sweep %d other %d) bank %d | tension in %d (%s) bank %d/%d full %ds | presses %d(%d big) crew %d, springs %d crew %d | lode %d | workers %d army %d (%d) supply %d/%d halls %d" % [
			r["m"], i, r["earned"], r["press"], r["sweep"], r["other"], r["bank"], r["tension_in"], str(r["springs"]), r["tension"], r["tension_cap"],
			r["full_s"], r["n_press"], r["n_press_big"], r["crew_press"], r["n_spring"], r["crew_spring"], r["lode"], r["workers"], r["army"], r["army_n"],
			r["supply"], r["cap"], r["halls"]]
	if r["fac"] == "brood":
		return "%2d:00 t%d BR earned %d bank %d | spoils in %d bank %d | rootmaws %d grubs %d | turtles %d (%d far) | ground %d | army %d (%d) supply %d/%d" % [
			r["m"], i, r["earned"], r["bank"], r["powder_in"], r["powder"], r["n_farm"], r["crew_farm"], r.get("turtles", 0), r.get("far", 0), r["soil"], r["army"], r["army_n"],
			r["supply"], r["cap"]] + " | maws %s" % r.get("maws", "")
	return "%2d:00 t%d CR earned %d bank %d | powder in %d bank %d | farms %d crew %d mills %d crew %d | soil %d salt %d | workers %d army %d (%d) supply %d/%d halls %d" % [
		r["m"], i, r["earned"], r["bank"], r["powder_in"], r["powder"], r["n_farm"], r["crew_farm"], r["n_mill"], r["crew_mill"], r["soil"], r["salt"],
		r["workers"], r["army"], r["army_n"], r["supply"], r["cap"], r["halls"]]
