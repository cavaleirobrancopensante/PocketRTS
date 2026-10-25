extends SceneTree
## Economy benchmark: measures how much each faction's economy earns, with nothing attacking.
##
## Usage (always with --fixed-fps 30, so the sim runs as fast as the CPU allows while every
## physics tick stays exactly 1/30 s, the same as a real match):
##
##   godot --headless --fixed-fps 30 --script res://tools/econ_bench.gd -- <mode> [faction] [key=value ...]
##
## Modes:
##   ai <faction>      The faction's Hard computer player (balanced strategy, AI.peaceful on, so
##                     it builds its normal economy and army but never attacks) against an idle
##                     opponent on a fixed map. One CSV row per game minute: income of each
##                     resource in that minute, banked amounts, workers, economy buildings, supply.
##                     Options: minutes=10 map=greenhold seed=1 opp=<faction>
##   sat <faction>     Saturation test: one hall with every economy structure its limit allows,
##                     placed with the AI's own placement (AI._econ_spot), and N workers sent to
##                     work the way the game assigns them (Game.free_site). Steady-state income
##                     per minute after a warm-up, for each N. No AI runs.
##                     Options: n=4,8,12,16,20,24 warm=60 measure=240 map=greenhold seed=1
##   pits              Brood only: one Feeding Pit at each hive distance (tiles, centre to
##                     centre) with a full crew of 5 grubs; food value, loads and food per minute.
##                     Options: d=6,9,12,15,18,21,24,27 warm=25 measure=120
##   crush             Clockwork only: one Boiler beside the Clocktower and one Ore Crusher at
##                     each distance from it, with W Winders; trip time, charge per battery,
##                     overloads, ore per minute.
##                     Options: d=4,6,8,11,14,18,24 w=7 warm=25 measure=120
##   all               ai + sat for all three factions, then pits and crush (long: ~30-40 min).
##
## Output: CSV files in tools/econ_bench_out/ (<mode>_<faction>.csv), and a summary on stdout.
## Uses only debug hooks that are off in real matches (AI.peaceful) and the "res2_in" statistic
## (secondary resource earned). Gameplay code is untouched.

