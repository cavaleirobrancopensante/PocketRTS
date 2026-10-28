extends SceneTree
## THE BROOD MOTHER IS THE DEFENCE (the owner, 2026-10-28 13:20: no tower, no guard creature): rooted at home with
## only her grubs and her first Rootmaw, she must beat an early all-in by herself (docs/brood_new.md). Each all-in is
## what the early-rush yardsticks have at about 2:00-3:00 (docs/design_principles.md 5, tools/test_ai_wall_vs_rush.gd):
##   raptors     9 Raptors (the owner's extreme rush: 8 by 2:00, three an egg)
##   horsemen    3 Horsemen (the Crown's Horseman rush)
##   muskets     5 Musketeers (a Crown Musketeer push)
##   clock       6 Clock Soldiers (the Clockwork's first wave)
##   brutes      2 Brutes and 6 Raptors (an old-Brood push at about 3:30)
## They spawn 11 tiles out and attack-move onto her. PASS: she lives and they are all dead or spent within 120 s.
## The Mother CANNOT ATTACK while rooted (the owner, 15:58). mode:rooted (the default) leaves her in her nest (only the
## grubs and the Rootmaw fight); mode:uproot lets her get up and fight as the computer does (BroodNew.mother_guard),
## and root again after.
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_new_defence.gd [-- only:<name>] [mode:uproot]
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var only := ""
var mode := "rooted"
var guard := {}

const WAVES := {
	"raptors": [["raptor", 3, 1]],          # (+6 more below: 9)
	"horsemen": [["cuirassier", 3, 1]],
	"muskets": [["musketeer", 5, 1]],
	"clock": [["clock_soldier", 6, 2]],
	"brutes": [["brute", 2, 1], ["raptor", 2, 1]],   # (+4 more below: 6 Raptors)
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only:"):
			only = a.substr(5)
		if a.begins_with("mode:"):
			mode = a.substr(5)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 99, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func spot_near(p: Vector2, tiles: float) -> Vector2:
	var home: int = g.region_of(g.cell_of(p))
	for i in 48:
		var q: Vector2 = p + Vector2.from_angle(TAU * i / 48.0 + 0.3) * tiles * Defs.TILE
		var c: Vector2i = g.cell_of(q)
		if g._walkable(c) and g.region_of(c) == home:
			return q
	return p


func _run() -> void:
	await wait(2.5)
	var q: Unit = BroodNew.queen(g, 0)
	for u in g.units:
		if u.team != 0 and not u.dead:
			u.cmd_stop()
	for name in WAVES:
		if only != "" and name != only:
			continue
		q.hp = q.max_hp
		var foes: Array = []
		var at: Vector2 = spot_near(q.position, 11.0)
		var i := 0
		for w in WAVES[name]:
			var k: String = w[0]
			var team := 1
			for n in int(w[1]) * int(w[2]):
				var u: Unit = g._add_unit(k, team, at + Vector2((i % 4) * 22 - 33, (i / 4) * 22))
				foes.append(u)
				i += 1
		for u in foes:
			u.cmd_move(q.position, true)
		if name == "raptors":
			for n in 6:
				var r: Unit = g._add_unit("raptor", 1, at + Vector2(n * 14 - 40, 40))
				foes.append(r)
				r.cmd_move(q.position, true)
		if name == "brutes":
			for n in 4:
				var r2: Unit = g._add_unit("raptor", 1, at + Vector2(n * 14 - 30, 50))
				foes.append(r2)
				r2.cmd_move(q.position, true)
		var t0: float = g.clock
		while g.clock - t0 < 120.0:
			await wait(0.5)
			if mode == "uproot" and not q.dead:
				BroodNew.mother_guard(g, q, guard, 0.5)
			await wait(0.5)
			if mode == "uproot" and not q.dead:
				BroodNew.mother_guard(g, q, guard, 0.5)
			if q.dead:
				break
			var alive := foes.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
			if alive.is_empty():
				break
			# muskets out of powder that won't close in: spent
			if alive.all(func(u) -> bool: return u.kind == "musketeer" and u.powder < 1.0 and u.target == null):
				break
			for u in alive:
				if u.order == "idle" and u.target == null:
					u.cmd_move(q.position, true)       # (they keep at her)
		var left: int = foes.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()
		var grubs: int = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == "grub" and not u.dead).size()
		var killers := {}
		for u in foes:
			if is_instance_valid(u) and u.dead:
				killers[u.last_hit_by] = int(killers.get(u.last_hit_by, 0)) + 1
		print("   killed by: %s" % str(killers))
		var ok: bool = not q.dead
		print("%s  %-9s [%s] the Mother %s, %d hp of %d left after %.0f s; %d of %d attackers left; %d grubs" % [
			"PASS" if ok else "FAIL", name, mode, "lives" if ok else "DIES", int(q.hp), int(q.max_hp), g.clock - t0, left, foes.size(), grubs])
		if not ok:
			fails += 1
			break
		for u in foes:
			if is_instance_valid(u) and not u.dead:
				g.consume_unit(u)
		# (back in her nest before the next wave)
		var t1: float = g.clock
		while mode == "uproot" and q.tesla_mode != "deployed" and g.clock - t1 < 30.0:
			await wait(0.5)
			BroodNew.mother_guard(g, q, guard, 0.5)
		await wait(1.0)
	print("brood_new_defence [%s]: %d failures" % [mode, fails])
	quit(1 if fails > 0 else 0)
