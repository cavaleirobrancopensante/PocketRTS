extends SceneTree
## The Clock Soldier after 0.14.49 (docs/clock_soldier_shield.md): its new base stats, the SHIELD WALL research at a
## Movement Works (it costs Tension: only where the Works meshes with a Mainspring), the SHIELD FORWARD stance
## (scripts/shield_wall.gd: the switch takes its moment, standing still; raised, it is slower, has more armour and takes
## less from shots and blows from the FRONT, not from behind nor from splash), the button on the card once researched,
## the stance on an online guest (NetSnapshot through the codec), the Clockwork computer's use of it (raised in ranged
## fire, lowered to chase) and its research when it meets shooters.
##   godot --headless --fixed-fps 30 --script res://tools/test_clock_soldier_shield.gd
const U := preload("res://tools/gear_test_util.gd")
const K := "clock_soldier"
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-76s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var SW: Dictionary = Defs.SHIELD_WALL
	var hall := U.hall(g, 0)
	# ---- base stats
	var d: Dictionary = Defs.UNITS[K]
	check("base: 75 health (was 90)", int(d["hp"]) == 75, str(d["hp"]))
	check("base: speed 68 (was 62)", int(d["speed"]) == 68, str(d["speed"]))
	var at := _open(g, hall.center() + Vector2(0, 300))
	var cs: Unit = g._add_unit(K, 0, at)
	check("a new Clock Soldier has 75 health", is_equal_approx(cs.max_hp, 75.0) and is_equal_approx(cs.hp, 75.0), "%.0f" % cs.max_hp)
	# ---- before the research: no stance
	cs.set_shield(true)
	check("before SHIELD WALL the soldier cannot raise its shield", not cs.shield_up and ShieldWall.problem(cs) != "", ShieldWall.problem(cs))
	# ---- the research at a Movement Works: Tension, so only where a Mainspring meshes
	var info: Dictionary = Defs.RESEARCH[ShieldWall.TECH]
	check("SHIELD WALL is researched at the Movement Works, for cogs and Tension", String(info["at"]) == Defs.CW_WORKS and Defs.tension_cost(info) > 0 and int(info["cost"]) > 0)
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var works := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	check("a Movement Works links", works != null and g.gear_net.is_linked(works))
	if works == null:
		_end()
		return
	if g.gear_net.spring_for(works) == null:
		var why0 := g.research_problem(works, ShieldWall.TECH)
		check("a Works meshing with no Mainspring refuses it (it costs Tension)", why0.contains("Mainspring"), why0)
		_spring_beside(g, works)
		U.step(g, 0.6)
	var cogs0 := int(g.players[0]["gold"])
	var ten0 := g.tension(0)
	var why := g.start_research(works, ShieldWall.TECH)
	check("with a Mainspring meshing it starts, paid in cogs and Tension", why == "" and int(g.players[0]["gold"]) == cogs0 - int(info["cost"]) \
			and is_equal_approx(g.tension(0), ten0 - float(Defs.tension_cost(info))), why)
	U.step(g, float(info["time"]) + 1.0)
	check("after its time SHIELD WALL is researched", g.has_tech(0, ShieldWall.TECH))
	check("the research has its icon name (assets/icons/clockwork/research_shield.png drops in)", String(info["icon"]) == "research_shield")
	_clear(g, g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.is_worker()))
	# ---- the switch takes its moment, standing still
	cs = g._add_unit(K, 0, at)
	cs.cmd_stop()
	U.step(g, 0.2)
	var p0 := cs.position
	cs.set_shield(true)
	cs.cmd_move(at + Vector2(400, 0))
	U.step(g, float(SW["switch"]) * 0.6)
	check("raising: it stands still for the switch", cs.position.distance_to(p0) < 1.5 and cs.shield_t > 0.0, "%.1f px" % cs.position.distance_to(p0))
	check("raising: no armour yet during the switch", is_equal_approx(cs.armor, float(d["armor"])), "%.0f" % cs.armor)
	U.step(g, float(SW["switch"]) * 0.6)
	check("after the switch the shield is up, with its armour", ShieldWall.active(cs) and is_equal_approx(cs.armor, float(d["armor"]) + float(SW["armor"])), "%.0f" % cs.armor)
	check("the soldier shows its guard strips", String(cs.anim).begins_with("guard"), cs.anim)
	# ---- slower with the shield up
	var dist_up := _walk(g, cs, at, 2.0)
	var plain: Unit = g._add_unit(K, 0, _open(g, at + Vector2(0, 80)))
	var dist_down := _walk(g, plain, plain.position, 2.0)
	check("shield up it walks about %d%% slower" % int((1.0 - float(SW["speed"])) * 100.0), dist_up > 0.0 and absf(dist_up / dist_down - float(SW["speed"])) < 0.08, "%.0f vs %.0f px" % [dist_up, dist_down])
	check("its blows come slower with the shield up", cs._cooldown() > plain._cooldown() - 0.001, "%.2f vs %.2f" % [cs._cooldown(), plain._cooldown()])
	# ---- front and back
	cs.cmd_stop()
	plain.cmd_stop()
	U.step(g, 0.2)
	cs.facing = Vector2.RIGHT
	plain.facing = Vector2.RIGHT
	var front: Unit = _foe(g, "musketeer", cs.position + Vector2(150, 0))
	var back: Unit = _foe(g, "musketeer", cs.position + Vector2(-150, 0))
	var blow := 20.0
	var plain_dmg := blow - float(d["armor"])
	var got_front := _hit(cs, blow, front, Entity.BLOW_RANGED)
	var got_back := _hit(cs, blow, back, Entity.BLOW_RANGED)
	var got_melee := _hit(cs, blow, front, Entity.BLOW_MELEE)
	var got_splash := _hit(cs, blow, front, "")
	var got_plain := _hit(plain, blow, front, Entity.BLOW_RANGED)
	var arm := float(d["armor"]) + float(SW["armor"])
	check("a shot from the FRONT does much less", is_equal_approx(got_front, blow * (1.0 - float(SW["front"])) - arm), "%.1f (plain %.1f)" % [got_front, got_plain])
	check("a shot from BEHIND is not stopped (only the armour)", is_equal_approx(got_back, blow - arm), "%.1f" % got_back)
	check("a blow from the front does less too", is_equal_approx(got_melee, blow * (1.0 - float(SW["front_melee"])) - arm), "%.1f" % got_melee)
	check("splash is not stopped by the shield", is_equal_approx(got_splash, blow - arm), "%.1f" % got_splash)
	check("without the stance the shot does its plain damage", is_equal_approx(got_plain, plain_dmg), "%.1f" % got_plain)
	# ---- lowering: takes its moment too, then the old pace and armour
	cs.set_shield(false)
	check("lowering: the armour goes at once", is_equal_approx(cs.armor, float(d["armor"])) and cs.shield_t > 0.0)
	U.step(g, float(SW["switch"]) + 0.1)
	var dist_again := _walk(g, cs, cs.position, 2.0)
	check("lowered: its full pace again", absf(dist_again - dist_down) < dist_down * 0.08, "%.0f vs %.0f px" % [dist_again, dist_down])
	_clear(g, [front, back, cs, plain])
	# ---- the computer: shields up in ranged fire, down to chase
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = 2
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.add_child(ai)
	await physics_frame
	var squad: Array = []
	for i in 4:
		squad.append(g._add_unit(K, 0, _open(g, at + Vector2(0, (i - 1.5) * 26.0))))
	var shooters: Array = []
	for i in 3:
		var m: Unit = _foe(g, "musketeer", _open(g, at + Vector2(230, (i - 1) * 30.0)))
		m.cmd_attack(squad[i])
		shooters.append(m)
	for u in squad:
		u.cmd_move(at + Vector2(260, 0), true)
	U.step(g, 0.5)
	ai._abilities()
	check("the computer raises its soldiers' shields as they walk into Musketeers' fire", squad.all(func(u: Unit) -> bool: return u.shield_up), str(squad.map(func(u: Unit) -> bool: return u.shield_up)))
	# a lone shooter walks off and the soldier chases it: down
	_clear(g, shooters.slice(1) + squad.slice(1))
	var chaser: Unit = squad[0]
	_clear(g, [shooters[0]])
	U.step(g, float(SW["switch"]) + ShieldWall.AI_HOLD + 0.2)
	check("(the soldier's shield is still up before the chase)", chaser.shield_up)
	var runner: Unit = g._add_unit("musketeer", 1, _open(g, chaser.position + Vector2(70, 0)))
	runner.hold_fire = true
	runner.cmd_move(g.on_map(chaser.position + Vector2(900, 0)))
	chaser.cmd_attack(runner)
	U.step(g, 1.5)
	ai._abilities()
	check("the computer lowers the shield to chase a shooter that walks off", not chaser.shield_up, "chasing %s order %s tgt %s vel %s gap %.0f" % [str(ShieldWall.chasing(chaser)), chaser.order, str(chaser.target), str(runner.velocity), runner.position.distance_to(chaser.position)])
	_clear(g, [chaser, runner])
	# ---- the computer researches SHIELD WALL once it meets shooters
	g.players[0]["tech"].erase(ShieldWall.TECH)
	for i in 5:
		g._add_unit(K, 0, _open(g, at + Vector2(-60, (i - 2) * 26.0)))
	var seen: Array = []
	for i in 4:
		seen.append(_foe(g, "musketeer", _open(g, at + Vector2(150, (i - 1.5) * 28.0))))
	U.step(g, 0.5)
	ai._shield_research()
	check("the computer researches SHIELD WALL once it has met a ranged army", g.researching(0, ShieldWall.TECH))
	_clear(g, g.units.filter(func(u: Unit) -> bool: return not u.is_worker()))
	ai.queue_free()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.queue_free()
	await process_frame
	await process_frame
	await _hud()
	await _online()
	_end()


