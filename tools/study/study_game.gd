extends SceneTree
## ONE study game, headless, Hard AI on both sides. Measurement only: it never changes the game, the AI or any balance
## number (it reads state and, in fast mode, hides the HUD).
##   godot --headless --fixed-fps 30 --script res://tools/study/study_game.gd -- \
##       a:crown b:brood pa:balanced pb:balanced map:greenhold seed:1 swap:0 out:/abs/dir id:g0001 [end:1800] [fast:1] [gg:1]
## `a` plays slot 0 (and sits on the first spawn) unless swap:1, then `a` is slot 1 (the second spawn).
## (Time series columns 39-41, from stage 9 on: threat = an enemy unit is within 330 px of one of the AI's buildings, which makes
##  AI._army() return before its wave logic; attack_at = the army supply it wants for the next wave; siege = a wall siege plan is active.)
## Writes (atomically, tmp then rename):
##   <out>/games/<id>.json   one row: setup, result, per-side totals, tech timings, waves, supply-block seconds ...
##   <out>/ts/<id>.csv       one line per side every 30 game seconds (economy, army, losses ...)
##   <out>/logs/<id>.log     the match log lines (no sound log)
## The game ends at `end` seconds (default 30:00), on victory (a side has no buildings left), or when one side has been
## "hopeless" by AIResign.verdict (the computer's own gg rule) for SUSTAIN + REPLY_WINDOW seconds: the cause is then "gg"
## (a human would have answered the gg). gg:0 turns that off.
const SAMPLE := 30.0

var main: Node
var t := 0.0
var g
var fa := "crown"
var fb := "brood"
var pa := "balanced"
var pb := "balanced"
var map := "greenhold"
var seed_ := 1
var swap := false
var out_dir := ""
var gid := "g"
var end_t := 1800.0
var fast := true
var gg_cut := true
var inited := false
var wall0 := 0
var ais: Array = [null, null]
var T: Array = []                       # per team accumulators
var rows: Array = []                    # time series lines
var next_sec := 1.0
var next_sample := SAMPLE
var next_hope := 3.0
var last_sec := 0.0
var last_hope := 0.0
var seen: Dictionary = {}               # unit instance id -> [team, kind, value, counted_dead]
var live: Dictionary = {}               # unit instance id -> the unit while it is alive (checked for .dead every few frames)
var frame_n := 0
var bseen: Dictionary = {}              # building instance id -> true
var hashes := {}
var hash_at := [300.0, 600.0, 1200.0, 1800.0]
var cause := ""
var done := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)
		elif a.begins_with("pa:"):
			pa = a.substr(3)
		elif a.begins_with("pb:"):
			pb = a.substr(3)
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("swap:"):
			swap = a.substr(5) == "1"
		elif a.begins_with("out:"):
			out_dir = a.substr(4)
		elif a.begins_with("id:"):
			gid = a.substr(3)
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))
		elif a.begins_with("fast:"):
			fast = a.substr(5) == "1"
		elif a.begins_with("gg:"):
			gg_cut = a.substr(3) == "1"


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var slots: Array = []
		var facs := [fb, fa] if swap else [fa, fb]
		var plans := [pb, pa] if swap else [pa, pb]
		for i in 2:
			slots.append({"who": "hard", "faction": facs[i], "colour": i, "side": i, "strategy": plans[i]})
		main.start({"map": map, "seed": seed_, "slots": slots})
		wall0 = Time.get_ticks_msec()
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if not inited:
		if g.ais.size() < 2:
			return false
		inited = true
		_init_state()
	if done:
		return false
	_step()
	return done


func _init_state() -> void:
	for a in g.ais:
		ais[a.team] = a
	if fast and g.hud:
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 2:
		T.append({
			"first_built": {}, "halls": [], "produced": {}, "produced_value": {}, "lost_kind": {}, "lost_value": {}, "waves": [],
			"blocked_s": 0.0, "capped_s": 0.0, "bank500_s": 0.0, "bank1000_s": 0.0, "idle_w_s": 0.0, "worker_s": 0.0,
			"army_idle_s": 0.0, "army_s": 0.0, "prod_idle_s": 0.0, "prod_s": 0.0, "peak_supply": 0, "peak_workers": 0,
			"peak_gold": 0, "first_blood_t": -1.0, "first_attack_t": -1.0, "first_worker_lost_t": -1.0, "plan_changes": [],
			"strategy": String(ais[i].strategy), "attacking": false, "wave": {},
			"hope_since": -1.0, "hope_first": -1.0, "hope_reason": "", "hope_flips": 0, "gg_t": -1.0, "min_workers_after_3": 9999,
			"soil_zero_t": -1.0, "wall_start_t": -1.0, "wall_done_t": -1.0, "workers_lost": 0, "cap200_t": -1.0,
		})


