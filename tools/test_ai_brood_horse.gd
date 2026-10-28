extends SceneTree
## The Brood keeps its Raptors home when it sees Horsemen (AI._horse_hold):
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_brood_horse.gd -- [plan:rush|balanced|timing] [see:<s>] [end:<s>] [hold:0|1] [map:<id>]
## A Hard Brood on the given plan against a Crown whose own AI is off. At `see` seconds four Crown
## Horsemen stand in the Brood's sight for a few seconds (then vanish, as a raid that went home).
## Prints "HORSE ..." with the first attack launched after the sighting, the Raptors / Spitters /
## Brutes alive at the end, and whether the Pen and the Gorge Pit stood. Checks (hold:1): no wave goes
## out in the 150 s after the sighting, the army grows more than Raptors, the plan is not idle.
var main: Node
var g: Game
var ai: AI
var fails := 0
var map := "ashford_crossing"
var plan := "rush"
var see := -1.0
var end_t := -1.0
var hold := true


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("see:"):
			see = float(a.substr(4))
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))
		elif a == "hold:0":
			hold = false
	if see < 0.0:
		see = 70.0 if plan == "rush" else 230.0
	if end_t < 0.0:
		end_t = see + 200.0
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _count(kind: String) -> int:
	return g.army(1).filter(func(u: Unit) -> bool: return u.kind == kind).size()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": plan}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 0:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	ai.horse_hold_on = hold
	while g.clock < see and not g.over:
		await physics_frame
	# four Horsemen in the Brood's sight, a little in front of its hall
	var hall: Building = g.halls_of(1)[0]
	var toward := (g.center_of_team(0) - hall.center()).normalized()
	var horses: Array = []
	for i in 4:
		horses.append(g._add_unit("cuirassier", 0, hall.center() + toward * 330.0 + toward.orthogonal() * (i - 1.5) * 30.0))
	var t0 := g.clock
	while g.clock < t0 + 6.0 and not g.over:
		await physics_frame
	for u in horses:
		if is_instance_valid(u) and not u.dead:
			u.die()
	# a Raptor found far from home while Horsemen are about walks back to the post
	var stray: Unit = null
	var stray_far0 := 0.0
	for u in g.army(1):
		if u.kind == "raptor" and not ai._attacking:
			stray = u
			break
	if stray != null:
		stray.position = stray.position + toward * 450.0
		stray.cmd_stop()
		stray_far0 = ai._home_dist(stray.position)
	var attack_t := -1.0
	var attacked_before := ai._attacking
	var raptors_sent := 0
	var nd := g.clock
	var stray_min := stray_far0 if stray != null else 0.0
	while g.clock < end_t and not g.over:
		await physics_frame
		if stray != null and is_instance_valid(stray) and not stray.dead:
			stray_min = minf(stray_min, ai._home_dist(stray.position))     # (brood-econ: the alert now ends 150 s after the last Horseman seen, so look while it lasts)
		if OS.get_cmdline_user_args().has("debug") and g.clock >= nd:
			nd += 20.0
			print("   t=%d biomass %d reserve %d saving %s hall_res %s army %d workers %d pit_busy %s" % [int(g.clock), ai._gold(), ai._reserve, ai._saving, ai._hall_reserve, ai._army_supply(g.army(1)), g.workers(1).size(), ai._busy_building("gorge_pit")])
		if attack_t < 0.0 and ai._attacking and not attacked_before:
			attack_t = g.clock
			raptors_sent = _count("raptor")
	print("HORSE plan:%s hold:%s sighting:%ds first_attack_after:%s raptors:%d spitters:%d brutes:%d army_supply:%d pen:%s gorge_pit:%s strategy:%s workers:%d" % [plan, hold, int(see),
		"never" if attack_t < 0.0 else str(int(attack_t)), _count("raptor"), _count("spitter"), _count("brute"), ai._army_supply(g.army(1)),
		ai._mine("brood_pen").size() > 0, ai._mine("gorge_pit").size() > 0, ai.strategy, g.workers(1).size()])
	var h0: Building = ai._halls()[0]
	print("   essence %s biomass %s can_train spitter '%s' brute '%s' gorge '%s' alert %s" % [ai._res2(), ai._gold(), g.can_train(h0, "spitter"), g.can_train(h0, "brute"), g.requirement_met(1, "gorge_pit"), ai._horse_alert()])
	if not hold:
		print("ALL PASS (hold off, numbers only)")
		quit(0)
		return
	check(ai._hz_horse_t > 0.0, "the Horsemen were seen")
	if stray != null and is_instance_valid(stray) and not stray.dead:
		check(stray_min < stray_far0 - 100.0, "a stray Raptor walks back to the post (%d -> %d)" % [int(stray_far0), int(stray_min)])
	check(attack_t < 0.0 or attack_t > see + 150.0, "no wave goes out in the 150 s after the sighting (first attack %s)" % ("never" if attack_t < 0.0 else str(int(attack_t))))
	check(_count("spitter") + _count("brute") > 0 or ai._mine("brood_pen").size() > 0, "it answers with a Pen / Spitters / Brutes, not Raptors only")
	check(ai.strategy != "rush" and ai.strategy != "xrush" or plan == "balanced" or plan == "timing", "a rush plan falls back to a normal game")
	check(g.workers(1).size() >= 6, "the economy goes on (%d workers)" % g.workers(1).size())
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
