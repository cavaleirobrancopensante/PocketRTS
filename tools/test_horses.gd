extends SceneTree
## The Crown's horses, end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_horses.gd
## A Crown player (you) against a Brood player whose AI is switched off; everything is set up
## by hand on open ground. Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on
## a failure).
##  1. buying horses at a Horse Breeder (40 gold, 15 s; nothing free, no income); 2 Farms a
##     Town Hall, breeders unlimited; the horse-needing units' prices
##  2. one man leading 3 horses (they follow him)
##  3. a Horseman at the Barracks: refused without a horse, the horse walks in, cancel gives
##     it back, the recruit rides that horse's coat
##  3b. one click trains rider and horse: a spare at a breeder is reserved (only the unit
##     paid), else the breeder trains one (40 more); no gold for the horse: refused; the
##     Horseman comes out on foot, mounts his horse and rides to the rally; a gun's horse
##     walks to the Foundry by itself; cancelling releases the reservation
##  4. a cannon's horse released (it stands, can't move, still fires) and harnessed again
##  4b. a team of up to 4 horses on a gun: HARNESS adds, +12% speed each, RELEASE HORSE one at
##     a time, a team horse killed slows it again
##  5. mounting and dismounting every pair, keeping armour, kit, kills, powder, hp share
##  6. the dragoon's loop: ride up, dismount, fire, remount to move (the reload waits mounted)
##  7. stealing an unattended horse (a Crown man, a Winder); a guarded one stays
##  8. the Brood kills horses but never takes them
##  9. the Shot Pouch: a recruit 10/10, refitted 10/20, refilled 20/20, kept through mount and
##     dismount
## 10. save and load mid-lead and mid-mount (and the rest of the horse state)
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


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


## Wait until cond() is true (at most `sec` game seconds). True if it came true.
func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear_units() -> void:
	for u in g.units.duplicate():
		if u.team == 0 and u.is_worker() and u.order == "gather":
			continue
		if u.position.distance_to(at(400, 300)) < 900.0:
			g.consume_unit(u)
	await physics_frame


func _run() -> void:
	origin = _open_area(26, 20)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	# the tech tree: no powder at the start; the Barracks and the palisade need a Cottage
	check(float(g.players[0]["res2"]) == 0.0, "the Crown starts with no powder")
	check(g.requirement_text(0, "barracks").contains("Cottage"), "the Barracks needs a Cottage ('%s')" % g.requirement_text(0, "barracks"))
	check(g.requirement_text(0, "wall").contains("Cottage") and g.requirement_text(0, "gate").contains("Cottage"), "the palisade and gates need a Cottage")
	var cot: Building = g._add_building("cottage", 0, origin + Vector2i(22, 16), true)
	check(g.requirement_met(0, "barracks") and g.requirement_met(0, "wall"), "a Cottage unlocks them")
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	for b in g.buildings:
		if b.team == 0:
			b.supply()
	await _buying()
	await _leading()
	await _training()
	await _one_click()
	await _cannon()
	await _teams()
	await _pairs()
	await _dragoon()
	await _stealing()
	await _brood()
	await _care()
	await _pouch()
	await _save_load()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. buying horses