func state_hash() -> int:
	var h := 17
	for u in g.units:
		if is_instance_valid(u):
			h = hash([h, u.kind, u.team, snappedf(u.position.x, 0.001), snappedf(u.position.y, 0.001), snappedf(u.hp, 0.001), u.dead])
	for b in g.buildings:
		if is_instance_valid(b):
			h = hash([h, b.kind, b.team, b.cell, snappedf(b.hp, 0.001), b.built])
	for p in g.players:
		h = hash([h, int(p["gold"]), snappedf(float(p["res2"]), 0.001)])
	return h


func _supply_of_army(team: int) -> int:
	var n := 0
	for u in g.army(team):
		n += int(u.d["supply"])
	return n


func _is_production(b) -> bool:
	for k in Defs.BUILDINGS[b.kind].get("trains", []):
		var ks := String(k)
		if Defs.UNITS.has(ks) and not Defs.is_worker(ks) and ks != "horse":
			return true
	return false


func _step() -> void:
	var clock: float = g.clock
	for h in hash_at:
		if clock >= h and not hashes.has(int(h)):
			hashes[int(h)] = state_hash()
	if g.over:
		cause = "victory"
		_finish()
		return
	frame_n += 1
	if frame_n % 6 == 0:
		_deaths()
	if clock >= next_sec:
		var dt := clock - last_sec
		last_sec = clock
		next_sec = clock + 1.0
		_second(dt)
	if clock >= next_hope:
		var dh := clock - last_hope
		last_hope = clock
		next_hope = clock + 3.0
		_hope(dh)
	if done:
		return
	if clock >= next_sample:
		next_sample += SAMPLE
		_sample()
	if clock >= end_t:
		cause = "timeout"
		_finish()


func _deaths() -> void:
	# Game.on_unit_died takes a unit out of g.units at once, but the Unit keeps `dead` = true for a while (its corpse):
	# a unit that vanished without being dead was turned into something else (mounted, hatched ...), not lost.
	for id in live.keys():
		var ref = live[id]
		if not is_instance_valid(ref):
			live.erase(id)
			continue
		if not ref.dead:
			continue
		live.erase(id)
		var rec: Array = seen[id]
		var tm: int = rec[0]
		var lt: Dictionary = T[tm]["lost_kind"]
		lt[rec[1]] = int(lt.get(rec[1], 0)) + 1
		var lv: Dictionary = T[tm]["lost_value"]
		lv[rec[1]] = int(lv.get(rec[1], 0)) + int(rec[2])
		if Defs.is_worker(rec[1]):
			T[tm]["workers_lost"] += 1
			if T[tm]["first_worker_lost_t"] < 0.0:
				T[tm]["first_worker_lost_t"] = snappedf(g.clock, 0.1)


