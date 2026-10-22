extends SceneTree
## The Crown's horses, end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_horses.gd
## A Crown player (you) against a Brood player whose AI is switched off; everything is set up
## by hand on open ground. Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on
## a failure).
##  1. breeding up to the cap round a Horse Breeder (and its gold)
##  2. one man leading 3 horses (they follow him)
##  3. a Horseman at the Barracks: refused without a horse, the horse walks in, cancel gives
##     it back, the recruit rides that horse's coat
##  4. a cannon's horse released (it stands, can't move, still fires) and harnessed again
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
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	for b in g.buildings:
		if b.team == 0:
			b.supply()
	await _breeding()
	await _leading()
	await _training()
	await _cannon()
	await _pairs()
	await _dragoon()
	await _stealing()
	await _brood()
	await _pouch()
	await _save_load()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. breeding

func _breeding() -> void:
	var b: Building = g._add_building("horse_breeder", 0, origin + Vector2i(2, 2), true)
	var gold0: int = g.players[0]["gold"]
	await wait(10.0)
	var earned: int = int(g.players[0]["gold"]) - gold0
	check(earned >= 40 and earned <= 60, "the breeder pays about 5 gold a second (%d in 10 s)" % earned)
	# speed the foals up: the cap must hold
	for i in 12:
		b.growth = 0.999
		await wait(1.2)
	var near: int = g.horses_of(0).filter(func(h: Unit) -> bool: return b.edge_distance(h.position) <= 6 * Defs.TILE).size()
	check(near == int(Defs.HORSES["graze_cap"]), "breeding stops at %d round the breeder (%d)" % [Defs.HORSES["graze_cap"], near])
	var h0: Unit = g.horses_of(0)[0]
	var p0: Vector2 = h0.position
	await wait(12.0)
	check(h0.position.distance_to(h0.graze_at) <= float(Defs.HORSES["wander"]) + 12.0, "a horse grazes where it was left")
	check(h0.coat != "" and HorseCoat.COATS.has(h0.coat), "a horse has a coat (%s)" % h0.coat)
	print("  (horse moved %.0f px while grazing)" % h0.position.distance_to(p0))


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
	var why: String = g.can_train(bar, "horseman")
	check(why.begins_with("Needs a horse"), "no horse: '%s'" % why)
	var lab := unit("labourer", at(250, 220))
	lab.auto_work = false
	var free: Array = g.horses_of(0).filter(func(h: Unit) -> bool: return h.leader == null)
	lab.cmd_lead(free[0])
	await wait_for(func() -> bool: return lab.led.size() == 1, 15.0)
	var coat: String = lab.led[0].coat
	lab.cmd_move(g.approach_point(bar, lab.position))
	await wait_for(func() -> bool: return g.can_train(bar, "horseman") == "", 25.0)
	check(g.can_train(bar, "horseman") == "", "a horse led to the Barracks: it can train a Horseman")
	var horses0: int = g.horses_of(0).size()
	check(g.train(bar, "horseman") == "", "trained")
	check(bar.kits[0].get("coat", "") == coat, "the queue entry keeps that horse's coat")
	check(g.can_train(bar, "horseman").begins_with("Needs a horse"), "the next one needs another horse")
	await wait(5.0)
	check(g.horses_of(0).size() == horses0 - 1, "the horse walked in and is gone")
	g.cancel_train(bar)
	await physics_frame
	check(g.horses_of(0).size() == horses0, "cancelling gives the horse back")
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
		m.powder = 7.0
	m.lock = "flintlock" if Defs.MUSKETS.has(foot) and foot != "dismounted" else ""
	var h := unit("horse", at(440, 300))
	var coat: String = h.coat
	check(m.cmd_mount(h), "%s told to MOUNT" % fname)
	await wait_for(func() -> bool: return m.kind == rides, 8.0)
	check(m.kind == rides and String(m.d["name"]) == rname and m.armoured == armoured, "%s -> %s (%s)" % [fname, rname, m.d["name"]])
	check(m.coat == coat and m.kills == 3 and absf(m.hp / m.max_hp - 0.5) < 0.02, "  keeps kills, hp share, rides the horse's coat")
	if m._pmax > 0.0:
		check(absf(m.powder - 7.0) < 0.01 and m.lock == ("flintlock" if foot != "dismounted" else ""), "  keeps his powder and lock")
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
	await _pair("dismounted", false, "cuirassier", "Horseman", "Dismounted Horseman")
	await _pair("dismounted", true, "cuirassier", "Cuirassier", "Dismounted Cuirassier")
	# a trained Horseman gets off and on
	var c := unit("cuirassier", at(400, 300))
	c.cmd_dismount()
	await wait_for(func() -> bool: return c.kind == "dismounted", 4.0)
	check(c.kind == "dismounted" and c.d.has("sabre"), "a Horseman dismounts with carbine and sabre")
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
	# Cuirassier with a pouch; a wagon without its horse
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
	dc.set_pouch()
	dc.powder = 17.0
	var w := unit("powder_wagon", at(250, 550))
	w.release_horse()
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
	var dcs: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "dismounted")
	check(dcs.size() == 1 and dcs[0].armoured and dcs[0].pouch and int(dcs[0]._pmax) == 20 and int(dcs[0].powder) == 17, "loaded: Dismounted Cuirassier with his pouch, 17/20 (%s)" % (
		"%d units, armour %s pouch %s %d/%d" % [dcs.size(), dcs[0].armoured, dcs[0].pouch, int(dcs[0].powder), int(dcs[0]._pmax)] if dcs.size() > 0 else "none"))
	var ws: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "powder_wagon")
	check(ws.size() == 1 and not ws[0].harnessed, "loaded: the wagon still without its horse")
	if mounting.size() == 1:
		var mm: Unit = mounting[0]
		await wait_for(func() -> bool: return mm.kind == "dragoon", 10.0)
		check(mm.kind == "dragoon", "  and he mounts")
	SaveGame.clear()
