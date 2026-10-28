extends SceneTree
## THE NEW BROOD (experiment: scripts/brood_new.gd, docs/brood_new.md), its rules in a real match:
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_new.gd
##  0. the start: no buildings, the Brood Mother, a Rootmaw and 5 grubs; both finish rooting in a moment; supply 40 + 20
##  1. rooted: armour and less damage (the same blow on a rooted and an uprooted Rootmaw)
##  2. the Mother lays an egg while she walks (it drops behind her)
##  3. warriors' eggs are fertilised only near the Mother (refused without the father beside her; fertilised by his
##     breath; hatch as 3 Raptors); an egg the father doesn't reach in time hatches as a grub (the difference paid back)
##  4. one Tyrannosaur at a time (an egg for one counts)
##  5. a Rootmaw drinks its ground into its body; rooted circles may not overlap
##  6. UPROOT spills its food as a pile (grubs take from it; it rots); HAUL carries it, slower; killed hauling it bursts
##  7. grubs carry food from the Rootmaw to the Mother (biomass comes in)
##  8. killing the Mother loses the game
## Prints PASS / FAIL lines and "brood_new: N failures".
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
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
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


func mine(k: String) -> Array:
	return g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == k)


## A walkable spot `tiles` from p, on p's level (for a test creature).
func spot_near(p: Vector2, tiles: float) -> Vector2:
	var h := int(g.height[g.idx(g.cell_of(p))])
	for i in 32:
		var q: Vector2 = p + Vector2.from_angle(TAU * i / 32.0) * tiles * Defs.TILE
		var c: Vector2i = g.cell_of(q)
		if g._walkable(c) and int(g.height[g.idx(c)]) == h and g.region_of(c) == g.region_of(g.cell_of(p)):
			return q
	return p


