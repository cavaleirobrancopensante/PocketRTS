extends SceneTree
## The Brood computer builds an army on a sensible curve:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_brood_army.gd [-- map:<id> seed:<n> brood:<plan> crown:<plan> min3:<v> end:<s>]
## A Hard Brood computer (plan `brood`, default rush) against a Hard Crown computer (plan `crown`,
## default rush) for `end` game seconds (default 270). Prints the Brood army value at 2:00, 3:00
## and 4:00 and checks: the Brood army value reaches `min3` by 3:00 (it may spend it on its own attack), and the Brood is not
## wiped out (still has its Burrow and workers or an army) after the first Crown attack.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "glimmerdeep"
var seed_ := 4242
var brood_plan := "rush"
var crown_plan := "rush"
var min3 := 150.0
var end_t := 270.0
var brood := 1
var crown := 0
var first_hit := -1.0
var peak_crown := 0.0
var vals := {}
var attack_t := -1.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("brood:"):
			brood_plan = a.substr(6)
		elif a.begins_with("crown:"):
			crown_plan = a.substr(6)
		elif a.begins_with("min3:"):
			min3 = float(a.substr(5))
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": crown_plan},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": brood_plan}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func army_value(team: int) -> float:
	var v := 0.0
	for u in g.units:
		if is_instance_valid(u) and u.team == team and not u.dead and not u.is_worker() and (u.has_attack() or Defs.MUSKETS.has(u.kind)):
			v += float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", 0)) * 0.5
	return v


func wait_until(clock: float) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if first_hit < 0.0:
			for b in g.buildings:
				if b.team == brood and not b.dead and b.built and b.hp < b.max_hp - 1:
					first_hit = g.clock
			if int(g.stats[brood]["lost"]) > 0:
				first_hit = g.clock
		if attack_t < 0.0:
			for a in g.ais:
				if a.team == brood and a._attacking:
					attack_t = g.clock
		peak_crown = maxf(peak_crown, army_value(crown))


func _row() -> String:
	return "brood: army %d supply %d/%d workers %d gold %d | crown: army %d workers %d" % [
		int(army_value(brood)), g.supply_used(brood), g.players[brood]["cap"], g.workers(brood).size(), g.players[brood]["gold"],
		int(army_value(crown)), g.workers(crown).size()]


func _run() -> void:
	print("Brood %s vs Crown %s, %s, seed %d" % [brood_plan, crown_plan, map, seed_])
	for s in [60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0]:
		if s > end_t:
			break
		await wait_until(s)
		print("%d:%02d  %s" % [int(s) / 60, int(s) % 60, _row()])
		vals[int(s)] = army_value(brood)
		
	check(g.clock >= 210.0 or g.over, "reached 3:30")
	var peak := 0.0
	for k in vals:
		if k <= 180:
			peak = maxf(peak, float(vals[k]))
	check(peak >= min3, "Brood army value reached %d by 3:00 (peak of the 30 s looks: %d)" % [int(min3), int(peak)])
	await wait_until(end_t)
	print("Brood attack out at %s, first Brood loss/damage at %s, crown peak army %d, end: %s" % [_mmss(attack_t), _mmss(first_hit), int(peak_crown), _row()])
	var hall_alive := false
	for b in g.buildings:
		if b.team == brood and b.kind == "hive" and not b.dead:
			hall_alive = true
	check(hall_alive and not g.over, "Brood survives to %d:%02d (over %s)" % [int(end_t) / 60, int(end_t) % 60, str(g.over)])
	print("(Brood killed %d of Crown value; the Brood Rush against a Crown Rush is a gamble either side can lose)" % int(g.stats[brood]["value_killed"]))
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]