func _second(dt: float) -> void:
	# new units, and units that left the list (killed: on_unit_died erases them at once; or turned into something else)
	var cur := {}
	for u in g.units:
		if not is_instance_valid(u):
			continue
		var id: int = u.get_instance_id()
		cur[id] = true
		if not seen.has(id):
			if u.team < 0 or u.team > 1:
				continue
			var val := Game.unit_value(u)
			seen[id] = [u.team, u.kind, val, u]
			live[id] = u
			var pr: Dictionary = T[u.team]["produced"]
			pr[u.kind] = int(pr.get(u.kind, 0)) + 1
			var pv: Dictionary = T[u.team]["produced_value"]
			pv[u.kind] = int(pv.get(u.kind, 0)) + val
	for b in g.buildings:
		if not is_instance_valid(b) or b.dead or b.ghost or b.team < 0 or b.team > 1 or not b.built:
			continue
		var id2: int = b.get_instance_id()
		if bseen.has(id2):
			continue
		bseen[id2] = true
		var fbd: Dictionary = T[b.team]["first_built"]
		if not fbd.has(b.kind):
			fbd[b.kind] = snappedf(g.clock, 0.1)
		if b.kind == g.faction_hall(b.team):
			(T[b.team]["halls"] as Array).append(snappedf(g.clock, 0.1))
	for i in 2:
		var X: Dictionary = T[i]
		var gold: int = g.players[i]["gold"]
		var cap: int = g.players[i]["cap"]
		var used: int = g.supply_used(i)
		X["peak_supply"] = maxi(X["peak_supply"], used)
		X["peak_gold"] = maxi(X["peak_gold"], gold)
		if used >= cap - 1 and cap < 200 and gold >= 100:
			X["blocked_s"] += dt
		if cap >= 200 and X["cap200_t"] < 0.0:
			X["cap200_t"] = snappedf(g.clock, 0.1)
		if used >= 199:
			X["capped_s"] += dt
		if gold > 500:
			X["bank500_s"] += dt
		if gold > 1000:
			X["bank1000_s"] += dt
		var ws: Array = g.workers(i)
		var idle := 0
		for w in ws:
			if w.order == "idle":
				idle += 1
		X["idle_w_s"] += idle * dt
		X["worker_s"] += ws.size() * dt
		X["peak_workers"] = maxi(X["peak_workers"], ws.size())
		if g.clock > 180.0:
			X["min_workers_after_3"] = mini(X["min_workers_after_3"], ws.size())
		var ar: Array = g.army(i)
		var aidle := 0
		for u in ar:
			if u.order == "idle":
				aidle += 1
		X["army_idle_s"] += aidle * dt
		X["army_s"] += ar.size() * dt
		var pb_n := 0
		var pb_idle := 0
		for b in g.buildings:
			if b.team == i and b.built and not b.dead and _is_production(b):
				pb_n += 1
				if b.queue.is_empty():
					pb_idle += 1
		if gold >= 100:
			X["prod_idle_s"] += pb_idle * dt
		X["prod_s"] += pb_n * dt
		# soil exhaustion (all halls at 0)
		var halls: Array = g.halls_of(i)
		if X["soil_zero_t"] < 0.0 and g.clock > 120.0 and not halls.is_empty():
			var allz := true
			for h in halls:
				if h.soil_left() > 0.001:
					allz = false
			if allz:
				X["soil_zero_t"] = snappedf(g.clock, 0.1)
		# strategy changes
		var ai = ais[i]
		if String(ai.strategy) != X["strategy"]:
			(X["plan_changes"] as Array).append([snappedf(g.clock, 0.1), X["strategy"], String(ai.strategy)])
			X["strategy"] = String(ai.strategy)
		# walls
		if X["wall_start_t"] < 0.0 and float(ai._wall_start_t) >= 0.0:
			X["wall_start_t"] = snappedf(float(ai._wall_start_t), 0.1)
		if X["wall_done_t"] < 0.0 and float(ai._wall_done_t) >= 0.0:
			X["wall_done_t"] = snappedf(float(ai._wall_done_t), 0.1)
		# first blood
		var st: Dictionary = g.stats[i]
		if X["first_blood_t"] < 0.0 and (int(st["killed"]) > 0 or int(g.stats[1 - i]["killed"]) > 0):
			X["first_blood_t"] = snappedf(g.clock, 0.1)
		# waves (an attack going out, or a Crown raiding party)
		var att: bool = bool(ai._attacking)
		var raid: bool = (ai._raiders as Array).size() > 0
		var active: bool = att or raid
		if active and (X["wave"] as Dictionary).is_empty():
			var comp := {}
			for u in ar:
				comp[u.kind] = int(comp.get(u.kind, 0)) + 1
			X["wave"] = {"t0": snappedf(g.clock, 0.1), "kind": "raid" if (raid and not att) else "wave", "supply": _supply_of_army(i),
				"value": g.army_value(i), "comp": comp, "kv0": int(st["value_killed"]), "lv0": int(g.stats[1 - i]["value_killed"]),
				"plan": String(ai.strategy), "rush_state": String(ai._rush_state), "ek0": int(st["killed"]), "el0": int(st["lost"]),
				"attack_at": int(ai._attack_at)}      # (the army supply wanted for the NEXT wave: stepped up at launch)
			if X["first_attack_t"] < 0.0:
				X["first_attack_t"] = snappedf(g.clock, 0.1)
		elif not active and not (X["wave"] as Dictionary).is_empty():
			var w: Dictionary = X["wave"]
			w["t1"] = snappedf(g.clock, 0.1)
			w["killed_value"] = int(st["value_killed"]) - int(w["kv0"])
			w["lost_value"] = int(g.stats[1 - i]["value_killed"]) - int(w["lv0"])
			w["kills"] = int(st["killed"]) - int(w["ek0"])
			w["losses"] = int(st["lost"]) - int(w["el0"])
			w["army_end"] = g.army_value(i)
			w["attack_at_end"] = int(ai._attack_at)      # (after _wave_end or a siege pull-back raised it)
			for k in ["kv0", "lv0", "ek0", "el0"]:
				w.erase(k)
			(X["waves"] as Array).append(w)
			X["wave"] = {}
		X["attacking"] = active