func _run() -> void:
	var p: Dictionary = g.players[0]
	# 0. the start
	check(BroodNew.on(g, 0) and not BroodNew.on(g, 1) and g.faction_of(0) == "brood", "0. side 0 plays the new Brood (as the Brood), side 1 does not")
	check(g.buildings.filter(func(b) -> bool: return b.team == 0).is_empty(), "   no buildings")
	var q: Unit = BroodNew.queen(g, 0)
	check(q != null and mine(BroodNew.MAW).size() == 1 and mine("grub").size() == 5, "   the Brood Mother, a Rootmaw and 5 grubs")
	var maw: Unit = mine(BroodNew.MAW)[0]
	check(q.tesla_mode == "deploying" and maw.tesla_mode == "deploying", "   both are finishing their rooting at the start (the cue)")
	await wait(2.0)
	check(q.tesla_mode == "deployed" and maw.tesla_mode == "deployed", "   then rooted")
	check(int(p["cap"]) == int(Defs.NB["queen_supply"]), "   supply %d (the Mother's, as the old Burrow's)" % int(p["cap"]))
	check(g.on_swamp(0, q.position) and g.on_swamp(0, maw.position), "   swamp round the rooted Mother and Rootmaw")
	# 1. rooting buffs
	var a: Unit = g._add_unit(BroodNew.MAW, 0, spot_near(q.position, 30.0))
	a.hp = a.max_hp
	a.take_damage(30.0, null)
	var lost_walk: float = a.max_hp - a.hp
	var lost_root: float = 0.0
	var hp0: float = maw.hp
	maw.take_damage(30.0, null)
	lost_root = hp0 - maw.hp
	check(lost_root < lost_walk * 0.8, "1. rooted takes less: %.1f from a 30 blow (uprooted %.1f)" % [lost_root, lost_walk])
	maw.hp = maw.max_hp
	a.die()
	# 2. lays while walking
	q.nb["eggs"] = 5
	q.cmd_uproot(true)
	var packed: bool = await wait_for(func() -> bool: return q.tesla_mode == "packed", 8.0)
	check(packed, "2. the Mother uproots (%.1f s)" % float(Defs.NB["queen_switch"]))
	var walk_to := spot_near(q.position, 8.0)
	q.cmd_move(walk_to)
	await wait(1.5)
	var moving: bool = q.velocity.length() > 5.0
	p["gold"] = 1000
	var n0: int = mine(BroodNew.EGG).size()
	var why: String = q.cmd_lay("grub")
	await wait(0.1)
	var eggs: Array = mine(BroodNew.EGG)
	var egg: Unit = eggs.back() if eggs.size() > n0 else null
	check(why == "" and egg != null and moving and q.velocity.length() > 5.0, "   she lays an egg while walking (moving %s, %s)" % [moving, why])
	if egg:
		var behind: float = (egg.position - q.position).dot(q.facing)
		check(behind < 0.0, "   the egg drops behind her (%.0f px along her heading)" % behind)
		check(float(egg.nb.get("drop", 0.0)) > 0.0, "   it falls (the drop drawn in code)")
		var eid: int = egg.get_instance_id()
		var hatched: bool = await wait_for(func() -> bool: return not is_instance_id_valid(eid) or (instance_from_id(eid) as Unit).dead, Defs.UNITS["grub"]["time"] + 2.0)
		check(hatched and mine("grub").size() >= 6, "   a grub's egg hatches by itself (no father needed): %d grubs" % mine("grub").size())
	await wait_for(func() -> bool: return q.order == "idle", 30.0)
	q.cmd_deploy()
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", 8.0)
	# 3. fertilising near the Mother only
	for gr in mine("grub"):
		gr.auto_work = false          # (no income meanwhile: the refund is counted below)
		gr.cmd_stop()
	q.nb["eggs"] = 8
	p["gold"] = 2000
	p["res2"] = 200.0
	check(BroodNew.lay_problem(g, q, "raptor").contains("Tyrannosaur"), "3. no father: a Raptor's egg is refused (%s)" % BroodNew.lay_problem(g, q, "raptor"))
	var far := spot_near(q.position, 20.0)
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, far)
	await wait(0.3)
	check(not BroodNew.father_near(g, 0) and BroodNew.lay_problem(g, q, "raptor") != "", "   the father far from her: still refused")
	f.position = q.position + Vector2(-q.radius - 40.0, 10.0)
	f.cmd_stop()
	await wait(0.3)
	check(BroodNew.father_near(g, 0) and BroodNew.lay_problem(g, q, "raptor") == "", "   the father beside her: allowed")
	var r0: int = mine("raptor").size()
	q.cmd_lay("raptor")
	await wait(0.1)
	var re: Unit = mine(BroodNew.EGG).back()
	check(re != null and int(re.nb["fert"]) == 1, "   the Raptor egg waits for the father's breath")
	var fert: bool = await wait_for(func() -> bool: return int(re.nb["fert"]) == 2, 6.0)
	check(fert, "   the father breathes on it: fertilised (red)")
	var got3: bool = await wait_for(func() -> bool: return mine("raptor").size() >= r0 + 3, Defs.UNITS["raptor"]["time"] + 3.0)
	check(got3, "   it hatches as 3 Raptors (%d)" % (mine("raptor").size() - r0))
	# an egg the father never reaches: a grub, the difference paid back
	q.cmd_lay("raptor")
	await wait(0.05)
	var lone: Unit = mine(BroodNew.EGG).back()
	f.position = far
	f.cmd_stop()
	var gold_a: int = int(p["gold"])
	var turned: bool = await wait_for(func() -> bool: return String(lone.nb.get("k", "")) == "grub", float(Defs.NB["fert_wait"]) + 2.0)
	check(turned and int(lone.nb["fert"]) == 0, "   not fertilised in %d s: it hatches as a grub" % int(Defs.NB["fert_wait"]))
	check(int(p["gold"]) - gold_a == int(Defs.UNITS["raptor"]["cost"]) - int(Defs.UNITS["grub"]["cost"]), "   the difference paid back (+%d)" % (int(p["gold"]) - gold_a))
	# 4. one father at a time
	check(BroodNew.lay_problem(g, q, BroodNew.FATHER).begins_with("Only one"), "4. one Tyrannosaur at a time: %s" % BroodNew.lay_problem(g, q, BroodNew.FATHER))
	f.die()
	await wait(0.2)
	check(BroodNew.lay_problem(g, q, BroodNew.FATHER) == "", "   it died: another can be grown from an egg")
	q.cmd_lay(BroodNew.FATHER)
	await wait(0.05)
	check(BroodNew.lay_problem(g, q, BroodNew.FATHER).begins_with("Only one"), "   an egg for one counts")
	# 5. the Rootmaw drinks its ground; circles may not overlap
	for gr in mine("grub"):
		gr.cmd_stop()
		gr.auto_work = false
	maw.nb["food"] = 0.0
	var left0: float = BroodNew.ground_left(g, maw)
	await wait(5.0)
	var food: float = float(maw.nb["food"])
	check(food > 15.0 and BroodNew.ground_left(g, maw) < left0 - 15.0, "5. the Rootmaw drinks its ground: %.0f food in 5 s, its ground %.0f -> %.0f" % [food, left0, BroodNew.ground_left(g, maw)])
	var b2: Unit = g._add_unit(BroodNew.MAW, 0, maw.position + Vector2(5.0 * Defs.TILE, 0))
	b2.cmd_deploy()
	await wait(0.2)
	check(b2.tesla_mode == "packed", "   another may not root with its circle over this one's")
	b2.die()
	# 6. UPROOT spills a pile; HAUL carries
	maw.nb["food"] = 200.0
	var piles0: int = g.units.filter(func(u) -> bool: return u.kind == BroodNew.PILE and not u.dead).size()
	maw.cmd_uproot(true)
	await wait(float(Defs.NB["maw_switch"]) + 0.3)
	var piles: Array = g.units.filter(func(u) -> bool: return u.kind == BroodNew.PILE and not u.dead)
	check(maw.tesla_mode == "packed" and float(maw.nb.get("food", 0.0)) == 0.0 and piles.size() == piles0 + 1, "6. UPROOT: the food spills as a pile, the Rootmaw walks off thin")
	if piles.size() > piles0:
		var pile: Unit = piles.back()
		var pf: float = float(pile.nb["food"])
		check(pf > 190.0 and pf <= 200.0, "   the pile holds it (%.0f)" % pf)
		await wait(2.0)
		check(float(pile.nb["food"]) < pf, "   it rots slowly (%.1f -> %.1f)" % [pf, float(pile.nb["food"])])
		var gr0: Unit = mine("grub")[0]
		gr0.cmd_gather(pile)
		check(gr0.order == "gather" and gr0.home_mine == pile, "   a grub can be sent to it")
	maw.cmd_deploy()
	await wait_for(func() -> bool: return maw.tesla_mode == "deployed", 6.0)
	maw.nb["food"] = 150.0
	maw.cmd_uproot(false)
	await wait(float(Defs.NB["maw_switch"]) + 0.3)
	check(maw.tesla_mode == "packed" and float(maw.nb.get("food", 0.0)) == 150.0, "   HAUL: it keeps its food uprooted")
	maw.cmd_move(spot_near(maw.position, 6.0))
	await wait(1.0)
	check(maw.speed < float(maw.d["speed"]) * 0.6, "   and walks at half speed (%.0f of %.0f)" % [maw.speed, float(maw.d["speed"])])
	var at: Vector2 = maw.position
	maw.take_damage(99999.0, null)
	await wait(0.1)
	var burst: Array = g.units.filter(func(u) -> bool: return u.kind == BroodNew.PILE and not u.dead and u.position.distance_to(at) < 60.0)
	check(not burst.is_empty() and float(burst[0].nb["food"]) >= 140.0, "   killed hauling: it bursts, all of it a pile (%.0f)" % (float(burst[0].nb["food"]) if not burst.is_empty() else 0.0))
	# 7. grubs carry food to the Mother
	var m2: Unit = g._add_unit(BroodNew.MAW, 0, spot_near(q.position, 7.0))
	m2.cmd_deploy()
	await wait_for(func() -> bool: return m2.tesla_mode == "deployed", 6.0)
	m2.nb["food"] = 200.0
	for gr in mine("grub"):
		gr.auto_work = true
		gr.cmd_gather(m2)
	p["gold"] = 0
	var paid: bool = await wait_for(func() -> bool: return int(p["gold"]) >= 20, 40.0)
	check(paid, "7. grubs carry food from the Rootmaw to the Mother (%d biomass)" % int(p["gold"]))
	check(mine("grub").any(func(gr) -> bool: return gr.anim == "harvest" or gr.work == "feeding" or gr.carrying > 0), "   harvesting at its flank")
	# 9 (after 8). a saved game keeps the new Brood: captured now, continued after the end
	q.nb["eggs"] = 7
	var saved = JSON.parse_string(JSON.stringify(SaveGame.capture(g, main.last_cfg)))
	var maws_rooted: int = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == BroodNew.MAW and u.tesla_mode == "deployed").size()
	# 10. the Mound Turtle (the old Clutch Mound): rooted, supply, faster eggs and swamp; uprooted, none
	var cap0: int = int(p["cap"])
	var rate0: float = BroodNew.egg_rate(g, 0)
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, spot_near(q.position, 9.0))
	tu.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 0.6)
	check(tu.tesla_mode == "deployed" and int(p["cap"]) == cap0 + int(Defs.NB["turtle_supply"]), "10. a rooted Mound Turtle gives %d supply (%d -> %d)" % [int(Defs.NB["turtle_supply"]), cap0, int(p["cap"])])
	check(BroodNew.egg_rate(g, 0) > rate0 + 0.05 and g.on_swamp(0, tu.position + Vector2(8.0 * Defs.TILE, 0)) or g.on_swamp(0, tu.position + Vector2(-8.0 * Defs.TILE, 0)), "    faster eggs (x%.2f) and swamp far round it" % BroodNew.egg_rate(g, 0))
	tu.cmd_uproot(true)
	await wait(float(Defs.NB["turtle_switch"]) + 0.6)
	check(tu.tesla_mode == "packed" and int(p["cap"]) == cap0, "    uprooted: no supply (%d)" % int(p["cap"]))
	# 11. SACRIFICE at the Mother: she devours it
	var r1: Unit = g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	var ess0: float = float(p["res2"])
	r1.cmd_sacrifice()
	var ate: bool = await wait_for(func() -> bool: return float(p["res2"]) > ess0, 8.0)
	check(ate and float(q.nb.get("devour", 0.0)) > 0.0 and BroodNew.anim(q, false) == "attack", "11. SACRIFICE at the Mother: essence %.0f -> %.0f, she devours it (a swipe)" % [ess0, float(p["res2"])])
	# 8. killing the Mother loses
	q.take_damage(999999.0, null)
	var out: bool = await wait_for(func() -> bool: return bool(g.eliminated[0]), 3.0)
	check(out and g.over, "8. the Mother killed: that side is out and the match is over")
	check(saved is Dictionary and not (saved as Dictionary).is_empty() and (saved as Dictionary).has("nb"), "9. the match saves (with the Rootmaws' ground)")
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		var cfg: Dictionary = (saved["cfg"] as Dictionary).duplicate(true)
		cfg["resume"] = saved
		main.start(cfg)
		await process_frame
		await process_frame
		g = main.game
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		if g.hud:
			g.hud.countdown = 0.0
		await wait(1.0)
		var q2: Unit = BroodNew.queen(g, 0)
		var rooted2: int = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == BroodNew.MAW and u.tesla_mode == "deployed").size()
		check(BroodNew.on(g, 0) and q2 != null and int(q2.nb.get("eggs", 0)) >= 7 and q2.tesla_mode == "deployed",
			"   continued: the side is still the new Brood, its Mother rooted with her eggs (%s)" % (str(q2.nb.get("eggs")) if q2 else "none"))
		check(rooted2 == maws_rooted and not g.nb_spots.is_empty(), "   its rooted Rootmaws (%d of %d) and their ground" % [rooted2, maws_rooted])
		check(g.buildings.filter(func(b) -> bool: return b.team == 0).is_empty() and not bool(g.eliminated[0]), "   no buildings, and not out")
	print("brood_new: %d failures" % fails)
	quit(1 if fails > 0 else 0)