func _buying() -> void:
	# the economy: 2 Farms and 1 Mill a Town Hall; the breeder isn't an economy building
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	check(g.econ_limit(0, "farm") == 2 * g.halls_of(0).size(), "2 Farms a Town Hall (%d)" % g.econ_limit(0, "farm"))
	check(g.econ_limit(0, "powder_mill") == g.halls_of(0).size(), "1 Powder Mill a Town Hall")
	check(Defs.FARM_YIELD == 380, "a harvest pays 380 (%d)" % Defs.FARM_YIELD)
	var farms: int = g.econ_count(0, "farm")
	if farms < 2 and hall:
		var spot: Vector2i = g.find_spot(0, "farm", hall, 4, Defs.ECON_RANGE - 2, "behind")
		check(spot.x >= 0 and g.placement_problem(0, "farm", spot, true) == "", "a second Farm can go by the hall ('%s')" % (g.placement_problem(0, "farm", spot, true) if spot.x >= 0 else "no spot"))
	check(not Defs.is_econ("horse_breeder"), "the Horse Breeder is no economy building")
	# prices: a unit and its horse cost about 10 more than before horses
	check(int(Defs.UNITS["horse"]["cost"]) == 40 and absf(float(Defs.UNITS["horse"]["time"]) - 15.0) < 0.01 and int(Defs.UNITS["horse"]["supply"]) == 0, "a horse: 40 gold, 15 s, no supply")
	check(int(Defs.UNITS["cuirassier"]["cost"]) == 115 and int(Defs.UNITS["cannon"]["cost"]) == 170 and int(Defs.UNITS["mortar"]["cost"]) == 145 and int(Defs.UNITS["powder_wagon"]["cost"]) == 70,
		"Horseman 115, Field Cannon 170, Mortar 145, Powder Wagon 70")
	var b: Building = g._add_building("horse_breeder", 0, origin + Vector2i(2, 2), true)
	# breeders: as many as you like, anywhere (far from any hall)
	var far_ok: bool = g.placement_problem(0, "horse_breeder", origin + Vector2i(2, 12), true) == ""
	var b2: Building = g._add_building("horse_breeder", 0, origin + Vector2i(2, 12), true)
	var b3: Building = g._add_building("horse_breeder", 0, origin + Vector2i(7, 12), true)
	check(far_ok and g.placement_problem(0, "horse_breeder", origin + Vector2i(12, 14), true) == "", "breeders: any number, anywhere (3 built, a 4th allowed, far from a hall)")
	# nothing comes free, no income (the farms are stopped meanwhile: only the breeders run)
	var farmland: Array = g.buildings.filter(func(x: Building) -> bool: return x.team == 0 and Defs.is_econ(x.kind))
	for x in farmland:
		x.process_mode = Node.PROCESS_MODE_DISABLED
	var gold0: int = g.players[0]["gold"]
	var n0: int = g.horses_of(0).size()
	await wait(40.0)
	check(g.horses_of(0).size() == n0, "no free horses in 40 s (%d -> %d)" % [n0, g.horses_of(0).size()])
	check(int(g.players[0]["gold"]) == gold0, "the breeder pays no gold (%+d)" % (int(g.players[0]["gold"]) - gold0))
	for x in farmland:
		x.process_mode = Node.PROCESS_MODE_INHERIT
	# HORSE: 40 gold, 15 s
	check(g.can_train(b, "horse") == "", "the breeder trains horses")
	gold0 = g.players[0]["gold"]
	check(g.train(b, "horse") == "", "HORSE")
	check(gold0 - int(g.players[0]["gold"]) == 40, "a horse costs 40 gold (%d)" % (gold0 - int(g.players[0]["gold"])))
	var t0: float = g.clock
	await wait_for(func() -> bool: return g.horses_of(0).size() > n0, 20.0)
	var took: float = g.clock - t0
	check(g.horses_of(0).size() == n0 + 1 and took > 14.5 and took < 15.6, "it comes out after 15 s (%.1f s)" % took)
	# RALLY: new horses go there and graze
	b2.rally = at(260, 200)
	g.train(b2, "horse")
	g.train(b2, "horse")
	g.train(b3, "horse")
	g.train(b3, "horse")
	g.train(b, "horse")
	await wait_for(func() -> bool: return g.horses_of(0).size() >= n0 + 6, 40.0)
	check(g.horses_of(0).size() == n0 + 6, "6 horses bought (%d)" % (g.horses_of(0).size() - n0))
	await wait(6.0)
	var rallied: int = g.horses_of(0).filter(func(h: Unit) -> bool: return h.position.distance_to(at(260, 200)) < 70.0).size()
	check(rallied == 2, "RALLY: the breeder's new horses went there (%d)" % rallied)
	for x in [b2, b3]:
		x.queue.clear()
	var h0: Unit = g.horses_of(0)[0]
	var p0: Vector2 = h0.position
	await wait(12.0)
	check(h0.position.distance_to(h0.graze_at) <= float(Defs.HORSES["wander"]) + 12.0, "a horse grazes where it was left")
	check(h0.coat != "" and HorseCoat.COATS.has(h0.coat), "a horse has a coat (%s)" % h0.coat)
	print("  (horse moved %.0f px while grazing)" % h0.position.distance_to(p0))
	check(g.horses_of(0).size() == n0 + 6, "still no free ones")


# ---------------------------------------------------------------- 2. leading

func _leading() -> void:
	var lab := unit("labourer", at(320, 120))
	lab.auto_work = false
	var n: int = g.lead_order([lab])
	check(n == 3, "LEAD sends one man for 3 horses (%d)" % n)
	await wait_for(func() -> bool: return lab.led.size() == 3, 20.0)
	check(lab.led.size() == 3, "he leads 3 horses")
	lab.cmd_move(at(700, 420))
	await wait_for(func() -> bool: return lab.order == "idle", 25.0)
	await wait(2.0)
	var far := 0.0
	for h in lab.led:
		far = maxf(far, h.position.distance_to(lab.position))
	check(far < 110.0, "the 3 horses followed him in a string (farthest %.0f px)" % far)
	lab.release_horses()
	check(lab.led.is_empty(), "RELEASE lets them go")
	g.consume_unit(lab)


# ---------------------------------------------------------------- 3. training

