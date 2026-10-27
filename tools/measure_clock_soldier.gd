extends SceneTree
## Measurement only (docs/clock_soldier_shield.md): Clock Soldiers in headless stand-up fights on open ground, with the
## OLD base stats (90 hp, speed 62), the NEW ones (Defs) and the NEW ones with SHIELD FORWARD raised; and the race:
## a soldier chasing a Musketeer that walks off, and one walking away from Musketeers' fire.
##   godot --headless --fixed-fps 30 --script res://tools/measure_clock_soldier.gd [-- reps:6 only:musketeer]
## Both sides attack-move at each other from 340 px apart; the Clockwork's wind is kept full (no gear field out there:
## the fight alone is measured). Each line: wins of the Clock Soldiers out of reps, their survivors and health left,
## the enemy's survivors, the fight's length.
const U := preload("res://tools/gear_test_util.gd")
const OLD := {"hp": 90.0, "speed": 62.0}

var g: Game
var at := Vector2.ZERO
var reps := 6
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.split(":")
		if p[0] == "reps":
			reps = int(p[1])
		elif p[0] == "only":
			only = p[1]
	_run.call_deferred()


func _run() -> void:
	g = U.make(root, ["clockwork", "brood"])
	await process_frame
	await process_frame
	var h0 := U.hall(g, 0)
	var h1 := U.hall(g, 1)
	at = _open((h0.center() + h1.center()) * 0.5)
	g.players[0]["tech"][ShieldWall.TECH] = true
	print("Clock Soldier: %s hp, speed %s (old 90, 62); SHIELD_WALL %s" % [Defs.UNITS["clock_soldier"]["hp"], Defs.UNITS["clock_soldier"]["speed"], str(Defs.SHIELD_WALL)])
	# [label, clock soldiers, enemy kind, enemy count]
	var fights := [
		["6 CS vs 6 Musketeers (420 vs 420)", 6, "musketeer", 6],
		["6 CS vs 18 Raptors (6 eggs, 450)", 6, "raptor", 18],
		["6 CS vs 5 Spitters (475)", 6, "spitter", 5],
		["6 CS vs 4 Springers (400 + 100 Tension)", 6, Defs.SPRINGER, 4],
		["6 CS vs 8 Labourers (400)", 6, "labourer", 8],
		["3 CS vs 8 Labourers", 3, "labourer", 8],
		["8 CS vs 6 Musketeers", 8, "musketeer", 6],
		["6 CS vs 5 Musketeers", 6, "musketeer", 5],
		["6 CS vs 7 Spitters", 6, "spitter", 7],
		["6 CS vs 6 Springers", 6, Defs.SPRINGER, 6],
		["6 CS vs 4 Brutes (600 + 80)", 6, "brute", 4],
	]
	for f in fights:
		if only != "" and not String(f[2]).contains(only):
			continue
		print("--- %s" % f[0])
		for mode in ["old", "new", "shield"]:
			var w := 0
			var left := 0.0
			var hpl := 0.0
			var foes := 0.0
			var tt := 0.0
			for r in reps:
				seed(1000 + r)
				var res: Dictionary = await _fight(int(f[1]), String(f[2]), int(f[3]), mode)
				w += 1 if res["win"] else 0
				left += float(res["left"])
				hpl += float(res["hp"])
				foes += float(res["foes"])
				tt += float(res["t"])
			print("  %-7s CS win %d/%d  CS left %.1f (hp %4.0f)  enemy left %.1f  %.0f s" % [mode, w, reps, left / reps, hpl / reps, foes / reps, tt / reps])
	await _races()
	print("DONE")
	quit(0)


func _set_mode(u: Unit, mode: String) -> void:
	if mode == "old":
		u.d = u.d.duplicate()
		u.d["hp"] = OLD["hp"]
		u.d["speed"] = OLD["speed"]
		u.max_hp = OLD["hp"]
		u.hp = OLD["hp"]
	elif mode == "shield":
		u.shield_up = true
		u.shield_t = 0.0
		u.armor = float(u.d["armor"]) + float(Defs.SHIELD_WALL["armor"])


