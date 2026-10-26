extends SceneTree
## A Hard Clockwork computer runs its base on the gear field for 7 game minutes:
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_ai.gd [-- vs:passive|crown|brood map:<id> seed:<n> minutes:<m>]
## vs:passive (default): a passive Crown, so the economy is the test. vs:crown / vs:brood: a Hard opponent that fights
## (no crash or stall is the test; the Clockwork may lose).
## Checks: it runs Cog Presses with Winders on them and earns cogs, every building it finishes is linked (never unlinked for
## long), nothing is left half-placed for ages, it keeps Winders and keeps spending.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var vs := "passive"
var minutes := 7.0
var next_print := 60.0
var worst_off := 0.0
var off_t := {}
var spent_at := {}
var worst_stall := 0.0
var last_spent := 0.0
var last_spent_t := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("vs:"):
			vs = a.substr(3)
		elif a.begins_with("minutes:"):
			minutes = float(a.substr(8))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var foe := "crown" if vs != "brood" else "brood"
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		if vs == "passive":
			for ai in g.ais:
				if ai.team != 0:
					ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _mine(kind := "") -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and (kind == "" or b.kind == kind))


func _watch() -> void:
	var net: GearNet = g.gear_net
	var tower_up := not _mine("clocktower").filter(func(b: Building) -> bool: return b.built).is_empty()
	for b in _mine():
		if b.built and tower_up:
			var id: int = b.get_instance_id()
			if not net.linked.has(b):
				off_t[id] = float(off_t.get(id, 0.0)) + 1.0 / 30.0
				worst_off = maxf(worst_off, float(off_t[id]))
			else:
				off_t.erase(id)
	var sp := float(g.stats[0]["spent"])
	if sp > last_spent:
		last_spent = sp
		last_spent_t = g.clock
	worst_stall = maxf(worst_stall, g.clock - last_spent_t)
	if g.clock >= next_print:
		next_print += 60.0
		var presses := _mine(Defs.GEAR_PRESS).filter(func(b: Building) -> bool: return b.built)
		var crew := 0
		var paid := 0.0
		for p in presses:
			crew += p.working_crew()
			paid += p.press_paid
		var linked := 0
		var all_b := _mine().filter(func(b: Building) -> bool: return b.built)
		for b in all_b:
			if net.linked.has(b):
				linked += 1
		var ghosts := _mine().filter(func(b: Building) -> bool: return not b.built).size()
		print("%d:%02d  cogs %d  supply %d/%d  buildings %d (linked %d, sites %d)  presses %d (winding %d, paid %d)  winders %d  worst unlinked %.0f s  worst spend gap %.0f s" % [
			int(g.clock) / 60, int(g.clock) % 60, int(g.players[0]["gold"]), g.supply_used(0), g.players[0]["cap"], all_b.size(), linked, ghosts,
			presses.size(), crew, int(paid), g.workers(0).size(), worst_off, worst_stall])


func _run() -> void:
	while g.clock < minutes * 60.0 and not g.over:
		await physics_frame
		_watch()
	var presses := _mine(Defs.GEAR_PRESS).filter(func(b: Building) -> bool: return b.built)
	var paid := 0.0
	for p in presses:
		paid += p.press_paid
	var winders: int = g.workers(0).filter(func(u: Unit) -> bool: return u.kind == "winder").size()
	var survived: bool = g.clock >= minutes * 60.0
	if vs == "passive":
		check(survived or (g.over and g.winner == 0), "the match ran %d minutes (or the Clockwork won sooner: %s)" % [int(minutes), str(g.over)])
		check(presses.size() >= 2, "it runs Cog Presses (%d)" % presses.size())
		check(paid > 1500.0, "its presses paid cogs (%d)" % int(paid))
		check(winders >= 4, "it still has its Winders (%d)" % winders)
		check(worst_off < 25.0, "no finished building stood unlinked for 25 s (worst %.0f s)" % worst_off)
		check(worst_stall < 120.0, "it never stopped spending for 2 minutes (worst %.0f s)" % worst_stall)
		check(g.supply_used(0) >= 12, "it grew an army/workforce (supply %d)" % g.supply_used(0))
		check(_mine().filter(func(b: Building) -> bool: return b.built).size() >= 6, "it built a base (%d buildings)" % _mine().filter(func(b: Building) -> bool: return b.built).size())
	else:
		check(true, "the match ran to %d:%02d (%s)" % [int(g.clock) / 60, int(g.clock) % 60, "ended" if g.over else "7 minutes"])
		check(worst_stall < 150.0 or g.over, "it kept spending (worst gap %.0f s)" % worst_stall)
		check(worst_off < 60.0 or g.over, "no finished building stood unlinked for a minute while its Clocktower lived (worst %.0f s)" % worst_off)
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