func _training() -> void:
	g.players[0]["tech"] = {}
	var bar: Building = g._add_building("barracks", 0, origin + Vector2i(12, 2), true)
	var fdy: Building = g._add_building("foundry", 0, origin + Vector2i(18, 2), true)
	check(g.can_train(bar, "musketeer").contains("Powder Mill"), "Musketeers need a Powder Mill ('%s')" % g.can_train(bar, "musketeer"))
	check(String(Defs.UNITS["cuirassier"]["requires"]) == "horse_breeder", "Horsemen need a Horse Breeder")
	check(g.free_horse_at(bar) == null, "no horse at the Barracks yet")
	var lab := unit("labourer", at(250, 220))
	lab.auto_work = false
	var free: Array = g.horses_of(0).filter(func(h: Unit) -> bool: return h.leader == null)
	lab.cmd_lead(free[0])
	await wait_for(func() -> bool: return lab.led.size() == 1, 15.0)
	var coat: String = lab.led[0].coat
	lab.cmd_move(g.approach_point(bar, lab.position))
	await wait_for(func() -> bool: return g.free_horse_at(bar) != null, 25.0)
	check(g.free_horse_at(bar) != null and g.can_train(bar, "horseman") == "", "a horse led to the Barracks: it can train a Horseman with it")
	var horses0: int = g.horses_of(0).size()
	check(g.train(bar, "horseman") == "", "trained")
	check(bar.kits[0].get("coat", "") == coat, "the queue entry keeps that horse's coat")
	check(g.free_horse_at(bar) == null, "that horse is taken (the next one gets his from a breeder)")
	await wait(5.0)
	check(g.horses_of(0).size() == horses0, "the horse walked over and stands hitched beside the Barracks (it does not vanish)")
	g.cancel_train(bar)
	await physics_frame
	check(g.horses_of(0).size() == horses0, "cancelling frees the horse where it stands")
	# again, and let him come out
	var back: Unit = g.free_horse_at(bar)
	check(back != null, "the horse stands at the Barracks again")
	g.train(bar, "horseman")
	var before: int = g.units.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()
	await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size() > before, 30.0)
	var rider: Unit = null
	for u in g.units:
		if u.kind == "cuirassier" and u.team == 0:
			rider = u
	check(rider != null and rider.coat == coat, "the Horseman rides that horse's coat (%s)" % (rider.coat if rider else "-"))
	if rider:
		g.consume_unit(rider)
	g.consume_unit(lab)


# ---------------------------------------------------------------- 3b. one click

func _one_click() -> void:
	await _clear_units()
	var bar: Building = null
	var fdy: Building = null
	for x in g.buildings:
		if x.team == 0 and not x.dead and x.kind == "barracks":
			bar = x
		if x.team == 0 and not x.dead and x.kind == "foundry":
			fdy = x
	for x in g.breeders_of(0):
		x.queue.clear()
		x.kits.clear()
		x.rally = Vector2.INF
	var br: Building = g.breeders_of(0)[0]
	bar.rally = at(640, 140)
	check(g.horses_of(0).is_empty(), "no horses about")
	# no gold for the horse: refused, and said why
	g.players[0]["gold"] = 130
	var why: String = g.can_train(bar, "horseman")
	check(why.contains("horse"), "115 for him but not 40 for a horse: '%s'" % why)
	g.players[0]["gold"] = 20000
	# no spare horse: the nearest breeder trains one for him, paid with him
	var gold0: int = g.players[0]["gold"]
	check(g.train(bar, "horseman") == "", "one click: HORSEMAN")
	check(gold0 - int(g.players[0]["gold"]) == 155, "paid 115 + 40 for his horse (%d)" % (gold0 - int(g.players[0]["gold"])))
	var rid := int(bar.kit_at(bar.queue.size() - 1).get("rid", 0))
	var brq: Building = g.rid_breeder(0, rid)
	check(rid != 0 and brq != null, "a breeder trains his horse, kept for him")
	# (his horse is ready before him: he comes out on foot and gets straight on)
	var on_foot := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "dismounted" and u.horse_rid == rid)
	await wait_for(func() -> bool: return not on_foot.call().is_empty(), 45.0)
	var foot: Array = on_foot.call()
	check(foot.size() == 1, "he comes out on foot, going for his horse")
	var rider: Unit = foot[0] if foot.size() == 1 else null
	if rider:
		await wait_for(func() -> bool: return rider.kind == "cuirassier", 40.0)
		check(rider.kind == "cuirassier" and rider.horse_rid == 0, "he walked to it and got on (%s)" % rider.kind)
		await wait_for(func() -> bool: return rider.position.distance_to(at(640, 140)) < 90.0, 30.0)
		check(rider.position.distance_to(at(640, 140)) < 90.0, "and rode to the Barracks' rally point (%.0f px off)" % rider.position.distance_to(at(640, 140)))
		g.consume_unit(rider)
	# a spare horse at a breeder is kept for him: only the Horseman is paid
	g.train(br, "horse")
	await wait_for(func() -> bool: return g.horses_of(0).size() == 1, 20.0)
	var spare: Unit = g.horses_of(0)[0] if g.horses_of(0).size() == 1 else null
	check(spare != null and spare.horse_rid == 0, "a spare horse at the breeder")
	gold0 = g.players[0]["gold"]
	g.train(bar, "horseman")
	check(gold0 - int(g.players[0]["gold"]) == 115, "with a spare at the breeder only the Horseman is paid (%d)" % (gold0 - int(g.players[0]["gold"])))
	var rid2 := int(bar.kit_at(bar.queue.size() - 1).get("rid", 0))
	check(spare != null and spare.horse_rid == rid2 and rid2 != 0, "that horse is reserved for him")
	check(g.horses_text(0) == "Horses: 1 (1 reserved)", "the card: '%s'" % g.horses_text(0))
	var lab := unit("labourer", spare.position + Vector2(40, 0))
	check(not Unit.horse_free_for(spare, lab), "nobody else can take a reserved horse")
	g.consume_unit(lab)
	# cancelling releases it (no horse comes back out of the Barracks)
	gold0 = g.players[0]["gold"]
	g.cancel_train(bar)
	await physics_frame
	check(spare.horse_rid == 0 and int(g.players[0]["gold"]) - gold0 == 115, "cancelling releases the horse and refunds the Horseman (%+d)" % (int(g.players[0]["gold"]) - gold0))
	check(g.horses_of(0).size() == 1, "and hands no extra horse back")
	# a gun: the spare walks to the Foundry by itself, and the gun rolls out with it
	var coat: String = spare.coat
	check(g.train(fdy, "cannon") == "", "one click: CANNON (%s)" % g.can_train(fdy, "cannon"))
	check(spare.into == fdy, "the gun's horse walks to the Foundry by itself, led by nobody")
	var cannons := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cannon")
	await wait_for(func() -> bool: return not cannons.call().is_empty(), 60.0)
	var cn: Array = cannons.call()
	check(cn.size() == 1 and cn[0].harnessed and cn[0].coat == coat, "the cannon comes out drawn by that horse (%s)" % coat)
	for c in cn:
		g.consume_unit(c)
	# a gun whose horse the breeder trains: cancelled, the horse is kept (it comes out a spare)
	gold0 = g.players[0]["gold"]
	g.train(fdy, "cannon")
	check(gold0 - int(g.players[0]["gold"]) == 210, "no spare: cannon 170 + horse 40 (%d)" % (gold0 - int(g.players[0]["gold"])))
	var q0: int = 0
	for x in g.breeders_of(0):
		q0 += x.queue.count("horse")
	g.cancel_train(fdy)
	var q1: int = 0
	for x in g.breeders_of(0):
		q1 += x.queue.count("horse")
	check(q0 == 1 and q1 == 1, "cancelled: the breeder keeps training that horse (paid for)")
	await wait_for(func() -> bool: return g.horses_of(0).size() == 1, 20.0)
	check(g.horses_of(0).size() == 1 and g.horses_of(0)[0].horse_rid == 0, "it comes out a free spare")
	await _clear_units()


