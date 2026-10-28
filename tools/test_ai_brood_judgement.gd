extends SceneTree
## The Brood computer's judgement (scripts/ai_brood.gd):
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_brood_judgement.gd [-- case:hold|retreat|harvest|supply|game]
##  hold    : 32 Raptors at home, ready to attack (800); an army of 16 Musketeers (960) is SEEN by a Raptor on watch
##            and walks off: no wave goes while what it saw is clearly stronger; once those Musketeers are seen to
##            fall, the wave goes.
##  retreat : a swarm of 32 Raptors goes out (nothing seen against it) and meets 24 tough Musketeers by its staging
##            point: it pulls back home (AIBrood.retreats) with Raptors to spare, instead of dying to the last.
##  harvest : six bodies lie outside the base where nothing armed is about: grubs go and wrap them, the essence
##            comes home, and the grubs go back to their pits when none are left.
##  supply  : the Brood with eggs and biomass in hand and the supply nearly full: a Clutch Mound is put by and
##            goes up before the cap is reached (two at once when the eggs could fill one at once).
##  game    : a Hard Brood on Balanced against a Hard Crown that defends but never attacks, to 7:00: the Brood Pen
##            stands by 5:30 (after the economy: docs/brood_ai_fixes.md), essence comes in by 6:00, a creature
##            that costs essence hatches by 7:00, and the
##            Brood is never supply-blocked with biomass in hand for more than 15 s.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _make(strategy: String, foe_ai := false, map := "greenhold", seed_ := 5) -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard" if foe_ai else "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": strategy}]})
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
	return [main, g, ai]


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _spawn(g: Game, kind: String, team: int, at: Vector2, n: int, spread := 50.0) -> Array:
	var out: Array = []
	for i in n:
		var c: Vector2i = g.nearest_free(g.cell_of(at + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))), 6)
		out.append(g._add_unit(kind, team, g.cell_center(c)))
	return out


## A point `d` px from the Brood's rally front toward the enemy, on open ground.
func _ahead(g: Game, ai: AI, d: float) -> Vector2:
	var front: Vector2 = ai._front()
	var p: Vector2 = front + (ai._enemy_base() - front).normalized() * d
	return g.cell_center(g.nearest_free(g.cell_of(p), 8))


func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


# ------------------------------------------------------------------ hold

func _case_hold() -> void:
	var r: Array = await _make("balanced")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _frames(30)
	ai.scout.enabled = false        # (only what this test shows it)
	var front: Vector2 = ai._front()
	var raptors := _spawn(g, "raptor", 1, front, 32, 70.0)
	ai._regroup_until = 0.0
	# the enemy army shows itself to a Raptor on watch out in front, then walks off home
	var watch_at := _ahead(g, ai, 700.0)
	var watcher: Unit = g._add_unit("raptor", 1, watch_at)
	var foes := _spawn(g, "musketeer", 0, watch_at + (ai._enemy_base() - watch_at).normalized() * 150.0, 16, 40.0)
	for f in foes:
		f.max_hp = 5000.0
		f.hp = 5000.0
	await _frames(20)
	var known := ai.brood.known_foe_value()
	var home: Vector2 = Vector2(g.starts[0]) * Defs.TILE
	for f in foes:
		f.position = g.cell_center(g.nearest_free(g.cell_of(home), 10))
		f.cmd_stop()
	if is_instance_valid(watcher) and not watcher.dead:
		watcher.position = front       # (the watcher goes home: only the memory is left)
	check(known >= 10 * 60 - 1, "most of the Musketeers were seen and remembered (known %d)" % int(known))   # (the fog shows the front ranks)
	var went := false
	for i in 30 * 25:
		await physics_frame
		if ai._swarm_phase != "" or ai._attacking:
			went = true
			break
	check(not went and ai.brood.holds >= 1, "no wave into the stronger army it saw (32 Raptors, 800, against %d seen; holds %d)" % [int(known), ai.brood.holds])
	# they are seen to fall: the wave goes
	for f in foes:
		f.position = _ahead(g, ai, 120.0)
	await _frames(10)
	for f in foes:
		f.take_damage(99999, raptors[0])
	await _frames(15)
	for i in 30 * 20:
		await physics_frame
		if ai._swarm_phase != "" or ai._attacking:
			went = true
			break
	check(went, "once the Musketeers it saw are seen to fall, the wave goes (known now %d)" % int(ai.brood.known_foe_value()))
	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ retreat

func _case_retreat() -> void:
	var r: Array = await _make("balanced")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _frames(30)
	ai.scout.enabled = false
	var front: Vector2 = ai._front()
	var raptors := _spawn(g, "raptor", 1, front, 32, 70.0)
	ai._regroup_until = 0.0
	var went := false
	for i in 30 * 10:
		await physics_frame
		if ai._swarm_phase != "":
			went = true
			break
	check(went, "the swarm of 32 Raptors goes out (nothing seen against it)")
	# a line of tough Musketeers it had not seen, at its staging point
	var stage: Vector2 = ai._swarm[0][1] if not ai._swarm.is_empty() else ai._front().lerp(ai._enemy_base(), 0.5)
	var foes := _spawn(g, "musketeer", 0, stage, 24, 70.0)
	for f in foes:
		f.max_hp = 400.0
		f.hp = 400.0
	var pulled := false
	for i in 30 * 60:
		await physics_frame
		if ai.brood.retreats > 0:
			pulled = true
			break
		if _alive(raptors).is_empty():
			break
	var left := _alive(raptors).size()
	check(pulled, "the swarm pulled back from the lost fight (retreats %d)" % ai.brood.retreats)
	check(left >= 12, "... with Raptors to spare (%d of 32 alive when it turned)" % left)
	check(not ai._attacking and ai._swarm_phase == "", "... and the wave is over (attacking %s, phase '%s')" % [str(ai._attacking), ai._swarm_phase])
	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ harvest

