extends SceneTree
## How the Brood computer plays a real game (no peaceful foe): a Hard Brood on `plan` against a Hard
## Crown computer on `foeplan` (default Balanced) for `end` game seconds (default 480):
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_ai.gd -- map:thornwood_maze seed:1 plan:rush [foeplan:balanced end:480 old log]
## "old": the Brood computer as it was before scripts/ai_brood.gd (AIBrood.enabled off), for a "before" number.
## Prints a line a minute and one summary line "BR ...": essence over time (banked / earned / from
## sacrifices), the seconds supply-blocked (a Raptor egg would not fit under the cap while 75+ biomass
## is banked), the army value (the match log's: cost per unit made) at 3, 5 and 7 minutes, the tech
## buildings' times, and every attack wave the Brood launched: when, what it sent, what it killed,
## what it lost and how it ended. Used for the numbers in docs/ai_build_timelines.md (Brood).
var main: Node
var t := 0.0
var g
var started := false
var plan := "rush"
var foe_plan := "balanced"
var map := "thornwood_maze"
var seed_ := 1
var end_t := 480.0
var me := 1
var foe := 0
var ai_me
var blocked := 0.0
var tight := 0.0
var _last_t := 0.0
var waves: Array = []           # {"t0", "sent", "n", "units", "kill0", "foe_army", "t1", "lost", "killed", "why"}
var _wave_on := false
var firsts := {}                # building kind -> clock it was first finished
var ess_min := {}               # minute -> [banked, earned, sacrificed]
var army_min := {}              # minute -> [brood army value, crown army value, brood workers, supply text]
var lost_home := 0.0            # Brood army value lost while no wave of its was out (defending)
var _alive_army := {}           # Unit -> value (the Brood army last tick)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("foeplan:"):
			foe_plan = a.substr(8)
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))
		elif a == "old":
			AIBrood.enabled = false


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": foe_plan},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": plan}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for a in g.ais:
			if a.team == me:
				ai_me = a
		_run()
	return false


func _wave_units() -> Array:
	var out: Array = []
	for u in ai_me._xr_wave:
		if is_instance_valid(u) and not out.has(u):
			out.append(u)
	for grp in ai_me._swarm:
		for u in grp[0]:
			if is_instance_valid(u) and not out.has(u):
				out.append(u)
	return out


func _attacking() -> bool:
	return ai_me._attacking or ai_me._swarm_phase != ""


func _step() -> void:
	var dt: float = g.clock - _last_t
	_last_t = g.clock
	var cap: int = g.players[me]["cap"]
	var used: int = g.supply_used(me)
	if cap < g.max_supply(me) and cap - used < 3:
		tight += dt
		if int(g.players[me]["gold"]) >= 75:
			blocked += dt
	for b in g.buildings:
		if b.team == me and b.built and not b.dead and not firsts.has(b.kind):
			firsts[b.kind] = g.clock
	# the army's losses: in a wave or at home
	var now := {}
	for u in g.army(me):
		now[u] = float(Game.unit_value(u))
	var in_wave := {}
	for w in waves:
		if w["t1"] < 0.0:
			for u in w["units"]:
				in_wave[u] = true
	for u in _alive_army:
		if not now.has(u) and is_instance_valid(u) and u.dead and not in_wave.has(u) and u.order != "sacrifice":
			lost_home += float(_alive_army[u])
	_alive_army = now
	# waves
	var on := _attacking()
	if on and not _wave_on:
		var units := _wave_units()
		var sent := 0.0
		for u in units:
			sent += float(Game.unit_value(u))
		waves.append({"t0": g.clock, "sent": sent, "n": units.size(), "units": units, "kill0": int(g.stats[me]["value_killed"]),
			"foe_army": g.army_value(foe), "t1": -1.0, "lost": 0.0, "killed": 0, "why": ""})
	elif on and not waves.is_empty():
		var w: Dictionary = waves[waves.size() - 1]
		for u in _wave_units():
			if not (w["units"] as Array).has(u):
				w["units"].append(u)
				w["sent"] += float(Game.unit_value(u))
				w["n"] += 1
	if not on and _wave_on and not waves.is_empty():
		_close_wave(waves[waves.size() - 1], "")
	_wave_on = on


func _close_wave(w: Dictionary, why: String) -> void:
	w["t1"] = g.clock
	var lost := 0.0
	for u in w["units"]:
		if not is_instance_valid(u) or u.dead:
			lost += float(Game.unit_value(u)) if is_instance_valid(u) else 25.0
	w["lost"] = lost
	w["killed"] = int(g.stats[me]["value_killed"]) - int(w["kill0"])
	w["why"] = why