func _hope(dh: float) -> void:
	for i in 2:
		var X: Dictionary = T[i]
		var ai = ais[i]
		var v: Dictionary = ai.gg_view(dh)
		var why: String = AIResign.verdict(v)
		if why == "":
			if X["hope_since"] >= 0.0:
				X["hope_flips"] += 1
			X["hope_since"] = -1.0
			X["hope_reason"] = ""
			continue
		if X["hope_since"] < 0.0:
			X["hope_since"] = g.clock
			if X["hope_first"] < 0.0:
				X["hope_first"] = snappedf(g.clock, 0.1)
		X["hope_reason"] = why
		var held: float = g.clock - float(X["hope_since"])
		if held >= AIResign.sustain_for(why) and X["gg_t"] < 0.0:
			X["gg_t"] = snappedf(g.clock, 0.1)
		if gg_cut and held >= AIResign.sustain_for(why) + AIResign.REPLY_WINDOW and not g.over:
			cause = "gg"
			_finish(i)
			return


func _sample() -> void:
	for i in 2:
		var X: Dictionary = T[i]
		var st: Dictionary = g.stats[i]
		var ost: Dictionary = g.stats[1 - i]
		var ws: Array = g.workers(i)
		var idle := 0
		for w in ws:
			if w.order == "idle":
				idle += 1
		var ar: Array = g.army(i)
		var aidle := 0
		for u in ar:
			if u.order == "idle":
				aidle += 1
		var halls: Array = g.halls_of(i)
		var soil_sum := 0.0
		var soil_min := 1.0
		var lode_sum := 0.0
		for h in halls:
			var s: float = h.soil_left()
			soil_sum += s
			soil_min = minf(soil_min, s)
			lode_sum += h.lode_left()
		var nb := 0
		var wallp := 0
		var prodb := 0
		var prodi := 0
		for b in g.buildings:
			if b.team != i or b.dead or b.ghost or not b.built:
				continue
			if Defs.BUILDINGS[b.kind].get("line", false):
				wallp += 1
			else:
				nb += 1
			if _is_production(b):
				prodb += 1
				if b.queue.is_empty():
					prodi += 1
		var nh := halls.size()
		rows.append([gid, int(g.clock), i, g.faction_of(i), int(g.players[i]["gold"]), int(g.players[i]["res2"]), int(st["gold"]),
			int(st["res2_in"]), int(st["spent"]), g.supply_used(i), int(g.players[i]["cap"]), ws.size(), idle, g.army_value(i),
			_supply_of_army(i), ar.size(), aidle, nh, nb, wallp, prodb, prodi, int(st["lost"]), int(st["killed"]),
			int(st["value_killed"]), int(ost["value_killed"]), int(st["bld_lost"]),
			snappedf(soil_sum / float(nh), 0.001) if nh > 0 else -1, snappedf(soil_min, 0.001) if nh > 0 else -1,
			snappedf(lode_sum / float(nh), 0.001) if nh > 0 else -1,
			1 if X["attacking"] else 0, snappedf(X["blocked_s"], 0.1), snappedf(X["bank500_s"], 0.1), snappedf(X["bank1000_s"], 0.1),
			snappedf(X["idle_w_s"], 0.1), snappedf(X["worker_s"], 0.1), 1 if X["hope_since"] >= 0.0 else 0, X["strategy"],
			1 if ais[i]._threat() != Vector2.INF else 0, int(ais[i]._attack_at), 0 if (ais[i]._siege as Dictionary).is_empty() else 1])


func _winner_by_power() -> int:
	var p0 := float(Game.power(g.standing(0)))
	var p1 := float(Game.power(g.standing(1)))
	if p0 > p1 * 1.25:
		return 0
	if p1 > p0 * 1.25:
		return 1
	return -1


