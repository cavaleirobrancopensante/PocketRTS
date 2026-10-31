extends SceneTree
## The computer's harass (scripts/ai_harass.gd, docs/ai_harass.md; owner, 2026-10-31: a lone Clock Soldier stood hitting a
## ROOTED Mound Turtle instead of pushing on to the Brood's worker line):
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_harass.gd
##  [clock]  a Brood base (its computer off): a rooted Mound Turtle in the way, grubs working a rooted Rootmaw behind it.
##           One Clock Soldier on attack-move INTO the turtle is taken by the harass. Within 40 s it has hurt the grubs
##           and spent little of its time on the turtle. A Tyrant Sire comes at it: it pulls back (alive); the Sire gone,
##           it comes again.
##  [horse]  the same with one Crown Horseman taken by the harass.
##  [raid]   the Crown's raiding party (AI._raid, two Horsemen) on the same ground: grubs hurt, the turtle left alone;
##           a Sire rides them home.
const T := 32.0
var fails := 0
var main: Node
var g: Game
var ai
var q: Unit
var dir := Vector2.ZERO
var turtle: Unit
var maw: Unit
var grubs: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


func _start(fac: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(7)
	main.start({"map": "greenhold", "seed": 7, "slots": [
		{"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still: the test's prop)
		else:
			ai = a
	ai.opening = "mill"
	await wait(1.0)
	q = BroodNew.queen(g, 1)
	dir = (g.center_of_team(0) - q.position).normalized()
	# a rooted Rootmaw a little to the side, grubs working it; a rooted Mound Turtle on the way in
	var side := dir.orthogonal()
	turtle = g._add_unit(BroodNew.TURTLE, 1, _root_spot(BroodNew.TURTLE, q.position + dir * 15.0 * T, false))
	turtle.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	# (the Rootmaw on the turtle's swamp, behind it and to one side: the new ground's worker line)
	maw = g._add_unit(BroodNew.MAW, 1, _root_spot(BroodNew.MAW, turtle.position - dir * 6.0 * T + side * 5.0 * T, true))
	maw.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	check(BroodNew.rooted(maw) and BroodNew.rooted(turtle), "(set-up) the Rootmaw and the Mound Turtle are rooted (%s, %s)" % [maw.tesla_mode, turtle.tesla_mode])
	grubs.clear()
	for i in 4:
		var gr: Unit = g._add_unit("grub", 1, _free(maw.position - dir * 2.0 * T + side * float(i - 2) * 20.0))
		gr.cmd_gather(maw)
		grubs.append(gr)
	await wait(2.0)


## A spot near p where a `k` of the Brood's may root (BroodRoot.place_problem).
func _root_spot(k: String, p: Vector2, swamp: bool) -> Vector2:
	for r in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		for i in 16:
			var sp: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 16.0) * r * T)
			if BroodRoot.place_problem(g, 1, k, sp, null, false, 1.0, swamp) == "":
				return sp
	return p


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 8:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _grub_loss() -> float:
	var lost := 0.0
	for gr in grubs:
		lost += gr.max_hp if (not is_instance_valid(gr) or gr.dead) else gr.max_hp - gr.hp
	return lost


## Watch the party for `secs`: how much of the time any of them had the turtle as target, the grubs' loss.
func _watch(party: Array, secs: float) -> Dictionary:
	var frames := 0
	var on_turtle := 0
	var until := g.clock + secs
	while g.clock < until:
		await physics_frame
		frames += 1
		for u in party:
			if is_instance_valid(u) and not u.dead:
				if u.kind == "clock_soldier":
					u.wind = 1.0          # (the test is about targets, not the battery: kept wound)
				if u.target == turtle or u.order_target == turtle:
					on_turtle += 1
					break
		if frames % 60 == 0 and OS.get_cmdline_user_args().has("trace"):
			for u in party:
				if is_instance_valid(u):
					print("      t=%.0f %s %s tgt=%s ot=%s pt=%s pos=%s dq=%.0f hp=%.0f" % [g.clock, u.kind, u.order, u.target.kind if u.target else "-", u.order_target.kind if u.order_target and is_instance_valid(u.order_target) else "-", u.order_point.round(), u.position.round(), u.position.distance_to(q.position), u.hp])
	return {"turtle": float(on_turtle) / maxf(1.0, frames), "grubs": _grub_loss()}


func _sire_at(u: Unit) -> Unit:
	var s: Unit = g._add_unit(BroodNew.FATHER, 1, _free(u.position + (q.position - u.position).normalized() * 160.0))
	s.cmd_attack(u)
	return s


func _case_one(fac: String, kind: String) -> void:
	await _start(fac)
	var u: Unit = g._add_unit(kind, 0, _free(turtle.position + dir * 4.0 * T))
	u.cmd_move(turtle.position, true)        # (what it did in the owner's game: attack-move into the turtle)
	await wait(1.0)
	check(ai.hz().add(u, "test"), "[%s] the harass takes the %s" % [kind, kind])
	var t_hp0 := turtle.hp
	var r := await _watch([u], 40.0)
	print("    %s: on the turtle %.0f%% of the time, turtle lost %.0f hp, grubs lost %.0f hp (%d dead)" % [kind, r["turtle"] * 100.0, t_hp0 - turtle.hp, r["grubs"], grubs.filter(func(x) -> bool: return not is_instance_valid(x) or x.dead).size()])
	check(r["grubs"] > 0.0, "[%s] within 40 s it hurt the grubs (%.0f hp)" % [kind, r["grubs"]])
	check(r["turtle"] < 0.25, "[%s] it spent little of its time on the rooted turtle (%.0f%%)" % [kind, r["turtle"] * 100.0])
	if not is_instance_valid(u) or u.dead:
		check(false, "[%s] still alive for the Sire part" % kind)
		await _stop()
		return
	u.hp = u.max_hp
	var n0: int = ai.hz().log_lines.size()
	var s := _sire_at(u)
	var d0 := s.position.distance_to(u.position)
	await _watch([u, s], 5.0)
	var pulled: bool = ai.hz().log_lines.slice(n0).any(func(l) -> bool: return String(l[1]).begins_with("pulls back"))
	check(pulled, "[%s] a Tyrant Sire comes: it pulls back" % kind)
	check(not u.dead and u.hp > u.max_hp * 0.3, "[%s] ... and lives (%.0f / %.0f hp, %.0f px from the Sire, was %.0f)" % [kind, u.hp, u.max_hp, s.position.distance_to(u.position), d0])
	s.take_damage(99999.0, null)
	var loss0 := _grub_loss()
	await _watch([u], 15.0)
	var st: String = String(ai.hz().units[u].get("state", "")) if ai.hz().has(u) else "let go"
	var again: bool = ai.hz().has(u) and not ai.hz().units[u]["home"] and st != "back"
	check(again, "[%s] the Sire gone, it comes again (%s; %.0f px from the Mother; grubs lost %.0f more hp)" % [kind, st, u.position.distance_to(q.position), _grub_loss() - loss0])
	if OS.get_cmdline_user_args().has("trace"):
		print(ai.hz().log_lines)
	await _stop()


func _case_raid() -> void:
	await _start("crown")
	var party: Array = []
	for i in 2:
		var u: Unit = g._add_unit("cuirassier", 0, _free(turtle.position + dir * 4.0 * T + dir.orthogonal() * float(i) * 30.0))
		u.cmd_move(turtle.position, true)
		party.append(u)
	ai._raiders = party.duplicate()
	ai._raid_peak = 2
	ai._raid_block = 0.0
	var t_hp0 := turtle.hp
	var r := await _watch(party, 40.0)
	print("    raid: on the turtle %.0f%% of the time, turtle lost %.0f hp, grubs lost %.0f hp" % [r["turtle"] * 100.0, t_hp0 - turtle.hp, r["grubs"]])
	check(r["grubs"] > 0.0, "[raid] the Crown's raiding party hurt the grubs (%.0f hp)" % r["grubs"])
	check(r["turtle"] < 0.25, "[raid] ... and left the rooted turtle alone (%.0f%% of the time on it)" % [r["turtle"] * 100.0])
	var alive: Array = party.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if alive.size() < 2:
		check(false, "[raid] both riders alive for the Sire part")
		await _stop()
		return
	var c: Vector2 = (alive[0].position + alive[1].position) * 0.5
	var s := _sire_at(alive[0])
	await wait(6.0)
	var c2: Vector2 = (alive[0].position + alive[1].position) * 0.5
	var home := g.center_of_team(0)
	check(c2.distance_to(home) < c.distance_to(home) - 60.0, "[raid] a Tyrant Sire comes: the riders ride home (%.0f -> %.0f px from home)" % [c.distance_to(home), c2.distance_to(home)])
	s.take_damage(99999.0, null)
	await _stop()


func _run() -> void:
	await _case_one("clockwork", "clock_soldier")
	if OS.get_cmdline_user_args().has("clock"):
		quit(0)
		return
	await _case_one("crown", "cuirassier")
	await _case_raid()
	print("ai harass: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
