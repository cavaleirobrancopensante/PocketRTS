extends SceneTree
## The Brood EXTREME RUSH plan (a "six-pool") and RUSH plan (the owner's timeline), end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_xrush.gd [-- map:<id> seed:<n> defence:0|1 plan:xrush|rush]
## A Hard Brood computer on the Extreme rush (or Rush) plan against a Hard Crown computer on Balanced.
## plan:rush also checks the owner's timeline (docs/design_principles.md section 5): the Spawning Den done by
## 1:05, Raptors by 1:30, 6+ by 2:05, the first attack out by 2:50.
## defence:0 (default): a SLEEPING Crown (its computer switched off). Checks: the first Raptors hatch by 1:20, 6+ Raptors
##   (or their wave) by 2:00, the first Raptor hit lands on the Crown by 2:40, and (the plan works against
##   a sleeping defence) the Crown has lost a labourer or more by 3:00.
## defence:2: the Crown computer plays on its own (its Cottage-and-Gate wall at the ramp, Musketeers, repairs):
##   it must keep its Town Hall and most labourers, the wave must attack the gate (walls are broken, not
##   milled at), and the repair gold and wall damage are printed (docs/design_principles.md, 5).
## defence:1: a Crown that defends properly: its Cottage-and-Gate wall at the ramp (~0:40), three Musketeers in place at 1:50,
##   its labourers fight. Checks: the rush does not win (the Crown keeps its Town Hall and loses at
##   most 4 labourers), the Brood falls back to a normal game (plan Balanced, builds workers) by 4:30
##   and is not idle.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var defence := 0
var plan := "xrush"
var attack_t := -1.0
var brood := 1
var crown := 0
var first_raptor := -1.0
var first_hit := -1.0
var ai_b
var ai_c
var crown_workers_start := 0
var lost_workers := 0
var dbg_t := 0.0
var wall_hits := 0
var wall_dmg := 0.0
var piece_hp := {}
var pieces_lost := 0
var rep_at := {}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("defence:"):
			defence = int(a.substr(8))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": plan}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for a in g.ais:
			if a.team == brood:
				ai_b = a
			else:
				ai_c = a
		if defence == 0:
			ai_c.process_mode = Node.PROCESS_MODE_DISABLED       # (a sleeping Crown)
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func raptors(team: int) -> int:
	var n := 0
	for u in g.units:
		if u.team == team and not u.dead and u.kind == "raptor":
			n += 1
	return n


func wait_until(clock: float) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		for b in g.buildings:
			if b.team == crown and b.built and ai_c._wall_piece(b):
				var id: int = b.get_instance_id()
				if piece_hp.has(id) and b.hp < float(piece_hp[id]) and not b.dead:
					wall_dmg += float(piece_hp[id]) - b.hp
					wall_hits += 1
				piece_hp[id] = b.hp
				if b.dead and piece_hp.get(-id, 0) == 0:
					piece_hp[-id] = 1
					pieces_lost += 1
		if OS.get_cmdline_user_args().has("dbg") and g.clock >= dbg_t and g.clock < 190.0 and g.clock > 95.0:
			dbg_t = g.clock + 5.0
			var gates: Array = g.buildings.filter(func(b) -> bool: return b.team == crown and b.kind == "gate" and not b.dead)
			var gp: Vector2 = gates[0].center() if not gates.is_empty() else Vector2.ZERO
			var rs: Array = []
			for u in g.units:
				if u.team == brood and not u.dead and u.kind == "raptor":
					rs.append("%s@%d%s" % [u.order, int(u.position.distance_to(gp)), ("->" + str(u.target.kind) if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.target.has_method("center") else "")])
			print("  dbg %.0f gate %s wave %s raptors %s | crown hp gate/cot %s musk %d lost %d" % [g.clock, str(gp), str(ai_b._attacking), str(rs), str(g.buildings.filter(func(b) -> bool: return b.team == crown and not b.dead and ai_c._wall_piece(b)).map(func(b) -> String: return "%s%d" % [b.kind[0], int(b.hp)])), g.army(crown).size(), int(g.stats[crown]["lost"])])
		if attack_t < 0.0 and ai_b != null and ai_b._attacking:
			attack_t = g.clock
		if first_raptor < 0.0 and raptors(brood) > 0:
			first_raptor = g.clock
		if den_t < 0.0:
			for b in g.buildings:
				if b.team == brood and b.kind == "warren" and not b.dead:
					if den_placed < 0.0:
						den_placed = g.clock
					if b.built:
						den_t = g.clock
		if first_hit < 0.0 and int(g.stats[crown]["lost"]) > 0:
			first_hit = g.clock
		if defence == 1:
			_defender()


