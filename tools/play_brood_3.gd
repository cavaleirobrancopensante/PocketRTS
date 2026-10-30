extends "res://tools/play_brood_new.gd"
## ROUND 3 OF THE COACHED BROOD GAMES (docs/brood_new_play_3.md): today's Brood (the Sire lures, research, young and
## mature, the Storm line, two young to an egg, her stages, spoils) coached through a written plan and filmed, against the
## Crown or the Clockwork computer. Side 0 is the Brood. Its moves are the computer's building blocks
## (scripts/ai_brood_new.gd: placing, laying, rooting, the same orders a player gives), STEERED by the coach: each game
## forces a plan (`coach:<plan>`, the settings below, any of them changed with `set:key=value,...`) and the coach adds
## its own hand orders on top (`ramp:1` walks the first Mound Turtle onto the ramp and roots it there).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_3.gd -- \
##       coach:rush b:crown map:greenhold seed:3 out:/abs/dir [end:900] [db:hard] [sb:balanced] [set:wave=8,wave_t=120]
## Everything of tools/play_brood_new.gd (fight shots, mother_MMSS.png, the match log, coach.txt, events.txt) plus:
##   <out>/minutes.txt  a line a minute: eggs laid that minute, food and spoils (unspent), supply, army value (both
##                      sides), research done, young matured, losses and kills, her stage
##   key moments: sire_<kind>_MMSS.png (a Sire arrived), wave_MMSS.png, clip_first_wave (GIF), moult_MMSS.png,
##   ramp_turtle_MMSS.png
## The coach's plans (each a set of the computer's plan settings, AIBroodNew.PLANS):
##   rush     Extreme rush: the Tyrant Sire's lure with 5 grubs, 6 grubs held, the first 6 Raptors go at once
##   rush10   Rush: 9 grubs, the first wave of 10 Raptors
##   tyrant   the Tyrant line timing: Bigger Clutch, Pack Hunt, her stage 3 early for Brutes and Battering Horns, then a wall
##   venom    the Venom line: Spitters ahead of Raptors (one for each), Long Spit and Slither, a later push
##   storm    the Storm line: her stage 2 early, the Storm Sire second, Hatchlings for flyers, Storm Challengers
##   expand   a fast expand: three Mound Turtles on new ground by 5:30, many Rootmaws, a late big army
##   turtle   a turtle-and-ramp defence: the first turtle roots on the ramp, the army stays home until 8:00
##   sirefront  (the owner, 23:31) a timing attack led by the Tyrant Sire himself (uprooted, the frontline), Spitters behind
##   venomback  (the owner) the opposite: a big Raptor pack in front, the Venom Sire walking with it as long-range support
##   mother     (the owner: "crazy") the Brood Mother uproots at once and attack-moves to the enemy's base; grubs and
##              Rootmaws go on being made on the way; at the enemy everything (grubs and Rootmaws too) attacks
##   airrush    (the owner) Storm Challengers as fast as possible: stage 2, the Storm Sire's lure, Hatchlings, stage 3,
##              MATURE, and attack with them
##   ai       the computer's own profile (sb2:<strategy>), not steered
## BROOD ECONOMY (docs/brood_eco.md; the owner, 2026-10-30 07:15: "exhaust better Brood economic play first"):
##   eco      the owner's build on Balanced: the first Mound Turtle on the NATURAL, the third Rootmaw at the natural's FAR
##            edge, grubs nonstop, the second turtle on the THIRD expansion with a Rootmaw there, spoils from offered-up
##            Raptors, a grub on watch (the Crown's ramp foot / the Clockwork's main) and the alarm's reactions
##   ecox     the same on the Economy profile (more grubs, the third turtle sooner)
##   ecoair   the AIR RUSH again on the owner's economy: spoils banked from offered-up Raptors for the Storm line (her
##            stage 2 early, the Storm Sire, Hatchlings, her stage 3, MATURE into Storm Challengers), then attack with them
## The new SACRIFICE rule (one egg back per egg's worth of young) is the game's since 0.22.3 (onegg:1: tools/brood_one_egg.gd
## applies it to an older build).

