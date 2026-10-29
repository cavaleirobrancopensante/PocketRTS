## The STUN MARK (scripts/stun_mark.gd): the stars over a stunned unit's head show for a REAL stun's time and go after it;
## internal holds and a netted unit show none; a save keeps a stun and its stars.
##   godot --headless --fixed-fps 30 --script res://tools/test_stun_mark.gd
extends SceneTree
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func make(facs: Array) -> Game:
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	return g


func step(g: Game, secs: float, hook := Callable()) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		if hook.is_valid():
			hook.call()
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		g.stun_layer._process(1.0 / 30.0)
		if i % 8 == 0:
			await process_frame


## How long the mark shows, by the game clock (from when it began), waiting up to `limit` s.
func mark_time(g: Game, u: Unit, limit := 6.0) -> float:
	var c0 := g.clock
	var began: float = g.stun_layer.marked.get(u, c0)
	while g.clock - c0 < limit and is_instance_valid(u) and u.stun_left() > 0.0 and g.stun_layer.marked.has(u):
		await step(g, 1.0 / 30.0)
	return g.clock - began


func tough(u: Unit) -> Unit:
	u.max_hp = 5000.0
	u.hp = 5000.0
	u.auto_work = false
	return u


func open_spot(g: Game, t: int) -> Vector2:
	var h: Building = null
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			h = b
	if h == null:
		# (a Brood side: no hall, its Brood Mother's footprint stands there)
		var q := BroodNew.queen(g, t)
		return q.position + Vector2(0, BroodRoot.rect_of(q).size.y * 0.5 + 140.0)
	return h.center() + Vector2(0, h.rect().size.y * 0.5 + 90.0)