# ---------------------------------------------------------------- 4b. a team of horses

func _teams() -> void:
	await _clear_units()
	var c := unit("cannon", at(300, 520))
	c.max_hp = 100000.0
	c.hp = c.max_hp
	await wait(0.3)
	var base: float = c.speed
	check(c.horse_count() == 1, "a cannon starts with one horse")
	var coats: Array = []
	for i in 4:
		var h := unit("horse", at(360 + i * 30, 580))
		coats.append(h.coat)
	await wait(0.2)
	for i in 3:
		check(g.harness_order([c]) == 1, "HARNESS sends one more horse (%d)" % (i + 2))
		await wait_for(func() -> bool: return c.horse_count() == i + 2, 15.0)
	check(c.horse_count() == 4, "4 horses in the team")
	check(not c.team_room() and g.harness_order([c]) == 0, "no room for a 5th")
	await wait(0.3)
	var cav := float(Defs.UNITS["cuirassier"]["speed"])
	check(absf(c.speed - base * 1.36) < 0.6 and c.speed < cav, "4 horses: +36%% speed (%.1f -> %.1f), still slower than cavalry (%.0f)" % [base, c.speed, cav])
	# a team horse killed: slower again
	var n0: int = c.horse_count()
	for i in 7:
		c.take_damage(30.0, null)
	await wait(0.3)
	check(c.horse_count() < n0 and c.harnessed, "blows kill a team horse (%d left)" % c.horse_count())
	check(c.speed < base * 1.36 - 1.0, "and it's slower (%.1f)" % c.speed)
	# RELEASE HORSE: one at a time, coats kept
	var n1: int = c.horse_count()
	var front: String = String(c.team_horses.back()["coat"]) if not c.team_horses.is_empty() else ""
	var h1: Unit = c.release_horse()
	check(h1 != null and c.horse_count() == n1 - 1 and h1.coat == front and c.harnessed, "RELEASE HORSE lets one go (%d left, coat %s)" % [c.horse_count(), h1.coat if h1 else "-"])
	while c.horse_count() > 1:
		c.release_horse()
	await wait(0.3)
	check(absf(c.speed - base) < 0.6 and c.can_roll(), "one horse: back to its own speed (%.1f)" % c.speed)
	c.release_horse()
	check(c.horse_count() == 0 and not c.can_roll(), "the last one: stationary")
	g.consume_unit(c)
	await _clear_units()


