extends SceneTree
## AI round 5 (docs/ai_round5.md), part B: Horsemen raid the Clockwork computer's Winders.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_cw_horse_raid.gd -- [map:<id>] [seed:<n>] [riders:<n>] [at:<s>] [for:<s>]
## A Hard Clockwork (balanced) against a Crown whose own AI is off. At `at` seconds `riders` Horsemen appear by the
## Clockwork's busiest Cog Press and raid it the way the owner did: every second each rider goes for the Winder
## nearest to him (he never stops to fight the soldiers). The same game is played twice, round 5 off ("before")
## and on ("after"). Prints "RAID before/after: winders lost, riders killed, soldiers sent, ramp post" and checks
## that round 5 loses fewer Winders (or kills more riders) and that the Winders do not scatter one by one.
var fails := 0
var map := "greenhold"
var seed_ := 5
var riders := 3
var at := 200.0
var dur := 45.0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("riders:"):
			riders = int(a.substr(7))
		elif a.begins_with("at:"):
			at = float(a.substr(3))
		elif a.begins_with("for:"):
			dur = float(a.substr(4))
	_run.call_deferred()


func _press(g: Game) -> Building:
	var best: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == Defs.GEAR_PRESS and b.built and not b.dead:
			if best == null or b.crew.size() > best.crew.size():
				best = b
	return best


func _alive(list: Array) -> int:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()


## One game: returns {"lost", "killed", "sent", "ramp", "spread"}.
func _game(r5_on: bool) -> Dictionary:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI = null
	for a in g.ais:
		if a.team == 0:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	ai.r5.on = r5_on
	while g.clock < at and not g.over:
		await physics_frame
	var press := _press(g)
	var out := {"lost": 0, "killed": 0, "sent": 0, "ramp": 0, "home": 0, "spread": 0.0, "w0": 0, "soldiers": 0}
	if press == null:
		print("  no Cog Press at %d s" % int(at))
		main.queue_free()
		await process_frame
		return out
	var hall: Building = g.halls_of(1)[0]
	var toward := (g.center_of_team(0) - hall.center()).normalized()
	var horses: Array = []
	for i in riders:
		horses.append(g._add_unit("cuirassier", 0, press.center() + toward * 160.0 + toward.orthogonal() * (i - riders * 0.5) * 30.0))
	var w0 := g.workers(1).size()
	out["w0"] = w0
	out["soldiers"] = g.army(1).filter(func(u: Unit) -> bool: return u.kind == "clock_soldier").size()
	var t0 := g.clock
	var next := t0
	var spread_n := 0
	while g.clock < t0 + dur and not g.over:
		await physics_frame
		if g.clock < next:
			continue
		next += 1.0
		# the riders: each on the Winder nearest to him
		for h in horses:
			if not is_instance_valid(h) or h.dead:
				continue
			var best: Unit = null
			for w in g.workers(1):
				if best == null or w.position.distance_to(h.position) < best.position.distance_to(h.position):
					best = w
			if best != null and h.target != best:
				h.cmd_attack(best)
		# how spread out the Winders who fight are (a group stands close together)
		var fighters: Array = g.workers(1).filter(func(w: Unit) -> bool: return w.order == "attack")
		if fighters.size() >= 2:
			var c := Vector2.ZERO
			for w in fighters:
				c += w.position
			c /= float(fighters.size())
			var s := 0.0
			for w in fighters:
				s += w.position.distance_to(c)
			out["spread"] = float(out["spread"]) + s / fighters.size()
			spread_n += 1
		out["sent"] = maxi(int(out["sent"]), g.army(1).filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and u.position.distance_to(press.center()) < 450.0).size())
	if spread_n > 0:
		out["spread"] = float(out["spread"]) / spread_n
	out["lost"] = w0 - g.workers(1).size()
	out["killed"] = riders - _alive(horses)
	for h in horses:
		if is_instance_valid(h) and not h.dead:
			h.die()
	var t1 := g.clock
	while g.clock < t1 + 20.0 and not g.over:
		await physics_frame
	out["ramp"] = ai.r5._ramp.size()
	# (soldiers at home: a wave that went out meanwhile does not man the ramp)
	out["home"] = g.army(1).filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and not (ai._attacking and ai._wave_set.has(u))).size()
	main.queue_free()
	await process_frame
	return out


func _run() -> void:
	var before: Dictionary = await _game(false)
	print("RAID before %s seed %d riders %d at %d s: winders %d, lost %d, riders killed %d, soldiers %d (most by the press %d), fighters' spread %.0f px" % [map, seed_, riders, int(at),
		before["w0"], before["lost"], before["killed"], before["soldiers"], before["sent"], before["spread"]])
	var after: Dictionary = await _game(true)
	print("RAID after  %s seed %d riders %d at %d s: winders %d, lost %d, riders killed %d, soldiers %d (most by the press %d), fighters' spread %.0f px, ramp post %d (%d soldiers at home)" % [map, seed_, riders, int(at),
		after["w0"], after["lost"], after["killed"], after["soldiers"], after["sent"], after["spread"], after["ramp"], after["home"]])
	check(int(after["lost"]) < int(before["lost"]) or int(after["killed"]) > int(before["killed"]) or int(after["lost"]) <= 2,
		"round 5 loses fewer Winders or kills more riders (lost %d -> %d, killed %d -> %d)" % [before["lost"], after["lost"], before["killed"], after["killed"]])
	check(int(after["sent"]) >= 2 or int(after["soldiers"]) < 2 or int(after["lost"]) <= 0, "a group of Clock Soldiers comes to the press (%d)" % after["sent"])
	check(int(after["lost"]) < int(after["w0"]) / 2, "the raid does not take half the Winders (%d of %d)" % [after["lost"], after["w0"]])
	if int(after["home"]) >= 12:
		check(int(after["ramp"]) >= 3, "with %d Clock Soldiers at home a ramp post stands after the raid (%d)" % [after["home"], after["ramp"]])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
