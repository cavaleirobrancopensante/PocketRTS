extends SceneTree
## Build-order study (docs/build_orders_study.md): ONE headless match where either side may follow a SCRIPTED OPENING
## (tools/study/build_orders.json, played by tools/study/bo_ai.gd) or be the ordinary Hard computer on a plan.
## Measurement only: it changes nothing in the game.
##
##   godot --headless --fixed-fps 30 --script res://tools/study/bo_match.gd -- \
##       a:crown b:brood sa:crown_musket_wall sb:ai:balanced map:ashford_crossing seed:1 [swap:0] [end:600] out:/abs/result.json
##
##   sa / sb   a build name from build_orders.json, or ai:<plan>[:<crown opening mill|breeder>] (plain Hard computer)
##   a / b     factions (a build's own faction wins); `a` takes the first spawn unless swap:1
##   end       game seconds to play (default 600); the match also ends on a victory
## Writes one JSON: per side the step log (when each step was placed / done), every unit's and building's arrival time,
## a sample every 30 s (workers, army value and supply, bank, income), the army at 3, 4, 5 and 6 minutes, the scripted
## attacks (left, arrived at the enemy hall, first blood, value killed and lost) and the result (victory, or who leads at
## the end by Game.power, 1.25x).

const BOAI := preload("res://tools/study/bo_ai.gd")
const SAMPLE := 30.0
const SNAP := [180.0, 240.0, 300.0, 360.0, 480.0]

var main: Node
var t := 0.0
var fa := "crown"
var fb := "brood"
var sa := "ai:balanced"
var sb := "ai:balanced"
var map := "ashford_crossing"
var seed_ := 1
var swap := false
var end_t := 600.0
var out := ""
var g
var inited := false
var done := false
var builds: Dictionary = {}
var spec := ["", ""]                    # per team: the spec string
var bo_ai: Array = [null, null]
var S: Array = []                       # per team record
var seen := {}                          # unit id -> [team, kind]
var bseen := {}
var next_sample := SAMPLE
var snap_i := 0
var wall0 := 0
var frame_n := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var p := a.split(":", true, 1)
		if p.size() < 2:
			continue
		match p[0]:
			"a": fa = p[1]
			"b": fb = p[1]
			"sa": sa = p[1]
			"sb": sb = p[1]
			"map": map = p[1]
			"seed": seed_ = int(p[1])
			"swap": swap = p[1] == "1"
			"end": end_t = float(p[1])
			"out": out = p[1]
	var f := FileAccess.open("res://tools/study/build_orders.json", FileAccess.READ)
	var j = JSON.parse_string(f.get_as_text())
	for b in (j["builds"] as Array):
		builds[String(b["name"])] = b
	for pair in [["sa", sa], ["sb", sb]]:
		var s: String = pair[1]
		if not s.begins_with("ai:") and s != "idle" and not builds.has(s):
			push_error("unknown build " + s)
			quit(2)
			return
	if builds.has(sa):
		fa = String(builds[sa]["faction"])
	if builds.has(sb):
		fb = String(builds[sb]["faction"])


func _plan_of(s: String) -> String:
	return String(s.split(":")[1]) if s.begins_with("ai:") else "balanced"


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var facs := [fb, fa] if swap else [fa, fb]
		var specs := [sb, sa] if swap else [sa, sb]
		spec = specs
		var slots: Array = []
		for i in 2:
			slots.append({"who": "hard", "faction": facs[i], "colour": i, "side": i, "strategy": _plan_of(specs[i])})
		main.start({"map": map, "seed": seed_, "slots": slots})
		wall0 = Time.get_ticks_msec()
		# (the swap happens now, in the frame the computers were made: none of them has thought yet)
		if main.game != null and main.game.ais.size() >= 2:
			g = main.game
			inited = true
			_setup()
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if g.hud:
		g.hud.countdown = 0.0
	if not inited:
		if g.ais.size() < 2:
			return false
		inited = true
		_setup()
	if done:
		return true
	_step()
	return done


func _setup() -> void:
	if g.hud:
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for old in g.ais.duplicate():
		var s: String = spec[old.team]
		if s == "idle":
			old.process_mode = Node.PROCESS_MODE_DISABLED       # (a sleeping opponent: its workers work, nothing else)
			continue
		if s.begins_with("ai:"):
			var p := s.split(":")
			if p.size() > 2 and g.faction_of(old.team) == "crown":
				old.opening = p[2]
			continue
		var nai = BOAI.new()
		nai.game = g
		nai.team = old.team
		nai.difficulty = old.difficulty
		nai.strategy = "balanced"
		nai.bo = builds[s]
		nai.bo_name = s
		old.process_mode = Node.PROCESS_MODE_DISABLED
		g.ais.erase(old)
		old.queue_free()
		g.add_child(nai)
		g.ais.append(nai)
		bo_ai[nai.team] = nai
	for i in 2:
		S.append({"spec": spec[i], "faction": g.faction_of(i), "spawns": {}, "built": {}, "samples": [], "snaps": {},
			"workers_lost": 0, "first_worker_lost": -1.0, "units_lost": 0, "opening": "", "plan_end": ""})
		for ai in g.ais:
			if ai.team == i and g.faction_of(i) == "crown":
				S[i]["opening"] = String(ai.opening)


func _step() -> void:
	frame_n += 1
	if g.over:
		_finish("victory")
		return
	if frame_n % 15 == 0:
		_scan()
	if g.clock >= next_sample:
		next_sample += SAMPLE
		_sample()
	while snap_i < SNAP.size() and g.clock >= SNAP[snap_i]:
		_snap(SNAP[snap_i])
		snap_i += 1
	if g.clock >= end_t:
		_finish("timeout")