const COACH := {
	"rush": {"strategy": "xrush", "set": {}},
	"rush10": {"strategy": "rush", "set": {}},
	"tyrant": {"strategy": "timing", "set": {"grow": [180.0, 400.0], "mix": "tyrant", "wave": 26, "wave_t": 480.0, "pack": true}},
	"venom": {"strategy": "balanced", "set": {"venom": 120.0, "mix": "venom", "wave": 26, "wave_t": 420.0}},
	"storm": {"strategy": "air", "set": {"grow": [150.0, 390.0], "storm": 160.0}},
	"expand": {"strategy": "economy", "set": {"far": [[150.0, 1], [240.0, 2], [330.0, 3]], "maws": [3, 60.0, 10], "grubs": 36}},
	"turtle": {"strategy": "balanced", "set": {"wave_t": 480.0, "wave": 30}},
	"sirefront": {"strategy": "timing", "set": {"mix": "venom", "venom": 120.0, "sire_leads": "tyrannosaur", "wave": 24, "wave_t": 420.0}},
	"venomback": {"strategy": "timing", "set": {"mix": "tyrant", "venom": 150.0, "sire_leads": "dilophosaurus", "wave": 24, "wave_t": 400.0}},
	"mother": {"strategy": "balanced", "set": {"mother_free": true, "wave_t": 9999.0, "sire_g": 99, "sire_t": 9999.0, "maws": [0, 9999.0, 0], "far": []}},
	"airrush": {"strategy": "air", "set": {"grow": [110.0, 320.0], "storm": 100.0, "storm_want": 14, "wave": 12, "wave_t": 0.0, "mature": "push"}},
	"ai": {"strategy": "", "set": {}},
	"eco": {"strategy": "balanced", "set": {"eco": true}},
	"ecox": {"strategy": "economy", "set": {"eco": true}},
	"ecoair": {"strategy": "air", "set": {"eco": true, "grow": [150.0, 360.0], "storm": 150.0, "storm_want": 12, "spoils_bank": 150.0,
		"wave": 16, "wave_t": 420.0, "mature": "push"}},
}

var coach_plan := "ai"
var strat2 := "balanced"
var sets := {}
var ramp_job := false
var noscout := false             # noscout:1 the enemy computer sends no scout (an opponent that does not scout a rush)
var _ai: AIBroodNew = null
var _min_lines: Array = []
var _next_min := 60.0
var _laid0 := 0
var _sires_seen := {}
var _matured_seen := {}
var _ramp_t: Unit = null
var _ramp_done := false
var _waves_seen := 0
var _egg_rule = preload("res://tools/brood_one_egg.gd").new()
var _earned0 := [0, 0]


func _initialize() -> void:
	super._initialize()
	ai_plays = true
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach_plan = kv[1]
			"sb2": strat2 = kv[1]
			"ramp": ramp_job = kv[1] == "1"
			"noscout": noscout = kv[1] == "1"
			"onegg": _egg_rule.on = kv[1] == "1"
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]
	if coach_plan == "turtle":
		ramp_job = true


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			var c: Dictionary = COACH.get(coach_plan, COACH["ai"])
			var st := String(c["strategy"]) if String(c["strategy"]) != "" else strat2
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "brood", "colour": 0, "side": 0, "strategy": st},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
			for a in main.game.ais:
				if a.team == 0 and a is AIBroodNew:
					_ai = a
					var o: Dictionary = (c["set"] as Dictionary).duplicate(true)
					for k in sets:
						o[k] = sets[k]
					_ai.over = o
					_ai._make_plan()
					print("COACH plan %s: strategy %s, forced %s" % [coach_plan, st, str(o)])
				elif a.team == 1 and noscout and a.scout != null:
					a.scout.enabled = false
					print("COACH the enemy computer sends no scout")
		return false
	g = main.game
	if not g.over and _ai != null:
		_egg_rule.tick(g, 0)
		_coach3()
	return super._process(delta)