func _finish(loser_team := -1) -> void:
	if done:
		return
	done = true
	_sample()
	var winner := -1
	if cause == "victory":
		winner = int(g.winner)
	elif cause == "gg":
		winner = 1 - loser_team
	else:
		winner = _winner_by_power()
		cause = "timeout_even" if winner < 0 else "timeout_lead"
	for i in 2:
		var X: Dictionary = T[i]
		if not (X["wave"] as Dictionary).is_empty():
			var w: Dictionary = X["wave"]
			w["t1"] = snappedf(g.clock, 0.1)
			w["open"] = true
			w["killed_value"] = int(g.stats[i]["value_killed"]) - int(w["kv0"])
			w["lost_value"] = int(g.stats[1 - i]["value_killed"]) - int(w["lv0"])
			for k in ["kv0", "lv0", "ek0", "el0"]:
				w.erase(k)
			(X["waves"] as Array).append(w)
	var a_team := 1 if swap else 0
	var row := {
		"id": gid, "version": ProjectSettings.get_setting("application/config/version", "dev"),
		"a": fa, "b": fb, "plan_a": pa, "plan_b": pb, "map": map, "seed": seed_, "swap": swap, "a_team": a_team,
		"faction0": g.faction_of(0), "faction1": g.faction_of(1),
		"winner_team": winner, "winner_faction": g.faction_of(winner) if winner >= 0 else "",
		"a_won": 1 if winner == a_team else (0 if winner >= 0 else -1),
		"end_t": snappedf(g.clock, 0.1), "cause": cause, "wall_s": snappedf(float(Time.get_ticks_msec() - wall0) / 1000.0, 0.1),
		"fast": fast, "hashes": hashes, "loss_tracking": 2, "teams": [],
	}
	for i in 2:
		var X: Dictionary = T[i]
		var st: Dictionary = g.stats[i]
		var stand: Dictionary = g.standing(i)
		var ai = ais[i]
		var td := {
			"team": i, "faction": g.faction_of(i), "plan_start": String(ai._opened), "plan_end": String(ai.strategy),
			"crown_opening": String(ai.opening), "failed_waves": int(ai._failed),
			"scout_verdict": String(ai.scout.verdict) if ai.scout else "",
			"earned": int(st["gold"]), "spent": int(st["spent"]), "trained": int(st["trained"]), "built": int(st["built"]),
			"killed": int(st["killed"]), "lost": int(st["lost"]), "razed": int(st["razed"]), "bld_lost": int(st["bld_lost"]),
			"value_killed": int(st["value_killed"]), "peak_army": int(st["peak_army"]), "res2_in": int(st["res2_in"]),
			"kills_by": st["kills_by"], "sacrificed": int(st.get("sacrificed", 0)),
			"end_army": stand["army"], "end_workers": stand["workers"], "end_buildings": stand["buildings"],
			"end_gold": int(g.players[i]["gold"]), "end_res2": int(g.players[i]["res2"]), "end_halls": g.halls_of(i).size(),
			"end_power": Game.power(stand),
		}
		td.merge(_peek(i))      # (why an army may be sitting still at the end; added at stage 9)
		for k in X:
			if k in ["wave", "attacking", "strategy"]:
				continue
			td[k] = X[k]
		(row["teams"] as Array).append(td)
	_write(row)
	quit(0)


## Read-only peeks at the AI's attack gates and where its army is, for games that stall (added at stage 9).
func _peek(i: int) -> Dictionary:
	var ai = ais[i]
	var ar: Array = g.army(i)
	var oc := {}
	var cen := Vector2.ZERO
	for u in ar:
		var k := String(u.order)
		oc[k] = int(oc.get(k, 0)) + 1
		cen += u.position
	if ar.size() > 0:
		cen /= float(ar.size())
	var wt: Vector2 = ai._wave_target
	return {
		"attack_at_end": int(ai._attack_at), "army_supply_end": _supply_of_army(i),
		"regroup_left": snappedf(maxf(0.0, float(ai._regroup_until) - g.clock), 0.1),
		"threat_end": ai._threat() != Vector2.INF, "siege_end": not (ai._siege as Dictionary).is_empty(),
		"walled_halls_end": (ai._walled_halls as Dictionary).size(), "peaceful": bool(ai.peaceful),
		"army_orders": oc, "army_centroid": [int(cen.x), int(cen.y)], "wave_target_end": [int(wt.x), int(wt.y)],
	}


func _write(row: Dictionary) -> void:
	for sub in ["games", "ts", "logs"]:
		DirAccess.make_dir_recursive_absolute(out_dir + "/" + sub)
	var csv := PackedStringArray()
	for r in rows:
		csv.append(",".join(PackedStringArray((r as Array).map(func(x) -> String: return str(x)))))
	_atomic("%s/ts/%s.csv" % [out_dir, gid], "\n".join(csv) + "\n")
	var lines := PackedStringArray()
	if g.mlog:
		lines = g.mlog.lines
	_atomic("%s/logs/%s.log" % [out_dir, gid], "\n".join(lines) + "\n")
	_atomic("%s/games/%s.json" % [out_dir, gid], JSON.stringify(row))     # (written last: its existence means the game is done)


func _atomic(path: String, text: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + tmp)
		return
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(tmp, path)
