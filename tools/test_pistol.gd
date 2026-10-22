extends SceneTree
## The cavalry's pistol, and the Officers and Dragoons at the Barracks:
##   godot --headless --fixed-fps 30 --script res://tools/test_pistol.gd
##  1. a Horseman (and an Officer) is trained loaded
##  2. mounted, he fires the pistol once at range (the pistol strip plays), then fights with
##     the sabre
##  3. no reload while mounted
##  4. on foot (an Officer) he reloads by himself and spends a charge of powder
##  5. no powder: no reload
##  6. HOLD FIRE: he never fires it by himself (the sabre only)
##  7. mounting and dismounting keep the pistol as it is
##  8. save / load keeps it loaded or not, and HOLD FIRE
##  9. the Barracks trains a Dragoon with his horse (Musketeer + horse) and an Officer (the
##     Horseman less the horse), and the armoured ones only after Armour
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


## A tough enemy that stands still and can't shoot back (a dry Musketeer of the Brood's side).
func dummy(p: Vector2) -> Unit:
	var e := unit("musketeer", p, 1)
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.powder = 0.0
	e._pmax = 0.0
	e.cmd_hold()
	e.stun_t = 9999.0          # (it never moves or strikes back)
	return e


func _run() -> void:
	origin = _open_area(26, 20)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	seed(7)
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	await _clear_units()
	await _fire_and_reload()
	await _hold_fire()
	await _mount_keeps()
	await _save_load()
	await _barracks()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1-5

func _fire_and_reload() -> void:
	var c := unit("cuirassier", at(200, 300))
	var o0 := unit("dismounted", at(200, 360))
	check(c.pistol and c.has_pistol() and o0.pistol, "trained loaded (a Horseman and an Officer)")
	g.consume_unit(o0)
	var e := dummy(at(420, 300))
	c.cmd_attack(e)
	var shot_at := -1.0
	var hp_before := e.hp
	var hp_after_shot := -1.0
	var saw_strip := false
	var end: float = g.clock + 15.0
	while g.clock < end and c.pistol:
		if c._anim_name() == "pistol":
			saw_strip = true
		hp_before = e.hp
		await physics_frame
	if not c.pistol:
		shot_at = c.position.distance_to(e.position) - e.radius - c.radius
		hp_after_shot = e.hp
	check(not c.pistol and shot_at > 60.0 and shot_at <= float(Defs.PISTOL["range"]) + 4.0,
		"mounted, he fires the pistol at range (%.0f px; a musket reaches %d)" % [shot_at, int(Defs.UNITS["musketeer"]["range"])])
	var hit := hp_before - hp_after_shot
	check(hit < 0.5 or absf(hit - float(Defs.PISTOL["damage"])) < 1.0, "  one shot of %d (this one: %.0f, a miss is 0)" % [int(Defs.PISTOL["damage"]), hit])
	check(saw_strip and ArtData.UNITS["horseman"]["frames"].has("pistol_e"), "  the pistol strip plays from the saddle")
	await wait_for(func() -> bool: return c.mode == "" and c.phase != "", 6.0)
	var hp1 := e.hp
	await wait(4.0)
	check(c.mode == "" and not c.pistol and e.hp < hp1 - 30.0 and c.kind == "cuirassier", "  then the sabre (%.0f damage in 4 s)" % (hp1 - e.hp))
	# 3: no reload in the saddle
	g.consume_unit(e)
	c.cmd_move(at(150, 300))
	await wait(float(Defs.PISTOL["reload"]) + 3.0)
	check(not c.pistol and c.kind == "cuirassier", "no reload while mounted")
	# 4: on foot he reloads, spending a charge
	c.cmd_dismount()
	await wait_for(func() -> bool: return c.kind == "dismounted", 4.0)
	var p0 := c.powder
	check(c.kind == "dismounted" and String(c.d["name"]) == "Officer" and not c.pistol, "dismounted: an Officer, the pistol still empty")
	await wait_for(func() -> bool: return c.pistol, float(Defs.PISTOL["reload"]) + 3.0)
	check(c.pistol and absf(c.powder - (p0 - float(Defs.PISTOL["powder"]))) < 0.01, "on foot he reloads by himself and spends powder (%.1f -> %.1f)" % [p0, c.powder])
	# the Officer's shot on foot plays his aim and fire frames
	var e2 := dummy(c.position + Vector2(100, 0))
	c.cmd_attack(e2)
	var anims := {}
	await wait_for(func() -> bool:
		anims[c._anim_name()] = true
		return not c.pistol, 6.0)
	await wait(0.4)
	anims[c._anim_name()] = true
	check(not c.pistol and anims.has("aim") and anims.has("fire"), "the Officer fires on foot: aim and fire frames (%s)" % ", ".join(anims.keys()))
	g.consume_unit(e2)
	c.cmd_stop()
	# 5: no powder, no reload
	c.powder = 0.0
	await wait(float(Defs.PISTOL["reload"]) + 2.0)
	check(not c.pistol, "no powder: no reload")
	check(g.hud.pistol_text(c).contains("no powder"), "  the card says so: '%s'" % g.hud.pistol_text(c))
	g.consume_unit(c)
	if c.steed and is_instance_valid(c.steed):
		g.consume_unit(c.steed)
	await physics_frame