const OUT_DIR := "res://tools/econ_bench_out"
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


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode := "ai"
	var fac := "crown"
	var pos: Array = []
	for a in args:
		if "=" in a:
			var kv: PackedStringArray = a.split("=", true, 1)
			opts[kv[0]] = kv[1]
		else:
			pos.append(a)
	if pos.size() > 0:
		mode = pos[0]
	if pos.size() > 1:
		fac = pos[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	wall0 = Time.get_ticks_msec()
	match mode:
		"ai":
			await _ai_run(fac)
		"sat":
			await _sat_run(fac)
		"pits":
			await _pit_sweep()
		"crush":
			await _crush_sweep()
		"all":
			for f in ["crown", "brood", "clockwork"]:
				await _ai_run(f)
			for f in ["crown", "brood", "clockwork"]:
				await _sat_run(f)
			await _pit_sweep()
			await _crush_sweep()
		_:
			print("unknown mode ", mode)
	print("done in %.1f s wall" % ((Time.get_ticks_msec() - wall0) / 1000.0))
	quit()


func _opt(k: String, def: Variant) -> Variant:
	if not opts.has(k):
		return def
	var v: String = opts[k]
	if def is int:
		return int(v)
	if def is float:
		return float(v)
	if def is Array:
		var out: Array = []
		for p in v.split(","):
			out.append(float(p) if "." in p else int(p))
		return out
	return v


# ------------------------------------------------------------------ match setup

## A match on a fixed map. `ai_team0`: team 0 is a (peaceful) computer player; otherwise
## team 0 is the "human" slot (no AI) and the opponent's AI is switched off too.
func _start(fac: String, opp: String, ai_team0: bool) -> Game:
	var slots := [
		{"who": "hard" if ai_team0 else "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "you" if ai_team0 else "hard", "faction": opp, "colour": 1, "side": 1, "strategy": "balanced"},
	]
	seed(int(_opt("seed", 1)))
	main.start({"map": _opt("map", "greenhold"), "slots": slots, "seed": int(_opt("seed", 1))})
	var g: Game = main.game
	for ai in g.ais:
		if ai.team == 0 and ai_team0:
			ai.peaceful = true
		else:
			ai.peaceful = true
			ai.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	return g


func _hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and not b.dead and b.kind == g.faction_hall(t):
			return b
	return null


func _built(g: Game, t: int, kind: String) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == t and not b.dead and b.built and b.kind == kind)


func _speed_note(g: Game) -> String:
	var w := (Time.get_ticks_msec() - wall0) / 1000.0
	return "(game %.0f s, x%.1f real time)" % [g.clock, g.clock / maxf(w, 0.001)]


# ------------------------------------------------------------------ per-frame trackers

## Watches team `t` every physics tick and counts what the economy does.
class Tracker:
	var g: Game
	var t: int
	var fac: String
	var w_carry := {}        # unit -> [carrying, carry_t, carry_blue, home]
	var bat_t := {}          # building -> last _bat_t
	var farm_g := {}         # farm -> last growth
	var only: Building = null  # count batteries of this building only
	# counters (reset with snapshot())
	var c := {}

	func _init(game: Game, team: int) -> void:
		g = game
		t = team
		fac = g.faction_of(t)
		reset()

	func reset() -> void:
		c = {"deliveries": 0, "delivered": 0.0, "carry_t": 0.0, "blasts": 0, "bat_made": 0,
			"stall_s": 0.0, "loads": 0, "food": 0.0, "harvests": 0, "growth_gold": 0.0,
			"by_pit": {}, "work_s": 0.0, "worker_s": 0.0}

	func tick(dt: float) -> void:
		for u in g.units:
			if u.team != t or u.dead or not u.is_worker():
				continue
			c["worker_s"] += dt
			if u.order == "gather" and u.home_mine != null:
				c["work_s"] += dt
			var prev: Array = w_carry.get(u, [0, 0.0, false, null])
			if fac == "clockwork":
				if prev[0] > 0 and u.carrying == 0:
					if u.carry_empty:
						var ct: float = prev[1] + dt
						c["deliveries"] += 1
						c["carry_t"] += ct
						c["delivered"] += roundf(Defs.battery_charge(prev[2], ct) * float(Defs.BATTERY["ore"]))
					else:
						c["blasts"] += 1
				w_carry[u] = [u.carrying, u.carry_t, u.carry_blue, u.home_mine]
			elif fac == "brood":
				if prev[0] > 0 and u.carrying == 0 and u.order == "gather":
					c["loads"] += 1
					c["food"] += prev[0]
					var pit = prev[3]
					if pit != null and is_instance_valid(pit):
						var key := str(pit.get_instance_id())
						var bp: Dictionary = c["by_pit"].get(key, {"loads": 0, "food": 0.0, "value": prev[0]})
						bp["loads"] += 1
						bp["food"] += prev[0]
						c["by_pit"][key] = bp
				w_carry[u] = [u.load_f if u.carrying > 0 else 0.0, 0.0, false, u.home_mine]
		for b in g.buildings:
			if b.team != t or b.dead or not b.built:
				continue
			if only != null and b != only:
				continue
			if b.d.has("battery"):
				var last: float = bat_t.get(b, b._bat_t)
				if b._bat_t < last - 1e-6:
					c["bat_made"] += 1
				bat_t[b] = b._bat_t
				if b.batteries >= int(b.d["battery"][1]):
					c["stall_s"] += dt
			elif b.kind == "farm":
				var lg: float = farm_g.get(b, b.growth)
				if b.growth < lg - 1e-6:
					c["harvests"] += 1
					c["growth_gold"] += (1.0 - lg + b.growth) * g.harvest_value(b)
				else:
					c["growth_gold"] += (b.growth - lg) * g.harvest_value(b)
				farm_g[b] = b.growth


# ------------------------------------------------------------------ mode: ai

func _ai_run(fac: String) -> void:
	var opp: String = _opt("opp", "crown" if fac != "crown" else "brood")
	var minutes: int = _opt("minutes", 10)
	var g := await _start(fac, opp, true)
	var tr := Tracker.new(g, 0)
	var res: Array = Defs.FACTIONS[fac]["res"]
	var econ: Array = Defs.FACTIONS[fac]["econ"].keys()
	var extra_kinds: Array = {"crown": ["cottage"], "brood": ["clutch_mound"], "clockwork": ["spring_tower", "charging_pylon"]}[fac]
	var head := ["minute", "income_" + res[0].to_lower(), "income_" + res[1].to_lower() + ("_batteries_filled" if fac == "clockwork" else ""),
		"bank_" + res[0].to_lower(), "bank_" + res[1].to_lower(), "spent", "workers", "workers_at_work", "halls"]
	for k in econ:
		head.append(k)
	for k in extra_kinds:
		head.append(k)
	head += ["crew_slots", "supply_used", "supply_cap", "army_supply", "army_value"]
	match fac:
		"crown":
			head += ["harvests", "farm_gold_incl_growth", "soil_pct_per_hall", "saltpetre_pct_per_mill"]
		"brood":
			head += ["food_loads", "avg_load_value", "pit_dists_tiles", "pit_values", "ground_pct_per_hive", "sacrificed", "essence_from_sacrifice"]
		"clockwork":
			head += ["deliveries", "avg_trip_s", "avg_charge", "overloads", "battery_stall_s", "ore_pct_per_crusher"]
	var rows: Array = [head]
	var last_gold := 0
	var last_r2 := 0.0
	var last_spent := 0
	print("== ai %s vs idle %s on %s, %d min" % [fac, opp, g.map_name, minutes])
	for m in minutes:
		tr.reset()
		var end := float(m + 1) * 60.0
		while g.clock < end and not g.over:
			await physics_frame
			tr.tick(DT)
		var st: Dictionary = g.stats[0]
		var inc1: int = int(st["gold"]) - last_gold
		var inc2: float = float(tr.c["bat_made"]) if fac == "clockwork" else float(st["res2_in"]) - last_r2
		last_gold = int(st["gold"])
		last_r2 = float(st["res2_in"])
		var spent: int = int(st["spent"]) - last_spent
		last_spent = int(st["spent"])
		var ws := g.workers(0)
		var working := ws.filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
		var crew := 0
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.built:
				crew += int(b.d.get("crew", 0))
		var army := g.army(0)
		var av := 0
		var asup := 0
		for u in army:
			av += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
			asup += int(u.d["supply"])
		var row: Array = [m + 1, inc1, snappedf(inc2, 0.1), g.players[0]["gold"], snappedf(float(g.players[0]["res2"]), 0.1), spent,
			ws.size(), working, _built(g, 0, g.faction_hall(0)).size()]
		for k in econ:
			row.append(_built(g, 0, k).size())
		for k in extra_kinds:
			row.append(_built(g, 0, k).size())
		row += [crew, g.supply_used(0), g.players[0]["cap"], asup, av]
		match fac:
			"crown":
				var soil: Array = []
				for h in g.halls_of(0):
					soil.append(int(round(h.soil_left() * 100)))
				row += [tr.c["harvests"], int(tr.c["growth_gold"]), " ".join(soil.map(func(x): return str(x))), _dep_pcts(g, "powder_mill")]
			"brood":
				var ds: Array = []
				var vs: Array = []
				for p in _built(g, 0, "feeding_pit"):
					var hv := g.nearest_hall(p.center(), 0)
					if hv:
						ds.append(snappedf(hv.center().distance_to(p.center()) / Game.T, 0.1))
						vs.append(snappedf(g.load_value(p), 0.1))
				var ground: Array = []
				for h in g.halls_of(0):
					ground.append(int(round(h.soil_left() * 100)))
				row += [tr.c["loads"], snappedf(tr.c["food"] / maxf(1, tr.c["loads"]), 0.1), " ".join(ds.map(func(x): return str(x))), " ".join(vs.map(func(x): return str(x))),
					" ".join(ground.map(func(x): return str(x))), int(g.stats[0].get("sacrificed", 0)), int(g.stats[0].get("sacrifice_essence", 0))]
			"clockwork":
				var n: int = tr.c["deliveries"]
				row += [n, snappedf(tr.c["carry_t"] / maxf(1, n), 0.01), snappedf(tr.c["delivered"] / maxf(1, n), 0.01), tr.c["blasts"], snappedf(tr.c["stall_s"], 0.1), _dep_pcts(g, "ore_crusher")]
		rows.append(row)
		print("  min %2d  %s=%d  %s=%.0f  bank=%d/%.0f  workers=%d (%d at work)  %s" % [m + 1, res[0], inc1, res[1], inc2,
			g.players[0]["gold"], float(g.players[0]["res2"]), ws.size(), working, _speed_note(g)])
	_write_csv("ai_%s.csv" % fac, rows)


## Share of its hall's saltpetre (ore) left (%) for each of team 0's Powder Mills (Ore Crushers).
func _dep_pcts(g: Game, kind: String) -> String:
	return " ".join(_built(g, 0, kind).map(func(b: Building) -> String: return str(int(round(b.lode_left() * 100)))))


# ------------------------------------------------------------------ mode: sat

## Fill one hall's economy slots the way the AI would place them (instantly built).
func _build_out(g: Game, t: int) -> void:
	var fac := g.faction_of(t)
	var helper := AI.new()
	helper.game = g
	helper.team = t
	var order: Array = []
	match fac:
		"crown":
			order = ["farm", "farm", "powder_mill"]
		"brood":
			order = ["feeding_pit", "feeding_pit", "feeding_pit", "brood_pen"]
		"clockwork":
			order = ["boiler", "ore_crusher", "boiler", "ore_crusher"]
	for k in order:
		if g.econ_count(t, k) >= g.econ_limit(t, k):
			continue
		var spot: Vector2i = helper._econ_spot(k)
		var tries := 0
		while spot.x < 0 and k == "feeding_pit" and tries < 3:
			# the AI pushes its swamp out with a Clutch Mound when a pit has no room
			var vs := g.find_spot(t, "clutch_mound", _hall(g, t), 6, 22, "far_safe")
			if vs.x >= 0:
				g._add_building("clutch_mound", t, vs, true)
				g._update_swamp()
			spot = helper._econ_spot(k)
			tries += 1
		if spot.x < 0:
			print("  no room for ", k)
			continue
		g._add_building(k, t, spot, true)
		g._update_swamp()
	helper.free()


func _clear_workers(g: Game, t: int) -> void:
	for u in g.workers(t):
		g.consume_unit(u)


func _spawn_workers(g: Game, t: int, n: int, assign := true) -> Array:
	var h := _hall(g, t)
	var hc := h.rect().get_center()
	var below: bool = g.starts[t].y < Game.H / 2
	var out: Array = []
	for i in n:
		var p := hc + Vector2(-90 + (i % 7) * 30, (80 + 26 * (i / 7)) * (1 if below else -1))
		p = g.cell_center(g.nearest_free(g.cell_of(p), 8))
		var u := g._add_unit(Defs.FACTIONS[g.faction_of(t)]["worker"], t, p)
		out.append(u)
		if assign:
			var site := g.free_site(t, u.position)
			if site:
				u.cmd_gather(site)
	return out


func _sat_run(fac: String) -> void:
	var ns: Array = _opt("n", [4, 8, 12, 16, 20, 24])
	var warm: float = _opt("warm", 60.0)
	var meas: float = _opt("measure", 240.0)
	var res: Array = Defs.FACTIONS[fac]["res"]
	var head := ["workers", "at_work", "crew_slots", "income_" + res[0].to_lower() + "_per_min", "income_" + res[1].to_lower() + "_per_min",
		"per_worker_" + res[0].to_lower(), "per_worker_" + res[1].to_lower()]
	match fac:
		"crown":
			head += ["harvests", "farm_crews", "mill_crew"]
		"brood":
			head += ["loads_per_min", "avg_load_value", "pit_dists_tiles", "pit_values", "pit_crews", "ground_drawn_per_min"]
		"clockwork":
			head += ["deliveries_per_min", "avg_trip_s", "avg_charge", "overloads", "batteries_filled_per_min", "battery_stall_s", "crews", "crusher_dists"]
	var rows: Array = [head]
	print("== sat %s (warm %d s, measure %d s)" % [fac, warm, meas])
	for n in ns:
		var g := await _start(fac, "crown" if fac != "crown" else "brood", false)
		_clear_workers(g, 0)
		_build_out(g, 0)
		if fac == "brood":
			_hall(g, 0).soil = 1e9      # (steady state: the Hive's ground never runs out here)
		_spawn_workers(g, 0, int(n))
		var tr := Tracker.new(g, 0)
		var t_end := g.clock + warm
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		tr.reset()
		var gold0 := int(g.stats[0]["gold"])
		var r20 := float(g.stats[0]["res2_in"])
		var c0 := g.clock
		t_end = g.clock + meas
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		var mins := (g.clock - c0) / 60.0
		var inc1 := (int(g.stats[0]["gold"]) - gold0) / mins
		if fac == "crown":
			inc1 = tr.c["growth_gold"] / mins     # harvests plus crop growth: no 40 s lumps
		var inc2 := (float(g.stats[0]["res2_in"]) - r20) / mins
		if fac == "clockwork":
			inc2 = tr.c["bat_made"] / mins
		var at_work := g.workers(0).filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
		var crew := 0
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.built:
				crew += int(b.d.get("crew", 0))
		var row: Array = [n, at_work, crew, int(inc1), snappedf(inc2, 0.1), snappedf(inc1 / n, 0.1), snappedf(inc2 / n, 0.01)]
		var extra := ""
		match fac:
			"crown":
				var crews: Array = []
				for f in _built(g, 0, "farm"):
					crews.append(f.working_crew())
				var mill: Array = _built(g, 0, "powder_mill")
				row += [tr.c["harvests"], " ".join(crews.map(func(x): return str(x))), mill[0].working_crew() if not mill.is_empty() else 0]
				extra = "farm crews %s" % [crews]
			"brood":
				var ds: Array = []
				var vs: Array = []
				var cs: Array = []
				for p in _built(g, 0, "feeding_pit"):
					var hv := g.nearest_hall(p.center(), 0)
					ds.append(snappedf(hv.center().distance_to(p.center()) / Game.T, 0.1))
					vs.append(snappedf(g.food_value(p), 0.1))
					cs.append(p.crew.size())
				row += [snappedf(tr.c["loads"] / mins, 0.1), snappedf(tr.c["food"] / maxf(1, tr.c["loads"]), 0.1),
					" ".join(ds.map(func(x): return str(x))), " ".join(vs.map(func(x): return str(x))), " ".join(cs.map(func(x): return str(x))),
					int((1e9 - _hall(g, 0).soil) / ((g.clock - c0) / 60.0 + warm / 60.0))]
				extra = "pits at %s tiles worth %s, crews %s" % [ds, vs, cs]
			"clockwork":
				var nd: int = tr.c["deliveries"]
				var cs: Array = []
				for b in g.buildings:
					if b.team == 0 and not b.dead and b.d.has("battery"):
						cs.append("%s:%d" % [b.kind, b.crew.size()])
				var cds: Array = []
				var hc := _hall(g, 0).center()
				for cr in _built(g, 0, "ore_crusher"):
					cds.append(snappedf(cr.center().distance_to(hc) / Game.T, 0.1))
				for bo in _built(g, 0, "boiler"):
					var near := g.nearest_of(bo.center(), 0, "ore_crusher")
					cds.append("boiler->crusher %.1f" % (near.center().distance_to(bo.center()) / Game.T))
				row += [snappedf(nd / mins, 0.1), snappedf(tr.c["carry_t"] / maxf(1, nd), 0.01), snappedf(tr.c["delivered"] / maxf(1, nd), 0.01),
					tr.c["blasts"], snappedf(tr.c["bat_made"] / mins, 0.1), snappedf(tr.c["stall_s"], 0.1), " ".join(cs), " ".join(cds.map(func(x): return str(x)))]
				extra = "trip %.2f s, charge %.2f, crews %s" % [tr.c["carry_t"] / maxf(1, nd), tr.c["delivered"] / maxf(1, nd), cs]
		rows.append(row)
		print("  N=%2d at_work=%d  %s/min=%d  %s/min=%.1f  %s %s" % [n, at_work, res[0], int(inc1), res[1], inc2, extra, _speed_note(g)])
	_write_csv("sat_%s.csv" % fac, rows)


# ------------------------------------------------------------------ mode: pits (Brood)

## A free spot for a building of `kind` whose centre is `d` tiles from `from`, with a
## clear straight line to it (so the walk is about the straight distance).
func _spot_at(g: Game, kind: String, from: Building, d: float, avoid: Array = []) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var c0: Vector2 = from.rect().get_center() / Game.T
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d) - 3, int(c0.y + d) + 3):
		for x in range(int(c0.x - d) - 3, int(c0.x + d) + 3):
			var cell := Vector2i(x, y)
			var cc := Vector2(cell) + Vector2(size) * 0.5
			var err := absf(cc.distance_to(c0) - d)
			if err > 0.75:
				continue
			var ok := true
			for yy in size.y:
				for xx in size.x:
					var q := cell + Vector2i(xx, yy)
					if not g.in_map(q) or not g.is_free(q):
						ok = false
			if not ok or not g.margin_free(cell, size):
				continue
			var too_close := false
			for a in avoid:
				if a.distance_to(cc) < 5.0:
					too_close = true
			if too_close:
				continue
			# prefer a clear walk: every tile on the line (outside the two buildings) is open
			var r0: Rect2 = from.rect().grow(4)
			var r1 := Rect2(Vector2(cell) * Game.T, Vector2(size) * Game.T).grow(4)
			var a0 := from.rect().get_center()
			var a1 := (cc) * Game.T
			var steps := int(a0.distance_to(a1) / 12.0) + 1
			var clear := true
			for s in steps + 1:
				var p := a0.lerp(a1, float(s) / steps)
				if r0.has_point(p) or r1.has_point(p):
					continue
				for off in [Vector2(-9, -9), Vector2(9, 9), Vector2(-9, 9), Vector2(9, -9)]:
					if not g.is_free(g.cell_of(p + off)):
						clear = false
			var score := err
			if not clear:
				# otherwise the shortest walk around whatever is in the way
				var path := g.find_path(a0, a1)
				var plen := 0.0
				var q0 := a0
				for q in path:
					plen += q0.distance_to(q)
					q0 = q
				if path.size() <= 1 or plen > a0.distance_to(a1) * 1.6:
					continue
				score = 10.0 + plen / maxf(1.0, a0.distance_to(a1))
			if score < bs:
				bs = score
				best = cell
	return best


