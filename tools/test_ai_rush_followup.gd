extends SceneTree
## What the computer sends after its first rush resolves (docs/ai_rush_followup.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_rush_followup.gd [-- case:failed|few|mop|wave|brood]
## A Hard Crown computer on the Horse Breeder opening (Horseman rush, raiding party) against a Brood
## player with no AI. The facts the rush is judged by are set up by the test (enemy value killed,
## workers and defenders "seen" through AI._known_foes), the AI decides.
##  failed : the riders are beaten back -> verdict FAILED, the survivor rides home, fresh Horsemen
##           stay home one by one and two by two (no lone unit goes out), the plan is a normal one
##  few    : the economy is crippled and 2 workers are left, no defenders -> SUCCEEDED / finish: one
##           fresh Horseman stays home, a second makes a pair and the pair rides out together
##  mop    : crippled but 8 workers and 4 Raptors left -> SUCCEEDED / mop: riders pull back, fresh
##           Horsemen wait, a mop-up force of MOP supply goes out as ONE group (wave set >= MOP)
##  wave   : the Rush plan's first wave (3 Horsemen) beaten back -> FAILED, a Horseman trained mid-rush stays home
##  brood  : a Brood Raptor rush (extreme rush) beaten back -> FAILED, a lone new Raptor stays home
## Throughout: no Crown/Brood soldier is ever alone far from home once the verdict is in
## (the lone-unit invariant), except inside the launched mop-up column.
var fails := 0
var lone_hits := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _make(ai_faction: String, strategy: String) -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var human_f := "crown" if ai_faction == "brood" else "brood"
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "human", "faction": human_f, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": ai_faction, "colour": 1, "side": 1, "strategy": strategy}]})
	var g: Game = main.game
	await process_frame
	await process_frame
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI
	for a in g.ais:
		if a.team == 1:
			ai = a
	for i in 30:
		await physics_frame
	g.clock = 200.0
	return [main, g, ai]


## Every frame: the AI is kept poor (it trains nothing of its own) and sees what the test says it sees.
func _frames(g: Game, ai: AI, n: int, seen: Array, watch: bool) -> void:
	for i in n:
		await physics_frame
		g.players[1]["gold"] = 0
		g.players[0]["gold"] = 0
		for b in g.buildings:
			if b.team == 0 and "eggs" in b:
				b.eggs = 0       # (the Brood player breeds no new grubs behind the test's back)
		for o in seen:
			if is_instance_valid(o) and not o.dead:
				ai._known_foes[o.get_instance_id()] = g.clock
		if watch and i % 10 == 0:
			lone_hits += _lone(g)


## Soldiers of team 1 alone (nobody of ours within 300) and far (450+) from every building of ours.
func _lone(g: Game) -> int:
	var n := 0
	var mine: Array = g.army(1)
	for u in mine:
		if u.aboard != null or u.is_air():
			continue
		var far := true
		for b in g.buildings:
			if b.team == 1 and not b.dead and b.center().distance_to(u.position) < 450.0:
				far = false
				break
		if not far:
			continue
		var buddy := false
		for o in mine:
			if o != u and o.position.distance_to(u.position) < 300.0:
				buddy = true
				break
		if not buddy:
			n += 1
	return n


func _front(ai: AI) -> Vector2:
	return ai._front()


func _spawn(g: Game, kind: String, team: int, at: Vector2, tough := false) -> Unit:
	var u: Unit = g._add_unit(kind, team, at + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
	if tough:
		u.max_hp = 4000.0
		u.hp = 4000.0
	return u


func _kill(u: Unit) -> void:
	u.hp = 0.0
	u.die()


func _foe_grubs(g: Game, keep: int) -> Array:
	var gr: Array = g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.is_worker())
	while gr.size() > keep:
		_kill(gr.pop_back())
	var hive: Building = g.halls_of(0)[0]
	while gr.size() < keep:
		gr.append(_spawn(g, g.workers(0)[0].kind, 0, hive.center() + Vector2(0, 90)))
	return gr


## The raiding party goes out (3 Horsemen at the rally point together).
func _party(g: Game, ai: AI) -> Array:
	ai.opening = "breeder"
	var hs: Array = []
	for i in 3:
		hs.append(_spawn(g, "cuirassier", 1, _front(ai)))
	var seen: Array = []
	for i in 40:
		await _frames(g, ai, 10, seen, false)
		if ai._rush_state == "ongoing":
			break
	return hs


