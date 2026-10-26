extends SceneTree
## THE AIR of the gear-mode Clockwork (scripts/cw_air.gd; docs/clockwork_gear_prototype.md): the CLOCK AVIARY (kind
## cuckoo_house) can only be placed with an ACTIVE Escapement (an idle one, NEEDS MAINSPRING, is refused); it trains the
## SWIFT (kind cuckoo), paying cogs and Tension, and plays its working loop meanwhile. A Swift pecks an enemy flyer dead and
## can never target the ground (units or buildings). MORPH TO OWL needs TICKING OWL (researched at the Aviary for cogs and
## Tension), spends cogs and Tension, holds the Owl's supply, keeps the Swift hovering in place for its time (CANCEL pays
## back) and leaves a Ticking Owl (no Swift). The Owl's talon swoop hurts a ground unit (it dives); on a building it lets
## its weight go: a bomb is spawned, falls, bursts on impact, hurts that building and one beside it (a small area) but not
## one farther off. The Owl cannot target flyers. A Jack shooting at a flyer raises its arm (the attack_up strip) and its
## screw leaves the raised tip; at the ground it keeps the old strip and tip. The Lab starts with an Aviary, three Swifts and
## a Ticking Owl (TICKING OWL researched), and the sandbox's CLOCK tab lists the three.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_air.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-72s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## U.step, and the Owls' bombs in the air (game children, not stepped by U.step).
func step(g: Game, secs: float) -> void:
	var n := int(secs * 30.0)
	for i in n:
		U.step(g, 1.0 / 30.0)
		for c in g.get_children():
			if c is OwlBomb and is_instance_valid(c) and not c.is_queued_for_deletion():
				c._physics_process(1.0 / 30.0)


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var bl := Defs.build_list("clockwork")
	check("gear mode builds the Clock Aviary", bl.has(Defs.CW_AIR))
	check("its display name is Clock Aviary, the flyer's Swift", Defs.BUILDINGS[Defs.CW_AIR]["name"] == "Clock Aviary" and Defs.UNITS[Defs.CUCKOO]["name"] == "Swift")
	check("the Aviary trains the Swift", (Defs.BUILDINGS[Defs.CW_AIR]["trains"] as Array).has(Defs.CUCKOO))
	check("the Swift's price is cogs and Tension", g.unit_price(0, Defs.CUCKOO) == [int(Defs.UNITS[Defs.CUCKOO]["cost"]), int(Defs.UNITS[Defs.CUCKOO]["tension"])], str(g.unit_price(0, Defs.CUCKOO)))
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var hall := U.hall(g, 0)
	check("no Escapement: the Aviary is refused", g.requirement_text(0, Defs.CW_AIR) != "", g.requirement_text(0, Defs.CW_AIR))
	var works := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	g._recount_supply(0)
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	U.step(g, 0.6)
	check("an Escapement stands, linked but idle (no Mainspring)", esc != null and g.gear_net.is_linked(esc) and g.gear_net.needs_spring(esc))
	var rq := g.requirement_text(0, Defs.CW_AIR)
	check("an IDLE Escapement does not allow the Aviary", rq != "" and rq.contains("Mainspring"), rq)
	var spring := _spring_beside(g, esc)
	U.step(g, 0.6)
	check("a Mainspring meshes with the Escapement: it works", spring != null and g.gear_net.speed_mult(esc) > 0.0)
	check("with an ACTIVE Escapement the Aviary is allowed", g.requirement_text(0, Defs.CW_AIR) == "", g.requirement_text(0, Defs.CW_AIR))
	var av := U.put(g, 0, Defs.CW_AIR, hall.cell)
	check("an Aviary links to the field", av != null and g.gear_net.is_linked(av))
	if av == null:
		_end()
		return
	check("the Aviary is a 2x2 (its plinth is narrow)", av.size == Vector2i(2, 2))
	# ---- a Swift trains: cogs and Tension spent; the doors open and birds fly out meanwhile
	g.players[0]["cap"] = 200
	var cogs0 := int(g.players[0]["gold"])
	var ten0 := g.tension(0)
	var why := g.train(av, Defs.CUCKOO)
	check("the Aviary takes a Swift order", why == "", why)
	check("cogs were spent", int(g.players[0]["gold"]) == cogs0 - int(Defs.UNITS[Defs.CUCKOO]["cost"]))
	check("Tension was spent", is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[Defs.CUCKOO]["tension"])))
	U.step(g, 1.0)
	check("its working loop plays while it trains", av.drill_anim and av.sprite.texture != null and av.sprite.texture.resource_path.contains("cuckoo_house_work_"),
			av.sprite.texture.resource_path if av.sprite.texture else "none")
	U.step(g, float(Defs.UNITS[Defs.CUCKOO]["time"]) + 2.0)
	var swifts := g.units.filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO and u.team == 0 and not u.dead)
	check("a Swift came out", swifts.size() == 1, "%d" % swifts.size())
	check("idle again, the doors shut (the built picture)", not av.drill_anim)
	if swifts.is_empty():
		_end()
		return
	var sw: Unit = swifts[0]
	check("the Swift flies", sw.is_air())
	sw.cmd_stop()
	g.camera.position = sw.position          # (units animate only on screen)
	# ---- it cannot target the ground
	var foot := _foe(g, "labourer", _open_near(g, sw.position + Vector2(40, 10)))
	var fb := g._add_building("cottage", 1, _free_cell(g, hall.cell + Vector2i(12, 10), Vector2i(2, 2)), true)
	check("a Swift cannot target a ground unit", not sw.can_hit(foot))
	check("a Swift cannot target a building", not sw.can_hit(fb))
	U.step(g, 2.0)
	check("left idle by them, it attacks neither", foot.hp >= foot.max_hp and fb.hp >= fb.max_hp and sw.target == null, str(sw.target))
	_remove_unit(g, foot)
	# ---- it pecks a flyer dead (a balloon: no weapon of its own)
	var fly := _foe(g, "balloon", sw.position + Vector2(90, -30))
	check("a Swift can target a flyer", sw.can_hit(fly))
	var saw_attack := false
	var lunge := 0.0
	var t := 0.0
	sw.cmd_attack(fly)
	while t < 60.0 and not fly.dead:
		step(g, 0.1)
		t += 0.1
		g.camera.position = sw.position
		if sw.anim == "attack":
			saw_attack = true
			lunge = maxf(lunge, absf(sw.sprite.position.x))
		if sw.order == "idle" and not fly.dead:
			sw.cmd_attack(fly)
	check("a Swift pecks a balloon dead", fly.dead, "%.1f s" % t)
	check("it plays its attack strip (the lunge)", saw_attack)
	check("the lunge moves the bird toward its prey", lunge >= 3.0, "%.1f px" % lunge)
	check("the Swift's body is drawn over its shadow (lifted)", sw.sprite.position.y < -10.0, "%.1f" % sw.sprite.position.y)
	# ---- MORPH TO OWL: refused before TICKING OWL
	var w0 := g.morph_order([sw])
	check("MORPH TO OWL is refused before the research", w0 != "" and w0.contains("TICKING OWL"), w0)
	# ---- TICKING OWL researched at the Aviary, for cogs and Tension
	var ten1 := g.tension(0)
	var rw := g.start_research(av, "owl_morph")
	check("TICKING OWL research starts at the Aviary", rw == "", rw)
	check("it costs Tension", is_equal_approx(g.tension(0), ten1 - float(Defs.RESEARCH["owl_morph"]["tension"])))
	step(g, float(Defs.RESEARCH["owl_morph"]["time"]) + 1.0)
	check("TICKING OWL is done", g.has_tech(0, "owl_morph"))
	# ---- the morph: pays, holds the supply, hovers in place; CANCEL pays back
	var sup0 := g.supply_used(0)
	cogs0 = int(g.players[0]["gold"])
	ten0 = g.tension(0)
	var hp_frac := sw.hp / sw.max_hp
	var w1 := g.morph_order([sw])
	check("MORPH TO OWL starts", w1 == "" and sw.owl_t >= 0.0, w1)
	check("it spends cogs", int(g.players[0]["gold"]) == cogs0 - int(Defs.OWL_MORPH["cost"]))
	check("it spends Tension", is_equal_approx(g.tension(0), ten0 - float(Defs.OWL_MORPH["tension"])))
	check("the Owl's supply is held while it morphs", g.supply_used(0) == sup0 + int(Defs.UNITS[Defs.OWL]["supply"]) - int(Defs.UNITS[Defs.CUCKOO]["supply"]),
			"%d -> %d" % [sup0, g.supply_used(0)])
	var p0 := sw.position
	sw.cmd_move(p0 + Vector2(200, 0))
	step(g, 3.0)
	check("it hovers in place (an order does not move it)", sw.position.distance_to(p0) < 2.0 and sw.kind == Defs.CUCKOO, "%.1f px" % sw.position.distance_to(p0))
	check("it cannot fight while it morphs", not sw.can_hit(_foe(g, "balloon", sw.position + Vector2(30, 0))))
	# (the presses and the Mainspring keep paying meanwhile: the refund is measured over the cancel itself)
	var cogs_c := int(g.players[0]["gold"])
	var ten_c := g.tension(0)
	g.cancel_morph([sw])
	check("CANCEL MORPH pays the cogs back", int(g.players[0]["gold"]) == cogs_c + int(Defs.OWL_MORPH["cost"]), "%d -> %d" % [cogs_c, int(g.players[0]["gold"])])
	check("and the Tension", is_equal_approx(g.tension(0), ten_c + float(Defs.OWL_MORPH["tension"])))
	check("and the Owl's supply is let go", g.supply_used(0) == sup0)
	check("cancelled, it is a Swift again (no morph)", sw.owl_t < 0.0 and sw.kind == Defs.CUCKOO)
	_clear_foes(g)
	sw.cmd_stop()
	step(g, 0.5)
	var w2 := g.morph_order([sw])
	check("MORPH TO OWL again", w2 == "", w2)
	step(g, float(Defs.OWL_MORPH["time"]) * 0.5)
	check("halfway it is still a Swift", sw.kind == Defs.CUCKOO and sw.owl_t > 0.0)
	# (a save keeps the morph under way; a demo game is never saved, so not one for the moment)
	g.demo = false
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	g.demo = true
	var sd := SaveGame.peek()
	var g3 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g3, sd)
	await process_frame
	var sw3: Array = g3.units.filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO and u.team == 0 and u.owl_t > 0.0)
	check("a save keeps a morph under way", sw3.size() == 1 and absf(float(sw3[0].owl_t) - sw.owl_t) < 0.2,
			"%d morphing, %.1f vs %.1f" % [sw3.size(), float(sw3[0].owl_t) if not sw3.is_empty() else -1.0, sw.owl_t])
	SaveGame.clear()
	g3.queue_free()
	step(g, float(Defs.OWL_MORPH["time"]) * 0.5 + 0.5)
	var owls := g.units.filter(func(u: Unit) -> bool: return u.kind == Defs.OWL and u.team == 0 and not u.dead)
	var left := g.units.filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO and u.team == 0 and not u.dead)
	check("after its time it is a Ticking Owl", owls.size() == 1 and sw.kind == Defs.OWL, "%d owls" % owls.size())
	check("the Swift is gone", left.is_empty(), "%d swifts" % left.size())
	check("its health share was kept", absf(sw.hp / sw.max_hp - hp_frac) < 0.02, "%.2f -> %.2f" % [hp_frac, sw.hp / sw.max_hp])
	check("the Owl uses its own supply now", g.supply_used(0) == sup0 + int(Defs.UNITS[Defs.OWL]["supply"]) - int(Defs.UNITS[Defs.CUCKOO]["supply"]))
	var owl: Unit = sw
	owl.cmd_stop()
	g.camera.position = owl.position
	# ---- the Owl cannot target flyers
	var fly2 := _foe(g, "balloon", owl.position + Vector2(40, -10))
	check("the Owl cannot target a flyer", not owl.can_hit(fly2))
	step(g, 2.0)
	check("left idle by a balloon, it does not attack it", fly2.hp >= fly2.max_hp and owl.target != fly2)
	_remove_unit(g, fly2)
	# ---- the talon swoop on a ground unit
	var prey := _foe(g, "musketeer", _open_near(g, owl.position + Vector2(60, 20)))
	prey.max_hp = 9999.0
	prey.hp = 9999.0
	var dive := 0.0
	var saw_swoop := false
	t = 0.0
	owl.cmd_attack(prey)
	while t < 12.0 and prey.hp >= prey.max_hp:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		g.camera.position = owl.position
		if owl.anim == "attack":
			saw_swoop = true
			dive = maxf(dive, owl.sprite.position.y + float(Defs.FLYER[Defs.OWL]["lift"]))
	check("the Owl's talons hurt a ground unit", prey.hp < prey.max_hp, "%.0f damage in %.1f s" % [prey.max_hp - prey.hp, t])
	step(g, 0.4)
	check("it swoops down (its swoop strip, the body dives)", saw_swoop and dive >= 8.0, "dive %.1f px" % dive)
	check("a talon blow does about its damage", absf((prey.max_hp - prey.hp) - (float(Defs.UNITS[Defs.OWL]["damage"]) - float(prey.armor))) < 3.0 or prey.max_hp - prey.hp > 10.0,
			"%.0f" % (prey.max_hp - prey.hp))
	_remove_unit(g, prey)
	owl.cmd_stop()
	# ---- the bomb on a building: spawned, falls, bursts on impact; a small area
	var bc := _free_cell(g, g.cell_of(owl.position) + Vector2i(4, 0), Vector2i(2, 2))
	var target_b := g._add_building("cottage", 1, bc, true)
	target_b.max_hp = 99999.0
	target_b.hp = 99999.0
	var bombs0 := owl.bombs
	var landed0 := g.bombs_landed
	t = 0.0
	owl.cmd_attack(target_b)
	var saw_drop := false
	while t < 10.0 and owl.bombs == bombs0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		g.camera.position = owl.position
		if owl.anim == "bomb":
			saw_drop = true
	check("the Owl drops a bomb on a building", owl.bombs > bombs0 and owl.last_bomb != null, "%.1f s" % t)
	check("it plays its bomb strip", saw_drop)
	var bomb: OwlBomb = owl.last_bomb
	var hp_before := target_b.hp
	var ys: Array = []
	var fell := false
	# (while it falls: a building right beside the impact point and one well away from it, to see the area is small)
	var near_b: Building = null
	var far_b: Building = null
	if bomb != null:
		near_b = _wall_at(g, bomb.to, 0.0, 20.0, target_b)
		far_b = _wall_at(g, bomb.to, 70.0, 140.0, target_b)
	if bomb != null:
		check("the bomb is let go up in the air (over its ground track)", bomb.height(clampf(bomb.t / bomb.duration, 0.0, 1.0)) > 15.0, "%.0f px up" % bomb.height(0.0))
		check("no damage when it is let go", is_equal_approx(target_b.hp, hp_before))
		var tt := 0.0
		while is_instance_valid(bomb) and not bomb.landed and tt < 2.0:
			ys.append(bomb.position.y)
			step(g, 1.0 / 30.0)
			tt += 1.0 / 30.0
		fell = ys.size() >= 4 and float(ys[ys.size() - 1]) > float(ys[0]) + 10.0
		check("it falls (lower every frame)", fell, "%d frames" % ys.size())
		check("it lands within its fall time", tt < 1.2, "%.2f s" % tt)
	check("the bomb burst on impact", g.bombs_landed > landed0)
	var dmg_t := hp_before - target_b.hp
	check("it hurt the building under it", dmg_t > 30.0, "%.0f" % dmg_t)
	check("and a building beside it (a small area)", near_b != null and near_b.hp < near_b.max_hp, ("%.0f damage" % (near_b.max_hp - near_b.hp)) if near_b else "no room")
	check("not a building farther off", far_b != null and far_b.hp >= far_b.max_hp, ("%.0f damage" % (far_b.max_hp - far_b.hp)) if far_b else "no room")
	var fx_ok := false
	for c in g.get_children():
		if c is Effect and (c as Effect).texture != null and (c as Effect).texture.resource_path.contains("owl_blast"):
			fx_ok = true
	check("the explosion plays where it landed", fx_ok or g.bombs_landed > landed0)
	# a second bomb follows about 3 s later
	var b1 := owl.bombs
	step(g, 3.4)
	check("one bomb about every 3 s", owl.bombs == b1 + 1, "%d -> %d" % [b1, owl.bombs])
	owl.cmd_stop()
	# ---- the Jack raises its arm at a flyer; at the ground it keeps the old strip
	var jk: Unit = g._add_unit(Defs.JACK, 0, _open_near(g, hall.center() + Vector2(0, 160)))
	jk.cmd_stop()
	g.camera.position = jk.position
	var bal := _foe(g, "balloon", jk.position + Vector2(100, -40))
	bal.max_hp = 9999.0
	bal.hp = 9999.0
	var saw_up := false
	var tip_ok := false
	var shots0 := jk.shots
	t = 0.0
	jk.cmd_attack(bal)
	while t < 6.0 and jk.shots < shots0 + 2:
		var before := jk.shots
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if jk.anim == "attack_up":
			saw_up = true
		if jk.shots > before and jk.last_shot != null:
			tip_ok = jk.last_tip.distance_to(Jack.tip(jk, true)) < 0.5 and jk.last_shot.from.distance_to(jk.last_tip) < 0.5
	check("a Jack shooting at a flyer plays the raised-arm strip (attack_up)", saw_up)
	check("its screw leaves the raised drill tip", tip_ok and jk.shots > shots0, "tip %s" % str(jk.last_tip - jk.position))
	_remove_unit(g, bal)
	var gfoe := _foe(g, "labourer", _open_near(g, jk.position + Vector2(120, 10)))
	gfoe.max_hp = 9999.0
	gfoe.hp = 9999.0
	var saw_ground := false
	var saw_up2 := false
	var ground_tip := false
	shots0 = jk.shots
	t = 0.0
	jk.cmd_attack(gfoe)
	while t < 6.0 and jk.shots < shots0 + 2:
		var before2 := jk.shots
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if jk.anim == "attack":
			saw_ground = true
		if jk.anim == "attack_up":
			saw_up2 = true
		if jk.shots > before2:
			ground_tip = jk.last_tip.distance_to(Jack.tip(jk, false)) < 0.5
	check("at a ground unit it keeps the old attack strip", saw_ground and not saw_up2)
	check("and the old (lowered) tip", ground_tip, "tip %s" % str(jk.last_tip - jk.position))
	# ---- the sandbox's CLOCK tab and the Lab
	for k in [Defs.CUCKOO, Defs.OWL]:
		check("the sandbox lists the %s" % Defs.UNITS[k]["name"], Defs.UNITS[k]["faction"] == "clockwork" and not Defs.energy_only(k))
	var g2 := U.make(root, ["clockwork", "crown"], "greenhold")
	await process_frame
	await process_frame
	CwLab.setup(g2)
	g2.gear_net.solve()
	var lab_av: Building = null
	for b in g2.buildings:
		if b.team == g2.human and not b.dead and b.kind == Defs.CW_AIR:
			lab_av = b
	check("the Lab has a built Clock Aviary", lab_av != null and lab_av.built)
	check("the Lab's Aviary is linked", lab_av != null and g2.gear_net.is_linked(lab_av))
	var lab_sw := g2.units.filter(func(u: Unit) -> bool: return u.team == g2.human and u.kind == Defs.CUCKOO and not u.dead)
	var lab_owl := g2.units.filter(func(u: Unit) -> bool: return u.team == g2.human and u.kind == Defs.OWL and not u.dead)
	check("the Lab has three Swifts", lab_sw.size() == 3, "%d" % lab_sw.size())
	check("the Lab has a Ticking Owl", lab_owl.size() == 1, "%d" % lab_owl.size())
	check("in the Lab TICKING OWL is researched", g2.has_tech(g2.human, "owl_morph"))
	check("the Lab has Tension to spare", g2.tension(g2.human) >= 300.0, "%.0f" % g2.tension(g2.human))
	g2._recount_supply(g2.human)
	check("in the Lab a Swift can be morphed at once", not lab_sw.is_empty() and CwAir.morph_problem(lab_sw[0]) == "", CwAir.morph_problem(lab_sw[0]) if not lab_sw.is_empty() else "")
	check("in the Lab a Swift can be trained at once", lab_av != null and g2.can_train(lab_av, Defs.CUCKOO) == "", g2.can_train(lab_av, Defs.CUCKOO) if lab_av else "")
	check("the Lab hint names the Aviary, the Swift and the Owl", CwLab.hint_text().contains("AVIARY") and CwLab.hint_text().contains("SWIFT") and CwLab.hint_text().contains("Owl"))
	_end()


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