func _coach3() -> void:
	var q := BroodNew.queen(g, 0)
	if q == null:
		return
	if g.clock >= _next_min:
		_next_min += 60.0
		_minute(q)
	# a Sire arrived: a picture of him on his nest
	for f in BroodNew.FATHERS:
		var s := BroodNew.father(g, 0, f)
		if s and not BroodRoot.in_cocoon(s) and not _sires_seen.has(f):
			_sires_seen[f] = g.clock
			say("the %s has come (%s)" % [Defs.UNITS[f]["name"], _mmss(g.clock)])
			_later.append([g.clock + 3.0, "sire_%s_%s.png" % [f, _mmss(g.clock)], s])
	# a young one moulting: a picture of the first
	for u in g.units:
		if u.team == 0 and not u.dead and u.moult_t >= 0.0 and not _matured_seen.has(u.get_instance_id()):
			_matured_seen[u.get_instance_id()] = true
			if _matured_seen.size() == 1:
				shot("moult", u, 1.6, 0.0)
	# the waves: the first one filmed, every one a picture
	var w := _ai.note.filter(func(n) -> bool: return String(n[1]).begins_with("attacks with")).size()
	if w > _waves_seen:
		_waves_seen = w
		var lead: Unit = null
		for u in _ai._wave:
			if is_instance_valid(u) and not u.dead:
				lead = u
				break
		if lead:
			if w == 1:
				clip("first_wave", lead, 30, 6, 1.0)
			_later.append([g.clock + 25.0, "wave%d_%s.png" % [w, _mmss(g.clock)], lead])
	_eco_shots(q)
	if ramp_job:
		_ramp3(q)
	if coach_plan == "mother":
		_mother_rush(q)


## The owner's economic build filmed (docs/shots/brood_eco/): the first Mound Turtle rooted on the natural, the third
## Rootmaw rooted (the natural's far edge), the grub on watch (40 s after it goes out), each ALARM, the first Storm
## Challenger.
var _eco_seen := {}


func _eco_shots(q: Unit) -> void:
	var exps := BroodNew.expansions(g, q)
	if not exps.is_empty() and not _eco_seen.has("natural"):
		_eco_seen["natural"] = true
		say("the first Mound Turtle on new ground (%d tiles out) at %s" % [int(exps[0].position.distance_to(q.position) / Defs.TILE), _mmss(g.clock)])
		_later.append([g.clock + 4.0, "natural_turtle_%s.png" % _mmss(g.clock), exps[0]])
	var maws: Array = mine(BroodNew.MAW).filter(func(m: Unit) -> bool: return BroodNew.rooted(m))
	if maws.size() >= 3 and not _eco_seen.has("maw3"):
		_eco_seen["maw3"] = true
		var far: Unit = maws[0]
		for m in maws:
			if m.serial > far.serial:
				far = m
		say("the third Rootmaw roots %d tiles from the Mother at %s" % [int(far.position.distance_to(q.position) / Defs.TILE), _mmss(g.clock)])
		_later.append([g.clock + 20.0, "third_rootmaw_%s.png" % _mmss(g.clock), far])
	for n in _ai.note:
		var key := "%d %s" % [int(n[0]), n[1]]
		if _eco_seen.has(key):
			continue
		_eco_seen[key] = true
		if String(n[1]).begins_with("sends a Grub") and _ai._scout != null:
			_later.append([g.clock + 40.0, "watching_grub_%s.png" % _mmss(g.clock + 40.0), _ai._scout])
		elif String(n[1]).begins_with("ALARM: an enemy"):
			shot("alarm", _ai.alarm_at, 0.9, 60.0)
	if not _eco_seen.has("storm_ch"):
		var sc := mine("storm_challenger")
		if not sc.is_empty():
			_eco_seen["storm_ch"] = true
			say("the first Storm Challenger at %s" % _mmss(g.clock))
			_later.append([g.clock + 3.0, "storm_challenger_%s.png" % _mmss(g.clock), sc[0]])