func _case_failed() -> void:
	var r: Array = await _make("crown", "economy")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	var hs: Array = await _party(g, ai)
	check(ai._rush_state == "ongoing" and ai._raiders.size() >= 2, "the Horseman rush goes out as a group (%d riders), verdict ongoing [failed]" % ai._raiders.size())
	var grubs := _foe_grubs(g, 9)
	var raptors: Array = []
	for i in 8:
		raptors.append(_spawn(g, "raptor", 0, g.halls_of(0)[0].center() + Vector2(0, 120), true))
	var seen: Array = grubs + raptors
	await _frames(g, ai, 60, seen, false)
	check(ai._rush_state == "ongoing", "no verdict in the first seconds (still ongoing at %.0f s) [failed]" % (g.clock - ai._rush_t0))
	_kill(hs[0])
	_kill(hs[1])
	await _frames(g, ai, 600, seen, false)
	check(ai._rush_state == "failed", "two of three riders gone, defenders alive: verdict FAILED (%s) [failed]" % ai._rush_why)
	check(ai._raiders.is_empty() and not ai._attacking, "the raiding party is disbanded [failed]")
	# fresh cavalry one by one, then two together: nobody leaves
	lone_hits = 0
	var front := _front(ai)
	var far := 0.0
	var f1 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 300, seen, true)
	var f2 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 450, seen, true)
	for u in [f1, f2]:
		if is_instance_valid(u) and not u.dead:
			far = maxf(far, u.position.distance_to(front))
	check(far < 450.0, "fresh Horsemen (1, then 2) stay home as defence (farthest %.0f px) [failed]" % far)
	check(ai._raiders.is_empty(), "no raiding party re-forms after a failed rush [failed]")
	check(lone_hits == 0, "never a lone soldier far from home (%d sightings) [failed]" % lone_hits)
	var surv = hs[2]
	check(not is_instance_valid(surv) or surv.dead or surv.position.distance_to(front) < 450.0, "the surviving rider retreated home or died, he is not left out there [failed]")
	check(ai._attack_at >= 14 and g.clock < ai._regroup_until, "it builds up: attack size %d, regroup until %.0f (now %.0f) [failed]" % [ai._attack_at, ai._regroup_until, g.clock])
	main.queue_free()
	await process_frame


func _case_few() -> void:
	var r: Array = await _make("crown", "economy")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	var hs: Array = await _party(g, ai)
	var grubs := _foe_grubs(g, 2)
	g.stats[1]["value_killed"] = int(g.stats[1]["value_killed"]) + 3000
	var seen: Array = grubs
	await _frames(g, ai, 600, seen, false)
	check(ai._rush_state == "succeeded" and ai._rush_mode == "finish", "crippled economy, 2 workers left, no defenders: SUCCEEDED / finish (%s/%s) [few]" % [ai._rush_state, ai._rush_mode])
	lone_hits = 0
	var front := _front(ai)
	var f1 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 240, seen, false)
	check(not ai._raiders.has(f1) and f1.position.distance_to(front) < 450.0, "one fresh Horseman does not ride out alone [few]")
	var f2 := _spawn(g, "cuirassier", 1, front)
	var joined := false
	for i in 40:
		await _frames(g, ai, 10, seen, true)
		if ai._raiders.has(f1) and ai._raiders.has(f2):
			joined = true
			break
	check(joined, "a second makes a pair and the pair joins the finish together [few]")
	await _frames(g, ai, 300, seen, true)
	check(lone_hits == 0, "the finishing pair never rides alone (%d lone sightings) [few]" % lone_hits)
	main.queue_free()
	await process_frame


func _case_mop() -> void:
	var r: Array = await _make("crown", "economy")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	var hs: Array = await _party(g, ai)
	var grubs := _foe_grubs(g, 8)
	var raptors: Array = []
	for i in 4:
		raptors.append(_spawn(g, "raptor", 0, g.halls_of(0)[0].center() + Vector2(0, 120), true))
		raptors[i].order = "hold"
	g.stats[1]["value_killed"] = int(g.stats[1]["value_killed"]) + 3000
	var seen: Array = grubs + raptors
	await _frames(g, ai, 600, seen, false)
	check(ai._rush_state == "succeeded" and ai._rush_mode == "mop", "crippled but 8 workers and 4 Raptors left: SUCCEEDED / mop-up (%s/%s) [mop]" % [ai._rush_state, ai._rush_mode])
	var need: int = ai._attack_at
	check(need >= AI.RUSH_MOP_MIN and ai._raiders.is_empty(), "a mop-up force of %d supply is wanted, the party is disbanded [mop]" % need)
	var front := _front(ai)
	await _frames(g, ai, 450, seen, false)
	var out := 0
	for u in hs:
		if is_instance_valid(u) and not u.dead and u.position.distance_to(front) > 450.0:
			out += 1
	check(out == 0, "the riders pulled back to the rally point (%d still out) [mop]" % out)
	lone_hits = 0       # (the riders' ride home is over: from here nobody may be out alone)
	var f1 := _spawn(g, "cuirassier", 1, front)
	var f2 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 450, seen, true)
	check(not ai._attacking and f1.position.distance_to(front) < 450.0 and f2.position.distance_to(front) < 450.0, "even two fresh Horsemen wait for the group of %d supply [mop]" % need)
	check(lone_hits == 0, "no lone soldier before the group goes (%d sightings) [mop]" % lone_hits)
	for i in 14:
		_spawn(g, "musketeer", 1, front)
	var launched := false
	for i in 60:
		await _frames(g, ai, 10, seen, false)
		if ai._attacking:
			launched = true
			break
	check(launched and ai._wave_set.size() >= need - 2, "the mop-up force goes out as ONE group (%d units in the wave set, wanted %d supply) [mop]" % [ai._wave_set.size(), need])
	main.queue_free()
	await process_frame