# ---------------------------------------------------------------- 4. cannon

func _cannon() -> void:
	var c := unit("cannon", at(300, 520))
	var coat: String = c.coat
	var h: Unit = c.release_horse()
	await physics_frame
	check(h != null and not c.harnessed and h.coat == coat, "RELEASE HORSE: the horse stands beside it, same coat")
	await wait(0.5)
	check(c.tesla_mode == "deployed", "without a horse the gun is set up at once")
	var p0: Vector2 = c.position
	c.cmd_move(at(600, 520))
	await wait(3.0)
	check(c.position.distance_to(p0) < 16.0, "stationary: it can't move (%.1f px)" % c.position.distance_to(p0))
	var r := unit("raptor", at(300 + 260, 520), 1)
	r.cmd_hold()
	var hp0: float = r.hp
	await wait_for(func() -> bool: return not is_instance_valid(r) or r.dead or r.hp < hp0, 15.0)
	check(not is_instance_valid(r) or r.dead or r.hp < hp0, "it still fires")
	if is_instance_valid(r) and not r.dead:
		g.consume_unit(r)
	var n: int = g.harness_order([c])
	check(n == 1, "HARNESS sends a horse")
	await wait_for(func() -> bool: return c.harnessed, 15.0)
	check(c.harnessed, "harnessed again")
	c.cmd_pack()
	await wait(3.0)
	c.cmd_move(at(500, 520))
	await wait(4.0)
	check(c.position.distance_to(p0) > 30.0, "and it rolls again")
	# a Powder Wagon keeps supplying without its horse
	var w := unit("powder_wagon", at(200, 600))
	w.release_horse()
	await physics_frame
	check(not w.harnessed, "a wagon's horse released too")
	g.consume_unit(c)
	g.consume_unit(w)


# ---------------------------------------------------------------- 5. pairs

func _pair(foot: String, armoured: bool, rides: String, rname: String, fname: String) -> void:
	var m := unit(foot, at(400, 300))
	m.auto_work = false
	if armoured:
		m.put_on_armour()
	m.kills = 3
	m.hp = m.max_hp * 0.5
	if m._pmax > 0.0:
		m.powder = minf(7.0, m._pmax)
	m.lock = "flintlock" if Defs.MUSKETS.has(foot) and foot != "dismounted" else ""
	var h := unit("horse", at(440, 300))
	var coat: String = h.coat
	check(m.cmd_mount(h), "%s told to MOUNT" % fname)
	await wait_for(func() -> bool: return m.kind == rides, 8.0)
	check(m.kind == rides and String(m.d["name"]) == rname and m.armoured == armoured, "%s -> %s (%s)" % [fname, rname, m.d["name"]])
	check(m.coat == coat and m.kills == 3 and absf(m.hp / m.max_hp - 0.5) < 0.02, "  keeps kills, hp share, rides the horse's coat")
	if m._pmax > 0.0:
		check(absf(m.powder - minf(7.0, m._pmax)) < 0.01 and m.lock == ("flintlock" if foot != "dismounted" else ""), "  keeps his powder and lock")
	m.cmd_dismount()
	await wait_for(func() -> bool: return m.kind == foot, 5.0)
	check(m.kind == foot and String(m.d["name"]) == fname and m.armoured == armoured, "%s dismounts -> %s" % [rname, m.d["name"]])
	var steed: Unit = m.steed
	check(steed != null and is_instance_valid(steed) and steed.coat == coat and steed.team == 0 and steed.leader == null, "  his horse stands beside him, unled, same coat")
	check(m.kills == 3 and absf(m.hp / m.max_hp - 0.5) < 0.02, "  still his kills and hp share")
	g.consume_unit(m)
	if is_instance_valid(steed):
		g.consume_unit(steed)
	await physics_frame