# ---------------------------------------------------------------- 6

func _hold_fire() -> void:
	var c := unit("cuirassier", at(200, 300))
	c.set_hold_fire(true)
	var e := dummy(at(320, 300))
	c.cmd_attack(e)
	var hp0 := e.hp
	await wait(6.0)
	check(c.pistol and c.hold_fire and e.hp < hp0 - 20.0, "HOLD FIRE: he keeps the shot and uses the sabre (%.0f damage)" % (hp0 - e.hp))
	# idle next to an enemy, he picks it himself: still no shot
	c.cmd_stop()
	await wait(4.0)
	check(c.pistol, "  nor on a target he picks himself")
	c.set_hold_fire(false)
	await wait_for(func() -> bool: return not c.pistol, 6.0)
	check(not c.pistol, "HOLD FIRE off: he fires")
	g.consume_unit(c)
	g.consume_unit(e)
	await physics_frame


# ---------------------------------------------------------------- 7

func _mount_keeps() -> void:
	var o := unit("dismounted", at(200, 300))
	o.pistol = false
	o.powder = 0.0              # (so he doesn't reload while we look)
	var h := unit("horse", at(240, 300))
	o.cmd_mount(h)
	await wait_for(func() -> bool: return o.kind == "cuirassier", 6.0)
	check(o.kind == "cuirassier" and not o.pistol, "an Officer with an empty pistol mounts: the Horseman's is empty")
	o.cmd_dismount()
	await wait_for(func() -> bool: return o.kind == "dismounted", 4.0)
	o.pistol = true
	o.hold_fire = true
	var st: Unit = o.steed
	o.cmd_mount(st)
	await wait_for(func() -> bool: return o.kind == "cuirassier", 6.0)
	check(o.kind == "cuirassier" and o.pistol and o.hold_fire, "a loaded one mounts loaded (HOLD FIRE kept)")
	g.consume_unit(o)
	await physics_frame


# ---------------------------------------------------------------- 8

func _save_load() -> void:
	await _clear_units()
	var a := unit("cuirassier", at(200, 300))
	a.pistol = false
	a.hold_fire = true
	var b := unit("dismounted", at(260, 300))
	b.put_on_armour()
	b.pistol = false
	b.powder = 2.0
	b.cmd_hold()
	var c := unit("dismounted", at(320, 300))
	c.pistol = true
	SaveGame.save(g, {"map": "random", "seed": 4242})
	var d := SaveGame.peek()
	SaveGame.restore(g, d)
	await physics_frame
	var cs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier")
	var ds: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "dismounted")
	check(cs.size() == 1 and not cs[0].pistol and cs[0].hold_fire, "loaded: the Horseman's pistol still empty, HOLD FIRE on")
	var arm: Array = ds.filter(func(u: Unit) -> bool: return u.armoured)
	var plain: Array = ds.filter(func(u: Unit) -> bool: return not u.armoured)
	check(arm.size() == 1 and not arm[0].pistol and int(arm[0].powder) == 2 and String(arm[0].d["name"]) == "Armoured Officer", "loaded: the Armoured Officer empty, 2 charges")
	check(plain.size() == 1 and plain[0].pistol and not plain[0].hold_fire, "loaded: the Officer loaded")
	SaveGame.clear()
	await _clear_units()


# ---------------------------------------------------------------- 9

func find(team: int, kind: String, armoured: bool) -> Unit:
	for u in g.units:
		if u.team == team and u.kind == kind and u.armoured == armoured and not u.dead:
			return u
	return null


