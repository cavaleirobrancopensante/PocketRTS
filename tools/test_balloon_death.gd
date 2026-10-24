extends SceneTree
## A balloon that is destroyed takes everyone aboard with it:
##   godot --headless --fixed-fps 30 --script res://tools/test_balloon_death.gd
##  1. shot down with 3 men aboard: all 3 die, 3 bodies lie spread round the wreck, supply and the
##     lost / killed counts are right (balloon + 3 lost, all credited to the Brood), none twice
##  2. a Brood grub harvests one of the bodies (essence for the Brood)
##  3. men let off before it was shot down live; men let off while it was coming down live
##  4. men still walking over to board are not aboard yet: they live
##  5. an empty balloon dies as before (one loss, no body)
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
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
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


## Open ground near our hall, away from everything.
func open_spot(i: int) -> Vector2:
	var h: Building = g._own_hall(0)
	var c0: Vector2i = g.cell_of(h.rect().get_center())
	var found := 0
	for r in range(6, 30):
		for y in range(c0.y - r, c0.y + r):
			for x in range(c0.x - r, c0.x + r):
				var c := Vector2i(x, y)
				if g.in_map(c) and g._clear_at(g.cell_center(c), 40.0, 0):
					if found == i:
						return g.cell_center(c)
					found += 1
	return g.cell_center(c0)


func balloon_with(n: int, p: Vector2) -> Unit:
	var b: Unit = g._add_unit("balloon", 0, p)
	for i in n:
		var m: Unit = g._add_unit("musketeer", 0, p + Vector2(10 * i, 0))
		b.take_aboard(m)
	return b


func shoot_down(b: Unit, by: Unit) -> void:
	b.take_damage(99999.0, by, "spit")