func _pairs() -> void:
	await _pair("labourer", false, "messenger", "Messenger", "Labourer")
	await _pair("musketeer", false, "dragoon", "Dragoon", "Musketeer")
	await _pair("musketeer", true, "dragoon", "Armoured Dragoon", "Guardsman")
	await _pair("dismounted", false, "cuirassier", "Horseman", "Officer")
	await _pair("dismounted", true, "cuirassier", "Cuirassier", "Armoured Officer")
	await _pair("missionary", false, "mounted_missionary", "Mounted Missionary", "Missionary")
	# a Mounted Missionary gets off to bandage (and back on after), and to raise the fallen
	var mm := unit("mounted_missionary", at(300, 300))
	var hurt := unit("musketeer", at(340, 300))
	hurt.hp = hurt.max_hp * 0.4
	await wait_for(func() -> bool: return hurt.hp >= hurt.max_hp and mm.kind == "mounted_missionary", 30.0)
	check(hurt.hp >= hurt.max_hp and mm.kind == "mounted_missionary", "a Mounted Missionary gets off to bandage, and back on after")
	var fallen := unit("musketeer", at(360, 340))
	fallen.take_damage(9999.0, null)
	await wait_for(func() -> bool: return not fallen.dead, 25.0)
	check(not fallen.dead and mm.kind == "missionary", "he gets off to raise the fallen (%s)" % mm.kind)
	for x in [mm, hurt, fallen, mm.steed]:
		if x and is_instance_valid(x) and not x.dead:
			g.consume_unit(x)
	# a trained Horseman gets off and on
	var c := unit("cuirassier", at(400, 300))
	c.cmd_dismount()
	await wait_for(func() -> bool: return c.kind == "dismounted", 4.0)
	check(c.kind == "dismounted" and c.d.has("sabre") and c.has_pistol(), "a Horseman dismounts with pistol and sabre")
	g.consume_unit(c)
	if c.steed:
		g.consume_unit(c.steed)


# ---------------------------------------------------------------- 6. dragoon

func _dragoon() -> void:
	var dg := unit("dragoon", at(200, 400))
	dg.cooldown = 1.5
	await wait(1.0)
	check(absf(dg.cooldown - 1.5) < 0.01, "mounted, the reload waits")
	var r := unit("brute", at(200 + 560, 400), 1)
	r.cmd_hold()
	r.d = r.d.duplicate()
	r.d["damage"] = 0.0
	dg.cmd_attack(r)
	check(dg.order == "d_attack", "a Dragoon told to attack rides at it")
	await wait_for(func() -> bool: return dg.kind == "musketeer", 15.0)
	check(dg.kind == "musketeer" and dg.auto_mount and dg.order == "attack", "in range he dismounts to fire")
	var dist: float = r.edge_distance(dg.position)
	check(dist <= float(Defs.UNITS["musketeer"]["range"]) + 20.0, "  within musket range (%.0f px)" % dist)
	var p0: float = dg.powder
	await wait_for(func() -> bool: return dg.powder < p0, 10.0)
	check(dg.powder < p0, "he fires on foot")
	var stayed := true
	for i in 30:
		await wait(0.1)
		if dg.kind != "musketeer":
			stayed = false
			print("  remounted: order %s target %s dist %.0f" % [dg.order, dg.order_target, r.edge_distance(dg.position)])
			break
	check(stayed, "  and stays on foot while the target is in range")
	check(absf(dg.musket_cooldown() - float(Defs.UNITS["musketeer"]["cooldown"]) * float(Defs.HORSES["dragoon_reload"])) < 0.01, "  reloading 1.3x slower (%.2f s)" % dg.musket_cooldown())
	var steed: Unit = dg.steed
	check(steed != null and steed.position.distance_to(dg.position) < 50.0, "  his horse beside him")
	dg.cmd_move(at(0, 400))
	await wait_for(func() -> bool: return dg.kind == "dragoon", 5.0)
	check(dg.kind == "dragoon", "ordered to move, he remounts by himself")
	await wait_for(func() -> bool: return dg.order == "idle", 15.0)
	check(dg.position.distance_to(at(0, 400)) < 60.0, "and rides off")
	# hold keeps him on foot
	dg.cmd_hold()
	await wait(1.5)
	check(dg.kind == "musketeer" and dg.order == "hold", "HOLD: he stays dismounted")
	g.consume_unit(r)
	g.consume_unit(dg)
	if dg.steed and is_instance_valid(dg.steed):
		g.consume_unit(dg.steed)


# ---------------------------------------------------------------- 7. stealing

func _stealing() -> void:
	var h := unit("horse", at(600, 200))
	var guard := unit("musketeer", at(600 + 30, 200))
	guard.cmd_hold()
	var thief := unit("musketeer", at(600 - 18, 200), 1)
	thief.cmd_hold()
	await wait(2.0)
	check(h.team == 0, "a guarded horse stays ours")
	g.consume_unit(guard)
	await wait(2.0)
	check(h.team == 1, "left alone beside an enemy man, it's stolen")
	g.consume_unit(thief)
	var h2 := unit("horse", at(650, 260))
	var w := unit("winder", at(650 + 16, 260), 1)
	w.auto_work = false
	w.cmd_hold()
	await wait(2.0)
	check(h2.team == 1, "a Clockwork Winder takes one too")
	# a led horse can't be stolen
	var lab := unit("labourer", at(700, 330))
	lab.auto_work = false
	var h3 := unit("horse", at(720, 330))
	lab.take_reins(h3)
	lab.cmd_hold()
	var thief2 := unit("labourer", at(735, 330), 1)
	thief2.auto_work = false
	thief2.cmd_hold()
	await wait(2.0)
	check(h3.team == 0, "a led horse isn't taken")
	for x in [h, h2, w, lab, h3, thief2]:
		if is_instance_valid(x) and not x.dead:
			g.consume_unit(x)