func _scan() -> void:
	for u in g.units:
		if not is_instance_valid(u) or u.team < 0 or u.team > 1:
			continue
		var id: int = u.get_instance_id()
		if not seen.has(id):
			seen[id] = [u.team, u.kind, u]
			var sp: Dictionary = S[u.team]["spawns"]
			if not sp.has(u.kind):
				sp[u.kind] = []
			(sp[u.kind] as Array).append(snappedf(g.clock, 0.1))
	for id in seen.keys():
		var rec: Array = seen[id]
		var u = rec[2]
		if rec.size() > 3:
			continue
		if not is_instance_valid(u) or u.dead:
			rec.append(true)
			# (a grub turned into a building, or a creature offered up at a Pen, is not a loss)
			if is_instance_valid(u) and u.dead and u.work != "morphing" and u.order != "sacrifice":
				var X: Dictionary = S[rec[0]]
				if Defs.is_worker(String(rec[1])):
					X["workers_lost"] += 1
					if float(X["first_worker_lost"]) < 0.0:
						X["first_worker_lost"] = snappedf(g.clock, 0.1)
				else:
					X["units_lost"] += 1
	for ai in g.ais:
		var X2: Dictionary = S[ai.team]
		if not X2.has("ai_attack") and (bool(ai._attacking) or (ai._raiders as Array).size() > 0):
			X2["ai_attack"] = snappedf(g.clock, 0.1)     # (the computer's own first wave or raiding party)
	for b in g.buildings:
		if not is_instance_valid(b) or b.dead or b.ghost or not b.built or b.team < 0 or b.team > 1:
			continue
		var id2: int = b.get_instance_id()
		if bseen.has(id2):
			continue
		bseen[id2] = true
		var bt: Dictionary = S[b.team]["built"]
		if not bt.has(b.kind):
			bt[b.kind] = []
		(bt[b.kind] as Array).append(snappedf(g.clock, 0.1))


func _army_supply(team: int) -> int:
	var n := 0
	for u in g.army(team):
		n += int(u.d["supply"])
	return n


func _sample() -> void:
	for i in 2:
		var st: Dictionary = g.stats[i]
		(S[i]["samples"] as Array).append([int(g.clock), g.workers(i).size(), g.army_value(i), _army_supply(i), int(g.players[i]["gold"]),
			snappedf(float(g.players[i]["res2"]), 0.1), snappedf(float(g.players[i].get("tension", 0.0)), 0.1), int(st["gold"]),
			g.supply_used(i), int(g.players[i]["cap"]), int(st["value_killed"]), int(st["lost"]), int(st["killed"]), g.building_count(i)])


func _snap(at: float) -> void:
	for i in 2:
		var comp := {}
		for u in g.army(i):
			comp[u.kind] = int(comp.get(u.kind, 0)) + 1
		S[i]["snaps"][str(int(at))] = {"army": comp, "value": g.army_value(i), "supply": _army_supply(i), "workers": g.workers(i).size(),
			"bank": int(g.players[i]["gold"]), "earned": int(g.stats[i]["gold"]), "res2": snappedf(float(g.players[i]["res2"]), 0.1),
			"tension": snappedf(float(g.players[i].get("tension", 0.0)), 0.1), "buildings": g.building_count(i)}


func _winner_by_power() -> int:
	var p0 := float(Game.power(g.standing(0)))
	var p1 := float(Game.power(g.standing(1)))
	if p0 > p1 * 1.25:
		return 0
	if p1 > p0 * 1.25:
		return 1
	return -1


func _finish(cause: String) -> void:
	if done:
		return
	done = true
	_scan()
	_sample()
	var winner := -1
	if cause == "victory":
		winner = int(g.winner)
	else:
		winner = _winner_by_power()
		cause = "lead" if winner >= 0 else "even"
	var a_team := 1 if swap else 0
	for i in 2:
		var X: Dictionary = S[i]
		var st: Dictionary = g.stats[i]
		X["end"] = {"standing": g.standing(i), "power": Game.power(g.standing(i)), "earned": int(st["gold"]), "spent": int(st["spent"]),
			"value_killed": int(st["value_killed"]), "killed": int(st["killed"]), "lost": int(st["lost"]), "bld_lost": int(st["bld_lost"]),
			"res2_in": int(st["res2_in"])}
		for ai in g.ais:
			if ai.team == i:
				X["plan_end"] = String(ai.strategy)
				X["ai_first_wave"] = bool(ai._first_wave)
				if bo_ai[i] != null:
					X["bo"] = bo_ai[i].report()
		if bo_ai[i] == null:
			X["bo"] = null
	var row := {"map": map, "seed": seed_, "swap": swap, "a_team": a_team, "sa": sa, "sb": sb, "fa": fa, "fb": fb,
		"end_t": snappedf(g.clock, 0.1), "cause": cause, "winner_team": winner, "a_won": 1 if winner == a_team else (0 if winner >= 0 else -1),
		"wall_s": snappedf(float(Time.get_ticks_msec() - wall0) / 1000.0, 0.1),
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "sides": S}
	var text := JSON.stringify(row)
	if out == "":
		print(text)
	else:
		if g.mlog:
			var lf := FileAccess.open(out.get_basename() + ".mlog", FileAccess.WRITE)
			lf.store_string("\n".join(g.mlog.lines) + "\n")
			lf.close()
		var f := FileAccess.open(out + ".tmp", FileAccess.WRITE)
		f.store_string(text)
		f.close()
		DirAccess.rename_absolute(out + ".tmp", out)
	quit(0)