func _run() -> void:
	var foe: Unit = g._add_unit("spitter", 1, open_spot(40))
	var sup0: int = g.supply_used(0)
	var lost0: int = g.stats[0]["lost"]
	var killed0: int = g.stats[1]["killed"]
	var corpses0: int = g.corpses.size()
	var mus_supply: int = int(Defs.UNITS["musketeer"]["supply"])
	var bal_supply: int = int(Defs.UNITS["balloon"]["supply"])
	# 1. three men aboard, shot down
	var b := balloon_with(3, open_spot(0))
	var men: Array = b.passengers.duplicate()
	check(men.size() == 3 and g.supply_used(0) == sup0 + bal_supply + 3 * mus_supply, "1. 3 men aboard count toward supply (%d)" % (g.supply_used(0) - sup0))
	shoot_down(b, foe)
	await wait(0.2)
	check(b.dead and b.passengers.is_empty(), "   the balloon is dead and its basket empty")
	var dead_men: Array = men.filter(func(u: Unit) -> bool: return u.dead)
	var live_men: Array = men.filter(func(u: Unit) -> bool: return not u.dead)
	check(men.all(func(u: Unit) -> bool: return u.aboard == null and not u.off_field), "   nobody is left aboard")
	check(dead_men.all(func(u: Unit) -> bool: return g.corpses.has(u) and u.visible), "   each who died left a body")
	check(live_men.all(func(u: Unit) -> bool: return u.hp > 0.0 and u.hp <= u.max_hp and not g.corpses.has(u)), "   each who lived has some health left")
	check(g.corpses.size() == corpses0 + dead_men.size(), "   bodies = the dead (%d)" % dead_men.size())
	check(g.supply_used(0) == sup0 + live_men.size() * mus_supply, "   supply: the survivors still count (%d vs %d)" % [g.supply_used(0), sup0])
	check(g.stats[0]["lost"] == lost0 + 1 + dead_men.size(), "   losses: balloon + the dead (%d)" % (g.stats[0]["lost"] - lost0))
	# the fall is a roll: over many men all four fates turn up
	var died := 0
	var bruised := 0
	var hurt := 0
	var crippled := 0
	for k in 12:
		var bb := balloon_with(4, open_spot(10 + k))
		var mm: Array = bb.passengers.duplicate()
		shoot_down(bb, foe)
		await wait(0.1)
		for u in mm:
			if u.dead:
				died += 1
			elif u.hp >= u.max_hp * 0.75:
				bruised += 1
			elif u.hp >= u.max_hp * 0.4:
				hurt += 1
			else:
				crippled += 1
	check(died > 0 and bruised > 0 and hurt > 0 and crippled > 0, "   the fall is a roll: died %d, bruised %d, hurt %d, crippled %d of 48" % [died, bruised, hurt, crippled])
	# (the dead of this batch are used below)
	for u in g.corpses:
		if is_instance_valid(u) and u.kind == "musketeer":
			dead_men.append(u)
	men = dead_men
	b.die()
	live_men.clear()
	var lost1: int = g.stats[0]["lost"]
	men[0].die()
	check(g.stats[0]["lost"] == lost1, "   dying again counts nothing more")
	# 2. a grub harvests one of the bodies (the men who lived would shoot it: they are cleared first)
	for u in g.units.duplicate():
		if u.team == 0 and u.kind == "musketeer" and not u.dead:
			u.die()
	var body: Unit = men[0]
	var grub: Unit = g._add_unit("grub", 1, body.position + Vector2(30, 0))
	var res0: float = float(g.players[1]["res2"])
	grub.cmd_harvest()
	var n_bodies: int = g.corpses.size()
	var done: bool = await wait_for(func() -> bool: return g.corpses.size() < n_bodies, 40.0)
	await wait(1.0)
	check(done, "2. a grub took a body to harvest")
	var got: bool = await wait_for(func() -> bool: return float(g.players[1]["res2"]) > res0 or grub.cocoon > 0, 40.0)
	check(got, "   and it carries essence home (cocoon %d, essence %.0f -> %.0f)" % [grub.cocoon, res0, float(g.players[1]["res2"])])
	# 3. men let off first live
	var b2 := balloon_with(2, open_spot(3))
	var off: Array = b2.passengers.duplicate()
	b2.drop_passengers(b2.position)
	check(off.all(func(u: Unit) -> bool: return not u.dead and u.aboard == null and not u.off_field), "3. men let off are on the ground")
	shoot_down(b2, foe)
	await wait(0.2)
	check(b2.dead and off.all(func(u: Unit) -> bool: return not u.dead and not g.corpses.has(u)), "   shot down afterwards: they live")
	# ... and men in the middle of being let off
	var b3 := balloon_with(2, open_spot(6))
	var mid: Array = b3.passengers.duplicate()
	b3.work = "dropping"
	b3.work_t = 0.6
	shoot_down(b3, foe)
	await wait(0.2)
	check(b3.dead and mid.all(func(u: Unit) -> bool: return not u.dead and u.aboard == null and not u.off_field), "   shot down while setting them down: they get out alive")
	# 4. men walking over to board
	var b4: Unit = g._add_unit("balloon", 0, open_spot(10))
	var walker: Unit = g._add_unit("musketeer", 0, b4.position + Vector2(200, 0))
	var rider := balloon_with(0, open_spot(13))
	walker.cmd_board(b4)
	await wait(0.3)
	var aboard_first: Unit = g._add_unit("musketeer", 0, b4.position)
	b4.take_aboard(aboard_first)
	check(walker.order == "board" and not walker.dead and b4.passengers.size() == 1, "4. one man aboard, one on his way")
	shoot_down(b4, foe)
	await wait(0.3)
	check(not walker.dead and walker.aboard == null and walker.order != "board", "   the man still walking over lives and stops")
	check(aboard_first.aboard == null and (aboard_first.dead or aboard_first.hp < aboard_first.max_hp), "   the one aboard fell (died or hurt)")
	# 5. an empty balloon
	var lost2: int = g.stats[0]["lost"]
	var cs: int = g.corpses.size()
	shoot_down(rider, foe)
	await wait(0.2)
	check(rider.dead and g.stats[0]["lost"] == lost2 + 1 and g.corpses.size() == cs, "5. an empty balloon: one loss, no body")
	print("balloon death: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