# ---------------------------------------------------------------- 8. brood

func _brood() -> void:
	var h := unit("horse", at(500, 600))
	var r := unit("raptor", at(500 + 20, 600), 1)
	await wait_for(func() -> bool: return h.dead, 20.0)
	check(h.dead and h.team == 0, "the Brood kills a horse, never takes it")
	if is_instance_valid(r) and not r.dead:
		g.consume_unit(r)


# ---------------------------------------------------------------- 9. pouch

func _pouch() -> void:
	var bar: Building = null
	for b in g.buildings:
		if b.kind == "barracks" and b.team == 0:
			bar = b
	g.players[0]["tech"]["pouch"] = true
	g._add_building("powder_mill", 0, origin + Vector2i(22, 13), true)     # (Musketeers need a Powder Mill)
	var before: int = g.units.filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.team == 0).size()
	g.train(bar, "musketeer")
	await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.team == 0).size() > before, 25.0)
	var m: Unit = null
	for u in g.units:
		if u.kind == "musketeer" and u.team == 0:
			m = u
	check(m != null and not m.pouch and int(m.powder) == 10 and int(m._pmax) == 10, "a recruit at 10/10 (%d/%d), no pouch" % [int(m.powder), int(m._pmax)])
	check(g.unit_price(0, "musketeer")[0] == int(Defs.UNITS["musketeer"]["cost"]) + Game.kit_fee(g.kit_for_new(0, "musketeer"))[0], "the pouch isn't in a recruit's price")
	m.cmd_move(at(560, 200))
	await wait_for(func() -> bool: return m.order == "idle", 15.0)
	m.powder = 10.0
	var gold0: int = g.players[0]["gold"]
	var r: Array = g.refit_order([m], "pouch")
	check(int(r[0]) == 1 and gold0 - int(g.players[0]["gold"]) == 5, "REFIT POUCH: 5 gold")
	await wait_for(func() -> bool: return m.pouch, 30.0)
	check(m.pouch and int(m._pmax) == 20, "refitted: he can carry 20")
	m.cmd_stop()
	m.powder = 10.0
	check(int(m.powder) == 10 and int(m._pmax) == 20, "  10/20 straight after")
	await wait_for(func() -> bool: return m.powder >= 20.0, 15.0)
	check(m.powder >= 20.0, "refilled at the Barracks: 20/20")
	var h := unit("horse", m.position + Vector2(30, 0))
	m.cmd_mount(h)
	await wait_for(func() -> bool: return m.kind == "dragoon", 6.0)
	check(m.kind == "dragoon" and m.pouch and int(m._pmax) == 20 and m.powder >= 20.0, "mounted: still the pouch, 20/20")
	m.cmd_dismount()
	await wait_for(func() -> bool: return m.kind == "musketeer", 4.0)
	check(m.pouch and int(m._pmax) == 20 and m.powder >= 20.0, "dismounted: still the pouch, 20/20")
	g.consume_unit(m)
	if m.steed:
		g.consume_unit(m.steed)


# ---------------------------------------------------------------- 10. save / load