func _run() -> void:
	var next_dbg := 60.0
	while g.clock < end_t and not g.over:
		await physics_frame
		_step()
		if g.clock >= next_dbg:
			var m := int(next_dbg / 60.0)
			next_dbg += 60.0
			ess_min[m] = [float(g.players[me]["res2"]), float(g.stats[me]["res2_in"]), int(g.stats[me].get("sacrifice_essence", 0))]
			army_min[m] = [g.army_value(me), g.army_value(foe), g.workers(me).size(), "%d/%d" % [g.supply_used(me), g.players[me]["cap"]], int(g.stats[me]["gold"])]
			var kinds := {}
			for u in g.army(me):
				kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
			print("  %d:00 brood army %d (%s) workers %d supply %s biomass %d essence %.1f (earned %.1f, sacrificed %d) blocked %.0fs | crown army %d workers %d | plan %s attack_at %d" % [
				m, g.army_value(me), str(kinds), g.workers(me).size(), army_min[m][3], int(g.players[me]["gold"]), float(g.players[me]["res2"]),
				float(g.stats[me]["res2_in"]), int(g.stats[me].get("sacrifice_essence", 0)), blocked, g.army_value(foe), g.workers(foe).size(), ai_me.strategy, ai_me._attack_at])
	if not waves.is_empty() and waves[waves.size() - 1]["t1"] < 0.0:
		_close_wave(waves[waves.size() - 1], "still out at the end")
	var ws: Array = []
	for w in waves:
		ws.append("%s sent %d (%d units) vs crown army %d -> killed %d, lost %d%s" % [_mmss(w["t0"]), int(w["sent"]), int(w["n"]), int(w["foe_army"]), int(w["killed"]), int(w["lost"]),
			(" [" + String(w["why"]) + "]") if w["why"] != "" else (" (back at %s)" % _mmss(w["t1"]))])
	var e := func(m: int) -> String:
		if not ess_min.has(m):
			return "-"
		return "%d/%d" % [int(ess_min[m][0]), int(ess_min[m][1])]
	var a := func(m: int) -> String:
		if not army_min.has(m):
			return "-"
		return "%d" % int(army_min[m][0])
	var fa := func(m: int) -> String:
		if not army_min.has(m):
			return "-"
		return "%d" % int(army_min[m][1])
	var eco := func(m: int) -> String:
		if not army_min.has(m):
			return "-"
		return "%d/%d" % [int(army_min[m][2]), int(army_min[m][4])]
	var tech: Array = []
	for k in ["warren", "brood_pen", "clutch_mound", "gorge_pit", "roost"]:
		tech.append("%s %s" % [k, _mmss(float(firsts.get(k, -1.0)))])
	print("BR map=%s seed=%d plan=%s vs crown %s | essence banked/earned 3:00 %s 5:00 %s 7:00 %s (sacrificed %d) | blocked %.0fs (tight %.0fs) | army 3:00 %s 5:00 %s 7:00 %s | crown army 3:00 %s 5:00 %s 7:00 %s | workers/earned 5:00 %s 7:00 %s | lost at home %d | %s | %s%s" % [
		map, seed_, plan, foe_plan, e.call(3), e.call(5), e.call(7), int(g.stats[me].get("sacrifice_essence", 0)), blocked, tight,
		a.call(3), a.call(5), a.call(7), fa.call(3), fa.call(5), fa.call(7), eco.call(5), eco.call(7), int(lost_home), ", ".join(tech),
		"waves: " + ("; ".join(ws) if not ws.is_empty() else "none"), (" | OVER winner %d at %s" % [g.winner, _mmss(g.clock)]) if g.over else ""])
	if ai_me.brood != null:
		print("BRX held %d, looked %d, pulled back %d, grubs sent to harvest %d, offered up %d, burrows added %d, halls %d | sacrificed %d essence of %.1f earned" % [ai_me.brood.holds, ai_me.brood.looks, ai_me.brood.retreats,
			ai_me.brood.harvest_sent, ai_me.brood.offered, ai_me.brood.burrows_added, ai_me._halls().size(), int(g.stats[me].get("sacrifice_essence", 0)), float(g.stats[me]["res2_in"])])
	if OS.get_cmdline_user_args().has("log"):
		for l in g.mlog.lines:
			if String(l).contains("P2 Brood") and not String(l).contains("busy with"):
				print("LOG ", l)
	quit(0)


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]