func _barracks() -> void:
	g.players[0]["tech"] = {}
	var bar: Building = g._add_building("barracks", 0, origin + Vector2i(4, 4), true)
	bar.rally = at(500, 400)
	g._add_building("powder_mill", 0, origin + Vector2i(12, 12), true)
	var br: Building = g._add_building("horse_breeder", 0, origin + Vector2i(18, 4), true)
	for i in 3:
		g._add_building("cottage", 0, origin + Vector2i(4 + 3 * i, 16), true)
	g.players[0]["cap"] = 100
	for h in g.horses_of(0):
		g.consume_unit(h)
	await physics_frame
	var keys: Array = Defs.train_keys(bar.d["trains"], false)
	check(keys == ["musketeer", "dragoon", "horseman", "dismounted"], "the Barracks' card: %s" % [keys])
	check(Defs.train_name("dismounted") == "Officer" and Defs.train_name("dismounted_cuirassier") == "Armoured Officer"
		and Defs.train_name("dragoon") == "Dragoon" and Defs.train_name("armoured_dragoon") == "Armoured Dragoon", "their names")
	check(g.can_train(bar, "armoured_dragoon").contains("Armour") and g.can_train(bar, "dismounted_cuirassier").contains("Armour"),
		"no armoured ones before Armour ('%s')" % g.can_train(bar, "armoured_dragoon"))
	# a Dragoon: the Musketeer's price, and his horse from the breeder (40 more)
	var gold0: int = g.players[0]["gold"]
	var pw0: float = g.players[0]["res2"]
	check(g.train(bar, "dragoon") == "", "one click: DRAGOON")
	var musk: Array = [int(Defs.UNITS["musketeer"]["cost"]), int(Defs.UNITS["musketeer"].get("cost2", 0))]
	var paid: int = gold0 - int(g.players[0]["gold"])
	check(paid == musk[0] + int(Defs.UNITS["horse"]["cost"]) and absf(pw0 - float(g.players[0]["res2"]) - musk[1]) < 0.01,
		"  paid the Musketeer and his horse: %d gold, %.0f powder" % [paid, pw0 - float(g.players[0]["res2"])])
	var rid := int(bar.kit_at(0).get("rid", 0))
	check(rid != 0 and g.rid_breeder(0, rid) == br, "  the breeder trains his horse, kept for him")
	await wait_for(func() -> bool: return find(0, "dragoon", false) != null, 60.0)
	var dg: Unit = find(0, "dragoon", false)
	check(dg != null, "he came out as a Musketeer, got on his horse: a Dragoon")
	# an Officer: the Horseman less the horse, on foot, loaded
	gold0 = g.players[0]["gold"]
	check(g.train(bar, "dismounted") == "", "one click: OFFICER")
	paid = gold0 - int(g.players[0]["gold"])
	check(paid == int(Defs.UNITS["cuirassier"]["cost"]) - int(Defs.UNITS["horse"]["cost"]) and paid == 75, "  paid the Horseman less his horse: %d" % paid)
	await wait_for(func() -> bool: return find(0, "dismounted", false) != null, 30.0)
	var of: Unit = find(0, "dismounted", false)
	check(of != null and of.pistol and not of.armoured and of.horse_rid == 0, "an Officer comes out on foot, loaded")
	# Armour: the armoured ones too
	g.players[0]["tech"]["armour"] = true
	keys = Defs.train_keys(bar.d["trains"], true)
	check(keys.has("armoured_dragoon") and keys.has("dismounted_cuirassier"), "with Armour: Armoured Dragoon and Armoured Officer on the card")
	check(g.can_train(bar, "armoured_dragoon") == "" and g.can_train(bar, "dismounted_cuirassier") == "", "  and they can be trained ('%s' / '%s')" % [g.can_train(bar, "armoured_dragoon"), g.can_train(bar, "dismounted_cuirassier")])
	var pa: Array = g.unit_price(0, "dismounted_cuirassier")
	check(pa[0] == 75 + int(Defs.RESEARCH["armour"]["fees"]["dismounted"][0]), "  the Armoured Officer: %d gold" % pa[0])
	g.train(bar, "dismounted_cuirassier")
	await wait_for(func() -> bool: return find(0, "dismounted", true) != null, 30.0)
	var ao: Unit = find(0, "dismounted", true)
	check(ao != null and String(ao.d["name"]) == "Armoured Officer" and ao.pistol, "an Armoured Officer comes out, loaded")
	for h in g.horses_of(0):
		g.consume_unit(h)
	g.train(br, "horse")
	await wait_for(func() -> bool: return g.horses_of(0).size() == 1, 25.0)
	gold0 = g.players[0]["gold"]
	g.train(bar, "armoured_dragoon")
	paid = gold0 - int(g.players[0]["gold"])
	check(paid == 60 + int(Defs.RESEARCH["armour"]["fees"]["dragoon"][0]), "an Armoured Dragoon with a spare horse at the breeder: %d gold (no horse to buy)" % paid)
	await wait_for(func() -> bool: return find(0, "dragoon", true) != null, 60.0)
	var ad: Unit = find(0, "dragoon", true)
	check(ad != null and String(ad.d["name"]) == "Armoured Dragoon", "  he comes out and rides off as an Armoured Dragoon")