func _save_load() -> void:
	await _clear_units()
	# a man leading 2 horses; a Musketeer on his way to mount; a Dragoon; a dismounted
	# Cuirassier (Armoured Officer) with 3 charges; a wagon without its horse
	var lab := unit("labourer", at(300, 300))
	lab.auto_work = false
	var a := unit("horse", at(330, 300))
	var b := unit("horse", at(340, 330))
	lab.take_reins(a)
	lab.take_reins(b)
	var coats := [a.coat, b.coat]
	var m := unit("musketeer", at(400, 400))
	var hm := unit("horse", at(560, 400))
	m.cmd_mount(hm)
	var dg := unit("dragoon", at(500, 250))
	var dg_coat: String = dg.coat
	var dc := unit("dismounted", at(60, 250))
	dc.put_on_armour()
	dc.powder = 3.0
	var w := unit("powder_wagon", at(250, 550))
	w.release_horse()
	# a cannon with a team of 3; a new rider and the horse kept for him
	var tc := unit("cannon", at(150, 450))
	tc.team_horses = [{"coat": HorseCoat.pick(), "hp": 1.0}, {"coat": HorseCoat.pick(), "hp": 0.5}]
	var team_coats: Array = tc.team_horses.map(func(th: Dictionary) -> String: return String(th["coat"]))
	var kept := unit("horse", at(600, 520))
	kept.horse_rid = 4242
	var nr := unit("dismounted", at(450, 560))
	nr.horse_rid = 4242
	nr.cmd_hold()
	await wait(0.5)
	check(m.order == "mount", "a Musketeer on his way to mount")
	SaveGame.save(g, {"map": "random", "seed": 4242})
	var d := SaveGame.peek()
	check(not d.is_empty(), "saved")
	SaveGame.restore(g, d)
	await wait(0.2)
	var leaders: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "labourer" and u.led.size() == 2)
	check(leaders.size() == 1, "loaded: the man still leads his 2 horses")
	if leaders.size() == 1:
		var l: Unit = leaders[0]
		check([l.led[0].coat, l.led[1].coat] == coats, "  in their string, same coats")
	var mounting: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.order == "mount")
	check(mounting.size() == 1, "loaded: the Musketeer goes on to mount his horse")
	var dgs: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "dragoon")
	check(dgs.size() == 1 and dgs[0].coat == dg_coat, "loaded: the Dragoon on the same coat")
	var dcs: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "dismounted" and u.horse_rid == 0)
	check(dcs.size() == 1 and dcs[0].armoured and int(dcs[0]._pmax) == 4 and int(dcs[0].powder) == 3, "loaded: Armoured Officer with 3/4 charges (%s)" % (
		"%d units, armour %s %d/%d" % [dcs.size(), dcs[0].armoured, int(dcs[0].powder), int(dcs[0]._pmax)] if dcs.size() > 0 else "none"))
	var ws: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "powder_wagon")
	check(ws.size() == 1 and not ws[0].harnessed, "loaded: the wagon still without its horse")
	var tcs: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "cannon")
	check(tcs.size() == 1 and tcs[0].horse_count() == 3 and tcs[0].team_horses.map(func(th: Dictionary) -> String: return String(th["coat"])) == team_coats \
		and absf(float(tcs[0].team_horses[1]["hp"]) - 0.5) < 0.02, "loaded: the cannon's team of 3, same coats and health")
	var nrs: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "dismounted" and u.horse_rid == 4242)
	var kps: Array = g.horses_of(0).filter(func(h: Unit) -> bool: return h.horse_rid == 4242)
	check(nrs.size() == 1 and kps.size() == 1, "loaded: the new rider and the horse kept for him")
	if nrs.size() == 1:
		var r0: Unit = nrs[0]
		r0.cmd_stop()
		await wait_for(func() -> bool: return r0.kind == "cuirassier", 20.0)
		check(r0.kind == "cuirassier", "  and he gets on it")
	if mounting.size() == 1:
		var mm: Unit = mounting[0]
		await wait_for(func() -> bool: return mm.kind == "dragoon", 10.0)
		check(mm.kind == "dragoon", "  and he mounts")
	SaveGame.clear()


# ---------------------------------------------------------------- Missionary priorities

func _care() -> void:
	await _clear_units()
	var window := float(Defs.REVIVE["window"])
	var m := unit("missionary", at(400, 260))
	m.cmd_hold()
	# a cheap body about to expire, an expensive veteran with more time, one too late to reach
	var cheap := unit("musketeer", at(520, 260))
	var vet := unit("cuirassier", at(250, 300))
	vet.kills = 5
	var late := unit("musketeer", at(400, 420))
	var hurt := unit("cuirassier", at(460, 330))
	hurt.cmd_hold()
	hurt.hp = hurt.max_hp * 0.3
	for b in [cheap, vet, late]:
		b.take_damage(99999.0, null)
	await wait(1.6)
	cheap.died_at = g.clock - (window - 12.0)
	vet.died_at = g.clock - 20.0
	late.died_at = g.clock - (window - 4.0)
	var sc: float = g.body_score(m, cheap)
	var sv: float = g.body_score(m, vet)
	var sl: float = g.body_score(m, late)
	print("  scores: cheap Musketeer (12 s left, %.0f px) %.0f · veteran Horseman (5 kills, 40 s left, %.0f px) %.0f · Musketeer 4 s left %.0f · wounded Horseman %.1f" % [
		cheap.position.distance_to(m.position), sc, vet.position.distance_to(m.position), sv, sl, g.patient_score(m, hurt)])
	check(sl == 0.0, "a body that would expire before he could raise it is skipped")
	check(sv > sc, "the expensive veteran outscores the cheap body about to expire (%.0f > %.0f)" % [sv, sc])
	check(g.find_body(m, float(Defs.REVIVE["scan"]) * Defs.TILE) == vet, "he picks the veteran's body first")
	m.cmd_stop()
	await wait_for(func() -> bool: return m.order == "revive", 3.0)
	check(m.order == "revive" and m._body == vet, "idle, he goes to raise the veteran")
	# a second Missionary leaves the claimed body alone and takes the next one
	var m2 := unit("missionary", at(420, 250))
	await wait(1.2)
	check(not (m2.order == "revive" and m2._body == vet), "a second Missionary doesn't go for the same body (%s)" % m2.order)
	await wait_for(func() -> bool: return not vet.dead, 20.0)
	check(not vet.dead, "the veteran is raised")
	await wait_for(func() -> bool: return hurt.hp >= hurt.max_hp, 30.0)
	check(hurt.hp >= hurt.max_hp, "then the wounded Horseman is bandaged")
	for x in [m, m2, cheap, vet, late, hurt]:
		if is_instance_valid(x) and not x.dead:
			g.consume_unit(x)