func _case_harvest() -> void:
	var r: Array = await _make("balanced")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _frames(30)
	# grubs enough to spare a few (they are the economy)
	var cap := g.capital(1)
	_spawn(g, "grub", 1, cap.center() + Vector2(0, 90), 6)
	await _frames(60)
	# bodies: Crown soldiers fallen in front of the base (in sight), where nothing armed is about
	var spot := _ahead(g, ai, 60.0)
	for d in [320.0, 260.0, 200.0, 140.0]:
		var p := _ahead(g, ai, d)
		if g.is_visible_to(1, p):
			spot = p
			break
	var dead := _spawn(g, "musketeer", 0, spot, 6, 30.0)
	for f in dead:
		f.take_damage(99999, null)
	await _frames(10)
	var e0 := float(g.stats[1]["res2_in"])      # (essence earned, not banked: a Brood with a Pen may spend it at once, brood-econ)
	var bodies0 := g.corpses.size()
	var out_max := 0
	for i in 30 * 70:
		await physics_frame
		var out := g.workers(1).filter(func(w: Unit) -> bool: return w.order == "harvest").size()
		out_max = maxi(out_max, out)
	var gained := float(g.stats[1]["res2_in"]) - e0
	check(bodies0 >= 6, "six bodies lie in front of the base (%d)" % bodies0)
	check(out_max >= 1 and ai.brood.harvest_sent >= 1, "grubs went to harvest them (at most %d out at once, %d sent)" % [out_max, ai.brood.harvest_sent])
	check(gained >= 5.0, "the essence came home (+%.2f)" % gained)
	var still := g.workers(1).filter(func(w: Unit) -> bool: return w.order == "harvest").size()
	check(still == 0, "the grubs went back to the pits when none were left (%d still out)" % still)
	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ supply

func _case_supply() -> void:
	var r: Array = await _make("balanced")
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _frames(30)
	g.clock = 240.0
	var cap := g.capital(1)
	_spawn(g, "grub", 1, cap.center() + Vector2(0, 90), 4)
	var front: Vector2 = ai._front()
	_spawn(g, "raptor", 1, front, 6)       # (5 grubs + 4 + 6 Raptors: 15 of the Burrow's 16)
	ai.peaceful = true
	g.players[1]["gold"] = 60
	await _frames(10)
	var margin := ai.brood.supply_margin()
	var due0 := ai.brood.supply_due
	# the mound's 75 is put by: no grub nor egg eats it
	var mounds0 := ai._mine("clutch_mound").size()
	var placed := false
	for i in 30 * 25:
		await physics_frame
		g.players[1]["gold"] = mini(int(g.players[1]["gold"]), 400) + (1 if i % 6 == 0 else 0)
		if ai._mine("clutch_mound").size() > mounds0:
			placed = true
			break
	check(due0 or ai.brood.supply_due or placed, "a Clutch Mound is due with the supply nearly full (margin %d, cap %d, used %d)" % [margin, g.players[1]["cap"], g.supply_used(1)])
	check(placed, "the mound goes down once its 75 biomass is put by (eggs and grubs waited)")
	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ a real game

func _case_game() -> void:
	var r: Array = await _make("balanced", true, "ashford_crossing", 4242)
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	for a in g.ais:
		if a.team == 0:
			a.peaceful = true       # (a normal economy and a defence, but it never attacks)
	var pen_t := -1.0
	var blocked := 0.0
	var tech_t := -1.0
	var last := g.clock
	var ess5 := 0.0
	while g.clock < 420.0 and not g.over:
		await physics_frame
		var dt := g.clock - last
		last = g.clock
		if pen_t < 0.0 and g._has_built(1, "brood_pen"):
			pen_t = g.clock
		var cap: int = g.players[1]["cap"]
		if cap < g.max_supply(1) and cap - g.supply_used(1) < 3 and int(g.players[1]["gold"]) >= 75:
			blocked += dt
		if tech_t < 0.0:
			for u in g.army(1):
				if int(u.d.get("cost2", 0)) > 0:
					tech_t = g.clock
		if ess5 <= 0.0 and g.clock >= 360.0:
			ess5 = float(g.stats[1]["res2_in"])
	print("Pen at %s, essence earned by 6:00 %.1f (sacrificed %d), first essence creature at %s, supply-blocked %.0f s, army %d, workers %d" % [
		_mmss(pen_t), ess5, int(g.stats[1].get("sacrifice_essence", 0)), _mmss(tech_t), blocked, g.army_value(1), g.workers(1).size()])
	check(pen_t >= 0.0 and pen_t <= 330.0, "the Brood Pen stands by 5:30 (%s)" % _mmss(pen_t))
	check(ess5 > 0.0, "essence comes in by 6:00 (%.1f)" % ess5)
	check(tech_t >= 0.0, "a creature that costs essence hatched by 7:00 (%s)" % _mmss(tech_t))
	check(blocked <= 15.0, "never supply-blocked with biomass in hand for long (%.0f s)" % blocked)
	main.queue_free()
	await process_frame


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]


func _run() -> void:
	var case := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("case:"):
			case = a.substr(5)
	if case == "" or case == "hold":
		await _case_hold()
	if case == "" or case == "retreat":
		await _case_retreat()
	if case == "" or case == "harvest":
		await _case_harvest()
	if case == "" or case == "supply":
		await _case_supply()
	if case == "" or case == "game":
		await _case_game()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