## The card: no SHIELD FORWARD before the research, the button after it (key F), and it toggles the selection.
func _hud() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_lab()
	for i in 6:
		await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	var me := g.human
	g.players[me]["tech"].erase(ShieldWall.TECH)
	var mine: Array = g.units.filter(func(u: Unit) -> bool: return u.team == me and u.kind == K and not u.dead)
	check("the Lab has Clock Soldiers", mine.size() >= 2, "%d" % mine.size())
	g.set_selection(mine)
	var has_button := func() -> Array:
		var l: Array = []
		g.hud._ability_buttons(l, g.selected_units())
		return l.filter(func(it: Array) -> bool: return String(it[1]).trim_prefix("~ ") == "SHIELD FORWARD")
	check("no SHIELD FORWARD button before the research", (has_button.call() as Array).is_empty())
	g.players[me]["tech"][ShieldWall.TECH] = true
	var b: Array = has_button.call()
	check("SHIELD FORWARD on the card once researched", b.size() == 1 and String(b[0][0]) == "ab_shield")
	check("its hotkey is F", String(g.hud.FIXED_KEYS.get("SHIELD FORWARD", "")) == "F")
	check("its icon is drawn as a placeholder until assets/icons/clockwork/ab_shield.png exists", g.hud._icon("ab_shield") != null and g.hud._icon("research_shield") != null)
	if not b.is_empty():
		(b[0][2] as Callable).call()
		check("the button raises the shields of the selected soldiers", mine.all(func(u: Unit) -> bool: return u.shield_up))
		b = has_button.call()
		check("the button then reads ~ SHIELD FORWARD (on)", String(b[0][1]).begins_with("~ "))
		(b[0][2] as Callable).call()
		check("pressed again it lowers them", mine.all(func(u: Unit) -> bool: return not u.shield_up))
	main.queue_free()
	await process_frame
	await process_frame