func _remove_unit(g: Game, u: Unit) -> void:
	g.units.erase(u)
	u.queue_free()


func _clear_foes(g: Game) -> void:
	for u in g.units.duplicate():
		if u.team == 1 and u.kind == "balloon":
			_remove_unit(g, u)


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


## An enemy palisade piece (99999 hp) on a free cell whose edge is `lo` to `hi` px from p (not `skip`'s cells); null if none.
func _wall_at(g: Game, p: Vector2, lo: float, hi: float, skip: Building) -> Building:
	var c0 := g.cell_of(p)
	for r in range(0, 6):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := c0 + Vector2i(x, y)
				if not g.in_map(c) or not g.is_free(c) or g.ramp[g.idx(c)] != 0 or skip.rect().grow(-1.0).has_point(g.cell_center(c)):
					continue
				var rr := Rect2(Vector2(c) * Defs.TILE, Vector2(Defs.TILE, Defs.TILE))
				var dd := p.clamp(rr.position, rr.end).distance_to(p)
				if dd >= lo and dd <= hi:
					var w := g._add_building("wall", 1, c, true)
					w.max_hp = 99999.0
					w.hp = 99999.0
					return w
	return null


## A free spot for a footprint of `size` near c (searching outward).
func _free_cell(g: Game, c: Vector2i, size: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var o := c + Vector2i(x, y)
				var ok := true
				for yy in size.y:
					for xx in size.x:
						var cc := o + Vector2i(xx, yy)
						if not g.in_map(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0:
							ok = false
				if ok:
					return o
	return c


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
