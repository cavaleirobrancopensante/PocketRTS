extends SceneTree
## TIER 3 of the gear-mode Clockwork (scripts/pendulum.gd, scripts/netter.gd; docs/clockwork_gear_prototype.md "Tier 3"):
## the PENDULUM (from the HEAVY WORKS since 0.14.94, on its big gear only, a Tension user) and the NETTER (from the Light
## Works) once an Escapement WORKS (none, or an idle one, refuses them); both cost cogs AND Tension (Tension short refuses; a
## cancel pays the Tension back). The Light Works cannot make the Pendulum; the Heavy Works cannot swap to the small gear. The Pendulum's swing hurts EVERY enemy in the arc
## in front of it, not one behind it nor one beside it out of the arc, never its own side; the blow lands on the 5th
## frame of its swing. The Netter's net flies and catches ONE enemy: caught, it does not move or fire for the net's time,
## then it does again; a flyer it catches is on the ground meanwhile (a ground-only unit can hit it, its sprite comes
## down) and flies again after; the Netter then waits its long reload; by itself it nets the most dangerous enemy in reach
## and not one caught already. The Lab starts with a Heavy Works, two Pendulums and two Netters; the sandbox lists both.
## Both cost Tension, so (THE TENSION RULE, scripts/gear_econ.gd) they are made only at a Works whose ring meshes with a
## Mainspring's: a Works with none refuses them.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_tier3.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## U.step, and the nets and bombs in the air (game children the util does not step).
func step(g: Game, secs: float) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		U.step(g, 1.0 / 30.0)
		for c in g.get_children():
			if (c is ChainNet or c is OwlBomb) and is_instance_valid(c) and not c.is_queued_for_deletion():
				c._physics_process(1.0 / 30.0)


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var P := Defs.PENDULUM
	var N := Defs.NETTER
	var wd: Dictionary = Defs.BUILDINGS[Defs.CW_WORKS]
	var hd: Dictionary = Defs.BUILDINGS[Defs.CW_HEAVY]
	check("the Light Works trains the Netter, not the Pendulum (0.14.94)", (wd["trains"] as Array).has(N) and not (wd["trains"] as Array).has(P))
	check("the Heavy Works trains the Pendulum", (hd["trains"] as Array).has(P))
	check("the Pendulum's price is cogs and Tension", g.unit_price(0, P) == [int(Defs.UNITS[P]["cost"]), int(Defs.UNITS[P]["tension"])], str(g.unit_price(0, P)))
	check("the Netter's price is cogs and Tension", g.unit_price(0, N) == [int(Defs.UNITS[N]["cost"]), int(Defs.UNITS[N]["tension"])], str(g.unit_price(0, N)))
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var hall := U.hall(g, 0)
	var works := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	check("a Light Works links (on its small gear)", works != null and g.gear_net.is_linked(works) and not works.gear_big)
	if works == null:
		_end()
		return
	g._recount_supply(0)
	g.players[0]["cap"] = 200
	var why := g.can_train(works, N)
	check("no Escapement: the Netter is refused", why.contains("Escapement"), why)
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	U.step(g, 0.6)
	check("an Escapement stands, linked but idle (no Mainspring)", esc != null and g.gear_net.needs_spring(esc))
	why = g.can_train(works, N)
	check("an IDLE Escapement does not allow the Netter", why != "" and why.contains("Mainspring"), why)
	var spring := _spring_beside(g, esc)
	U.step(g, 0.6)
	check("a Mainspring meshes with the Escapement: it works", spring != null and g.gear_net.speed_mult(esc) > 0.0)
	# ---- THE TENSION RULE (GearEcon): the Netter costs Tension, so it is made only at a Works whose ring meshes with a Mainspring's
	if g.gear_net.spring_for(works) == null:
		why = g.can_train(works, N)
		check("a Works meshing with no Mainspring refuses the Netter (it costs Tension)", why.contains("meshes with no Mainspring"), why)
		var wsp := _spring_beside(g, works)
		U.step(g, 0.6)
		check("a Mainspring put beside the Works meshes with it", wsp != null and g.gear_net.spring_for(works) != null)
	why = g.can_train(works, N)
	check("with a working Escapement the Netter trains at a small-gear Light Works", why == "", why)
	why = g.can_train(works, P)
	check("the Light Works cannot make the Pendulum", why != "", why)
	# ---- the HEAVY WORKS: on its big gear, a Tension user (by a Mainspring)
	var heavy := U.put(g, 0, Defs.CW_HEAVY, hall.cell)
	check("a Heavy Works stands on its big gear", heavy != null and heavy.gear_big)
	if heavy == null:
		_end()
		return
	if g.gear_net.spring_for(heavy) == null:
		U.step(g, 0.6)
		check("a Heavy Works with no Mainspring stands idle", g.gear_net.needs_spring(heavy) and g.can_train(heavy, P) != "", g.can_train(heavy, P))
		var hsp := _spring_beside(g, heavy)
		U.step(g, 0.6)
		check("a Mainspring put beside the Heavy Works meshes with it", hsp != null and g.gear_net.spring_for(heavy) != null)
	check("the Heavy Works stays on its big gear (no gear swap since 0.24.4)", heavy.gear_big and not g.has_method("swap_gear"))
	g.players[0]["cap"] = 200          # (the game counts the supply again as it runs: room for the orders)
	var cogs0 := int(g.players[0]["gold"])
	var ten0 := g.tension(0)
	why = g.train(heavy, P)
	check("the Heavy Works takes a Pendulum order", why == "", why)
	check("its cogs were spent", int(g.players[0]["gold"]) == cogs0 - int(Defs.UNITS[P]["cost"]), "%d -> %d" % [cogs0, int(g.players[0]["gold"])])
	check("its Tension was spent", is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[P]["tension"])), "%.0f -> %.0f" % [ten0, g.tension(0)])
	# (a second one, cancelled: its Tension comes back)
	why = g.train(heavy, P)
	var ten1 := g.tension(0)
	g.cancel_train(heavy)
	check("a cancelled Pendulum pays its Tension back", why == "" and heavy.queue == [P] and is_equal_approx(g.tension(0), ten1 + float(Defs.UNITS[P]["tension"])), why)
	# Tension short: refused, with a reason
	var keep := g.tension(0)
	g.players[0]["tension"] = 20.0
	why = g.can_train(heavy, P)
	check("short of Tension, the Pendulum is refused", why.contains("Tension"), why)
	why = g.can_train(works, N)
	check("short of Tension, the Netter is refused", why.contains("Tension"), why)
	g.players[0]["tension"] = keep
	cogs0 = int(g.players[0]["gold"])
	ten0 = g.tension(0)
	why = g.train(works, N)
	check("the Light Works takes a Netter order", why == "", why)
	check("the Netter's cogs and Tension were spent", int(g.players[0]["gold"]) == cogs0 - int(Defs.UNITS[N]["cost"]) \
			and is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[N]["tension"])))
	U.step(g, float(Defs.UNITS[P]["time"]) + float(Defs.UNITS[N]["time"]) + 2.0)
	var made_p := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == P and not u.dead)
	var made_n := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == N and not u.dead)
	check("a Pendulum came out", made_p.size() == 1, "%d" % made_p.size())
	check("a Netter came out", made_n.size() == 1, "%d" % made_n.size())
	_clear(g, made_p + made_n)
	# ---- the PENDULUM's swing: every enemy in the arc in front, not behind, not beside, not its own side
	var at := _open_near(g, hall.center() + Vector2(0, 260))
	var pd: Unit = g._add_unit(P, 0, at)
	pd.cmd_stop()
	g.camera.position = at
	var dmg := float(Defs.UNITS[P]["damage"])
	var polar := func(deg: float, dist: float) -> Vector2: return at + Vector2.from_angle(deg_to_rad(deg)) * dist
	var front: Unit = _foe(g, "labourer", polar.call(0.0, 42.0))
	var front2: Unit = _foe(g, "labourer", polar.call(-35.0, 44.0))
	var front3: Unit = _foe(g, "labourer", polar.call(35.0, 44.0))
	var behind: Unit = _foe(g, "labourer", polar.call(180.0, 42.0))
	var beside: Unit = _foe(g, "labourer", polar.call(95.0, 44.0))         # (out of the arc: 60 degrees either side)
	var friend: Unit = g._add_unit("clock_soldier", 0, polar.call(52.0, 62.0))      # (in the arc, of its own side)
	friend.cmd_hold()
	for o in [front, front2, front3, behind, beside]:
		(o as Unit).max_hp = 500.0
		(o as Unit).hp = 500.0
		(o as Unit).d = (o as Unit).d.duplicate()
		(o as Unit).d["damage"] = 0           # (they stand there: no blows back, so only the swing moves the numbers)
	var fhp: float = friend.hp
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(front)
	var t := 0.0
	var saw_attack := false
	var blow_frame := -1
	while pd.swings == 0 and t < 6.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if String(pd.anim).begins_with("attack"):
			saw_attack = true
		if pd.swings > 0:
			blow_frame = pd.frame_i
	check("the Pendulum swung (it plays its arm's strip)", pd.swings == 1 and saw_attack, "%.2f s" % t)
	check("the blow lands on the 4th frame of its arm's strip (the low sweep through the front)", blow_frame == 3, "frame %d" % blow_frame)
	var hit := func(o: Unit) -> bool: return o.hp <= 500.0 - (dmg - o.armor) + 0.5
	check("the swing hit the enemy it swung at", hit.call(front), "%.0f" % front.hp)
	check("and two more enemies in the arc in front", hit.call(front2) and hit.call(front3), "%.0f %.0f" % [front2.hp, front3.hp])
	check("it caught at least three", pd.last_hits >= 3, "%d" % pd.last_hits)
	check("not the enemy behind it", behind.hp >= 500.0, "%.0f" % behind.hp)
	check("not the enemy beside it, out of the arc", beside.hp >= 500.0, "%.0f" % beside.hp)
	check("never its own side in the arc", friend.hp >= fhp, "%.0f" % friend.hp)
	check("it cannot reach flyers", not pd.can_hit(_foe(g, "balloon", at + Vector2(30, -40))))
	_clear(g, [pd, front, front2, front3, behind, beside, friend])
	_clear_team(g, 1)
	# ---- the NETTER: a net stops ONE enemy moving and fighting for its time
	var target: Unit = g._add_unit("clock_soldier", 0, _open_near(g, at + Vector2(-120, 0)))
	target.cmd_hold()
	target.max_hp = 5000.0
	target.hp = 5000.0
	var jk: Unit = g._add_unit(Defs.SPRINGER, 1, _open_near(g, at + Vector2(150, 0)))
	jk.max_hp = 5000.0
	jk.hp = 5000.0
	jk.cmd_attack(target)
	step(g, 3.0)
	check("the enemy Springer is shooting before the net", jk.shots > 0, "%d screws" % jk.shots)
	# it walks off; a Netter comes and nets it
	var nt: Unit = g._add_unit(N, 0, _open_near(g, jk.position + Vector2(-150, 30)))
	jk.cmd_move(jk.position + Vector2(300, 0))
	nt.cmd_attack(jk)
	t = 0.0
	var fired_at := -1.0
	while jk.nets_taken == 0 and t < 6.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if nt.nets == 1 and fired_at < 0.0:
			fired_at = g.clock
	check("the Netter fired a net and it caught the Springer", nt.nets == 1 and jk.nets_taken == 1 and jk.net_t > 0.0, "%.2f s, net_t %.2f" % [t, jk.net_t])
	check("the net flew a while before it caught (visible in flight)", fired_at > 0.0 and g.clock - fired_at >= 0.1, "%.2f s" % (g.clock - fired_at))
	var p0 := jk.position
	jk.cmd_move(jk.position + Vector2(300, 0))          # (told to go on: it cannot)
	var s0 := jk.shots
	jk.cmd_attack(target)                               # (told to shoot: it cannot either)
	step(g, float(Defs.NET["time"]) - 0.6)
	check("the Netter is on its long reload meanwhile", nt.cooldown > float(Defs.UNITS[N]["cooldown"]) - float(Defs.NET["time"]), "%.1f s" % nt.cooldown)
	check("caught, it does not move", jk.position.distance_to(p0) < 2.0, "%.1f px" % jk.position.distance_to(p0))
	check("caught, it does not fire", jk.shots == s0, "%d -> %d" % [s0, jk.shots])
	check("the net still holds it near the end of its time", jk.net_t > 0.0, "%.2f" % jk.net_t)
	step(g, 1.0)
	check("then the net is gone", jk.net_t <= 0.0)
	step(g, 4.0)
	check("free again, it fires again", jk.shots > s0, "%d -> %d" % [s0, jk.shots])
	jk.cmd_move(jk.position + Vector2(60, 0))
	var p1 := jk.position
	step(g, 1.0)
	check("free again, it moves again", jk.position.distance_to(p1) > 20.0, "%.1f px" % jk.position.distance_to(p1))
	# ---- the long reload: the second net only a whole cycle after the first
	nt.cmd_attack(jk)
	var nets0 := nt.nets
	var waited := 0.0
	while nt.nets == nets0 and waited < 20.0:
		step(g, 1.0 / 30.0)
		waited += 1.0 / 30.0
	var cycle := float(Defs.UNITS[N]["aim"]) + float(Defs.NET["strike"]) + float(Defs.UNITS[N]["cooldown"])
	check("its second net comes only after the long reload", nt.nets == nets0 + 1 and g.clock - fired_at >= cycle - 0.2,
			"%.1f s between the nets (a cycle: %.1f s)" % [g.clock - fired_at, cycle])
	_clear(g, [jk, target])
	# ---- a FLYER caught comes down to the ground for the net's time
	var fly: Unit = g._add_unit(Defs.CUCKOO, 1, _open_near(g, at + Vector2(110, -20)))
	fly.max_hp = 5000.0
	fly.hp = 5000.0
	fly.cmd_hold()
	var foot: Unit = g._add_unit("clock_soldier", 0, _open_near(g, at + Vector2(80, 30)))
	foot.cmd_hold()
	g.camera.position = fly.position
	check("a flyer: a ground melee unit cannot hit it in the air", fly.is_air() and not foot.can_hit(fly))
	nt.phase = ""             # (its last net's follow-through done too: a new order no longer skips the reload, 0.14.73)
	nt.cooldown = 0.0
	nt.cmd_attack(fly)
	t = 0.0
	while fly.nets_taken == 0 and t < 6.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		g.camera.position = fly.position
	check("the net caught the flyer", fly.nets_taken == 1 and fly.net_t > 0.0)
	check("netted, the flyer is on the ground (not in the air)", not fly.is_air())
	check("a ground-only melee unit can hit it now", foot.can_hit(fly))
	check("a flyer hunter (air only) cannot", not g._add_unit(Defs.CUCKOO, 0, at + Vector2(0, -60)).can_hit(fly))
	step(g, 1.0)
	g.camera.position = fly.position
	step(g, 0.1)
	check("its sprite came down to the ground", fly.sprite.position.y > -6.0 and fly._low > 0.9, "sprite y %.1f, low %.2f" % [fly.sprite.position.y, fly._low])
	step(g, float(Defs.NET["time"]))
	g.camera.position = fly.position
	step(g, 1.0)
	check("then it flies again", fly.is_air() and not foot.can_hit(fly) and fly.sprite.position.y < -12.0, "sprite y %.1f" % fly.sprite.position.y)
	_clear_team(g, 1)
	_clear(g, [foot])
	for u in g.units.duplicate():
		if u.team == 0 and u.kind == Defs.CUCKOO:
			_clear(g, [u])
	# ---- by itself: the most dangerous enemy in reach, not one caught already
	nt.cmd_stop()
	nt.cooldown = 0.0
	var cheap: Unit = _foe(g, "labourer", _open_near(g, nt.position + Vector2(70, 10)))
	var big: Unit = _foe(g, "brute", _open_near(g, nt.position + Vector2(150, -20)))
	for o in [cheap, big]:
		(o as Unit).d = (o as Unit).d.duplicate()
		(o as Unit).d["damage"] = 0
	step(g, 0.1)            # (the units the test took off leave the game's spatial hash)
	var pick := Netter.pick(nt, nt._scan_range())
	check("by itself it picks the most dangerous enemy (the Brute, not the nearer Labourer)", pick == big, str(pick.kind if pick else "none"))
	big.net_t = 3.0
	pick = Netter.pick(nt, nt._scan_range())
	check("one already caught is passed over", pick == cheap, str(pick.kind if pick else "none"))
	check("it never targets a building", not nt.can_hit(hall))
	_clear_team(g, 1)
	# ---- the sandbox's CLOCK tab and the Lab
	for k in [P, N]:
		check("the sandbox lists the %s" % Defs.UNITS[k]["name"], Defs.UNITS[k]["faction"] == "clockwork" and not Defs.energy_only(k))
		check("the %s has its card icon" % Defs.UNITS[k]["name"], ResourceLoader.exists("res://assets/icons/%s.png" % k))
	var g2 := U.make(root, ["clockwork", "crown"], "greenhold")
	await process_frame
	await process_frame
	CwLab.setup(g2)
	g2.gear_net.solve()
	g2._recount_supply(g2.human)
	var big_works: Building = null
	for b in g2.buildings:
		if b.team == g2.human and not b.dead and b.kind == Defs.CW_HEAVY:
			big_works = b
	check("the Lab has a Heavy Works, linked", big_works != null and big_works.built and g2.gear_net.is_linked(big_works))
	var regs: int = g2.buildings.filter(func(b: Building) -> bool: return b.team == g2.human and b.kind == Defs.CW_SUPPLY and b.built and not b.dead).size()
	check("in the Lab a Pendulum can be trained at once", big_works != null and g2.can_train(big_works, P) == "",
			"%s (supply %d / %d, %d Regulators)" % [g2.can_train(big_works, P) if big_works else "no Heavy Works", g2.supply_used(g2.human), int(g2.players[g2.human]["cap"]), regs])
	var lab_p := g2.units.filter(func(u: Unit) -> bool: return u.team == g2.human and u.kind == P and not u.dead)
	var lab_n := g2.units.filter(func(u: Unit) -> bool: return u.team == g2.human and u.kind == N and not u.dead)
	check("the Lab has two Pendulums", lab_p.size() == 2, "%d" % lab_p.size())
	check("the Lab has two Netters", lab_n.size() == 2, "%d" % lab_n.size())
	check("the Lab hint names the Pendulum and the Netter", CwLab.hint_text().contains("PENDULUM") and CwLab.hint_text().contains("NETTER"))
	# (the two games off first: the online pair is on another map, and Game.W/H are shared by every game)
	for gg in [g, g2]:
		gg.process_mode = Node.PROCESS_MODE_DISABLED
		gg.queue_free()
	await process_frame
	await process_frame
	await _online()
	_end()


