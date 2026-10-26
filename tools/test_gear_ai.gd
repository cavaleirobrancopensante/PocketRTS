extends SceneTree
## A Hard Clockwork computer runs its base on the gear field for 7 game minutes:
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_ai.gd [-- vs:passive|crown|brood map:<id> seed:<n> minutes:<m>]
## vs:passive (default): a passive Crown, so the economy is the test. vs:crown / vs:brood: a Hard opponent that fights
## (no crash or stall is the test; the Clockwork may lose).
## Checks: it runs Cog Presses with Winders on them and earns cogs, every building it finishes is linked (never unlinked for
## long), nothing is left half-placed for ages, it keeps Winders and keeps spending. Tier 2 is reported (a NOTE line: its
## Mainspring, Escapement, Jacks; a passive Crown usually falls first, against vs:crown minutes:11 it gets there) and every Escapement it
## finishes must mesh with a Mainspring.
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


var _jacks_seen := {}
var _air_seen := {}             # Swifts (and the Owls they became) it made
var _owls_seen := {}


func _watch() -> void:
	var net: GearNet = g.gear_net
	for u in g.units:
		if u.team == 0 and u.kind == Defs.JACK:
			_jacks_seen[u.get_instance_id()] = true
		if u.team == 0 and (u.kind == Defs.CUCKOO or u.kind == Defs.OWL):
			_air_seen[u.get_instance_id()] = true
		if u.team == 0 and u.kind == Defs.OWL:
			_owls_seen[u.get_instance_id()] = true
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
		# the new-style army (gear mode): Movement Works, Regulators, Clock Soldiers
		var soldiers: int = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "clock_soldier" and not u.dead).size()
		check(not _mine(Defs.CW_WORKS).is_empty(), "it built a Movement Works (%d)" % _mine(Defs.CW_WORKS).size())
		check(not _mine(Defs.CW_SUPPLY).is_empty() and _mine("spring_tower").is_empty(), "it built Regulators (%d), no Spring Tower" % _mine(Defs.CW_SUPPLY).size())
		check(soldiers >= 3, "it trained Clock Soldiers (%d)" % soldiers)
		# no power in gear mode: no Boiler, Pylon, Engine Hall or Capacitor Works; a Ratchet Turret for defence
		var power: Array = Defs.ENERGY_KINDS.filter(func(k: String) -> bool: return not _mine(k).is_empty())
		check(power.is_empty(), "it built nothing that runs on power (%s)" % str(power))
		check(not _mine(Defs.CW_TURRET).is_empty(), "it built a Ratchet Turret (%d)" % _mine(Defs.CW_TURRET).size())
	else:
		check(true, "the match ran to %d:%02d (%s)" % [int(g.clock) / 60, int(g.clock) % 60, "ended" if g.over else "7 minutes"])
		check(worst_stall < 150.0 or g.over, "it kept spending (worst gap %.0f s)" % worst_stall)
		check(Defs.ENERGY_KINDS.all(func(k: String) -> bool: return _mine(k).is_empty()), "it built nothing that runs on power")
		check(worst_off < 60.0 or g.over, "no finished building stood unlinked for a minute while its Clocktower lived (worst %.0f s)" % worst_off)
	# tier 2 (it may not get there before the passive Crown falls): reported; an Escapement it built must mesh with a Mainspring
	var esc_n := _mine(Defs.CW_TECH).filter(func(b: Building) -> bool: return b.built).size()
	var working := _mine(Defs.CW_TECH).filter(func(b: Building) -> bool: return b.built and g.gear_net.speed_mult(b) > 0.0).size()
	print("NOTE  tier 2 at %d:%02d: %d Mainspring(s), %d Escapement(s) built (%d working), %d Jacks trained, %d alive, Tension %d, High Leap %s" % [
		int(g.clock) / 60, int(g.clock) % 60, _mine("mainspring").size(), esc_n, working, _jacks_seen.size(),
		g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == Defs.JACK and not u.dead).size(), int(g.tension(0)), str(g.has_tech(0, "high_leap"))])
	check(esc_n == working or (vs != "passive" and g.over), "every Escapement it built meshes with a Mainspring (%d of %d)" % [working, esc_n])
	# the air (it builds an Aviary only against flyers or late): reported
	print("NOTE  the air at %d:%02d: %d Clock Aviary(ies), %d Swifts made, %d Ticking Owls, TICKING OWL %s" % [
		int(g.clock) / 60, int(g.clock) % 60, _mine(Defs.CW_AIR).size(), _air_seen.size(), _owls_seen.size(), str(g.has_tech(0, "owl_morph"))])
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