## ONLINE: the guest sees the stance (raised, switching, lowered) through the codec.
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
		sh.snap_n = 1
		var m := NetSnapshot.build(sh)
		NetSnapshot.apply(sg, NetCodec.unpack(NetCodec.pack(m)))
	h.players[0]["tech"][ShieldWall.TECH] = true
	var hall := U.hall(h, 0)
	var cs: Unit = h._add_unit(K, 0, _open(h, hall.center() + Vector2(0, 200)))
	sync.call()
	var gcs: Unit = null
	for u in gu.units:
		if u.kind == K and u.team == 0:
			gcs = u
	check("online: the guest has the soldier", gcs != null)
	if gcs == null:
		return
	check("online: the unit lists match the direct readers", NetSnapshot.check_lists(cs, hall) == "", NetSnapshot.check_lists(cs, hall))
	cs.set_shield(true)
	sync.call()
	check("online: the guest sees the shield being raised", gcs.shield_up and gcs.shield_t > 0.0)
	U.step(h, float(Defs.SHIELD_WALL["switch"]) + 0.1)
	sync.call()
	check("online: the guest sees it up", gcs.shield_up and gcs.shield_t <= 0.0)
	check("online: the guest draws the guard strip", gcs._anim_name().begins_with("guard"), gcs._anim_name())
	cs.set_shield(false)
	U.step(h, float(Defs.SHIELD_WALL["switch"]) + 0.1)
	sync.call()
	check("online: the guest sees it lowered", not gcs.shield_up)
	check("online: a guest's SHIELD FORWARD order goes to the host", NetCommands.ENTITY.has("set_shield"))
	for gg in [h, gu]:
		gg.process_mode = Node.PROCESS_MODE_DISABLED
		gg.queue_free()
	await process_frame


func _hit(u: Unit, amount: float, from: Unit, blow: String) -> float:
	var hp0 := u.hp
	u.take_damage(amount, from, blow)
	var got := hp0 - u.hp
	u.hp = u.max_hp
	return got


func _walk(g: Game, u: Unit, from: Vector2, secs: float) -> float:
	u.cmd_move(from + Vector2(600, 0))
	U.step(g, 0.3)
	var a := u.position
	U.step(g, secs)
	u.wind = 1.0
	return u.position.distance_to(a)


func _spring_beside(g: Game, b: Building) -> Building:
	for deg in [0.0, 90.0, 180.0, -90.0, 45.0, 135.0, -45.0, -135.0]:
		var c := GearNet.ring_spot(g, 0, "mainspring", b, deg)
		if c.x >= 0:
			var m := g._add_building("mainspring", 0, c, true)
			g.gear_net.solve()
			return m
	return null


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


func _open(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
