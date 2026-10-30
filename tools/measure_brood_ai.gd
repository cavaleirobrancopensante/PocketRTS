extends SceneTree
## THE BROOD'S COMPUTER MEASURED (docs/brood_ai.md): one computer match, the Brood (side 0) against a Crown or a
## Clockwork computer (side 1), both at the same level, to the end or `secs`. Prints a line a minute for both sides and
## one RESULT line (JSON) at the end that tools/study/brood_ai_table.py combines:
##   winner, end time, army value of both sides at 3/5/8/12 min, the Brood's first attack, its Sires (when each came),
##   its stages, its research (when each was done), how many young it matured, its far turtles (new ground), its food
##   bank at each minute, losses and kills.
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_ai.gd -- \
##       [map:hollowfen] [seed:4242] [foe:crown|clockwork] [secs:900] [who:hard] [plan:balanced] [foeplan:balanced] [tag:x]
##       [onegg:0]  (the new SACRIFICE rule, one egg back per egg's worth of young, is on by default: tools/brood_one_egg.gd)
## Brood economy (docs/brood_eco.md): income a minute of both sides ("inc", "foe_inc": food / gold earned that minute),
## grubs and rooted Rootmaws a minute, the first Mound Turtle on new ground ("natural": when, how far), the third Rootmaw
## rooted ("maw3"), the scouting grub out ("scout"), spoils earned and Raptors offered up.
var main: Node
var t := 0.0
var g
var map := "hollowfen"
var seed_ := 4242
var secs := 900.0
var foe := "crown"
var who := "hard"
var plan := "balanced"
var foeplan := "balanced"
var tag := ""
var sets := {}                   # set:key=value,... the Brood computer's plan settings forced (AIBroodNew.over)
var next_min := 60.0
var res := {}
var _attack_seen := false
var _matured := 0
var _young_seen := {}
var _egg_rule = preload("res://tools/brood_one_egg.gd").new()
var _earned0 := [0, 0]


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
			"who": who = kv[1]
			"plan": plan = kv[1]
			"foeplan": foeplan = kv[1]
			"tag": tag = kv[1]
			"onegg": _egg_rule.on = kv[1] != "0"
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]
	res = {"tag": tag, "map": map, "seed": seed_, "foe": foe, "plan": plan, "who": who, "version": ProjectSettings.get_setting("application/config/version", "dev"),
		"army": {}, "foe_army": {}, "bank": {}, "supply": {}, "first_attack": -1, "sires": {}, "stages": {}, "research": {},
		"matured": 0, "far_turtles": 0, "turtles": 0, "maws": 0, "grubs_max": 0, "winner": -1, "end": 0, "lost": 0, "killed": 0,
		"value_killed": 0, "foe_value_killed": 0, "earned": 0, "foe_earned": 0, "waves": 0, "scouted": "",
		"inc": {}, "foe_inc": {}, "grubs": {}, "maws_at": {}, "natural": -1, "natural_tiles": 0, "maw3": -1, "scout": -1,
		"spoils_in": 0, "sacrificed": 0, "eggs_taken": 0, "alarms": []}


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": who, "faction": "brood", "colour": 0, "side": 0, "strategy": plan},
			{"who": who, "faction": foe, "colour": 1, "side": 1, "strategy": foeplan}]})
		res["sets"] = str(sets)
		if not sets.is_empty():
			for a in main.game.ais:
				if a.team == 0 and a is AIBroodNew:
					a.over = sets
					a._make_plan()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	_egg_rule.tick(g, 0)
	_watch()
	if g.clock >= next_min:
		var m := int(round(g.clock / 60.0))
		next_min += 60.0
		res["army"][str(m)] = _value(0)
		res["foe_army"][str(m)] = _value(1)
		res["bank"][str(m)] = int(g.players[0]["gold"])
		res["supply"][str(m)] = g.supply_used(0)
		res["inc"][str(m)] = int(g.stats[0]["gold"]) - _earned0[0]
		res["foe_inc"][str(m)] = int(g.stats[1]["gold"]) - _earned0[1]
		_earned0 = [int(g.stats[0]["gold"]), int(g.stats[1]["gold"])]
		res["grubs"][str(m)] = BroodNew.count_of(g, 0, "grub")
		var rm := 0
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
				rm += 1
		res["maws_at"][str(m)] = rm
		print("       income this minute: brood %d, foe %d | grubs %d, rooted Rootmaws %d" % [res["inc"][str(m)], res["foe_inc"][str(m)], res["grubs"][str(m)], rm])
		print("%2d:00  %s" % [m, _line(0)])
		print("       %s" % _line(1))
		var q = BroodNew.queen(g, 0)
		if q:
			var fs := ""
			for f in BroodNew.FATHERS:
				var s = BroodNew.father(g, 0, f)
				if s:
					fs += " %s:%s/%s/%.0ft%s" % [f.left(4), s.tesla_mode, s.order, s.position.distance_to(q.position) / Defs.TILE, "/research" if BroodResearch.busy(s) else ""]
			var ai: AIBroodNew = null
			for a in g.ais:
				if a.team == 0 and a is AIBroodNew:
					ai = a
			print("       mother %s eggs %d grow_t %.0f | raptor: %s | grub: %s |%s | keep morph %d growth %d spoils-keep %d | attack_at %d attacking %s" % [q.tesla_mode, int(q.nb.get("eggs", 0)),
				float(q.nb.get("grow_t", 0.0)), BroodNew.lay_problem(g, q, "raptor"), BroodNew.lay_problem(g, q, "grub"), fs,
				ai._morph_keep if ai else -1, ai._nb_growth_keep(q) if ai else -1, int(ai._nb_spoils_keep(q)) if ai else -1, ai._attack_at if ai else -1, str(ai._attacking) if ai else "-"])
	if g.clock >= secs or g.over:
		_finish()
		quit()
	return false


