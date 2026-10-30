## THE MARCHING BAND (the owner's experiment, 2026-10-30; scripts/marching_band.gd, docs/marching_band.md):
## off by default (the setting, the Barracks' card, training refused); with it on: one band per player (a second
## refused, also one waiting in a queue), musicians taken on for their price and time (one at a time, each once, +15
## health), solos (only with the instrument, one at a time, the cooldown), the area (own and allied fighting units within
## the ring; not enemies, workers or the band, not outside), the buffs applied and removed (speed, reload, melee), a
## save, the online snapshot (and so a replay) and the command funnel carry it.
##   godot --headless --fixed-fps 30 --script res://tools/test_marching_band.gd
extends SceneTree
var fails := 0
const B := Defs.MARCHING_BAND


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
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


func step(g: Game, secs: float) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		if i % 8 == 0:
			await process_frame


func tough(u: Unit) -> Unit:
	u.max_hp = 5000.0
	u.hp = 5000.0
	u.auto_work = false
	return u


func hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			return b
	return null


func open_spot(g: Game, t: int) -> Vector2:
	var h := hall(g, t)
	return h.center() + Vector2(0, h.rect().size.y * 0.5 + 160.0)


func _run() -> void:
	# ---- off by default
	check("the setting is off by default", Settings.marching_band == false, str(Settings.marching_band))
	check("Defs.marching_band is off by default", Defs.marching_band == false)
	check("the Barracks' card has no band while it's off", not Defs.train_keys(Defs.BUILDINGS["barracks"]["trains"], false).has(MarchingBand.KIND))
	var g := make(["crown", "clockwork"])
	await process_frame
	await process_frame
	var at := open_spot(g, 0)
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500
	var bk: Building = g._add_building("barracks", 0, g.cell_of(hall(g, 0).center()) + Vector2i(8, -2), true)
	check("training a band is refused while the experiment is off", g.can_train(bk, MarchingBand.KIND) != "", g.can_train(bk, MarchingBand.KIND))
	# ---- on
	Defs.marching_band = true
	check("on: the Barracks' card shows the band", Defs.train_keys(Defs.BUILDINGS["barracks"]["trains"], false).has(MarchingBand.KIND))
	check("on: the Barracks can train a band", g.can_train(bk, MarchingBand.KIND) == "", g.can_train(bk, MarchingBand.KIND))
	var why := g.train(bk, MarchingBand.KIND)
	check("a band goes into the queue", why == "" and bk.queue.count(MarchingBand.KIND) == 1, why)
	check("a second band is refused while one waits in a queue", g.can_train(bk, MarchingBand.KIND) != "", g.can_train(bk, MarchingBand.KIND))
	g.cancel_train(bk)
	var band := tough(g._add_unit(MarchingBand.KIND, 0, at))
	band.max_hp = float(band.d["hp"])
	band.hp = band.max_hp
	band.cmd_hold()
	check("a second band is refused with one on the field", g.can_train(bk, MarchingBand.KIND) == "Only one Marching Band per player.", g.can_train(bk, MarchingBand.KIND))
	check("the Clockwork can't have one", not MarchingBand.on(g, 1))
	# ---- musicians
	check("it starts as the bandmaster alone", (band.band.get("m", []) as Array).is_empty() and MarchingBand.muls(band) == Vector3.ONE)
	var gold0 := int(g.players[0]["gold"])
	band.band_hire("drums")
	check("ADD DRUMMER is paid", int(g.players[0]["gold"]) == gold0 - int(B["drums"]["cost"]), "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	check("one musician at a time", MarchingBand.hire_problem(band, "fife") != "")
	await step(g, float(B["drums"]["time"]) - 1.0)
	check("the drummer isn't there before his time", not MarchingBand.has(band, "drums"))
	await step(g, 1.5)
	check("the drummer joins after his time", MarchingBand.has(band, "drums"))
	check("each musician adds health", is_equal_approx(band.max_hp, float(band.d["hp"]) + float(B["hp_per"])), str(band.max_hp))
	check("a second drummer is refused", MarchingBand.hire_problem(band, "drums") != "")
	band.band_hire("fife")
	await step(g, float(B["fife"]["time"]) + 0.5)
	band.band_hire("pipes")
	await step(g, float(B["pipes"]["time"]) + 0.5)
	check("all three join", MarchingBand.has(band, "fife") and MarchingBand.has(band, "pipes"), str(band.band.get("m")))
	var m2 := MarchingBand.muls(band)
	check("with no solo every instrument plays its secondary share",
		is_equal_approx(m2.x, 1.0 + float(B["drums"]["second"])) and is_equal_approx(m2.y, 1.0 + float(B["pipes"]["second"])) and is_equal_approx(m2.z, 1.0 + float(B["fife"]["second"])), str(m2))
	# ---- the area
	var near := tough(g._add_unit("musketeer", 0, at + Vector2(100, 0)))
	var far := tough(g._add_unit("musketeer", 0, at + Vector2(float(B["area"]) + 80.0, 0)))
	var worker := tough(g._add_unit("labourer", 0, at + Vector2(-60, 30)))
	var foe := tough(g._add_unit("clock_soldier", 1, at + Vector2(0, -120)))
	for u in [near, far, worker, foe]:
		u.cmd_hold()
	foe.hold_fire = true
	near.hold_fire = true
	far.hold_fire = true
	await step(g, 0.6)
	check("a soldier inside the ring gets the band's buff", near.band_until > g.clock and near.band_mul == m2, str(near.band_mul))
	check("one outside it does not", far.band_until <= g.clock)
	check("a worker does not", worker.band_until <= g.clock)
	check("an enemy does not", foe.band_until <= g.clock)
	check("the band does not buff itself", band.band_until <= g.clock)
	# ---- solos
	check("a solo needs its instrument (a fresh band)", MarchingBand.solo_problem(_fresh_band(g, at), "fife") != "")
	band.band_solo("fife")
	check("FIFE SOLO: the fife leads", MarchingBand.lead(band) == "fife")
	check("one solo at a time", MarchingBand.solo_problem(band, "drums") != "")
	await step(g, 0.4)
	check("the fife's full share reaches the ring", is_equal_approx(near.band_mul.z, 1.0 + float(B["fife"]["lead"])), str(near.band_mul))
	# the reload: the cooldown runs down faster by the fife's share
	# (measured against the game clock: the scene tree ticks the game too while the test waits for a frame)
	near.cooldown = 3.0
	var c0 := g.clock
	await step(g, 1.0)
	var ran := (3.0 - near.cooldown) / (g.clock - c0)
	check("the reload runs %.0f%% faster in the fife's solo" % (float(B["fife"]["lead"]) * 100.0), absf(ran - (1.0 + float(B["fife"]["lead"]))) < 0.03, "%.2f s a second" % ran)
	far.cooldown = 3.0
	c0 = g.clock
	await step(g, 1.0)
	var ran2 := (3.0 - far.cooldown) / (g.clock - c0)
	check("outside the ring the reload runs as usual", absf(ran2 - 1.0) < 0.03, "%.2f s a second" % ran2)
	await step(g, float(B["solo"]))
	check("the solo ends after its time", MarchingBand.lead(band) == "")
	check("the instrument waits out its cooldown", MarchingBand.solo_problem(band, "fife") != "", MarchingBand.solo_problem(band, "fife"))
	check("another instrument may solo now", MarchingBand.solo_problem(band, "pipes") == "")
	# the melee: a bayonet thrust with the pipes leading
	# (the Clock Soldier's armour comes off each blow: compared with it added back)
	near.mode = "bayonet"
	var hp0 := foe.hp
	near._strike(foe)
	var plain := hp0 - foe.hp + foe.armor
	band.band_solo("pipes")
	await step(g, 0.4)
	near.mode = "bayonet"
	hp0 = foe.hp
	near._strike(foe)
	var piped := hp0 - foe.hp + foe.armor
	check("PIPE SOLO: a bayonet thrust hits %.0f%% harder" % (float(B["pipes"]["lead"]) * 100.0),
		plain > 0.0 and absf(piped / plain - (1.0 + float(B["pipes"]["lead"])) / (1.0 + float(B["pipes"]["second"]))) < 0.02, "%.1f -> %.1f (with its armour)" % [plain, piped])
	near.mode = ""
	# the speed: the drums' solo
	await step(g, float(B["solo"]) + 0.2)
	band.band_solo("drums")
	await step(g, 0.4)
	var walker := tough(g._add_unit("musketeer", 0, at + Vector2(40, 40)))
	await step(g, 0.4)
	walker.cmd_move(walker.position + Vector2(400, 0))
	await step(g, 0.3)
	var sp := walker.speed
	check("DRUM SOLO: a soldier in the ring walks %.0f%% faster" % (float(B["drums"]["lead"]) * 100.0),
		absf(sp / float(walker.d["speed"]) - (1.0 + float(B["drums"]["lead"]))) < 0.02, "%.1f of %.1f" % [sp, float(walker.d["speed"])])
	# ---- save
	var keep := MarchingBand.save(band)
	g.demo = false
	var d := SaveGame.capture(g, {"map": g.map_id, "seed": 4242})
	g.demo = true
	SaveGame.restore(g, d)
	await process_frame
	var back: Unit = null
	for u in g.units:
		if u.kind == MarchingBand.KIND and u.team == 0 and u.position.distance_to(at) < 4.0:
			back = u
	check("a save keeps the band, its musicians, solo and cooldowns", back != null and MarchingBand.save(back) == keep and is_equal_approx(back.max_hp, float(back.d["hp"]) + 3.0 * float(B["hp_per"])),
		str(MarchingBand.save(back)) if back else "none")
	# ---- online snapshot (a replay records the same snapshots)
	if back:
		var row := NetSnapshot.unit_vals(back)
		var copy := g._add_unit(MarchingBand.KIND, 0, at + Vector2(0, 200))
		NetSnapshot._set_unit_vals(copy, row, 0)
		check("the online snapshot carries the band's state", MarchingBand.save(copy) == keep, str(MarchingBand.save(copy)))
		check("the snapshot's lists match its values", NetSnapshot.UNIT_PROPS.size() == row.size() and NetSnapshot.UNIT_PROPS.has("band"))
		check("a replay records the field", (ReplayRecorder.lists()["up"] as Array).has("band"))
	check("a guest's band orders go through the funnel", NetCommands.ENTITY.has("band_hire") and NetCommands.ENTITY.has("band_solo"))
	# ---- the buff goes when the band goes
	if back:
		var nb := tough(g._add_unit("musketeer", 0, back.position + Vector2(60, 0)))
		nb.cmd_hold()
		await step(g, 0.5)
		var had := nb.band_until > g.clock
		back.take_damage(99999.0, null, Entity.BLOW_RANGED)
		await step(g, float(B["linger"]) + 0.3)
		check("killed, the band's buff is gone after its linger", had and nb.band_until <= g.clock and MarchingBand.speed_mul(nb) == 1.0)
	Defs.marching_band = false
	print("marching band: %d failures" % fails)
	quit(1 if fails > 0 else 0)


var _fresh_n := 0


func _fresh_band(g: Game, at: Vector2) -> Unit:
	_fresh_n += 1
	var u := g._add_unit(MarchingBand.KIND, 0, at + Vector2(-200, 100 + _fresh_n * 30))
	u.band = MarchingBand.fresh()
	return u