## The coach's hand order (turtle plan): the first Mound Turtle rooted at home gets up and walks onto the ramp below
## the Mother's ground, and roots there (a wall the enemy must break; the computer leaves it alone: AIBroodNew.held).
func _ramp3(q: Unit) -> void:
	if _ramp_done:
		return
	if _ramp_mid == Vector2.INF:
		_ramp_mid = _find_ramp_mid(q.position)
		if _ramp_mid == Vector2.INF:
			_ramp_done = true
			say("ramp: no ramp found by the Mother")
			return
	if _ramp_t == null:
		for tt in mine(BroodNew.TURTLE):
			if BroodNew.rooted(tt):
				_ramp_t = tt
				_ai.held.append(tt)
				BroodNew.uproot(tt, false)
				say("ramp: the first Mound Turtle gets up and walks to the ramp (%d tiles)" % int(tt.position.distance_to(_ramp_mid) / Defs.TILE))
				break
		return
	if not is_instance_valid(_ramp_t) or _ramp_t.dead:
		_ramp_done = true
		return
	if _ramp_t.tesla_mode == "packed":
		if _ramp_t.position.distance_to(_ramp_mid) < 30.0 or (_ramp_t.order == "idle" and _ramp_t.position.distance_to(_ramp_mid) < 70.0):
			_ramp_t.cmd_deploy()
		elif _ramp_t.order == "idle":
			_ramp_t.cmd_move(_ramp_mid)
	elif BroodNew.rooted(_ramp_t):
		_ramp_done = true
		say("ramp: the turtle roots on the ramp")
		shot("ramp_turtle", _ramp_t, 1.1, 0.0)


## The Mother rush (the owner's "crazy" test, 23:34: an insane ALL-IN, whatever it costs): from the first second she gets
## up and walks on the enemy's start, and EVERYTHING goes with her: every grub (no gathering), the Rootmaw (got up), every
## creature hatched on the way (the computer lays grubs out of the food in hand, nothing else: no Sire, no Rootmaws).
## On the way they escort her (attack-moving to just ahead of her); near the enemy (18 tiles) everything attacks.
## noscout:1 switches the enemy computer's scout off (an opponent that does NOT scout it).
var _mr_t := 0.0
var _mr_arrived := false


