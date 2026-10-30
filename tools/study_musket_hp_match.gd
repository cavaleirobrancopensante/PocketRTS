extends SceneTree
## THE MUSKETEER HEALTH TEST, computer against computer (docs/musket_hp_test.md). Measurement only: the variant's health
## is a test-only override (tools/musket_hp.gd), applied to every Musketeer of the match each frame; nothing in the game
## is changed. The Crown (side 0) against the Brood or the Clockwork (side 1), both Hard, to `secs` or the end.
##   godot --headless --fixed-fps 30 --script res://tools/study_musket_hp_match.gd -- \
##       [foe:brood|clockwork] [map:greenhold] [seed:1] [secs:900] [hpv:now|55/65] [plan:balanced] [foeplan:balanced] [out:/abs/f.json]
## Prints a line a minute and writes one JSON object: winner, end, the army value of both sides each minute (cost at
## face value, first + second resource, a Brood egg's share), the Crown's Musketeers made / lost / alive each minute,
## the value each side lost, and the Crown's buildings lost.
const MH := preload("res://tools/musket_hp.gd")

var main: Node
var t := 0.0
var g
var map := "greenhold"
var seed_ := 1
var secs := 900.0
var foe := "brood"
var plan := "balanced"
var foeplan := "balanced"
var hpv := "now"
var out_path := ""
var _hp := [0.0, 0.0]
var next_min := 60.0
var res := {}
var seen := {}          # instance id -> [team, kind, value, unit]
var lost_v := [0.0, 0.0]
var lost_n := {}
var made_n := {}
var done := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"secs": secs = float(kv[1])
			"foe": foe = kv[1]
			"plan": plan = kv[1]
			"foeplan": foeplan = kv[1]
			"hpv": hpv = kv[1]
			"out": out_path = kv[1]
	_hp = MH.parse(hpv)
	res = {"map": map, "seed": seed_, "foe": foe, "hpv": hpv, "plan": plan, "foeplan": foeplan,
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "army": {}, "foe_army": {},
		"musk_alive": {}, "guards_alive": {}, "workers": {}, "foe_workers": {}, "lost_value": {}, "foe_lost_value": {},
		"winner": -1, "end": 0}


func _value_of(u) -> float:
	var c := float(u.d.get("cost", 0)) + float(u.d.get("cost2", 0))
	if Defs.tension_cost(u.d) > 0:
		c = float(u.d.get("cost", 0)) + float(Defs.tension_cost(u.d))
	if u.kind == "musketeer":
		var f := Game.kit_fee(u.get_kit(), "musketeer")
		c += f[0] + f[1]
	return c / maxf(1.0, float(u.d.get("spawn", 1)))


func _army_value(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		if BroodNew.is_nb(u.kind):
			continue          # (the Brood's structure-units: the Mother, Rootmaws, Turtles, Sires)
		v += _value_of(u)
	return int(v)


func _track() -> void:
	for u in g.units:
		if not is_instance_valid(u):
			continue
		var id: int = u.get_instance_id()
		if not seen.has(id):
			if u.dead:
				continue
			seen[id] = [u.team, u.kind, 0.0, u]
			if u.team == 0 and u.kind == "musketeer":
				made_n["musketeer"] = int(made_n.get("musketeer", 0)) + 1
	for id in seen.keys():
		var e: Array = seen[id]
		var u = e[3]
		if u == null:
			continue
		if not is_instance_valid(u) or u.dead:
			var tm: int = e[0]
			if tm >= 0 and tm < 2:
				lost_v[tm] += float(e[2])
				var key := "%d:%s" % [tm, e[1]]
				lost_n[key] = int(lost_n.get(key, 0)) + 1
			e[3] = null
		else:
			e[1] = u.kind
			e[2] = 0.0 if (u.is_worker() or BroodNew.is_nb(u.kind)) else _value_of(u)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan},
			{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": foeplan}]})
		return false
	if main.game == null or done:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	MH.apply(g, _hp[0], _hp[1])
	if Engine.get_process_frames() % 6 == 0:
		_track()
	if g.clock >= next_min:
		var m := str(int(round(g.clock / 60.0)))
		next_min += 60.0
		_track()
		res["army"][m] = _army_value(0)
		res["foe_army"][m] = _army_value(1)
		res["musk_alive"][m] = g.army(0).filter(func(u) -> bool: return u.kind == "musketeer" and not u.armoured).size()
		res["guards_alive"][m] = g.army(0).filter(func(u) -> bool: return u.kind == "musketeer" and u.armoured).size()
		res["workers"][m] = g.workers(0).size()
		res["foe_workers"][m] = g.workers(1).size()
		res["lost_value"][m] = int(lost_v[0])
		res["foe_lost_value"][m] = int(lost_v[1])
		print("%s:00 crown army %d (musk %d, guards %d) workers %d lost %d | %s army %d workers %d lost %d" % [m, res["army"][m],
			res["musk_alive"][m], res["guards_alive"][m], res["workers"][m], int(lost_v[0]), foe, res["foe_army"][m],
			res["foe_workers"][m], int(lost_v[1])])
	if g.clock >= secs or g.over:
		done = true
		_track()
		res["winner"] = g.winner if g.over else -1
		res["end"] = int(g.clock)
		res["made"] = made_n
		res["lost_n"] = lost_n
		res["lost_total"] = [int(lost_v[0]), int(lost_v[1])]
		res["army_end"] = [_army_value(0), _army_value(1)]
		res["buildings_end"] = [g.buildings.filter(func(b) -> bool: return b.team == 0 and not b.dead).size(),
			g.buildings.filter(func(b) -> bool: return b.team == 1 and not b.dead).size()]
		var line := JSON.stringify(res)
		print("RESULT " + line)
		if out_path != "":
			var f := FileAccess.open(out_path, FileAccess.WRITE)
			f.store_line(line)
			f.close()
		quit(0)
	return false