func _pit_sweep() -> void:
	var ds: Array = _opt("d", [6, 9, 12, 15, 18, 21, 24, 27])
	var warm: float = _opt("warm", 25.0)
	var meas: float = _opt("measure", 120.0)
	var g := await _start("brood", "crown", false)
	_clear_workers(g, 0)
	for b in g.buildings.duplicate():
		if b.team == 0 and b.kind == "feeding_pit":
			b.die()
	var hive := _hall(g, 0)
	hive.soil = 1e9                 # (fresh ground throughout)
	var grubs := _spawn_workers(g, 0, 5, false)
	var rows: Array = [["dist_tiles", "walk_tiles", "food_value", "swamp_at_midpoint", "loads_per_min", "food_per_min", "per_grub_per_min", "cycle_s", "theory_cycle_offswamp_s"]]
	print("== pits: 5 grubs on one Feeding Pit at each distance from the Hive")
	for d in ds:
		var spot := _spot_at(g, "feeding_pit", hive, float(d))
		if spot.x < 0:
			print("  d=%s: no clear spot" % d)
			continue
		var pit := g._add_building("feeding_pit", 0, spot, true)
		g._update_swamp()
		for u in grubs:
			u.carrying = 0
			u.cmd_gather(pit)
		var tr := Tracker.new(g, 0)
		var t_end := g.clock + warm
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		tr.reset()
		var c0 := g.clock
		t_end = g.clock + meas
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		var mins := (g.clock - c0) / 60.0
		var real_d := hive.center().distance_to(pit.center()) / Game.T
		var val := snappedf(g.food_value(pit), 0.1)
		var lpm: float = tr.c["loads"] / mins
		var fpm: float = tr.c["food"] / mins
		# walk = centre distance less half of each building, at plain grub speed
		var walk := (real_d - 2.25 - 1.5) * Game.T
		var theory := Defs.PIT_TIME + 2.0 * walk / float(Defs.UNITS["grub"]["speed"])
		var mid := hive.center().lerp(pit.center(), 0.5)
		rows.append([snappedf(real_d, 0.1), snappedf(_walk_tiles(g, hive, pit), 0.1), val, g.on_swamp(0, mid), snappedf(lpm, 0.1), int(fpm), snappedf(fpm / 5.0, 0.1),
			snappedf(5.0 * 60.0 / maxf(lpm, 0.01), 0.1), snappedf(theory, 0.1)])
		print("  d=%.1f walk=%.1f value=%d  loads/min=%.1f food/min=%d per grub=%.1f cycle=%.1f s %s" % [real_d, _walk_tiles(g, hive, pit), val, lpm, fpm, fpm / 5.0, 5.0 * 60.0 / maxf(lpm, 0.01), _speed_note(g)])
		pit.die()
		await physics_frame
	_write_csv("pits_brood.csv", rows)


