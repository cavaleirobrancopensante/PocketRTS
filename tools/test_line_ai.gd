extends SceneTree
## A Hard Clockwork computer runs its base on the Line for 7 game minutes against a passive Crown:
##   godot --headless --fixed-fps 30 --script res://tools/test_line_ai.gd [-- map:<id> seed:<n>]
## Checks: its Drills and trains deliver ore, new Clockwork buildings get Line (powered), no Line is left
## half-laid, it keeps Winders, it buys Ore Trains for its Drills, nothing stands without a Line for long.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var next_print := 60.0
var worst_off := 0.0
var off_t := {}


func _initialize() -> void:
	Defs.line_mode = true      # (the shelved Line economy: gear mode off)
	Defs.gear_mode = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			if ai.team != 0:
				ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _watch() -> void:
	var net: LineNetwork = g.line_net
	for b in g.buildings:
		if b.team == 0 and b.built and not b.dead and net.is_consumer(b) and net.state_of(b) == "off":
			var id: int = b.get_instance_id()
			off_t[id] = float(off_t.get(id, 0.0)) + 1.0 / 30.0
			worst_off = maxf(worst_off, float(off_t[id]))
		elif b.team == 0:
			off_t.erase(b.get_instance_id())
	if g.clock >= next_print:
		next_print += 60.0
		var drills: int = g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == "ore_drill" and b.built and not b.dead).size()
		var cons: int = g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.built and not b.dead and net.is_consumer(b)).size()
		print("%d:%02d  ore %d  supply %d/%d  segs %d (unbuilt %d)  drills %d  trains %d  delivered %d  consumers %d  worst unpowered %.0f s" % [
			int(g.clock) / 60, int(g.clock) % 60, int(g.players[0]["gold"]), g.supply_used(0), g.players[0]["cap"], net.count(0), net.unbuilt_count(0),
			drills, net.rails.count(0, "ore"), int(net.rails.delivered.get(0, 0.0)), cons, worst_off])


func _run() -> void:
	while g.clock < 420.0 and not g.over:
		await physics_frame
		_watch()
	var net: LineNetwork = g.line_net
	var drills: int = g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == "ore_drill" and b.built and not b.dead).size()
	var winders: int = g.workers(0).filter(func(u: Unit) -> bool: return u.kind == "winder").size()
	var consumers: Array = g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.built and not b.dead and net.is_consumer(b))
	var off: int = consumers.filter(func(b: Building) -> bool: return net.state_of(b) == "off").size()
	check(g.clock >= 420.0, "the match ran 7 minutes (eliminated early otherwise)")
	check(net.count(0) >= 12, "it has laid a Line (%d segments)" % net.count(0))
	check(net.unbuilt_count(0) <= 6, "no big half-laid Line is left (%d unbuilt)" % net.unbuilt_count(0))
	check(drills >= 1, "it runs Ore Drills (%d)" % drills)
	check(net.rails.count(0, "ore") >= 1, "it runs Ore Trains (%d)" % net.rails.count(0, "ore"))
	check(float(net.rails.delivered.get(0, 0.0)) > 1000.0, "trains delivered ore (%d)" % int(net.rails.delivered.get(0, 0.0)))
	check(consumers.size() >= 3 and off <= 1, "its buildings have Line (%d of %d without)" % [off, consumers.size()])
	check(worst_off < 90.0, "no building stood without Line for 90 s (worst %.0f s)" % worst_off)
	check(winders >= 3, "it still has its Winders (%d)" % winders)
	check(g.supply_used(0) >= 12, "it grew an army/workforce (supply %d)" % g.supply_used(0))
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