## ONLINE (no relay: the host's snapshots go through the codec straight into a guest game): the guest sees a Ticking Owl's
## bomb FALL and burst where it lands (a picture: the damage is the host's), a Swift's MORPH progress, and a Netter's net
## fly at its target and the catch.
func _online() -> void:
	var h := U.make(root, ["clockwork", "crown"])
	var gu := Game.new()
	gu.map_id = h.map_id
	gu.demo = true
	gu.factions = ["clockwork", "crown"]
	gu.sides = [0, 1]
	gu.puppet = true
	root.add_child(gu)
	await process_frame
	await process_frame
	var sh := NetSession.attach(h, NetLink.new(), true, 0, {1: 1})
	var sg := NetSession.attach(gu, NetLink.new(), false, 1, {})
	sh.set_process(false)
	var sync := func() -> void:
		sh.snap_n = 1      # (a keyframe, every unit's row: since 0.14.44 rows fogged for the guest wait for one, and this checks the values, not the culling)
		var m := NetSnapshot.build(sh)
		NetSnapshot.apply(sg, NetCodec.unpack(NetCodec.pack(m)))
	var hall := U.hall(h, 0)
	var foe_hall := U.hall(h, 1)
	var at := foe_hall.center() + Vector2(0, -float(foe_hall.size.y) * Defs.TILE * 0.5 - 30.0)
	var owl: Unit = h._add_unit(Defs.OWL, 0, at)
	var sw: Unit = h._add_unit(Defs.CUCKOO, 0, hall.center() + Vector2(120, -60))
	sync.call()
	gu.view_rect = Rect2(at - Vector2(900, 700), Vector2(1800, 1400))
	# the bomb
	var bomb := CwAir.drop_bomb(owl, foe_hall)
	sync.call()
	var gb: OwlBomb = null
	for c in gu.get_children():
		if c is OwlBomb:
			gb = c
	check("online: the guest gets the Owl's bomb, falling (a picture)", gb != null and gb.view and gb.from.distance_to(bomb.from) < 1.0 and gb.to.distance_to(bomb.to) < 1.0)
	var hp0: float = 0.0
	var gfoe: Building = null
	for b in gu.buildings:
		if b.kind == foe_hall.kind and b.team == 1:
			gfoe = b
	hp0 = gfoe.hp if gfoe else 0.0
	var fell := false
	var bursts := 0
	for i in 40:
		if gb != null and is_instance_valid(gb) and not gb.is_queued_for_deletion():
			var y0 := gb.position.y
			gb._physics_process(1.0 / 30.0)
			if gb.position.y > y0 + 0.1:
				fell = true
	for c in gu.get_children():
		if c is Effect and c.position.distance_to(bomb.to) < 2.0:
			bursts += 1
	check("online: on the guest it falls and bursts where it lands", fell and bursts >= 1, "fell %s, bursts %d" % [str(fell), bursts])
	check("online: the guest's bomb does no damage of its own", gfoe != null and gfoe.hp >= hp0)
	# the morph's progress
	CwAir.start_morph(sw)
	sw.owl_t = 7.5
	sync.call()
	var gsw: Unit = null
	for u in gu.units:
		if u.net_id == sw.net_id:
			gsw = u
	check("online: the guest sees the Swift's morph under way (its bar)", gsw != null and absf(gsw.owl_t - 7.5) < 0.05 and CwAir.morph_frac(gsw) > 0.3,
			"owl_t %.2f" % (gsw.owl_t if gsw else -9.0))
	# the Netter's net
	var nt: Unit = h._add_unit(Defs.NETTER, 0, hall.center() + Vector2(0, 200))
	var prey: Unit = h._add_unit("musketeer", 1, hall.center() + Vector2(150, 200))
	sync.call()
	gu.view_rect = Rect2(nt.position - Vector2(900, 700), Vector2(1800, 1400))
	var cn := Netter.fire(nt, prey)
	sync.call()
	var gcn: ChainNet = null
	for c in gu.get_children():
		if c is ChainNet:
			gcn = c
	check("online: the guest sees the net fly (a picture)", gcn != null and gcn.view and gcn.target != null and gcn.target.net_id == prey.net_id)
	for i in 30:
		if is_instance_valid(cn) and not cn.is_queued_for_deletion():
			cn._physics_process(1.0 / 30.0)
		if gcn != null and is_instance_valid(gcn) and not gcn.is_queued_for_deletion():
			gcn._physics_process(1.0 / 30.0)
	sync.call()
	var gprey: Unit = gcn.target if gcn != null else null
	check("online: the catch shows on the guest (its copy is caught)", prey.net_t > 0.0 and gprey != null and gprey.net_t > 0.0 and gprey.nets_taken == 0,
			"host %.2f, guest %.2f" % [prey.net_t, gprey.net_t if gprey else -1.0])
	sg.queue_free()
	sh.queue_free()


## A finished Mainspring whose ring meshes with b's (directly or through an idler), linked; null if none fits.
func _spring_beside(g: Game, b: Building) -> Building:
	for deg in [0.0, 90.0, 180.0, -90.0, 45.0, 135.0, -45.0, -135.0]:
		var c := GearNet.ring_spot(g, 0, "mainspring", b, deg)
		if c.x >= 0:
			var m := g._add_building("mainspring", 0, c, true)
			g.gear_net.solve()
			return m
	return null


## An enemy (team 1) standing still at p.
func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _clear(g: Game, list: Array) -> void:
	for u in list:
		if is_instance_valid(u):
			g.units.erase(u)
			g.selection.erase(u)
			u.queue_free()


## Team t's soldiers off the map (not its workers: a Farm's crew list keeps them).
func _clear_team(g: Game, t: int) -> void:
	_clear(g, g.units.filter(func(u: Unit) -> bool: return u.team == t and not u.is_worker()))


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