func _value(tm: int) -> int:
	var v := 0
	for u in g.army(tm):
		if BroodNew.is_nb(u.kind):
			continue
		v += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
	return v


var _next_half := 30.0


func _watch() -> void:
	if g.clock >= _next_half and g.clock <= 361.0:
		_next_half += 30.0
		if not res.has("early"):
			res["early"] = {}
		res["early"][str(int(round(g.clock)))] = [_value(0), _value(1)]
	if not res.has("arrive"):
		var st := (Vector2(g.starts[1]) + Vector2(2.5, 2.0)) * Defs.TILE
		for u in g.army(0):
			if not BroodNew.is_nb(u.kind) and u.position.distance_to(st) < 16.0 * Defs.TILE and u.kind != "grub":
				res["arrive"] = int(g.clock)
				break
	var q = BroodNew.queen(g, 0)
	if q:
		var st := BroodNew.stage(q) + 1
		if st > 1 and not res["stages"].has(str(st)):
			res["stages"][str(st)] = int(g.clock)
		for f in BroodNew.FATHERS:
			var s = BroodNew.father(g, 0, f)
			if s and not BroodRoot.in_cocoon(s) and not res["sires"].has(f):
				res["sires"][f] = int(g.clock)
		var far := 0
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == BroodNew.TURTLE and BroodNew.rooted(u) and u.position.distance_to(q.position) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE:
				far += 1
		res["far_turtles"] = maxi(int(res["far_turtles"]), far)
		if far > 0 and int(res["natural"]) < 0:
			res["natural"] = int(g.clock)
			for u in BroodNew.expansions(g, q):
				res["natural_tiles"] = int(u.position.distance_to(q.position) / Defs.TILE)
		if int(res["maw3"]) < 0:
			var rm := 0
			for u in g.units:
				if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
					rm += 1
			if rm >= 3:
				res["maw3"] = int(g.clock)
		if int(res["scout"]) < 0:
			for a in g.ais:
				if a.team == 0 and a is AIBroodNew:
					for n in a.note:
						if String(n[1]).begins_with("sends a"):
							res["scout"] = int(n[0])
							break
		res["turtles"] = maxi(int(res["turtles"]), BroodNew.count_of(g, 0, BroodNew.TURTLE))
		res["maws"] = maxi(int(res["maws"]), BroodNew.count_of(g, 0, BroodNew.MAW))
		res["grubs_max"] = maxi(int(res["grubs_max"]), BroodNew.count_of(g, 0, "grub"))
	for key in BroodResearch.keys():
		if g.has_tech(0, key) and not res["research"].has(key):
			res["research"][key] = int(g.clock)
	for u in g.units:
		if u.team == 0 and not u.dead and BroodMature.is_mature(u.kind) and not _young_seen.has(u.get_instance_id()):
			_young_seen[u.get_instance_id()] = true
			_matured += 1
	res["matured"] = _matured
	if not _attack_seen and g.mlog:
		for l in g.mlog.lines:
			if String(l).contains("Brood attacks with") or String(l).contains("Brood: wave"):
				_attack_seen = true
				res["first_attack"] = int(g.clock)
				break


func _line(tm: int) -> String:
	var counts := {}
	for u in g.units:
		if u.team == tm and not u.dead:
			counts[u.kind] = int(counts.get(u.kind, 0)) + 1
	var p: Dictionary = g.players[tm]
	return "t%d food/gold %d res2 %d supply %d/%d army %d killed %d lost %d %s" % [tm, int(p["gold"]), int(p["res2"]), g.supply_used(tm), int(p["cap"]),
		_value(tm), int(g.stats[tm]["value_killed"]), int(g.stats[tm]["lost"]), str(counts)]


func _finish() -> void:
	res["winner"] = g.winner if g.over else -1
	res["end"] = int(g.clock)
	res["lost"] = int(g.stats[0]["lost"])
	res["value_killed"] = int(g.stats[0]["value_killed"])
	res["foe_value_killed"] = int(g.stats[1]["value_killed"])
	res["earned"] = int(g.stats[0]["gold"])
	res["foe_earned"] = int(g.stats[1]["gold"])
	res["spoils_in"] = int(g.stats[0].get("res2_in", 0))
	res["sacrificed"] = int(g.stats[0].get("sacrificed", 0))
	res["eggs_taken"] = _egg_rule.taken
	for a in g.ais:
		if a.team == 0 and a is AIBroodNew:
			for n in a.note:
				if String(n[1]).begins_with("ALARM") or String(n[1]).begins_with("rush evidence"):
					res["alarms"].append("%d %s" % [int(n[0]), n[1]])
	if g.mlog:
		var waves := 0
		for l in g.mlog.lines:
			var s := String(l)
			if s.contains("Brood attacks with") or s.contains("Brood: wave"):
				waves += 1
			if s.contains("scout") and s.begins_with("[") and s.contains(g.mlog.who(0)) and res["scouted"] == "":
				res["scouted"] = s
			if s.contains(g.mlog.who(0)) or s.contains("Brood"):
				print("  LOG ", s)
		res["waves"] = waves
	print("RESULT " + JSON.stringify(res))