func _mother_rush(q: Unit) -> void:
	if g.clock < 0.5 or g.clock < _mr_t:
		return
	_mr_t = g.clock + 1.5
	var goal := foe_start()
	if q.tesla_mode == "deployed" and not BroodRoot.in_cocoon(q):
		BroodNew.uproot(q, false)
		if not _shots_t.has("mr_start"):
			_shots_t["mr_start"] = g.clock
			say("MOTHER RUSH: she uproots and marches on the enemy (%d tiles), everything with her" % int(q.position.distance_to(goal) / Defs.TILE))
			clip("mother_march", q, 30, 8, 0.9)
	elif q.tesla_mode == "packed" and q.target == null and (q.order == "idle" or q.path_goal.distance_to(goal) > 120.0):
		q.cmd_move(goal, true)
	if not _mr_arrived and q.position.distance_to(goal) < 18.0 * Defs.TILE:
		_mr_arrived = true
		say("MOTHER RUSH: she is at the enemy's base (%d hp): everything attacks" % int(q.hp))
		clip("mother_at_base", q, 30, 6, 0.9)
	var ahead: Vector2 = q.position + (goal - q.position).normalized() * 3.0 * Defs.TILE
	var to: Vector2 = goal if _mr_arrived else ahead
	for u in mine("grub") + mine(BroodNew.MAW) + army():
		if u.kind == BroodNew.MAW:
			if not _ai.held.has(u):
				_ai.held.append(u)
			if u.tesla_mode == "deployed" and not BroodRoot.in_cocoon(u):
				BroodNew.uproot(u, false)
				continue
		if u.tesla_mode == "deploying" or u.tesla_mode == "packing" or u.order == "sacrifice" or u.cocoon > 0.0:
			continue
		if u.target != null and is_instance_valid(u.target):
			continue
		if u.order != "amove" or u.path_goal.distance_to(to) > 90.0:
			u.cmd_move(to, true)
	# all in: every egg she has goes into grubs (they fight too), as long as the food lasts
	if BroodNew.lay_problem(g, q, "grub") == "":
		BroodNew.lay(g, q, "grub")
	if _mr_arrived:
		shot("mother_fight", q, 0.9, 30.0)
		# a wall or gate in the way (the Crown walls its ramp in the first minute): she breaks it, the rest with her
		var gate: Building = null
		var gd := 7.0 * Defs.TILE
		for b in g.buildings:
			if b.team != 0 and not b.dead and b.built and (b.kind == "wall" or b.kind == "gate") and b.center().distance_to(q.position) < gd:
				gd = b.center().distance_to(q.position)
				gate = b
		if gate != null and (q.target == null or not (q.target is Building)):
			q.cmd_attack(gate)
			if not _shots_t.has("mr_gate"):
				_shots_t["mr_gate"] = g.clock
				say("MOTHER RUSH: a %s bars the way: she batters it (%d hp)" % [gate.kind, int(gate.hp)])


func _minute(q: Unit) -> void:
	var laid := int(q.nb.get("laid", 0))
	var val := 0
	for u in army():
		val += Game.unit_value(u)
	var fv := 0
	for u in g.army(1):
		if not u._k_nb:
			fv += Game.unit_value(u)
	var res: Array = []
	for k in BroodResearch.keys():
		if g.has_tech(0, k):
			res.append(String(Defs.RESEARCH[k]["label"]).to_lower())
	var line := "%s | stage %d | eggs laid %d | food %d spoils %d | supply %d/%d | grubs %d maws %d turtles %d (far %d) | army %d (%s) | foe army %d | matured %d | research %s | killed %d lost %d (value killed %d, lost by foe %d) | earned %d foe %d | income %d foe %d | spoils in %d, offered %d" % [
		_mmss(g.clock), BroodNew.stage(q) + 1, laid - _laid0, int(g.players[0]["gold"]), int(g.players[0]["res2"]),
		g.supply_used(0), int(g.players[0]["cap"]), BroodNew.count_of(g, 0, "grub"), BroodNew.count_of(g, 0, BroodNew.MAW),
		BroodNew.count_of(g, 0, BroodNew.TURTLE), BroodNew.expansions(g, q).size(), val, _kinds(army()), fv, _matured_seen.size(),
		",".join(res), int(g.stats[0]["killed"]), int(g.stats[0]["lost"]), int(g.stats[0]["value_killed"]), int(g.stats[1]["value_killed"]),
		int(g.stats[0]["gold"]), int(g.stats[1]["gold"]), int(g.stats[0]["gold"]) - _earned0[0], int(g.stats[1]["gold"]) - _earned0[1],
		int(g.stats[0].get("res2_in", 0)), int(g.stats[0].get("sacrificed", 0))]
	_earned0 = [int(g.stats[0]["gold"]), int(g.stats[1]["gold"])]
	_laid0 = laid
	_min_lines.append(line)
	print("MIN " + line)


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("minutes.txt"), FileAccess.WRITE)
	f.store_line("coach plan %s, %s v %s, %s seed %d" % [coach_plan, "brood", fb, map, seed_])
	for l in _min_lines:
		f.store_line(l)
	for n in (_ai.note if _ai else []):
		f.store_line("%s %s" % [_mmss(float(n[0])), n[1]])
	f.store_line("result: over %s winner %d at %s" % [str(g.over), g.winner, _mmss(g.clock)])
	f.close()