func _run() -> void:
	var g := make(["crown", "brood"])
	await process_frame
	await process_frame
	var at := open_spot(g, 0)
	# ---- a Mist Toad's TONGUE on a Field Cannon: only STAGGERED (TONGUE "no_pull": the owner, 2026-10-29), stunned
	# TONGUE "stagger" s; a Musketeer (light) is pulled, stunned for the pull and after
	var toad := tough(g._add_unit("mist_toad", 1, at + Vector2(0, 150)))
	var gun := tough(g._add_unit("cannon", 0, at))
	var pull := float(Defs.TONGUE["stagger"])
	var gun_at := gun.position
	toad.charge = 200.0
	toad.cmd_tongue(gun)
	var waited := 0.0
	while gun.stun_left() <= 0.0 and waited < 8.0:
		await step(g, 1.0 / 30.0)
		waited += 1.0 / 30.0
	check("the tongue staggers the cannon (not pulled), stunned", gun.stun_left() > 0.0 and g.stun_layer.marked.has(gun) and gun.position.distance_to(gun_at) < 20.0, "%.1f s in, moved %.0f px" % [waited, gun.position.distance_to(gun_at)])
	var shown := await mark_time(g, gun)
	check("its stars show for the stagger, %.1f s" % pull, absf(shown - pull) < 0.12, "%.2f s" % shown)
	await step(g, 0.2)
	check("and go after it", not g.stun_layer.marked.has(gun) and gun.stun_left() == 0.0)
	gun.position = at + Vector2(-400, 0)
	var man := tough(g._add_unit("musketeer", 0, at))
	man.hold_fire = true
	toad.charge = 200.0
	toad.tongue_stage = ""
	toad.cmd_tongue(man)
	waited = 0.0
	while man.stun_left() <= 0.0 and waited < 8.0:
		await step(g, 1.0 / 30.0)
		waited += 1.0 / 30.0
	check("the tongue pulls the Musketeer, stunned", man.stun_left() > 0.0 and g.stun_layer.marked.has(man), "%.1f s in" % waited)
	shown = await mark_time(g, man)
	var mpull := float(Defs.TONGUE["pull"]) + float(Defs.TONGUE["after"])
	check("his stars show for the pull and after, %.1f s" % mpull, absf(shown - mpull) < 0.12, "%.2f s" % shown)
	toad.position = at + Vector2(400, 300)
	toad.cmd_stop()
	# ---- a Cavalry CHARGE knocks a Musketeer down
	g.players[0]["tech"]["charge"] = true
	var foe := tough(g._add_unit("musketeer", 1, at + Vector2(0, 40)))
	foe.hold_fire = true
	var cav := tough(g._add_unit("cuirassier", 0, at + Vector2(0, 20)))
	cav.target = foe
	cav.order = "attack"
	cav.order_target = foe
	var hook := func() -> void:
		if foe.stun_left() <= 0.0:
			cav.run_t = 10.0
			cav.rb_last = -99.0
	waited = 0.0
	while foe.stun_left() <= 0.0 and waited < 6.0:
		await step(g, 1.0 / 30.0, hook)
		waited += 1.0 / 30.0
	check("a charge knocks the Musketeer down, stunned", foe.stun_left() > 0.0 and g.stun_layer.marked.has(foe), "%.1f s in" % waited)
	cav.position = at + Vector2(-500, 300)
	cav.cmd_stop()
	cav.run_t = 0.0
	shown = await mark_time(g, foe)
	check("his stars show for the knock, %.1f s" % float(Defs.CHARGE["stun"]), absf(shown - float(Defs.CHARGE["stun"])) < 0.12, "%.2f s" % shown)
	# a heavy unit (3 supply or more) knocked by a charge: 0.24 s, too short for stars
	var heavy := tough(g._add_unit("brute", 1, at + Vector2(120, 0)))
	heavy.stun(float(Defs.CHARGE["stun"]) * 0.4)
	check("a heavy unit's short knock (%.2f s) shows no stars" % (float(Defs.CHARGE["stun"]) * 0.4), heavy.stun_t > 0.0 and heavy.stun_left() == 0.0 and not g.stun_layer.marked.has(heavy))
	# ---- internal holds: no stars
	var w := tough(g._add_unit("musketeer", 0, at + Vector2(-120, 0)))
	w.stun(0.25, false)
	check("an internal hold (0.25 s, no show) shows no stars", w.stun_t > 0.0 and w.stun_left() == 0.0 and not g.stun_layer.marked.has(w))
	w.stun(0.2)
	check("a stun under %.1f s shows no stars" % StunMark.MIN_SHOW, w.stun_left() == 0.0 and not g.stun_layer.marked.has(w))
	# ---- a Netter's net: the net shows, not stars
	Netter.catch(w, null, 0.0)
	await step(g, 0.1)
	check("a netted unit is held but shows no stars (its net shows)", w.stun_t > 1.0 and w.stun_left() == 0.0 and not g.stun_layer.marked.has(w))
	w.stun(1.0)
	check("a netted unit given a real stun still shows only its net", w.stun_left() == 0.0)
	# ---- saves keep a stun and its stars
	var sv := tough(g._add_unit("musketeer", 0, at + Vector2(-60, -60)))
	sv.stun(2.0)
	await step(g, 0.5)
	var before := sv.stun_left()
	g.demo = false              # (a demo game isn't saved)
	var d := SaveGame.capture(g, {"map": g.map_id, "seed": 4242})
	g.demo = true
	SaveGame.restore(g, d)
	await process_frame
	var back: Unit = null
	for u in g.units:
		if u.kind == "musketeer" and u.team == 0 and u.position.distance_to(at + Vector2(-60, -60)) < 4.0:
			back = u
	check("a save keeps the stun and its stars", back != null and absf(back.stun_left() - before) < 0.15 and g.stun_layer.marked.has(back),
		"%.2f s of %.2f" % [back.stun_left() if back else -1.0, before])
	g.queue_free()
	await process_frame
	# ---- the Brood: the Tyrannosaur (a father) and the Brood Mother are only staggered; a flyer is pulled through the air
	var g2 := make(["crown", "brood"])      # (side 1: the Brood, with its Mother and fathers; 0.18.0: no old Brood for side 0)
	await process_frame
	await process_frame
	var at2 := open_spot(g2, 0)
	var toad2 := tough(g2._add_unit("mist_toad", 0, at2 + Vector2(0, 150)))
	for kind in ["tyrannosaur", "brood_mother"]:
		var big := tough(g2._add_unit(kind, 1, at2))
		big.hold_fire = true
		big.cmd_hold()
		check("the %s can't be pulled (too heavy)" % kind, Unit.too_heavy(big))
		toad2.charge = 200.0
		toad2.cmd_tongue(big)
		var w2 := 0.0
		while big.stun_left() <= 0.0 and w2 < 8.0:
			await step(g2, 1.0 / 30.0)
			w2 += 1.0 / 30.0
		var from := big.position
		check("the tongue staggers the %s" % kind, big.stun_left() > 0.0 and g2.stun_layer.marked.has(big), "%.1f s in" % w2)
		var sh2 := await mark_time(g2, big)
		check("its stars show for the stagger, %.1f s" % float(Defs.TONGUE["stagger"]), absf(sh2 - float(Defs.TONGUE["stagger"])) < 0.12, "%.2f s" % sh2)
		check("and it stays where it was (not pulled)", big.position.distance_to(from) < 4.0, "%.0f px" % big.position.distance_to(from))
		big.position = at2 + Vector2(-900, 900)
		big.visible = false
		await step(g2, 0.3)
	# a Skywing in the air: pulled through the air to just over the Toad, still flying
	var wing := tough(g2._add_unit("skywing", 1, at2 + Vector2(40, -20)))
	wing.hold_fire = true
	wing.cmd_hold()
	check("the Skywing is flying", wing.is_air())
	toad2.charge = 200.0
	toad2.cmd_tongue(wing)
	var w3 := 0.0
	while toad2.tongue_stage != "windup" and w3 < 6.0:
		await step(g2, 1.0 / 30.0)
		w3 += 1.0 / 30.0
	check("the Toad marks a flyer (the crosshair: windup)", toad2.tongue_stage == "windup" and toad2.tongue_victim == wing)
	while wing.stun_left() <= 0.0 and w3 < 10.0:
		await step(g2, 1.0 / 30.0)
		w3 += 1.0 / 30.0
	check("the tongue pulls the Skywing, stunned with stars", wing.stun_left() > 0.0 and g2.stun_layer.marked.has(wing))
	await step(g2, float(Defs.TONGUE["pull"]) + 0.1)
	var dd: float = wing.position.distance_to(toad2.position)
	check("it ends just over the Toad", dd <= float(Defs.TONGUE["over"]) + 3.0, "%.1f px" % dd)
	check("and stays in the air", wing.is_air() and wing.sky == "air", "sky %s" % wing.sky)
	await step(g2, 1.0)
	check("its stars go after the stun", not g2.stun_layer.marked.has(wing))
	# the windup still breaks when the flyer flies out of reach
	var wing2 := tough(g2._add_unit("skywing", 1, at2 + Vector2(-60, -20)))
	toad2.charge = 200.0
	toad2.cmd_tongue(wing2)
	var w4 := 0.0
	while toad2.tongue_stage != "windup" and w4 < 6.0:
		await step(g2, 1.0 / 30.0)
		w4 += 1.0 / 30.0
	wing2.position = toad2.position + Vector2(0, -float(Defs.TONGUE["range"]) * float(Defs.TONGUE["break"]) - 40.0)
	await step(g2, 0.2)
	check("a flyer flown out of reach breaks the windup", toad2.tongue_stage == "" and wing2.stun_left() == 0.0)
	# the retired Stormcaller's storm code still runs safely: a unit inside gets stars until it ends
	var gs := tough(g2._add_unit("raptor", 1, at2 + Vector2(200, 0)))
	gs.stun(0.2, true, g2.clock + 1.0)
	await step(g2, 0.1)
	check("(a storm's top-up stun still marks safely)", g2.stun_layer.marked.has(gs))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
