extends SceneTree
## The Brood hall's three levels (Defs.HALL_LEVELS):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_hall.gd
##  1. a Burrow: 5 eggs, 1500 health; WARREN costs 150 biomass, CANCEL pays it back
##  2. while it grows it keeps hatching; 40 s later it's a Warren: 2000 health, eggs fill to 10
##  3. BROODMOUND needs a Gorge Pit, costs 250 + 50 essence; saved and loaded mid-upgrade it
##     goes on from where it was; a Broodmound: 2600 health, armour 2, eggs fill to 15
##  4. the match log, a save at level 3, and a Burrow destroyed while growing pays it back
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
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
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


## A free spot of w x h cells (solid ground, one height) for a test building.
func free_spot(near: Vector2i, w: int, h: int) -> Vector2i:
	for r in range(6, 40):
		for y in range(near.y - r, near.y + r):
			for x in range(near.x - r, near.x + r):
				var ok := true
				for yy in h:
					for xx in w:
						var c := Vector2i(x + xx, y + yy)
						if not g.in_map(c) or not g.is_free(c):
							ok = false
							break
					if not ok:
						break
				if ok:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func hall() -> Building:
	var hs: Array = g.halls_of(0)
	return hs[0] if not hs.is_empty() else null


func _run() -> void:
	var p: Dictionary = g.players[0]
	var h := hall()
	check(h != null, "the Brood starts with its hall")
	check(h.level == 1 and h.d["name"] == "Burrow" and h.eggs_max() == 5 and int(h.max_hp) == 1500, "1. a Burrow: 5 eggs, 1500 health (%s, %d eggs, %d hp)" % [h.d["name"], h.eggs_max(), int(h.max_hp)])
	check(Defs.BUILDINGS["warren"]["name"] == "Spawning Den", "   the tech building is the Spawning Den")
	p["gold"] = 1000
	p["res2"] = 200.0
	var why: String = g.start_hall_upgrade(h)
	check(why == "" and int(p["gold"]) == 850 and h.upgrade_t >= 0.0, "   WARREN started: 150 biomass paid (%s, %d left)" % [why, int(p["gold"])])
	check(g.start_hall_upgrade(h) != "", "   can't start it twice (%s)" % g.hall_upgrade_problem(h))
	await wait(3.0)
	g.cancel_hall_upgrade(h)
	check(int(p["gold"]) == 1000 and h.upgrade_t < 0.0 and h.level == 1, "   cancelled: paid back (%d)" % int(p["gold"]))
	check(g.start_hall_upgrade(h) == "" and int(p["gold"]) == 850, "   started again")
	# it keeps hatching while it grows
	await wait(2.0)
	var grubs0: int = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "grub" and not u.dead).size()
	var tw: String = g.train(h, "grub")
	check(tw == "" and h.queue.size() == 1, "2. hatching a grub while it grows (%s)" % tw)
	var hatched: bool = await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "grub" and not u.dead).size() > grubs0, 30.0)
	check(hatched and h.upgrade_t > 0.0 and h.level == 1, "   the grub hatched, still growing (%.1f s in)" % h.upgrade_t)
	var hp0: float = h.hp
	var up: bool = await wait_for(func() -> bool: return h.level == 2, 45.0)
	check(up and h.d["name"] == "Warren" and int(h.max_hp) == 2000 and h.eggs_max() == 10, "   a Warren after 40 s: 2000 health, 10 eggs (%s, %d hp)" % [h.d["name"], int(h.max_hp)])
	check(h.hp >= hp0 + 400.0, "   it gained the health (%d -> %d)" % [int(hp0), int(h.hp)])
	var tex_scale: float = h.sprite.scale.x
	check(absf(tex_scale - 1.15) < 0.01 or Building.hall_art(2)[0] == "warren_hall", "   drawn bigger (scale %.2f)" % tex_scale)
	var ten: bool = await wait_for(func() -> bool: return h.eggs == 10, 60.0)
	await wait(8.0)
	check(ten and h.eggs == 10, "   its eggs fill to 10 and stop (%d)" % h.eggs)
	check(g.train(h, "grub") == "" and h.eggs == 9, "   still trains")
	# Broodmound: needs a Gorge Pit
	p["gold"] = 1000
	p["res2"] = 200.0
	check(g.hall_upgrade_problem(h) == "Needs a Gorge Pit first.", "3. BROODMOUND needs a Gorge Pit (%s)" % g.hall_upgrade_problem(h))
	var spot := free_spot(h.cell, 4, 3)
	g._add_building("gorge_pit", 0, spot, true)
	await wait(0.2)
	why = g.start_hall_upgrade(h)
	check(why == "" and int(p["gold"]) == 750 and absf(float(p["res2"]) - 150.0) < 0.01, "   BROODMOUND started: 250 biomass + 50 essence (%s, %d / %.0f)" % [why, int(p["gold"]), float(p["res2"])])
	await wait(10.0)
	var ut: float = h.upgrade_t
	SaveGame.save(g, {"map": "hollowfen", "seed": 4242})
	var d := SaveGame.peek()
	SaveGame.restore(g, d)
	await wait(0.2)
	h = hall()
	check(h != null and h.level == 2 and h.d["name"] == "Warren" and absf(h.upgrade_t - ut) < 1.0 and int(h.max_hp) == 2000, "   saved and loaded mid-upgrade: a Warren, %.1f s in (was %.1f)" % [h.upgrade_t if h else -1.0, ut])
	up = await wait_for(func() -> bool: return h.level == 3, 55.0)
	check(up and h.d["name"] == "Broodmound" and int(h.max_hp) == 2600 and int(h.armor) == 2 and h.eggs_max() == 15, "   a Broodmound: 2600 health, armour 2, 15 eggs (%s, %d hp, armour %d)" % [h.d["name"], int(h.max_hp), int(h.armor)])
	check(h.next_level().is_empty() and g.hall_upgrade_problem(h) != "", "   the top level (%s)" % g.hall_upgrade_problem(h))
	var full: bool = await wait_for(func() -> bool: return h.eggs == 15, 60.0)
	check(full, "   its eggs fill to 15 (%d)" % h.eggs)
	var lines: String = "\n".join(g.mlog.lines)
	check(lines.contains("upgraded a Burrow to a Warren") and lines.contains("upgraded a Warren to a Broodmound"), "4. the match log notes both upgrades")
	SaveGame.save(g, {"map": "hollowfen", "seed": 4242})
	SaveGame.restore(g, SaveGame.peek())
	await wait(0.2)
	h = hall()
	check(h != null and h.level == 3 and h.d["name"] == "Broodmound" and h.eggs_max() == 15 and int(h.max_hp) == 2600 and h.hp > 2000.0, "   loaded: still a Broodmound (%d hp)" % [int(h.hp) if h else -1])
	# a new Burrow destroyed while growing pays the upgrade back
	var spot2 := free_spot(h.cell + Vector2i(12, 0), 5, 4)
	var b2: Building = g._add_building("hive", 0, spot2, true)
	await wait(0.2)
	check(b2.level == 1 and b2.d["name"] == "Burrow" and h.d["name"] == "Broodmound", "   a second hall is a Burrow (the first stays a Broodmound)")
	p["gold"] = 500
	g.start_hall_upgrade(b2)
	var g1 := int(p["gold"])
	b2.hp = 0.0
	b2.die()
	check(g1 == 350 and int(p["gold"]) == 500, "   destroyed while growing: paid back (%d -> %d)" % [g1, int(p["gold"])])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