func _fight(n: int, foe: String, m: int, mode: String) -> Dictionary:
	_clear()
	var mine: Array = []
	var theirs: Array = []
	for i in n:
		var u: Unit = g._add_unit("clock_soldier", 0, _open(at + Vector2(-170, (i - n * 0.5) * 22.0)))
		_set_mode(u, mode)
		u.facing = Vector2.RIGHT
		mine.append(u)
	var spawned := 0
	var i2 := 0
	while spawned < m:
		var p := _open(at + Vector2(170 + (i2 % 2) * 20.0, (i2 / 2 - m * 0.25) * 22.0))
		var u2: Unit = g._add_unit(foe, 1, p)
		u2.auto_work = false
		u2.facing = Vector2.LEFT
		# (a Raptor egg's three come one by one here: each its own unit)
		theirs.append(u2)
		spawned += 1
		i2 += 1
	for u in mine:
		u.cmd_move(at + Vector2(170, 0), true)
	for u in theirs:
		u.cmd_move(at + Vector2(-170, 0), true)
	var t := 0.0
	while t < 120.0:
		for u in mine:
			if is_instance_valid(u) and not u.dead:
				u.wind = 1.0
		U.step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		var a := mine.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		var b := theirs.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		if a.is_empty() or b.is_empty():
			break
		# (stragglers: anyone idle goes at the nearest enemy)
		if int(t * 30.0) % 30 == 0:
			for u in a:
				if u.order == "idle" and not b.is_empty():
					u.cmd_move(b[0].position, true)
			for u in b:
				if u.order == "idle" and not a.is_empty():
					u.cmd_move(a[0].position, true)
	var al := mine.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var bl := theirs.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var hp := 0.0
	for u in al:
		hp += u.hp
	return {"win": bl.is_empty() and not al.is_empty(), "left": al.size(), "hp": hp, "foes": bl.size(), "t": t}


## The race: (1) a Clock Soldier chases a Musketeer that walks straight off (does it catch it in 20 s?); (2) a Clock
## Soldier walks 420 px straight away from 4 Musketeers firing at it (damage taken); (3) the same toward them (the
## advance into fire, until it reaches them).
func _races() -> void:
	print("--- the race")
	for mode in ["old", "new", "shield"]:
		_clear()
		var cs: Unit = g._add_unit("clock_soldier", 0, _open(at))
		_set_mode(cs, mode)
		var mk: Unit = g._add_unit("musketeer", 1, _open(at + Vector2(60, 0)))
		mk.hold_fire = true
		mk.cmd_move(at + Vector2(1200, 0))
		cs.cmd_attack(mk)
		var t := 0.0
		var caught := -1.0
		while t < 20.0:
			cs.wind = 1.0
			U.step(g, 1.0 / 30.0)
			t += 1.0 / 30.0
			if mk.hp < mk.max_hp and caught < 0.0:
				caught = t
		print("  chase   %-7s first blow on a Musketeer walking off: %s; gap at 20 s %.0f px" % [mode, ("%.1f s" % caught) if caught >= 0.0 else "never", cs.position.distance_to(mk.position)])
	for dir in ["away", "toward"]:
		for mode in ["old", "new", "shield"]:
			var tot := 0.0
			var tt := 0.0
			for r in reps:
				seed(2000 + r)
				_clear()
				var cs: Unit = g._add_unit("clock_soldier", 0, _open(at))
				_set_mode(cs, mode)
				cs.max_hp = 5000.0
				cs.hp = 5000.0
				var mks: Array = []
				for i in 4:
					var mk: Unit = g._add_unit("musketeer", 1, _open(at + Vector2(170, (i - 1.5) * 24.0)))
					mk.cmd_hold()
					mk.cmd_attack(cs)
					mks.append(mk)
				cs.facing = Vector2.LEFT if dir == "away" else Vector2.RIGHT
				if dir == "away":
					cs.cmd_move(at + Vector2(-420, 0))
				else:
					cs.cmd_move(at + Vector2(150, 0))
				var t := 0.0
				while t < 25.0:
					cs.wind = 1.0
					U.step(g, 1.0 / 30.0)
					t += 1.0 / 30.0
					if cs.order == "idle":
						break
				tot += 5000.0 - cs.hp
				tt += t
			print("  %-6s  %-7s walking %s 4 Musketeers: %.0f damage taken over %.1f s" % [dir, mode, "away from" if dir == "away" else "up to", tot / reps, tt / reps])
	await process_frame


func _clear() -> void:
	for u in g.units.duplicate():
		if not u.is_worker() or u.kind == "labourer":
			g.units.erase(u)
			g.selection.erase(u)
			u.queue_free()
	for c in g.get_children():
		if c is Effect:
			c.queue_free()


func _open(p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))