func _case_brood() -> void:
	var r: Array = await _make("brood", "xrush")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	var front := _front(ai)
	var rs: Array = []
	for i in 6:
		rs.append(_spawn(g, "raptor", 1, front))
	var seen: Array = []
	for i in 40:
		await _frames(g, ai, 10, seen, false)
		if ai._rush_state == "ongoing":
			break
	check(ai._rush_state == "ongoing" and ai._attacking, "the Raptor rush goes out (%d in the wave) [brood]" % ai._xr_wave.size())
	var mus: Array = []
	for i in 8:
		mus.append(_spawn(g, "musketeer", 0, g.halls_of(0)[0].center() + Vector2(0, 100), true))
		mus[i].order = "hold"
	seen = mus
	for i in 5:
		_kill(rs[i])
	await _frames(g, ai, 500, seen, false)
	check(ai._rush_state == "failed", "5 of 6 Raptors gone against Musketeers: verdict FAILED (%s) [brood]" % ai._rush_why)
	check(ai.strategy == "balanced", "the plan switches to a normal build (%s) [brood]" % ai.strategy)
	lone_hits = 0
	var n := _spawn(g, "raptor", 1, front)
	await _frames(g, ai, 400, seen, true)
	check(n.position.distance_to(front) < 450.0 and lone_hits == 0, "a lone new Raptor stays home (%.0f px, %d lone sightings) [brood]" % [n.position.distance_to(front), lone_hits])
	main.queue_free()
	await process_frame


func _case_wave() -> void:
	var r: Array = await _make("crown", "rush")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	ai.opening = "breeder"
	var front := _front(ai)
	var hs: Array = []
	for i in 3:
		hs.append(_spawn(g, "cuirassier", 1, front))
	var seen: Array = []
	for i in 40:
		await _frames(g, ai, 10, seen, false)
		if ai._rush_state == "ongoing":
			break
	check(ai._rush_state == "ongoing" and ai._attacking and ai._wave_set.size() == 3, "the Rush plan's first wave of 3 Horsemen goes out as the rush [wave]")
	var raptors: Array = []
	for i in 8:
		raptors.append(_spawn(g, "raptor", 0, g.halls_of(0)[0].center() + Vector2(0, 120), true))
		raptors[i].order = "hold"
	seen = raptors
	_kill(hs[0])
	_kill(hs[1])
	var f0 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 120, seen, false)
	check(not ai._wave_set.has(f0) and f0.position.distance_to(front) < 450.0, "a Horseman trained mid-rush is not sent after the wave alone [wave]")
	await _frames(g, ai, 600, seen, false)
	check(ai._rush_state == "failed" and not ai._attacking, "beaten back: FAILED, wave over (%s) [wave]" % ai._rush_why)
	check(ai.strategy == "balanced", "the Rush plan switches to a normal game (%s) [wave]" % ai.strategy)
	lone_hits = 0
	var f1 := _spawn(g, "cuirassier", 1, front)
	await _frames(g, ai, 450, seen, true)
	var far := maxf(f0.position.distance_to(front), f1.position.distance_to(front))
	check(far < 450.0 and lone_hits == 0 and not ai._attacking, "new cavalry stays home as defence (%.0f px, %d lone sightings) [wave]" % [far, lone_hits])
	main.queue_free()
	await process_frame


func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("case:"):
			only = a.substr(5)
	if only == "" or only == "failed":
		await _case_failed()
	if only == "" or only == "few":
		await _case_few()
	if only == "" or only == "mop":
		await _case_mop()
	if only == "" or only == "wave":
		await _case_wave()
	if only == "" or only == "brood":
		await _case_brood()
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