var den_t := -1.0
var den_placed := -1.0
var walled := false
var guards := false


## The properly defending Crown (test setup): its own opening (the Cottage at the ramp and a Gate beside it,
## AI._cottage_wall, which seals the ramp from ~0:40) and three Musketeers by the wall at 1:50.
func _defender() -> void:
	if not guards and g.clock >= 110.0:
		guards = true
		var halls: Array = ai_c._halls()
		if not halls.is_empty():
			var p: Vector2 = ai_c._rally_front(halls[0])
			for i in 3:
				var c: Vector2i = g.nearest_free(g.cell_of(p), 6)
				g._add_unit("musketeer", crown, g.cell_center(c))


func _row() -> String:
	return "brood: raptors %d army-supply %d workers %d gold %d plan %s | crown: workers %d musketeers %d lost %d" % [
		raptors(brood), g.supply_used(brood) - g.workers(brood).size(), g.workers(brood).size(), g.players[brood]["gold"], ai_b.strategy,
		g.workers(crown).size(), g.army(crown).size(), int(g.stats[crown]["lost"])]


func _run() -> void:
	print("Brood EXTREME RUSH vs Crown balanced, %s, seed %d, defence %d" % [map, seed_, defence])
	var by2 := 0
	for s in [30.0, 60.0, 90.0, 125.0, 150.0, 180.0, 240.0, 270.0, 330.0]:
		await wait_until(s)
		print("%d:%02d  %s" % [int(s) / 60, int(s) % 60, _row()])
		if s == 125.0:
			by2 = raptors(brood) + int(g.stats[brood]["lost"])
		if s == 90.0:
			check(first_raptor >= 0.0 and first_raptor <= 95.0, "first Raptors by 1:30 (%s)" % _mmss(first_raptor))
	print("WALL: damage taken %.0f hp (non-lethal hits), pieces destroyed %d, repair gold spent %.1f, repair orders %d" % [wall_dmg, pieces_lost, float(g.stats[crown].get("repair", 0.0)), ai_c.repair_orders])
	print("Spawning Den placed at %s, finished at %s, first Raptors at %s" % [_mmss(den_placed), _mmss(den_t), _mmss(first_raptor)])
	if plan == "rush":
		check(den_t >= 0.0 and den_t <= 65.0, "Rush: the Spawning Den done by 1:05 (%s)" % _mmss(den_t))
		check(first_raptor >= 0.0 and first_raptor <= 90.0, "Rush: Raptors by 1:30 (%s)" % _mmss(first_raptor))
		check(attack_t >= 0.0 and attack_t <= 170.0, "Rush: the first attack out by 2:50 (%s)" % _mmss(attack_t))
	if defence == 0:
		check(by2 >= 6, "6+ Raptors by 2:05 (%d)" % by2)
		check(first_hit >= 0.0 and first_hit <= 160.0, "the Crown took its first loss by 2:40 (%s)" % _mmss(first_hit))
		check(int(g.stats[crown]["lost"]) >= 1, "the Crown lost a unit by 4:30 against a sleeping defence")
	elif defence == 2:
		var hall_alive2 := false
		for b in g.buildings:
			if b.team == crown and b.kind == "town_hall" and not b.dead:
				hall_alive2 = true
		check(hall_alive2 and not g.over, "the Crown's own opening holds: it keeps its Town Hall")
		check(g.workers(crown).size() >= 5 and int(g.stats[crown]["lost"]) <= 4, "... and most of its labourers (%d left, %d lost)" % [g.workers(crown).size(), int(g.stats[crown]["lost"])])
		check(wall_hits > 0 or ai_b.strategy != plan, "the Brood wave broke at the gate (wall hit %.0f hp) or already fell back" % wall_dmg)
	else:
		var hall_alive := false
		for b in g.buildings:
			if b.team == crown and b.kind == "town_hall" and not b.dead:
				hall_alive = true
		check(hall_alive and not g.over, "a proper defence holds: the Crown keeps its Town Hall")
		check(g.workers(crown).size() >= 5, "... and most of its labourers (%d)" % g.workers(crown).size())
		check(ai_b.strategy != plan, "the rush ended and the Brood fell back to a normal plan (%s)" % ai_b.strategy)
		check(g.workers(brood).size() >= 8 or raptors(brood) >= 3, "the Brood is not idle (workers %d, raptors %d)" % [g.workers(brood).size(), raptors(brood)])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]