# ------------------------------------------------------------------ mode: crush (Clockwork)

func _crush_sweep() -> void:
	var ds: Array = _opt("d", [4, 6, 8, 11, 14, 18, 24])
	var nw: int = _opt("w", 7)
	var warm: float = _opt("warm", 25.0)
	var meas: float = _opt("measure", 120.0)
	var g := await _start("clockwork", "crown", false)
	_clear_workers(g, 0)
	for b in g.buildings.duplicate():
		if b.team == 0 and b.kind == "ore_crusher":
			b.die()
	await physics_frame
	var tower := _hall(g, 0)
	var bspot := g.find_spot(0, "boiler", tower, 4, 10, "behind")
	var boiler := g._add_building("boiler", 0, bspot, true)
	var ws := _spawn_workers(g, 0, nw, false)
	var rows: Array = [["dist_tiles", "walk_tiles", "winders", "deliveries_per_min", "avg_trip_s", "avg_charge", "ore_per_min", "per_winder_per_min", "overloads", "boiler_stall_s", "batteries_filled_per_min"]]
	print("== crush: %d Winders on one Boiler, one Ore Crusher at each distance" % nw)
	for d in ds:
		var spot := _spot_at(g, "ore_crusher", boiler, float(d), [tower.rect().get_center() / Game.T])
		if spot.x < 0:
			print("  d=%s: no clear spot" % d)
			continue
		var cr := g._add_building("ore_crusher", 0, spot, true)
		boiler.batteries = 0
		for u in ws:
			u.carrying = 0
			u.carry_t = 0.0
			u.cmd_gather(boiler)
		var tr := Tracker.new(g, 0)
		tr.only = boiler
		var t_end := g.clock + warm
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		tr.reset()
		var gold0 := int(g.stats[0]["gold"])
		var c0 := g.clock
		t_end = g.clock + meas
		while g.clock < t_end:
			await physics_frame
			tr.tick(DT)
		var mins := (g.clock - c0) / 60.0
		var real_d := boiler.center().distance_to(cr.center()) / Game.T
		var nd: int = tr.c["deliveries"]
		var ore := (int(g.stats[0]["gold"]) - gold0) / mins
		rows.append([snappedf(real_d, 0.1), snappedf(_walk_tiles(g, boiler, cr), 0.1), nw, snappedf(nd / mins, 0.1), snappedf(tr.c["carry_t"] / maxf(1, nd), 0.01), snappedf(tr.c["delivered"] / maxf(1, nd), 0.01),
			int(ore), snappedf(ore / nw, 0.1), tr.c["blasts"], snappedf(tr.c["stall_s"], 0.1), snappedf(tr.c["bat_made"] / mins, 0.1)])
		print("  d=%.1f walk=%.1f deliveries/min=%.1f trip=%.2f s charge=%.2f ore/min=%d per winder=%.1f overloads=%d stall=%.0f s %s" % [real_d, _walk_tiles(g, boiler, cr), nd / mins,
			tr.c["carry_t"] / maxf(1, nd), tr.c["delivered"] / maxf(1, nd), ore, ore / nw, tr.c["blasts"], tr.c["stall_s"], _speed_note(g)])
		cr.die()
		await physics_frame
	_write_csv("crush_clockwork.csv", rows)


## Length in tiles of the walk between two buildings (door to door, by the game's pathfinder).
func _walk_tiles(g: Game, a: Building, b: Building) -> float:
	var p0 := g.approach_point(a, b.center())
	var p1 := g.approach_point(b, a.center())
	var path := g.find_path(p0, p1)
	var plen := 0.0
	var q0 := p0
	for q in path:
		plen += q0.distance_to(q)
		q0 = q
	return plen / Game.T


# ------------------------------------------------------------------ output

func _write_csv(name: String, rows: Array) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	for r in rows:
		var cells: Array = []
		for v in r:
			var s := str(v)
			if "," in s or " " in s:
				s = "\"" + s + "\""
			cells.append(s)
		f.store_line(",".join(cells))
	f.close()
	print("wrote ", path)
