extends SceneTree
## THE NEW BROOD (experiment: scripts/brood_new.gd, docs/brood_new.md), its rules in a real match:
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_new.gd
##  0. the start: no buildings, the Brood Mother, a Rootmaw and 5 grubs; both finish rooting in a moment; supply 40 + 20
##  1. rooted: armour and less damage (the same blow on a rooted and an uprooted Rootmaw)
##  2. the Mother lays an egg while she walks (it drops behind her)
##  3. warriors' eggs are fertilised only by the father ROOTED on his nest near the Mother (refused without him, far
##     off or standing; rooted he takes less damage; her eggs go into his nest, 2 queued; fertilised by his breath;
##     they hatch there as 2 Raptors); when he gets up the egg lies on the ground and, never fertilised, hatches as a
##     grub (the difference paid back)
##  4. one Tyrannosaur at a time (an egg for one counts)
##  5. a Rootmaw drinks its ground into its body; rooted circles may not overlap
##  6. UPROOT spills its food as a pile (grubs take from it; it rots); HAUL carries it, slower; killed hauling it bursts
##  7. grubs carry food from the Rootmaw to the Mother (biomass comes in)
##  8. killing the Mother loses the game
##  15. ROOTED = A BUILDING (the owner's playtest of 0.15.13, scripts/brood_root.gd): the Mother can't lay the
##     structure-units, a grub turns into one (walks, pays, cocoon, rooted), one Tyrannosaur counts the morphing grub;
##     a footprint on the grid that blocks paths and pushes units out; the building layer; a right-click sets the
##     rally (never uproots), given to her eggs and their hatchlings; ROOT like BUILD (walks to the spot, roots on it);
##     the building card; idle stillness; the computer's Mother doesn't flip-flop under fire from range
##  16. THE OWNER'S PLAYTEST OF 0.15.14: the grub's BUILD menu (B), its own text (no old Brood word), the laying show
##     2.5-3 s (her rate not slowed), the worker count over a Rootmaw and a pile, a click on her drawn body (a unit over
##     her first), the Tyrannosaur fertilising till the last egg hatched, eggs on the nearest empty spot (boxed in: on a
##     creature, on top; the hatchling walks out through its own side's creatures to the rally), her GROWING bar on the
##     HUD and STOP GROWING, the other progress (egg, cocoon, uprooting)
##  17. THE ROOTED ART ON ITS FOOTPRINT (the owner, 2026-10-29): each rooted creature's drawn bottom on its footprint's
##     bottom edge (the Mother at stages 1 and 3), the selection frame under its pictures, no jump when it roots (the
##     drop eased over the rooting frames), the father's nest point and the ghost's picture moved with the art
##  18. THE THREE FATHERS (the owner, 2026-10-29 11:10): the lines (Tyrannosaur: Raptor, Brute; Dilophosaurus:
##     Spitter, Mist Toad; Pterodactyl: Skywing; no Bloater), THE TIERS (the owner, 12:20: the Tyrant and Venom Sires
##     from the start, the Storm Sire at her stage 2; Raptors and Spitters (since 0.17.0) at stage 1, Brutes, Mist Toads, Skywings 3;
##     the reasons name the stage), each father
##     made from a grub (a cocoon that opens rooted beside her), one of each (the morphing grub counts), her card's
##     refusals name the right father, each line's eggs go to its own father's nest and are fertilised all at once
##     there, the pheromones of three fathers stack, the Pterodactyl a ground structure rooted (a Musketeer can shoot
##     it, its footprint solid) and a flyer uprooted (it flies over and lands again on its nest), the Toad only
##     staggers every father
##  19. YOUNG AND MATURE (the owner, 2026-10-29 12:40-14:40): eggs lay only the young; MATURE locked until her stage 2,
##     its price, the moult (can't move or fight, supply held), then the Challenger with its kills and health share; a
##     group as far as the food allows; both Challengers fight (the Venom one splashes); the MATURE button; the Mother's
##     own art at each stage; the computer matures
##  20. THE SIRE LURES (the owner, 2026-10-29 18:03-18:31): a grub swells into a Sire's lure, ripens, the Sire arrives
##     and nests on its spot, his eggs in front of his footprint, a lure killed early, one Sire at a time counts the
##     lure, the computer's Sire through a lure, a match saved mid-lure and continued
##  21. THE BROOD'S RESEARCH (the owner, 2026-10-29 18:31 and 18:59; scripts/brood_research.gd): young two to an egg (a
##     Raptor egg 50, a Spitter egg 90 + 5) and three with BIGGER CLUTCH (75; 135 + 8), the research buttons on a rooted
##     Sire's card and the Mother's, a Sire researching lays no eggs of his line but keeps his loop (RESEARCHING on his card,
##     STOP RESEARCH), the Mother keeps laying while she researches (and can't grow), each effect (PACK HUNT, BATTERING
##     HORNS, SLITHER, LONG SPIT, UPDRAFT, QUICK ROOTS, SWAMP MENDING), a Sire killed or uprooted mid-research (paid back,
##     finished research stays), Spitters can't target flyers (the Venom Challenger can), the computer researches, a match
##     saved mid-research and continued (resumed at the end of the run)
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
		if g._walkable(c) and int(g.height[g.idx(c)]) == h and g.region_of(c) == BroodRoot.home_region(g, p):
			return q
	return p


## A spot `tiles` (or about) from p where a `k` may root (BroodRoot.place_problem); swamp: the Rootmaw's swamp rule.
func free_spot(k: String, p: Vector2, tiles: float, me = null, swamp := true) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles - 1.0, tiles + 2.0, tiles - 2.0, tiles + 3.0, tiles + 4.0]:
		for i in 32:
			var s: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 32.0) * maxf(r, 0.0) * Defs.TILE)
			if g.region_of(g.cell_of(s)) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, 0, k, s, me, false, 1.0, swamp) == "":
				return s
	return p


func card_labels() -> Array:
	var out: Array = []
	if g.hud:
		for it in g.hud._build_card():
			out.append(String(it[1]))
	return out


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
	check(g.on_swamp(0, q.position) and g.on_swamp(0, maw.position), "   swamp round the rooted Mother, and under the Rootmaw")
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
	var walk_to: Vector2 = free_spot(BroodNew.QUEEN, q.position, 3.0, q)      # (where she may root again: her footprint clear)
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
	check(BroodNew.lay_problem(g, q, "raptor").contains("Tyrant Sire"), "3. no father: a Raptor's egg is refused (%s)" % BroodNew.lay_problem(g, q, "raptor"))
	check(BroodNew.lay_problem(g, q, "spitter").contains("Venom Sire"), "   a Spitter's egg (stage 1 since the owner's 14:40) waits for the Venom Sire (%s)" % BroodNew.lay_problem(g, q, "spitter"))
	check(not BroodNew.hatch_list().has("spore_mother") and BroodNew.hatch_list().has("spitter"), "   on her card: Spitters, not the retired Spore Mother")
	var far := spot_near(q.position, 20.0)
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, far)
	await wait(0.3)
	check(not BroodNew.father_near(g, 0) and BroodNew.lay_problem(g, q, "raptor") != "", "   the father far from her: still refused")
	f.position = free_spot(BroodNew.FATHER, q.position, 5.0, f)
	f.cmd_stop()
	await wait(0.3)
	check(not BroodNew.father_near(g, 0) and BroodNew.lay_problem(g, q, "raptor").contains("rooted"), "   the father beside her but standing: still refused (%s)" % BroodNew.lay_problem(g, q, "raptor"))
	var fwhy := BroodNew.root_problem(g, f)
	f.cmd_deploy()
	var on_nest: bool = await wait_for(func() -> bool: return f.tesla_mode == "deployed", float(Defs.NB["father_switch"]) + 2.0)
	check(on_nest and BroodNew.father_near(g, 0) and BroodNew.lay_problem(g, q, "raptor") == "", "   ROOTED on his nest beside her: allowed (%s)" % fwhy)
	if not on_nest:
		print("brood_new: %d failures (stopped: the father did not root)" % fails)
		quit(1)
		return
	check(BroodNew.incoming(f, 20.0) < 20.0, "   rooted, he takes less damage (20 -> %.1f)" % BroodNew.incoming(f, 20.0))
	var r0: int = mine("raptor").size()
	q.cmd_lay("raptor")
	await wait(0.1)
	var re: Unit = mine(BroodNew.EGG).back()
	check(re != null and int(re.nb["fert"]) == 1 and bool(re.nb.get("nest", false)) and re.position.distance_to(BroodNew.nest_point(f)) < 2.0 \
			and re.position.y > BroodRoot.rect_of(f).end.y and re.z_index == BroodNew.EGG_Z and re.sprite.visible, "   the Raptor egg goes into his nest: IN FRONT of his footprint, seen, on the top layer")
	q.cmd_lay("raptor")
	await wait(0.1)
	check(BroodNew.nest_eggs(g, f).size() == 2, "   a second one: 2 eggs in the nest (%d)" % BroodNew.nest_eggs(g, f).size())
	var fert: bool = await wait_for(func() -> bool: return int(re.nb["fert"]) == 2, 6.0)
	check(fert, "   he breathes on it: fertilised (red)")
	# (all at once: the eggs in his nest redden together; the second, laid a moment later, is already well on when the first is done)
	var others := 0
	var busy := 0
	for ne in BroodNew.nest_eggs(g, f):
		if ne != re:
			others += 1
			if int(ne.nb.get("fert", 0)) == 2 or float(ne.nb.get("redden", 0.0)) > 0.2:
				busy += 1
	var all2: bool = await wait_for(func() -> bool:
		for ne in BroodNew.nest_eggs(g, f):
			if int(ne.nb.get("fert", 0)) != 2:
				return false
		return true, float(Defs.NB["fert_time"]) + 0.5)
	check(others > 0 and busy == others and all2, "   ALL the eggs in his nest fertilised together, not one at a time (the owner, 22:42: %d of %d already under his breath)" % [busy, others])
	var got3: bool = await wait_for(func() -> bool: return mine("raptor").size() >= r0 + 2, Defs.UNITS["raptor"]["time"] + 3.0)
	var at_nest := 0
	for rp in mine("raptor"):
		if rp.position.distance_to(BroodNew.nest_point(f)) < 60.0:
			at_nest += 1
	check(got3 and at_nest >= 2, "   it hatches as 2 Raptors (two to an egg since 0.20.0), in the nest (%d, %d by it)" % [mine("raptor").size() - r0, at_nest])
	await wait_for(func() -> bool: return BroodNew.nest_eggs(g, f).is_empty(), Defs.UNITS["raptor"]["time"] + 5.0)
	# an egg the father never breathes on: he gets up, it lies on the ground, a grub after all, the difference paid back
	for rp in mine("raptor"):
		g.consume_unit(rp)          # (room in the supply for one more egg)
	var old_eggs: Array = mine(BroodNew.EGG)
	var lwhy: String = q.cmd_lay("raptor")
	check(lwhy == "", "   one more Raptor egg (%s)" % lwhy)
	await wait(0.05)
	var lone: Unit = mine(BroodNew.EGG).filter(func(e) -> bool: return not old_eggs.has(e)).back()
	f.cmd_uproot(false)
	await wait(0.2)
	check(not bool(lone.nb.get("nest", false)), "   he gets up: the egg in his nest lies on the ground")
	await wait_for(func() -> bool: return f.tesla_mode == "packed", float(Defs.NB["father_switch"]) + 2.0)
	f.position = far
	f.cmd_stop()
	var gold_a: int = int(p["gold"])
	var turned: bool = await wait_for(func() -> bool: return String(lone.nb.get("k", "")) == "grub", float(Defs.NB["fert_wait"]) + 2.0)
	check(turned and int(lone.nb["fert"]) == 0, "   not fertilised in %d s: it hatches as a grub" % int(Defs.NB["fert_wait"]))
	check(int(p["gold"]) - gold_a == int(Defs.UNITS["raptor"]["cost"]) - int(Defs.UNITS["grub"]["cost"]), "   the difference paid back (+%d)" % (int(p["gold"]) - gold_a))
	# 4. one father at a time (a grub turns into him now: the Mother lays none)
	check(BroodNew.lay_problem(g, q, BroodNew.FATHER).begins_with("A grub turns into it"), "4. the Mother lays no Tyrannosaur: %s" % BroodNew.lay_problem(g, q, BroodNew.FATHER))
	check(BroodRoot.morph_problem(g, 0, BroodNew.FATHER).begins_with("Only one"), "   one Tyrannosaur at a time: %s" % BroodRoot.morph_problem(g, 0, BroodNew.FATHER))
	f.die()
	await wait(0.2)
	check(BroodRoot.morph_problem(g, 0, BroodNew.FATHER) == "", "   it died: a grub can turn into another")
	var fg: Unit = mine("grub")[0]
	fg.give({"o": "nb_morph", "k": BroodNew.FATHER, "p": free_spot(BroodNew.FATHER, q.position, 5.0)})
	await wait(0.05)
	check(BroodRoot.morph_problem(g, 0, BroodNew.FATHER).begins_with("Only one"), "   a grub on its way to turn into one counts")
	fg.cmd_stop()
	fg.nb.erase("mk")
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
	check(maw.speed < float(maw.d["speed"]) * 0.7, "   and walks at half speed (with the swamp's speed on top) (%.0f of %.0f)" % [maw.speed, float(maw.d["speed"])])
	var at: Vector2 = maw.position
	maw.take_damage(99999.0, null)
	await wait(0.1)
	var burst: Array = g.units.filter(func(u) -> bool: return u.kind == BroodNew.PILE and not u.dead and u.position.distance_to(at) < 60.0)
	check(not burst.is_empty() and float(burst[0].nb["food"]) >= 140.0, "   killed hauling: it bursts, all of it a pile (%.0f)" % (float(burst[0].nb["food"]) if not burst.is_empty() else 0.0))
	# 7. grubs carry food to the Mother
	var m2: Unit = g._add_unit(BroodNew.MAW, 0, free_spot(BroodNew.MAW, q.position, 9.0))
	m2.cmd_deploy()
	await wait_for(func() -> bool: return m2.tesla_mode == "deployed", 6.0)
	m2.nb["food"] = 200.0
	for gr in mine("grub"):
		gr.auto_work = true
		gr.cmd_gather(m2)
	p["gold"] = 0
	var paid: bool = await wait_for(func() -> bool: return int(p["gold"]) >= 20, 40.0)
	check(paid, "7. grubs carry food from the Rootmaw to the Mother (%d biomass)" % int(p["gold"]))
	var at_flank: bool = await wait_for(func() -> bool: return mine("grub").any(func(gr) -> bool: return gr.anim == "harvest" or gr.work == "feeding" or gr.carrying > 0), 5.0)
	check(at_flank, "   harvesting at its flank")          # (a moment after: they may all have just delivered together)
	# 12. the turtle is the expansion: a Rootmaw roots only on its side's swamp (any: it need not join the Mother's)
	var far2 := free_spot(BroodNew.MAW, q.position, 21.0, null, false)
	var dir2: Vector2 = (far2 - q.position).normalized()
	var mx: Unit = g._add_unit(BroodNew.MAW, 0, far2)
	mx.cmd_deploy()
	await wait(0.3)
	check(mx.tesla_mode == "packed", "12. a Rootmaw 21 tiles out (off her swamp) may not root")
	var tx: Unit = g._add_unit(BroodNew.TURTLE, 0, free_spot(BroodNew.TURTLE, q.position + dir2 * 14.0 * Defs.TILE, 0.0))
	tx.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.2)
	check(BroodNew.on_swamp(g, 0, far2), "    a Mound Turtle rooted 14 tiles out spreads swamp there")
	mx.cmd_deploy()
	await wait(float(Defs.NB["maw_switch"]) + 1.0)
	mx.nb["food"] = 0.0
	await wait(2.0)
	check(mx.tesla_mode == "deployed" and float(mx.nb["food"]) > 3.0, "    now the Rootmaw roots there and feeds (%.0f food)" % float(mx.nb["food"]))
	tx.take_damage(999999.0, null)
	var dried: bool = await wait_for(func() -> bool: return bool(mx.nb.get("dry", false)), 30.0)
	var f0: float = float(mx.nb["food"])
	await wait(2.0)
	check(dried and float(mx.nb["food"]) <= f0 + 0.01, "    the turtle killed: its swamp shrinks back and the Rootmaw stops feeding")
	mx.take_damage(999999.0, null)
	# 13. a rooted turtle closes a ramp (body-blocks it, as the Crown's wall)
	var ramp_c := Vector2i(-1, -1)
	var best_d := -1.0
	for y in Game.H:
		for x in Game.W:
			# (the ramp farthest from the Mother and anything of hers)
			if g.ramp[g.idx(Vector2i(x, y))] != 0 and Vector2(x, y).distance_to(q.position / Defs.TILE) > best_d:
				best_d = Vector2(x, y).distance_to(q.position / Defs.TILE)
				ramp_c = Vector2i(x, y)
	var cells: Array = [ramp_c]
	var seen := {ramp_c: true}
	var ki := 0
	while ki < cells.size():
		var c: Vector2i = cells[ki]
		ki += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if g.in_map(n) and not seen.has(n) and g.ramp[g.idx(n)] != 0:
				seen[n] = true
				cells.append(n)
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-1, -1)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var mid: Vector2 = (Vector2(lo + hi) * 0.5 + Vector2(0.5, 0.5)) * Defs.TILE
	# the way up: the axis whose two ends are at different heights
	var my := (lo.y + hi.y) / 2
	var mxx := (lo.x + hi.x) / 2
	var hx: bool = g.in_map(Vector2i(lo.x - 1, my)) and g.in_map(Vector2i(hi.x + 1, my)) \
		and g.height[g.idx(Vector2i(lo.x - 1, my))] != g.height[g.idx(Vector2i(hi.x + 1, my))]
	var along := Vector2(1, 0) if hx else Vector2(0, 1)
	var span: int = (hi.x - lo.x + 1) if hx else (hi.y - lo.y + 1)
	var wide: int = (hi.y - lo.y + 1) if hx else (hi.x - lo.x + 1)
	var half_len: float = (float(span) * 0.5 + 4.0) * Defs.TILE
	var wall: Unit = g._add_unit(BroodNew.TURTLE, 0, BroodRoot.feet_at(BroodNew.TURTLE, BroodRoot.cell_centred(BroodNew.TURTLE, mid)))
	wall.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 0.5)
	var runners: Array = []
	for i in 8:
		var r: Unit = g._add_unit("raptor", 1, mid - along * half_len + along.orthogonal() * float(i % 3 - 1) * 14.0 - along * float(i / 3) * 16.0)
		runners.append(r)
		r.cmd_move(mid + along * half_len)
	await wait(25.0)
	var through: int = runners.filter(func(r) -> bool: return is_instance_valid(r) and not r.dead and (r.position - mid).dot(along) > BroodRoot.rect_for(BroodNew.TURTLE, BroodRoot.snap(BroodNew.TURTLE, mid)).size.x * 0.5 + 26.0).size()
	check(through == 0, "13. a rooted Mound Turtle closes a ramp %d tiles wide (%d long): %d of 8 Raptors got past in 25 s (ramp cells %s..%s, turtle %s, %s)" % [wide, span, through, str(lo), str(hi), str(wall.rect()), wall.tesla_mode])
	wall.cmd_uproot(true)
	await wait(float(Defs.NB["turtle_switch"]) + 0.3)
	wall.cmd_move(mid + along.orthogonal() * 6.0 * Defs.TILE)
	var killed: int = runners.filter(func(r) -> bool: return not is_instance_valid(r) or r.dead).size()
	check(true, "    (meanwhile the turtle bit %d of the 8 to death: they kept at it and its shell shrugs off their claws)" % killed)
	await wait(4.0)
	runners.clear()
	for i in 8:
		var r2: Unit = g._add_unit("raptor", 1, mid - along * half_len + along.orthogonal() * float(i % 3 - 1) * 14.0 - along * float(i / 3) * 16.0)
		runners.append(r2)
		r2.cmd_move(mid + along * half_len)
	await wait(12.0)
	through = runners.filter(func(r) -> bool: return is_instance_valid(r) and not r.dead and (r.position - mid).dot(along) > BroodRoot.rect_for(BroodNew.TURTLE, BroodRoot.snap(BroodNew.TURTLE, mid)).size.x * 0.5 + 26.0).size()
	check(through >= 6, "    uprooted and moved off: the ramp is open again (%d of 8 through)" % through)
	for r in runners:
		if is_instance_valid(r) and not r.dead:
			g.consume_unit(r)
	g.consume_unit(wall)
	# 9 (after 8). a saved game keeps the new Brood: captured now, continued after the end
	q.nb["eggs"] = 7
	var saved = JSON.parse_string(JSON.stringify(SaveGame.capture(g, main.last_cfg)))
	var maws_rooted: int = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == BroodNew.MAW and u.tesla_mode == "deployed").size()
	# 10. the Mound Turtle (the old Clutch Mound): rooted, supply, faster eggs and swamp; uprooted, none
	var cap0: int = int(p["cap"])
	var rate0: float = BroodNew.egg_rate(g, 0)
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, free_spot(BroodNew.TURTLE, q.position, 9.0))
	tu.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 0.6)
	check(tu.tesla_mode == "deployed" and int(p["cap"]) == cap0 + int(Defs.NB["turtle_supply"]), "10. a rooted Mound Turtle gives %d supply (%d -> %d)" % [int(Defs.NB["turtle_supply"]), cap0, int(p["cap"])])
	check(absf(BroodNew.egg_rate(g, 0) - rate0) < 0.001 and (g.on_swamp(0, tu.position + Vector2(8.0 * Defs.TILE, 0)) or g.on_swamp(0, tu.position + Vector2(-8.0 * Defs.TILE, 0))), "    at home: swamp far round it, but no faster eggs (x%.2f, was x%.2f)" % [BroodNew.egg_rate(g, 0), rate0])
	# an EXPANSION: a turtle rooted on new ground (15+ tiles from her) makes her lay faster; a second one beside it doesn't
	var newg: Vector2 = free_spot(BroodNew.TURTLE, q.position, float(Defs.NB["expansion_tiles"]) + 2.0)
	var nb_tx: Unit = g._add_unit(BroodNew.TURTLE, 0, newg)
	nb_tx.cmd_deploy()
	var nb_tx2: Unit = g._add_unit(BroodNew.TURTLE, 0, free_spot(BroodNew.TURTLE, newg + (newg - q.position).normalized() * 4.5 * Defs.TILE, 0.0))
	nb_tx2.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 0.6)
	var nb_lr: Array = BroodNew.lay_rate(g, q)
	check(int(nb_lr[3]) == 1 and absf(float(nb_lr[0]) - float(nb_lr[1]) * (1.0 + float(Defs.NB["father_rate"]) * int(nb_lr[2]) + float(Defs.NB["expansion_rate"]))) < 0.001,
		"    on new ground (%.0f tiles out): 1 expansion, +%d%% (a second turtle beside it doesn't count): %s" % [newg.distance_to(q.position) / Defs.TILE, int(float(Defs.NB["expansion_rate"]) * 100.0), BroodNew.levers_text(g, q)])
	nb_tx.take_damage(999999.0, null)
	await wait(0.5)
	check(BroodNew.expansions(g, q).size() == 1 and BroodNew.expansions(g, q)[0] == nb_tx2, "    it dies: the other one counts now (%d)" % BroodNew.expansions(g, q).size())
	g.consume_unit(nb_tx2)
	await wait(0.2)
	tu.cmd_uproot(true)
	await wait(float(Defs.NB["turtle_switch"]) + 0.6)
	check(tu.tesla_mode == "packed" and int(p["cap"]) == cap0, "    uprooted: no supply (%d)" % int(p["cap"]))
	# 11. SACRIFICE at the Mother: she devours it. The eggs it gives back are per EGG (the owner, 2026-10-30): the young
	# of one egg together give ONE egg (two Raptors of one egg: one egg and twice the spoils; three of a BIGGER CLUTCH:
	# one egg); a creature hatched alone (a Brute) gives a whole egg
	q.nb["eggs"] = 2
	q.nb["eggp"] = 0
	q.nb["egg_t"] = -1000.0        # (no egg grows meanwhile: the count is the offering's)
	var one_egg := [g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0)), g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 40.0))]
	for r in one_egg:
		r.clutch_n = 2           # (two young of one egg, as BroodNew._hatch marks them)
	var ess0: float = float(p["res2"])
	var eggs_s0: int = 2
	one_egg[0].cmd_sacrifice()
	var ate: bool = await wait_for(func() -> bool: return float(p["res2"]) > ess0, 8.0)
	check(ate and float(q.nb.get("devour", 0.0)) > 0.0 and BroodNew.anim(q, false) == "attack", "11. SACRIFICE at the Mother: spoils %.0f -> %.0f, she devours it (a swipe)" % [ess0, float(p["res2"])])
	check(int(q.nb.get("eggs", 0)) == eggs_s0 and int(q.nb.get("eggp", 0)) == BroodNew.EGG_PARTS / 2, "    the first young of an egg: half an egg kept on her, no egg yet (%d eggs, %d/%d)" % [int(q.nb.get("eggs", 0)), int(q.nb.get("eggp", 0)), BroodNew.EGG_PARTS])
	var ess_mid: float = float(p["res2"])
	one_egg[1].cmd_sacrifice()
	await wait_for(func() -> bool: return float(p["res2"]) > ess_mid, 8.0)
	check(int(q.nb.get("eggs", 0)) == eggs_s0 + 1 and int(q.nb.get("eggp", 0)) == 0 and is_equal_approx(float(p["res2"]) - ess0, 2.0 * Game.sacrifice_value("raptor")),
		"    both young of one egg: ONE egg back (%d -> %d) and twice the spoils (+%.0f, %d each)" % [eggs_s0, int(q.nb.get("eggs", 0)), float(p["res2"]) - ess0, Game.sacrifice_value("raptor")])
	var sac_three := []
	for i in 3:
		var r: Unit = g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0 * i))
		r.clutch_n = 3           # (a BIGGER CLUTCH egg's three)
		sac_three.append(r)
	var eggs_s1: int = int(q.nb.get("eggs", 0))
	var sac_got := []
	for r in sac_three:
		var e0: float = float(p["res2"])
		r.cmd_sacrifice()
		await wait_for(func() -> bool: return float(p["res2"]) > e0, 8.0)
		sac_got.append(int(q.nb.get("eggs", 0)) - eggs_s1)
	check(sac_got == [0, 0, 1] and int(q.nb.get("eggp", 0)) == 0, "    three young of a BIGGER CLUTCH egg: one egg, after the third (eggs back after each: %s)" % str(sac_got))
	var sac_egg: Unit = g._add_unit(BroodNew.EGG, 0, q.position + Vector2(0, q.radius + 90.0))
	sac_egg.nb["k"] = "raptor"
	sac_egg.nb["n"] = 3
	BroodNew._hatch(g, sac_egg)
	var sac_young: Array = g.units.filter(func(u) -> bool: return u.kind == "raptor" and u.team == 0 and u.clutch_n == 3 and u.position.distance_to(sac_egg.position) < 30.0)
	check(sac_young.size() == 3, "    an egg of three hatches three young marked as one egg's three (%d)" % sac_young.size())
	for u in sac_young:
		g.consume_unit(u)
	var sac_br: Unit = g._add_unit("brute", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	var eggs_s2: int = int(q.nb.get("eggs", 0))
	var eb: float = float(p["res2"])
	sac_br.cmd_sacrifice()
	await wait_for(func() -> bool: return float(p["res2"]) > eb, 10.0)
	check(int(q.nb.get("eggs", 0)) == eggs_s2 + 1, "    a Brute (one to an egg): a whole egg (%d -> %d)" % [eggs_s2, int(q.nb.get("eggs", 0))])
	q.nb["eggs"] = BroodNew.eggs_max(q)
	q.nb["eggp"] = BroodNew.EGG_PARTS / 2
	var r2: Unit = g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	r2.clutch_n = 2
	var ess1: float = float(p["res2"])
	r2.cmd_sacrifice()
	await wait_for(func() -> bool: return float(p["res2"]) > ess1, 8.0)
	check(int(q.nb.get("eggs", 0)) == BroodNew.eggs_max(q) and int(q.nb.get("eggp", 0)) == 0, "    her clutch full: the egg it makes is lost, spoils still paid (%d eggs, %d parts)" % [int(q.nb.get("eggs", 0)), int(q.nb.get("eggp", 0))])
	await _grub_sacrifice(q, p)
	q.nb["egg_t"] = 0.0
	# 12. no rooted creature attacks (the owner, 17:14): rooted, the Mother, a Rootmaw, a turtle and the Tyrannosaur can't
	# hit a foe beside them; uprooted, they can
	var foe: Unit = g._add_unit("musketeer", 1, q.position + Vector2(0, 400))
	var rooted_hit := []
	for k in [BroodNew.QUEEN, BroodNew.MAW, BroodNew.TURTLE, BroodNew.FATHER]:
		var c: Unit = q if k == BroodNew.QUEEN else g._add_unit(k, 0, q.position + Vector2(0, 360))
		var was: String = c.tesla_mode
		c.tesla_mode = "deployed"
		if c.can_hit(foe):
			rooted_hit.append(k)
		c.tesla_mode = "packed"
		if not c.can_hit(foe):
			rooted_hit.append(k + " (not even uprooted)")
		c.tesla_mode = was
		if c != q:
			g.consume_unit(c)
	g.consume_unit(foe)
	check(rooted_hit.is_empty(), "12. no rooted creature attacks; uprooted they do (%s)" % str(rooted_hit))
	# 14. her GROWTH STAGES: GROW costs, takes its time rooted, no laying meanwhile; then more eggs held, faster laying,
	# a bigger body and swamp; stage 3 needs essence
	var nb_stages: Array = Defs.NB["stages"]
	p["gold"] = 2000
	p["res2"] = 0.0
	q.nb["eggs"] = 4
	var nb_g0: int = int(p["gold"])
	var nb_r_before: float = q.radius
	var nb_gw: String = q.cmd_grow()
	check(nb_gw == "" and int(p["gold"]) == nb_g0 - int(nb_stages[1]["cost"]) and float(q.nb.get("grow_t", 0.0)) > 0.0, "14. GROW: paid %d food, growing %.0f s (%s)" % [nb_g0 - int(p["gold"]), float(q.nb.get("grow_t", 0.0)), nb_gw])
	check(BroodNew.lay_problem(g, q, "grub").begins_with("She is growing"), "    no laying while she grows: %s" % BroodNew.lay_problem(g, q, "grub"))
	q.nb["egg_t"] = 0.0
	await wait(float(Defs.NB["egg_time"]) + 1.0)
	check(int(q.nb.get("eggs", 0)) == 4, "    and no new eggs grow meanwhile (%d)" % int(q.nb.get("eggs", 0)))
	var nb_grown: bool = await wait_for(func() -> bool: return BroodNew.stage(q) == 1, float(nb_stages[1]["time"]) + 2.0)
	check(nb_grown and BroodNew.eggs_max(q) == int(nb_stages[1]["eggs"]) and BroodNew.drawn_r(q) > nb_r_before * 1.1 and q.radius <= BroodNew.BODY_R and absf(float(BroodNew.lay_rate(g, q)[1]) - float(nb_stages[1]["rate"])) < 0.001,
		"    stage 2 after %d s: %d eggs held, laying x%.2f, drawn %.0f -> %.0f px, her walking body capped (%.0f, ground %.0f)" % [int(nb_stages[1]["time"]), BroodNew.eggs_max(q), float(BroodNew.lay_rate(g, q)[1]), nb_r_before, BroodNew.drawn_r(q), q.radius, q.ground_r()])
	check(BroodNew.swamp_sources(g, 0).any(func(sw) -> bool: return absf(float(sw[1]) - float(nb_stages[1]["swamp"])) < 0.01), "    her swamp %.1f tiles" % float(nb_stages[1]["swamp"]))
	check(BroodNew.grow_problem(g, q).contains(String(Defs.FACTIONS["brood"]["res"][1]).to_lower()), "    stage 3 needs essence: %s" % BroodNew.grow_problem(g, q))
	p["res2"] = 200.0
	q.cmd_uproot(false)
	await wait(0.2)
	check(BroodNew.grow_problem(g, q) != "", "    uprooted she can't grow: %s" % BroodNew.grow_problem(g, q))
	q.cmd_deploy()
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", float(Defs.NB["queen_switch"]) + 2.0)
	var nb_g1: int = int(p["gold"])
	q.cmd_grow()
	q.cmd_uproot(false)
	await wait(0.3)
	check(int(p["gold"]) == nb_g1 and BroodNew.stage(q) == 1, "    uprooting while growing stops it and pays it back (%d)" % int(p["gold"]))
	q.cmd_deploy()
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", float(Defs.NB["queen_switch"]) + 2.0)
	q.cmd_grow()
	var nb_grown3: bool = await wait_for(func() -> bool: return BroodNew.stage(q) == 2, float(nb_stages[2]["time"]) + 2.0)
	check(nb_grown3 and BroodNew.eggs_max(q) == int(nb_stages[2]["eggs"]) and absf(float(BroodNew.lay_rate(g, q)[1]) - float(nb_stages[2]["rate"])) < 0.001 and BroodNew.grow_problem(g, q) == "She is fully grown.",
		"    stage 3: %d eggs, laying x%.2f; fully grown" % [BroodNew.eggs_max(q), float(BroodNew.lay_rate(g, q)[1])])
	# a father near her: his pheromones (+father_rate); away from her: nothing
	var nb_fx: Unit = g._add_unit(BroodNew.FATHER, 0, q.position + Vector2(-q.radius - 60.0, 30.0))
	await wait(0.2)
	var nb_lr2: Array = BroodNew.lay_rate(g, q)
	check(int(nb_lr2[2]) >= 1 and absf(float(nb_lr2[0]) - float(nb_lr2[1]) * (1.0 + float(Defs.NB["father_rate"]) * int(nb_lr2[2]) + float(Defs.NB["expansion_rate"]) * int(nb_lr2[3]))) < 0.001, "    a Tyrannosaur near her: %s" % BroodNew.levers_text(g, q))
	nb_fx.position = spot_near(q.position, 20.0)
	await wait(0.2)
	check(int(BroodNew.lay_rate(g, q)[2]) == int(nb_lr2[2]) - 1, "    away from her: he gives nothing (%s)" % BroodNew.levers_text(g, q))
	g.consume_unit(nb_fx)
	await _rooted_is_a_building(q, p)
	await _fixes_2(q, p)
	await _rooted_art(q)
	await _fathers(q, p)
	await _mature(q, p)
	await _lures(q, p)
	await _storm_arrival(q)
	await _research(q, p)
	await _storm_line(q, p)
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
	await _lure_resumed()
	await _research_resumed()
	print("brood_new: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## 11b. GRUB SACRIFICE (the owner, 2026-10-30 08:19; docs/grub_sacrifice.md): a grub can be offered up for less than a
## Raptor (Defs.NB "sac": a grub 10 spoils, a Raptor 15, set by hand; the owner, 08:34) and gives its whole egg back (it hatches alone, like a Brute); a grub at work
## hands over what it carries there (food, a body's cocoon); a grub on its way to turn into something (nb_morph) can't be.
func _grub_sacrifice(q: Unit, p: Dictionary) -> void:
	check(Game.sacrifice_value("grub") == int(Defs.NB["sac"]["grub"]) and Game.sacrifice_value("grub") == 10 and Game.sacrifice_value("raptor") == 15 and Game.sacrifice_value("brute") == 53,
		"11b. GRUB SACRIFICE: a grub gives %d spoils, a Raptor %d (set by hand); a Brute on the formula %d" % [Game.sacrifice_value("grub"), Game.sacrifice_value("raptor"), Game.sacrifice_value("brute")])
	q.nb["eggs"] = 2
	q.nb["eggp"] = 0
	var gr: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	gr.cmd_stop()
	g.set_selection([gr])
	var labs := card_labels()
	var sac_key := ""
	for it in g.hud._with_keys(g.hud._build_card()):
		if String(it[1]) == "SACRIFICE":
			sac_key = String(it[it.size() - 1])
	check(gr.can_sacrifice() and labs.has("SACRIFICE") and (sac_key == "C" or (Settings.pc() and Settings.grid_keys)), "    SACRIFICE (%s) on the grub's card: %s" % [sac_key, str(labs)])
	g.set_selection([])
	var e0: float = float(p["res2"])
	var n0 := int(g.stats[0].get("sacrificed", 0))
	gr.cmd_sacrifice()
	await wait_for(func() -> bool: return int(g.stats[0].get("sacrificed", 0)) >= n0 + 1, 8.0)      # (not the grub: it is freed)
	check(is_equal_approx(float(p["res2"]) - e0, 10.0) and int(q.nb.get("eggs", 0)) == 3 and int(q.nb.get("eggp", 0)) == 0 and int(g.stats[0].get("sacrificed", 0)) == n0 + 1,
		"    a grub offered up: +%.0f spoils and its WHOLE egg back (2 -> %d eggs, %d parts)" % [float(p["res2"]) - e0, int(q.nb.get("eggs", 0)), int(q.nb.get("eggp", 0))])
	# from its work: a grub carrying food, one carrying a body's cocoon (HARVEST): what it carries is handed over at her
	var fg: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 60.0, 30.0))
	fg.carrying = 7
	fg.load_f = 7.0
	var hg: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 60.0, -30.0))
	hg.cmd_harvest()
	hg.cocoon = 6.0
	var gold0: float = float(p["gold"]) + float(p["gold_f"])
	var e1: float = float(p["res2"])
	check(fg.can_sacrifice() and hg.can_sacrifice(), "    grubs at work (carrying food, harvesting a body) can be sent")
	fg.cmd_sacrifice()
	hg.cmd_sacrifice()
	await wait_for(func() -> bool: return int(g.stats[0].get("sacrificed", 0)) >= n0 + 3, 10.0)
	var gold_in: float = float(p["gold"]) + float(p["gold_f"]) - gold0
	check(is_equal_approx(float(p["res2"]) - e1, 10.0 + 10.0 + 6.0) and gold_in >= 7.0 - 0.01,
		"    they hand over their loads first: +%.0f spoils (10 + 10 + the cocoon's 6), +%.1f food (its 7)" % [float(p["res2"]) - e1, gold_in])
	# a grub on its way to turn into something: not offered up, no button
	var mg: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 60.0, 60.0))
	var spot := free_spot(BroodNew.MAW, q.position, 12.0, mg)
	BroodRoot.start_morph(mg, BroodNew.MAW, spot)
	g.set_selection([mg])
	var labs2 := card_labels()
	g.set_selection([])
	mg.cmd_sacrifice()
	check(mg.order == "nb_morph" and not mg.can_sacrifice() and not labs2.has("SACRIFICE"), "    a grub on its way to morph can't be offered up (order %s, card %s)" % [mg.order, str(labs2)])
	g.consume_unit(mg)
	# the VENOM SIRE costs 25 spoils on top of his 200 food (the owner, 08:28: "sac 3 grubs to get a Venom Sire")
	var gold_keep: int = int(p["gold"])
	var res2_keep: float = float(p["res2"])
	p["gold"] = 1000
	p["res2"] = 20.0
	var vg: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 60.0, 60.0))
	g.set_selection([vg])
	g.hud.page = "build"
	var vlabs := card_labels()
	var vtip: Array = g.hud._tip_for.get("VENOM SIRE", ["", "", ""])
	var vi: Array = _item("VENOM SIRE")
	var why20 := BroodRoot.morph_problem(g, 0, BroodNew.DILO, vg)
	p["res2"] = 25.0
	var why25 := BroodRoot.morph_problem(g, 0, BroodNew.DILO, vg)
	g.hud.page = ""
	g.set_selection([])
	check(int(Defs.UNITS[BroodNew.DILO].get("cost2", 0)) == 25 and String(vtip[2]).begins_with("200 ") and String(vtip[2]).contains(" + 25 spoils") and vlabs.has("VENOM SIRE")
		and not vi.is_empty() and not bool(vi[3]) and why20 == "Not enough spoils." and why25 == "",
		"    the VENOM SIRE costs 200 food + 25 spoils: his lure's price on the BUILD card (%s), refused with 20 spoils (%s), fine with 25" % [String(vtip[2]), why20])
	g.consume_unit(vg)
	p["gold"] = gold_keep
	p["res2"] = res2_keep
	# HARVEST: twice the spoils (4 a supply point, 2 a kill), and each delivery is +1 veterancy for the Mother (+1% laying)
	q.nb["hvet"] = 0
	var foe_b: Unit = g._add_unit("musketeer", 1, q.position + Vector2(q.radius + 70.0, 0.0))
	foe_b.kills = 3
	await physics_frame
	foe_b.take_damage(999999.0, null)
	await wait(0.5)
	check(g.corpses.has(foe_b) and is_equal_approx(g.corpse_value(foe_b), 4.0 + 6.0), "    HARVEST doubled: a Musketeer's body with 3 kills is worth %.0f (4 + 2 x 3)" % g.corpse_value(foe_b))
	var hv_g: Unit = g._add_unit("grub", 0, q.position + Vector2(q.radius + 100.0, 0.0))
	await physics_frame
	hv_g.cmd_harvest()
	var hr0: float = float(p["res2"])
	var hv_got: bool = await wait_for(func() -> bool: return float(p["res2"]) > hr0 + 0.01, 30.0)
	check(hv_got and is_equal_approx(float(p["res2"]) - hr0, 10.0) and BroodNew.hvet(q) == 1,
		"    a grub brings it to the Mother: +%.0f spoils and her veterancy 0 -> %d" % [float(p["res2"]) - hr0, BroodNew.hvet(q)])
	g.consume_unit(hv_g)
	var base_rate: float = float(BroodNew.lay_rate(g, q)[0]) - float(BroodNew.lay_rate(g, q)[1]) * 0.01
	for i in 60:
		BroodNew.add_hvet(q)
	var lr_v: Array = BroodNew.lay_rate(g, q)
	await wait(0.7)
	check(BroodNew.hvet(q) == 50 and int(lr_v[4]) == 50 and absf(float(lr_v[0]) - (base_rate + float(lr_v[1]) * 0.5)) < 0.001 and absf(float(q.nb.get("rate", 0.0)) - float(lr_v[0])) < 0.001
		and BroodNew.levers_text(g, q).contains("veterancy 50"),
		"    60 more harvests: capped at %d, laying x%.2f (x%.2f without it: eggs every %.2f s, not %.2f): %s" % [BroodNew.hvet(q), float(lr_v[0]), base_rate,
		float(Defs.NB["egg_time"]) / float(lr_v[0]), float(Defs.NB["egg_time"]) / base_rate, BroodNew.levers_text(g, q)])
	g.set_selection([q])
	var q_labs := card_labels()
	g.set_selection([])
	check(q_labs.has("VETERANCY 50 · EGGS +50%"), "    her card shows it: %s" % str(q_labs.filter(func(l) -> bool: return String(l).begins_with("VET") or String(l).begins_with("LAY"))))
	var sv := BroodNew.unit_save(q)
	check(int(sv.get("hvet", -1)) == 50, "    saved with her (nb hvet %d)" % int(sv.get("hvet", -1)))
	q.nb["hvet"] = 0


## 15. ROOTED = A BUILDING (the owner's playtest of 0.15.13; scripts/brood_root.gd).
func _rooted_is_a_building(q: Unit, p: Dictionary) -> void:
	var T := Defs.TILE
	p["gold"] = 5000
	for gr in mine("grub"):
		gr.auto_work = false
		gr.cmd_stop()
	# the Mother lays only units
	check(BroodNew.lay_problem(g, q, BroodNew.MAW).begins_with("A grub turns into it") and not BroodNew.hatch_list().has(BroodNew.TURTLE) \
		and not BroodNew.hatch_list().has(BroodNew.FATHER), "15. the Mother lays no structure-units: %s" % BroodNew.lay_problem(g, q, BroodNew.MAW))
	# her footprint: the cells under her are solid, paths go round
	var qr: Rect2 = q.rect()
	var solid_ok := true
	for y in int(qr.size.y / T):
		for x in int(qr.size.x / T):
			var c: Vector2i = g.cell_of(qr.position + Vector2(x + 0.5, y + 0.5) * T)
			if g.solid[g.idx(c)] == 0:
				solid_ok = false
	check(BroodRoot.has_fp(q) and solid_ok and qr.size.x >= 9.0 * T, "    rooted, the Mother takes a building's footprint (%dx%d tiles, solid)" % [int(qr.size.x / T), int(qr.size.y / T)])
	var pa := Vector2(qr.position.x - 40.0, qr.get_center().y)
	var pb := Vector2(qr.end.x + 40.0, qr.get_center().y)
	if g._walkable(g.cell_of(pa)) and g._walkable(g.cell_of(pb)):
		var path: PackedVector2Array = g.find_path(pa, pb)
		var inside := false
		var cur := pa
		for pt in path:
			for s in 20:
				if qr.grow(-6.0).has_point(cur.lerp(pt, s / 20.0)):
					inside = true
			cur = pt
		check(not inside and path.size() >= 2, "    a path from one side of her to the other goes round her footprint (%d points)" % path.size())
	else:
		check(true, "    (her sides are not both open ground here: the path check is skipped)")
	# a creature rooting pushes out a unit standing there
	var ms := free_spot(BroodNew.MAW, q.position, 13.0)
	var mr: Unit = g._add_unit(BroodNew.MAW, 0, ms)
	var rx: Unit = g._add_unit("raptor", 0, BroodRoot.rect_for(BroodNew.MAW, ms).get_center())
	mr.cmd_deploy()
	await wait(0.2)
	check(BroodRoot.has_fp(mr) and not mr.rect().grow(-2.0).has_point(rx.position), "    rooting pushes a unit standing on its footprint out (%s)" % str(rx.position - mr.position))
	g.consume_unit(rx)
	await wait_for(func() -> bool: return mr.tesla_mode == "deployed", 5.0)
	await wait(0.5)
	check(mr.get_node_or_null(BroodRoot.SORT) != null and mr.y_sort_enabled and mr.sprite.get_parent().name == BroodRoot.SORT,
		"    rooted, it is drawn in the building layer (sorted at its footprint's top, %.0f px above its feet)" % -BroodRoot.sort_dy(mr))
	# a right-click on the ground sets its rally, it never uproots; a move order doesn't walk it off either
	var rp: Vector2 = spot_near(mr.position, 7.0)
	g.smart_command([mr], rp)
	await wait(1.0)
	check(mr.tesla_mode == "deployed" and BroodRoot.rally_of(mr).distance_to(rp) < 1.0, "    a right-click on the ground sets its rally point; it stays rooted (%s)" % mr.tesla_mode)
	var at0 := mr.position
	mr.cmd_move(rp)
	await wait(1.0)
	check(mr.tesla_mode == "deployed" and mr.position == at0, "    a move order (a hotkey) doesn't get it up either")
	# its card is a building's
	g.set_selection([mr])
	var labs := card_labels()
	check(not labs.has("MOVE") and not labs.has("ATTACK") and not labs.has("STOP") and not labs.has("HOLD") and not labs.has("PATROL") \
		and labs.has("UPROOT") and labs.has("HAUL") and labs.has("RALLY"), "    its card is a building's: %s" % str(labs))
	# UPROOT: its ground free again, a unit again
	var old_cells: Array = (mr.nb.get("fpc", []) as Array).duplicate()
	mr.cmd_uproot(true)
	await wait_for(func() -> bool: return mr.tesla_mode == "packed", 5.0)
	await wait(0.4)
	var freed := old_cells.all(func(i) -> bool: return g.solid[int(i)] == 0)
	check(not BroodRoot.has_fp(mr) and freed and mr.get_node_or_null(BroodRoot.SORT) == null and not mr.y_sort_enabled, "    UPROOT: its ground free again and drawn as a unit")
	labs = card_labels()
	check(labs.has("MOVE") and labs.has("ROOT"), "    uprooted: the unit card (%s)" % str(labs))
	# ROOT like BUILD: told to root at a spot, it walks there and roots on that exact spot
	var target := ms
	for i in 32:
		# (a spot well away from where it stood, round her)
		var cand: Vector2 = BroodRoot.snap(BroodNew.MAW, q.position + Vector2.from_angle(TAU * i / 32.0) * 11.0 * T)
		if cand.distance_to(ms) > 8.0 * T and BroodRoot.home_region(g, cand) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, BroodNew.MAW, cand, mr) == "":
			target = cand
			break
	mr.give({"o": "nb_root", "p": target})
	var there: bool = await wait_for(func() -> bool: return mr.tesla_mode != "packed", 40.0)
	check(there and mr.position.distance_to(target) < 1.0, "    ROOT like BUILD: it walks %.0f tiles to the spot and roots exactly there (%s, off by %.0f px, %s)" % [ms.distance_to(target) / T, mr.tesla_mode, mr.position.distance_to(target), mr.order])
	var red := BroodRoot.place_problem(g, 0, BroodNew.MAW, mr.position + Vector2(2.0 * T, 0), null)
	check(red != "", "    the ghost beside it is red: %s" % red)
	var red2 := ""
	for i in 32:
		red2 = BroodRoot.place_problem(g, 0, BroodNew.FATHER, BroodRoot.snap(BroodNew.FATHER, q.position + Vector2.from_angle(TAU * i / 32.0) * 12.0 * T), null)
		if red2.begins_with("Out of range"):
			break
	check(red2.begins_with("Out of range"), "    the Tyrannosaur's ghost out of the father range: %s" % red2)
	g.consume_unit(mr)
	# the Mother's rally goes to her eggs, an egg takes its own by right-click, the hatchling walks there
	var qrally: Vector2 = spot_near(q.position, 10.0)
	q.cmd_nb_rally(qrally, "army")          # (her warriors' rally: her right-clicks take turns since 0.24.1)
	q.nb["eggs"] = 3
	var e0: Array = mine(BroodNew.EGG)
	var lwhy: String = q.cmd_lay("grub")
	await wait(0.1)
	var ge_l: Array = mine(BroodNew.EGG).filter(func(e) -> bool: return not e0.has(e))
	var ge: Unit = ge_l[0] if not ge_l.is_empty() else null
	check(ge != null and BroodRoot.rally_of(ge).distance_to(qrally) < 1.0, "    the Mother's rally goes to the egg she lays (%s)" % lwhy)
	if ge != null:
		var own_r: Vector2 = spot_near(q.position, 12.0)
		g.smart_command([ge], own_r)
		check(BroodRoot.rally_of(ge).distance_to(own_r) < 1.0 and ge.nb.has("ro"), "    a right-click gives the egg its own rally")
		g.set_selection([ge])
		labs = card_labels()
		check(labs.any(func(l) -> bool: return String(l).begins_with("GRUB · ")) and labs.has("RALLY") and not labs.has("MOVE"), "    the egg's card says what it hatches: %s" % str(labs))
		var grubs0: Array = mine("grub")
		var gid := ge.get_instance_id()
		await wait_for(func() -> bool: return not is_instance_id_valid(gid) or (instance_from_id(gid) as Unit).dead, float(Defs.UNITS["grub"]["time"]) + 3.0)
		await wait(0.2)
		var hatched: Array = mine("grub").filter(func(x) -> bool: return not grubs0.has(x))
		check(not hatched.is_empty() and hatched[0].order == "move" and hatched[0].order_point.distance_to(own_r) < 20.0, "    the hatchling walks to the egg's rally")
	BroodRoot.set_rally(q, Vector2.INF)
	# a grub turns into a structure-unit: walks to the spot, pays, a cocoon (its footprint), then rooted there
	var tspot := free_spot(BroodNew.TURTLE, q.position, 13.0)
	var mg: Unit = mine("grub")[0]
	var gold0: int = int(p["gold"])
	g.set_selection([mg])
	labs = card_labels()
	check(labs.has("BUILD") and not labs.has("CLUTCH MOUND") and not labs.has("FEEDING PIT"),
		"    a grub's card has BUILD (its creatures in its build menu: 16), no old Brood buildings: %s" % str(labs))
	mg.give({"o": "nb_morph", "k": BroodNew.TURTLE, "p": tspot})
	var morphed: bool = await wait_for(func() -> bool: return mine(BroodNew.TURTLE).any(func(u) -> bool: return u.position.distance_to(tspot) < 1.0), 40.0)
	var coc: Array = mine(BroodNew.TURTLE).filter(func(u) -> bool: return u.position.distance_to(tspot) < 1.0)
	check(morphed and int(p["gold"]) == gold0 - int(Defs.UNITS[BroodNew.TURTLE]["cost"]) and (not is_instance_valid(mg) or mg.dead),
		"    a grub walks to the spot, pays %d and turns into a Mound Turtle's cocoon" % (gold0 - int(p["gold"])))
	if not coc.is_empty():
		var tu: Unit = coc[0]
		check(BroodRoot.in_cocoon(tu) and BroodRoot.has_fp(tu) and not BroodNew.rooted(tu), "    the cocoon takes its footprint; not working yet")
		var cap0: int = int(p["cap"])
		var opened: bool = await wait_for(func() -> bool: return not BroodRoot.in_cocoon(tu), BroodNew.egg_time(BroodNew.TURTLE) + 2.0)
		await wait(0.3)
		check(opened and BroodNew.rooted(tu) and tu.position == tspot and int(p["cap"]) == cap0 + int(Defs.NB["turtle_supply"]),
			"    out of the cocoon (%d s): rooted on that spot, its supply counts" % int(BroodNew.egg_time(BroodNew.TURTLE)))
		await wait(1.0)
		check(not BroodNew.producing(g, tu) and tu.sprite.frame == 0, "    idle (a turtle never produces), it holds its first frame")
		g.consume_unit(tu)
	# the player's Mother never roots or uproots by herself; the computer's doesn't flip-flop under fire from range
	var foe: Unit = g._add_unit("musketeer", 1, spot_near(q.position, 9.0))
	foe.max_hp = 1000000.0
	foe.hp = foe.max_hp
	foe.cmd_attack(q)
	await wait(6.0)
	check(q.tesla_mode == "deployed", "    the player's rooted Mother under fire stays rooted (no automatic uproot)")
	var guard := {}
	var roots := 0
	var ups := 0
	var was: String = q.tesla_mode
	var tg := 0.0
	while tg < 60.0:
		BroodNew.mother_guard(g, q, guard, 0.5)
		await wait(0.5)
		tg += 0.5
		if q.tesla_mode != was:
			if q.tesla_mode == "deploying":
				roots += 1
			if q.tesla_mode == "packing":
				ups += 1
			was = q.tesla_mode
		if foe.target != q and foe.order != "attack":
			foe.cmd_attack(q)
	check(ups == 1 and roots == 0, "    the computer's Mother shot at from range: up once, and she stays up while it lasts (%d up, %d root in 60 s)" % [ups, roots])
	g.consume_unit(foe)
	var t_calm: float = g.clock
	var back := false
	while g.clock - t_calm < 60.0 and not back:
		BroodNew.mother_guard(g, q, guard, 0.5)
		await wait(0.5)
		back = q.tesla_mode == "deploying" or q.tesla_mode == "deployed"
	check(back and g.clock - t_calm >= BroodNew.MOTHER_CALM, "    no enemy left: she roots again after a real calm (%.0f s)" % (g.clock - t_calm))
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", 30.0)


## 16. THE OWNER'S PLAYTEST OF 0.15.14 (docs/brood_new.md): the grub's BUILD menu, the longer laying show, the worker
## count, the Tyrannosaur fertilising till the last egg hatched, the grub's own text, a click on her drawn body, eggs
## laid on the nearest empty spot (boxed in: on a creature, drawn on top, the hatchling walking out through its own
## side's creatures), her GROWING bar and STOP GROWING.
const OLD_WORDS := ["Burrow", "Hive", "Warren", "Broodmound", "Feeding Pit", "Clutch Mound", "Brood Pen", "Gorge Pit", "Roost", "Spawning Den", "building", "construct"]


func _old_word(txt: String) -> String:
	for w in OLD_WORDS:
		if txt.contains(w):
			return w
	return ""


func _item(label: String) -> Array:
	for it in g.hud._build_card():
		if String(it[1]) == label:
			return it
	return []


func _fixes_2(q: Unit, p: Dictionary) -> void:
	var T := Defs.TILE
	p["gold"] = 5000
	p["res2"] = 500.0
	for gr in mine("grub"):
		gr.auto_work = false
		gr.cmd_stop()
	for k in ["raptor", "brute", "spore_mother", "mist_toad", "spitter", "skywing", "hatchlings"]:
		for u in mine(k):
			g.consume_unit(u)          # (room in the supply for the eggs below)
	var grs: Array = mine("grub")
	for i in range(6, grs.size()):
		g.consume_unit(grs[i])
	if mine("grub").size() < 3:
		for i in 3:
			g._add_unit("grub", 0, spot_near(q.position, 8.0))
	var sup_t := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 20.0))
	sup_t.nb.erase("coc")              # (a rooted turtle out of the way: supply for the eggs below)
	BroodNew.recount(g, 0)
	print("    (supply %d of %d; %d grubs, %d eggs)" % [g.supply_used(0), int(p["cap"]), mine("grub").size(), mine(BroodNew.EGG).size()])
	# (1) the grub keeps BUILD; its page has the structure-units
	var gr0: Unit = mine("grub")[0]
	g.set_selection([gr0])
	g.hud.page = ""
	var labs: Array = card_labels()
	check(labs.has("BUILD") and not labs.has("ROOTMAW") and not labs.has("MOUND TURTLE"), "16. the grub's card keeps BUILD (B), the creatures are not loose on it: %s" % str(labs))
	var bi: Array = _item("BUILD")
	if not bi.is_empty():
		(bi[2] as Callable).call()
	labs = card_labels()
	check(g.hud.page == "build" and labs.has("ROOTMAW") and labs.has("MOUND TURTLE") and labs.has("TYRANT SIRE") and labs.has("BACK") and not labs.has("CLUTCH MOUND") and not labs.has("FEEDING PIT"),
		"    BUILD opens its build menu: %s" % str(labs))
	var ri: Array = _item("ROOTMAW")
	if not ri.is_empty():
		(ri[2] as Callable).call()
	check(String(g.controls.mode) == "nb_root" and String(g.controls.place_kind) == BroodNew.MAW and g.hud.page == "", "    a creature there gives the ROOT placement ghost")
	g.controls.cancel_mode()
	g.hud.page = "build"          # (the B key sets this for any worker)
	check(card_labels().has("TYRANT SIRE"), "    the B key's page is the same menu")
	g.hud.page = ""
	# (6) the grub's own text: no old Brood building in it
	card_labels()
	var texts := {"its card": String(gr0.d["about"]), "its tooltip": Defs.tip("grub"), "the BUILD tip": String(g.hud._tip_for.get("BUILD", ["", ""])[1]),
		"HARVEST": String(g.hud._tip_for.get("HARVEST", ["", g.hud.CMD_TIPS.get("HARVEST", "")])[1]), "the food": String(g.hud._res_tip(0).get("body", "")),
		"the essence": String(g.hud._res_tip(1).get("body", "")), "the supply": String(g.hud._res_tip(2).get("body", ""))}
	var bad := ""
	for k in texts:
		if _old_word(String(texts[k])) != "" or String(texts[k]) == "":
			bad += "%s (%s) " % [k, _old_word(String(texts[k]))]
	check(bad == "" and String(gr0.d["about"]).contains("Brood Mother"), "    the new Brood's grub text says the Rootmaws and the Brood Mother, no old Brood word: %s" % (bad if bad != "" else String(gr0.d["about"]).left(70)))
	check(_old_word(Defs.tip("grub")) == "" and _old_word(String(Defs.UNITS["grub"]["about"])) == "", "    (0.18.0: the Brood's only grub text has no old Brood word either)")
	# (4) the expansion spots for the new Brood: its best TURTLE spots (fresh ground 15+ tiles from her, room for Rootmaws)
	Settings.expansion_spots = true
	g.exp_spots._key = "-"
	g.exp_spots.refresh()
	var shown: Array = g.exp_spots.shown
	var far_ok := shown.all(func(sp) -> bool: return sp.has("tc") and BroodRoot.feet_at(BroodNew.TURTLE, sp["tc"]).distance_to(q.position) >= float(Defs.NB["expansion_tiles"]) * T and int(sp["maws"]) >= 2)
	check(not shown.is_empty() and far_ok and int(shown[0]["rank"]) == 1, "    the new Brood sees its best turtle spots (%d: %s)" % [shown.size(), ", ".join(shown.map(func(sp) -> String: return "#%d %s, %d Rootmaw circles, %.0f tiles out" % [int(sp["rank"]), str(sp["tc"]), int(sp["maws"]), BroodRoot.feet_at(BroodNew.TURTLE, sp["tc"]).distance_to(q.position) / T]))])
	if not shown.is_empty():
		var tsp: Dictionary = shown[0]
		var tt := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, BroodRoot.feet_at(BroodNew.TURTLE, tsp["tc"]))
		tt.nb.erase("coc")
		g.exp_spots.refresh()
		var after: Array = g.exp_spots.shown
		check(not after.any(func(sp) -> bool: return sp["c"] == tsp["c"]) and after.all(func(sp) -> bool: return BroodRoot.feet_at(BroodNew.TURTLE, sp["tc"]).distance_to(tt.position) >= float(Defs.NB["expansion_tiles"]) * T),
			"    a turtle rooted on the best one: it goes, and the others are 15+ tiles from it (%d shown)" % after.size())
		g.consume_unit(tt)
		BroodNew.recount(g, 0)
	# (2) the laying show lasts about 2.5-3 s, frames 3 and 4 the longest; her rate is not slowed
	var lt := BroodNew.lay_time(q)
	var ld: Array = BroodNew.LAY_DUR
	check(lt >= 2.5 and lt <= 3.0 and float(ld[2]) >= float(ld.max()) and float(ld[3]) >= float(ld.max()) and float(Defs.NB["egg_time"]) == 6.0,
		"    the Mother's laying show lasts %.2f s (frames 3-4 held %.2f s each); a new egg still every %.0f s" % [lt, float(ld[2]), float(Defs.NB["egg_time"])])
	q.nb["eggs"] = 6
	var e_before: Array = mine(BroodNew.EGG)
	q.cmd_lay("grub")
	await wait(0.5)
	var lt_left := float(q.nb.get("lay_t", 0.0))
	q.cmd_lay("grub")
	await wait(0.05)
	var two: Array = mine(BroodNew.EGG).filter(func(e) -> bool: return not e_before.has(e))
	check(two.size() == 2 and float(q.nb.get("lay_t", 0.0)) < lt_left and absf(float(two[1].nb.get("hold", 0.0)) - float(q.nb.get("lay_t", 0.0))) < 0.1 and int(q.nb["eggs"]) == 4,
		"    two eggs at once: both paid and counted at once (%d left), the second comes out at the end of the same show" % int(q.nb["eggs"]))
	await wait(lt + 0.5)
	# (3) the worker count over a rooted Rootmaw
	var maw: Unit = null
	for m in mine(BroodNew.MAW):
		if BroodNew.rooted(m):
			maw = m
	if maw == null:
		var ms := free_spot(BroodNew.MAW, q.position, 9.0)
		maw = BroodRoot.cocoon(g, 0, BroodNew.MAW, ms)
		maw.nb.erase("coc")
		BroodNew.recount(g, 0)
	maw.nb["food"] = 300.0
	var crew_g: Array = mine("grub").slice(0, 2)
	for c in crew_g:
		c.cmd_gather(maw)
	await wait(0.5)
	var cl := BroodNew.crew_label(g, maw)
	check(cl == "%d/%d" % [BroodNew.crew(g, maw), BroodNew.crew_max(g, maw)] and BroodNew.crew(g, maw) == 2 and cl.ends_with("/%d" % BroodNew.crew_max(g, maw)),
		"    over a rooted Rootmaw: its grubs at work / the most it takes (%s)" % cl)
	var pile: Unit = g._add_unit(BroodNew.PILE, -1, spot_near(q.position, 10.0))
	pile.nb["food"] = 100.0
	pile.nb["start"] = 100.0
	check(BroodNew.crew_label(g, pile) == "0/%d" % int(Defs.NB["pile_crew"]), "    and over a food pile (%s)" % BroodNew.crew_label(g, pile))
	g.consume_unit(pile)
	for c in crew_g:
		c.cmd_stop()
	# (7) a click anywhere on her drawn body selects her; a unit standing over her is picked first
	var br: Rect2 = BroodRoot.body_rect(q)
	var far_pt := Vector2(br.get_center().x, br.position.y + br.size.y * 0.3)
	var top_hit = g.entity_at(far_pt)
	check(br.size.x > 100.0 and top_hit == q and far_pt.distance_to(q.position) > 60.0, "    a click high on her drawn body (%.0f px from her feet) selects her (body %dx%d px)" % [far_pt.distance_to(q.position), int(br.size.x), int(br.size.y)])
	var side_pt := Vector2(br.position.x + br.size.x * 0.12, br.get_center().y)
	check(g.entity_at(side_pt) == q, "    and near the edge of her body")
	var over: Unit = mine("grub")[2]
	over.cmd_stop()
	over.position = far_pt + Vector2(0, 12)
	await wait(0.1)
	check(g.entity_at(over.position + Vector2(0, -12)) == over, "    a grub standing over her body is picked, not her")
	over.position = spot_near(q.position, 9.0)
	g.note_move(over)
	# (5) the Tyrannosaur keeps fertilising until the last warrior egg in his nest has hatched
	var f: Unit = BroodNew.father(g, 0)
	if f == null:
		f = g._add_unit(BroodNew.FATHER, 0, free_spot(BroodNew.FATHER, q.position, 5.0))
	if not BroodNew.rooted(f):
		f.position = free_spot(BroodNew.FATHER, q.position, 5.0, f)
		g.note_move(f)
		f.cmd_deploy()
		await wait_for(func() -> bool: return f.tesla_mode == "deployed", 6.0)
	q.nb["eggs"] = 6
	var lw := q.cmd_lay("raptor")
	await wait(0.1)
	var ne: Array = BroodNew.nest_eggs(g, f)
	var fe0: Unit = ne[0] if not ne.is_empty() else null
	var fertd: bool = fe0 != null and await wait_for(func() -> bool: return int(fe0.nb.get("fert", 0)) == 2, 6.0)
	await wait(1.0)
	check(fertd and not BroodNew.fertilising(f) and BroodNew.producing(g, f) and f.anim == "rooted", "    fertilised, his egg incubating: he keeps his fertilising loop (%s)" % lw)
	var fr_seen := {}
	for i in 12:
		await wait(0.2)
		fr_seen[f.sprite.frame] = true
	check(fr_seen.size() > 1, "    (his loop's frames move: %d seen)" % fr_seen.size())
	var fid := fe0.get_instance_id() if fe0 else 0
	await wait_for(func() -> bool: return fid == 0 or not is_instance_id_valid(fid) or (instance_from_id(fid) as Unit).nb.has("out"), float(Defs.UNITS["raptor"]["time"]) + 3.0)
	await wait(1.5)
	check(BroodNew.nest_eggs(g, f).is_empty() and not BroodNew.producing(g, f) and f.sprite.frame == 0, "    the last warrior egg hatched: then still")
	# (8) eggs on the nearest EMPTY spot: the Tyrannosaur rooted right under her front does not hide them
	f.cmd_uproot(false)
	await wait_for(func() -> bool: return f.tesla_mode == "packed", 6.0)
	var qr: Rect2 = q.rect()
	var under := BroodRoot.snap(BroodNew.FATHER, Vector2(qr.get_center().x - 40.0, qr.end.y + 2.0 * T))
	var uwhy := BroodRoot.place_problem(g, 0, BroodNew.FATHER, under, f)
	if uwhy == "":
		BroodRoot.start_root(f, under)
		await wait_for(func() -> bool: return f.tesla_mode == "deployed", 20.0)
	var fr: Rect2 = f.rect() if BroodRoot.has_fp(f) else Rect2()
	var e_b: Array = mine(BroodNew.EGG)
	q.cmd_lay("grub")
	await wait(0.1)
	var ge: Unit = mine(BroodNew.EGG).filter(func(e) -> bool: return not e_b.has(e)).back() if mine(BroodNew.EGG).size() > e_b.size() else null
	check(ge != null and BroodRoot.has_fp(f) and not fr.grow(4.0).has_point(ge.position) and g._walkable(g.cell_of(ge.position)) and ge.z_index == BroodNew.EGG_Z,
		"    the Tyrannosaur rooted under her front (%s): her egg goes to the nearest empty spot, %.0f px from her rim, drawn on top" % [uwhy if uwhy != "" else "rooted there", qr.grow(0).get_center().distance_to(ge.position) if ge else -1.0])
	await _boxed(q, p, f)
	# (9) her GROWING: a bar over her and on her card, STOP GROWING pays it back
	var st0: int = BroodNew.stage(q)
	q.nb["stage"] = 0
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	var gold_g: int = int(p["gold"])
	var gw: String = q.cmd_grow()
	await wait(3.0)
	var pg: Dictionary = BroodNew.progress(g, q)
	g.set_selection([q])
	await wait(0.2)
	var hud_pg: Dictionary = g.hud.nb_prog
	check(gw == "" and String(pg.get("label", "")) == "GROWING · STAGE 2" and float(pg["f"]) > 0.0 and float(pg["f"]) < 0.2 and float(pg["left"]) > 0.0,
		"    GROWING: progress %s, %.0f%%, %.0f s left" % [String(pg.get("label", "")), float(pg.get("f", 0.0)) * 100.0, float(pg.get("left", 0.0))])
	check(String(hud_pg.get("label", "")) == "GROWING · STAGE 2", "    her card shows it (the HUD's progress corner: %s)" % str(hud_pg.get("label", "none")))
	labs = card_labels()
	check(labs.has("STOP GROWING") and not labs.has("GROW"), "    her card has STOP GROWING: %s" % str(labs))
	var si: Array = _item("STOP GROWING")
	if not si.is_empty():
		(si[2] as Callable).call()
	await wait(0.2)
	check(float(q.nb.get("grow_t", 0.0)) <= 0.0 and int(p["gold"]) >= gold_g and BroodNew.progress(g, q).is_empty(), "    STOP GROWING: stopped, paid back (%d)" % int(p["gold"]))
	q.nb["stage"] = st0
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	# the other progress: an egg hatching, a rooting creature, a cocoon
	var pe: Dictionary = BroodNew.progress(g, ge) if ge != null and is_instance_valid(ge) and not ge.dead else {"label": "HATCHING", "f": 0.5}
	var tc := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 14.0))
	await wait(1.0)
	var pc: Dictionary = BroodNew.progress(g, tc)
	tc.nb.erase("coc")
	tc.cmd_uproot(false)
	await wait(0.5)
	var pr: Dictionary = BroodNew.progress(g, tc)
	check(String(pe.get("label", "")) == "HATCHING" and String(pc.get("label", "")) == "MORPHING" and float(pc["f"]) > 0.0 and String(pr.get("label", "")) == "UPROOTING" and float(pr["f"]) > 0.0,
		"    and the others: an egg %s, a cocoon %s, %s" % [String(pe.get("label", "")), String(pc.get("label", "")), String(pr.get("label", ""))])
	g.consume_unit(tc)
	g.set_selection([])


## (8) the Mother boxed in on every side by her rooted creatures: no empty spot within 3 tiles of her rim
func _boxed(q: Unit, p: Dictionary, f: Unit) -> void:
	var T := Defs.TILE
	if BroodRoot.has_fp(f):
		f.cmd_uproot(false)
		await wait_for(func() -> bool: return f.tesla_mode == "packed", 6.0)
		f.position = spot_near(q.position, 16.0)
		g.note_move(f)
	for e in mine(BroodNew.EGG):
		g.consume_unit(e)
	for o in g.units:
		if o.team == 0 and not o.dead and o != q and o.kind != BroodNew.EGG and q.rect().grow(4.0 * T).has_point(o.position) and not BroodNew.ROOTERS.has(o.kind):
			o.position = spot_near(q.position, 18.0)
			g.note_move(o)
	await wait(0.2)
	var qr: Rect2 = q.rect()
	var c0 := Vector2i(qr.position / T)
	var sz := Vector2i(qr.size / T)
	var box: Array = []
	# a ring 3 tiles thick of rooted creatures round her footprint: Mound Turtles (3x3) along her front and back,
	# Rootmaws (3x2) and turtles down her sides
	var cells: Array = []
	var x := c0.x - 3
	while x < c0.x + sz.x + 3:
		cells.append([BroodNew.TURTLE, Vector2i(x, c0.y - 3)])
		cells.append([BroodNew.TURTLE, Vector2i(x, c0.y + sz.y)])
		x += 3
	for side in [c0.x - 3, c0.x + sz.x]:
		var y := c0.y
		while y < c0.y + sz.y:
			var left: int = c0.y + sz.y - y
			if left >= 3:
				cells.append([BroodNew.TURTLE, Vector2i(side, y)])
				y += 3
			else:
				cells.append([BroodNew.MAW, Vector2i(side, y - (2 - left))])
				y += left
	for cc in cells:
		var k: String = cc[0]
		var u: Unit = g._add_unit(k, 0, BroodRoot.feet_at(k, cc[1]))
		u.facing = BroodNew.SE
		u.tesla_mode = "deployed"
		u.nb["m"] = "deployed"
		u.nb_mass = 1000.0
		BroodRoot.footprint_on(g, u, false)
		box.append(u)
	await wait(0.3)
	var ring: Rect2 = qr.grow(3.0 * T)
	var rally := q.position + Vector2(0, qr.size.y * 0.5 + 9.0 * T)
	rally = g.cell_center(g.nearest_free(g.cell_of(rally), 6))
	BroodRoot.set_rally(q, rally, true, "worker")          # (a grub: her grubs' rally, 0.24.1)
	q.nb["eggs"] = 4
	var e_b: Array = mine(BroodNew.EGG)
	var lw := q.cmd_lay("grub")
	await wait(0.1)
	var ne: Array = mine(BroodNew.EGG).filter(func(e) -> bool: return not e_b.has(e))
	var be: Unit = ne[0] if not ne.is_empty() else null
	if be != null:
		print("    (egg at %s, top %s, her rect %s, ring %s, free cells in the ring: %d)" % [str(be.position), str(be.nb.get("top", false)), str(qr), str(ring), _free_in(ring, qr)])
	check(be != null and bool(be.nb.get("top", false)) and ring.has_point(be.position) and not qr.has_point(be.position) and be.z_index == BroodNew.EGG_Z,
		"    BOXED IN by %d rooted creatures (no empty spot within 3 tiles of her rim): the egg is laid ON a creature at her front, drawn on top (%s)" % [box.size(), lw])
	var g_b: Array = mine("grub")
	var bid := be.get_instance_id() if be else 0
	await wait_for(func() -> bool: return bid == 0 or not is_instance_id_valid(bid) or (instance_from_id(bid) as Unit).nb.has("out"), float(Defs.UNITS["grub"]["time"]) + BroodNew.lay_time(q) + 2.0)
	await wait(0.2)
	var hg: Array = mine("grub").filter(func(x2) -> bool: return not g_b.has(x2))
	var h: Unit = hg[0] if not hg.is_empty() else null
	check(h != null and h.nb_pass > 0.0, "    it hatches, and the grub may walk through its own side's creatures (%s)" % ("passing" if h and h.nb_pass > 0.0 else "no"))
	var out: bool = h != null and await wait_for(func() -> bool: return not ring.grow(-2.0).has_point(h.position) and h.nb_pass <= 0.0, 25.0)
	var there: bool = h != null and await wait_for(func() -> bool: return h.position.distance_to(rally) < 64.0, 25.0)
	check(out and there, "    it walks out through them and on to the rally point (%.0f px from it)" % (h.position.distance_to(rally) if h else -1.0))
	# enemies still can't pass: a turtle's cells are solid to them
	var tcell: Vector2 = box[0].rect().get_center()
	check(not BroodRoot.clear_for(g, tcell, 8.0, 1) and BroodRoot.clear_for(g, tcell, 8.0, 0), "    an enemy still can't walk through them (only their own side can)")
	for u in box:
		g.consume_unit(u)
	BroodRoot.set_rally(q, Vector2.INF)
	await wait(0.3)


## 17. THE ROOTED ART ON ITS FOOTPRINT (the owner, 2026-10-29; BroodRoot.drop, Defs.NB "nest_y")
func _rooted_art(q: Unit) -> void:
	var T := Defs.TILE
	g.set_selection([])
	if q.tesla_mode == "packed":
		q.cmd_deploy()
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", 8.0)
	var made: Array = []
	var f: Unit = BroodNew.father(g, 0)
	if f == null:
		f = g._add_unit(BroodNew.FATHER, 0, free_spot(BroodNew.FATHER, q.position, 5.5))
		made.append(f)
	if not BroodNew.rooted(f):
		f.position = free_spot(BroodNew.FATHER, q.position, 5.5, f)
		g.note_move(f)
		f.cmd_deploy()
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, free_spot(BroodNew.TURTLE, q.position, 13.0))
	made.append(tu)
	var mw: Unit = g._add_unit(BroodNew.MAW, 0, free_spot(BroodNew.MAW, q.position, 12.0))
	made.append(mw)
	# no jump as the turtle roots: its picture's feet before and on the first rooting step (on screen: it animates)
	g.camera.position = tu.position
	await wait(0.3)
	var before := tu.sprite.global_position.y - tu.position.y
	tu.cmd_deploy()
	mw.cmd_deploy()
	var first := INF
	var mid := -1.0
	var sw := tu.switch_time()
	for i in 400:
		await physics_frame
		if tu.tesla_mode == "deploying" and first == INF and tu.anim == "root":
			first = tu.sprite.global_position.y - tu.position.y
		if tu.tesla_mode == "deploying" and mid < 0.0 and tu.tesla_t < sw * 0.5:
			mid = BroodRoot.art_dy(tu)
		if tu.tesla_mode == "deployed" and BroodNew.rooted(f) and mw.tesla_mode == "deployed":
			break
	await wait(0.5)
	var full := BroodRoot.drop(tu)
	check(absf(before) < 0.5 and first != INF and absf(first - before) < 3.0 and mid > 1.0 and mid < full - 1.0 and absf(tu.sprite.global_position.y - tu.position.y - full) < 0.5,
		"17. a Mound Turtle rooting: no jump (feet %.1f px walking, %.1f on the first rooting frame), the drop eased (%.1f half way), %.1f px rooted" % [before, first, mid, full])
	for u in [q, f, tu, mw]:
		g.camera.position = u.position
		await wait(0.3)
		var r: Rect2 = BroodRoot.rect_of(u) if BroodRoot.has_fp(u) else Rect2()
		var br: Rect2 = BroodRoot.body_rect(u)
		var sc: float = BroodRoot.scale_of(u)
		check(BroodRoot.has_fp(u) and br.end.y >= r.end.y - 4.0 and br.end.y <= r.end.y + 14.0 * sc,
			"    the %s's drawn bottom on its footprint's bottom edge (%.0f px from it; the drop %.0f px)" % [u.d["name"], br.end.y - r.end.y, BroodRoot.drop(u)])
		var srt: Node = u.get_node_or_null(BroodRoot.SORT)
		var fr: Node = srt.get_node_or_null(BroodRoot.FP_NODE) if srt else null
		check(fr != null and u.sprite.get_parent() == srt and fr.get_index() < u.sprite.get_index(), "    its selection frame is drawn under its pictures")
	check(absf(BroodRoot.drop_for(BroodNew.TURTLE) - BroodRoot.drop(tu)) < 0.5 and absf(BroodRoot.drop_for(BroodNew.FATHER) - BroodRoot.drop(f)) < 0.5,
		"    the ROOT ghost draws the rooted picture as low (%.0f, %.0f px)" % [BroodRoot.drop_for(BroodNew.TURTLE), BroodRoot.drop_for(BroodNew.FATHER)])
	var fr2 := BroodRoot.rect_of(f)
	check(absf(BroodNew.nest_point(f).y - fr2.end.y - BroodNew.NEST_FRONT) < 0.5 and absf(BroodNew.nest_point(f).x - fr2.get_center().x) < 0.5,
		"    his eggs' row lies just in front of his footprint (the owner, 18:31)")
	# the Mother at stage 3: her bigger footprint, her art on its bottom edge
	var st0 := BroodNew.stage(q)
	for u in made:
		if u != f:
			g.consume_unit(u)
	if made.has(f):
		g.consume_unit(f)
	else:
		f.cmd_uproot(false)
		await wait_for(func() -> bool: return f.tesla_mode == "packed", 6.0)
		f.position = spot_near(q.position, 20.0)
		g.note_move(f)
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	g.camera.position = q.position
	await wait(0.5)
	var r3 := BroodRoot.rect_of(q)
	var b3 := BroodRoot.body_rect(q)
	check(b3.end.y >= r3.end.y - 4.0 and b3.end.y <= r3.end.y + 14.0 * 1.3, "    the Mother at stage 3 (%dx%d tiles): her drawn bottom %.0f px from her footprint's bottom edge" % [int(r3.size.x / T), int(r3.size.y / T), b3.end.y - r3.end.y])
	q.nb["stage"] = st0
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	await wait(0.3)


func _free_in(ring: Rect2, inner: Rect2) -> int:
	var n := 0
	var T := Defs.TILE
	for y in int(ring.size.y / T):
		for x in int(ring.size.x / T):
			var p := ring.position + Vector2(x + 0.5, y + 0.5) * T
			if not inner.has_point(p) and g._walkable(g.cell_of(p)):
				n += 1
	return n


## 18. THE THREE FATHERS (the owner, 2026-10-29 11:10: FATHER LINES; docs/brood_new.md "The three fathers").
func _fathers(q: Unit, p: Dictionary) -> void:
	var T := Defs.TILE
	p["gold"] = 9000
	p["res2"] = 900.0
	for gr in mine("grub"):
		gr.auto_work = false
		gr.cmd_stop()
	for k in ["raptor", "brute", "mist_toad", "spitter", "skywing", "hatchlings", BroodNew.EGG, BroodNew.FATHER, BroodNew.DILO, BroodNew.PTERO]:
		for u in mine(k):
			g.consume_unit(u)
	while mine("grub").size() < 4:
		g._add_unit("grub", 0, spot_near(q.position, 12.0))
	await wait(0.3)
	for i in 4:
		if int(p["cap"]) - g.supply_used(0) >= 32:
			break
		# (room for three fathers and their eggs: Mound Turtles rooted out of their way)
		var tu: Unit = BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 13.0 + 3.0 * i))
		tu.nb["coc"] = BroodRoot.cocoon_time(tu) - 0.05
		await wait(0.4)
	# the lines
	check(BroodNew.father_of("raptor") == BroodNew.FATHER and BroodNew.father_of("brute") == BroodNew.FATHER
		and BroodNew.father_of("spitter") == BroodNew.DILO and BroodNew.father_of("mist_toad") == BroodNew.DILO
		and BroodNew.father_of("hatchlings") == BroodNew.PTERO and not BroodNew.hatch_list().has("bloater")
		and BroodNew.hatch_list().has("hatchlings") and not BroodNew.hatch_list().has("skywing") and BroodRoot.morph_list().has(BroodNew.DILO) and BroodRoot.morph_list().has(BroodNew.PTERO),
		"18. the lines: Tyrannosaur Raptor, Brute; Dilophosaurus Spitter, Mist Toad; Pterodactyl Hatchlings (no Skywing); no Bloater (her card: %s)" % str(BroodNew.hatch_list()))
	# locked until her stage
	var st0 := BroodNew.stage(q)
	q.nb["stage"] = 0
	var l_d0 := BroodRoot.morph_problem(g, 0, BroodNew.DILO)
	var l_p0 := BroodRoot.morph_problem(g, 0, BroodNew.PTERO)
	var l_t0 := BroodRoot.morph_problem(g, 0, BroodNew.FATHER)
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var tiers := {}
	for st in 3:
		q.nb["stage"] = st
		for k in ["raptor", "spitter", "brute", "mist_toad", "hatchlings"]:
			tiers["%s%d" % [k, st]] = BroodNew.lay_problem(g, q, k).begins_with("Needs the Brood Mother at stage")
	q.nb["stage"] = 1
	var l_p1 := BroodRoot.morph_problem(g, 0, BroodNew.PTERO)
	q.nb["stage"] = 0
	var why_b := BroodNew.lay_problem(g, q, "brute")
	q.nb["stage"] = st0
	check(l_t0 == "" and l_d0 == "" and l_p0 == "Needs the Brood Mother at stage 2.", "    stage 1: the Tyrant and Venom Sires open, the Storm Sire locked (%s)" % l_p0)
	check(l_p1 == "", "    stage 2: the Storm Sire too")
	check(not tiers["raptor0"] and not tiers["spitter0"] and tiers["brute0"] and tiers["mist_toad0"] and tiers["hatchlings0"]
		and not tiers["spitter1"] and tiers["brute1"] and tiers["mist_toad1"] and not tiers["hatchlings1"]
		and not tiers["brute2"] and not tiers["mist_toad2"] and not tiers["hatchlings2"] and why_b == "Needs the Brood Mother at stage 3.",
		"    the warriors' tiers: Raptors and Spitters at stage 1, Hatchlings 2, Brutes and Mist Toads 3 (a Brute at stage 1: %s)" % why_b)
	check(st0 == 2 and BroodRoot.morph_problem(g, 0, BroodNew.PTERO) == "", "    stage 3: all three Sires")
	# her card's refusals name the right father
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var w_r := BroodNew.lay_problem(g, q, "raptor")
	var w_s := BroodNew.lay_problem(g, q, "spitter")
	var w_m := BroodNew.lay_problem(g, q, "mist_toad")
	var w_k := BroodNew.lay_problem(g, q, "hatchlings")
	check(w_r.contains("Tyrant Sire") and w_s.contains("Venom Sire") and w_m.contains("Venom Sire") and w_k.contains("Storm Sire"),
		"    no father: the refusals name each line's father (%s | %s | %s)" % [w_r, w_s, w_k])
	# made from grubs: each walks to a spot beside her and morphs; one of each (the grub on its way counts)
	var made := {}
	var ang := {BroodNew.FATHER: 0.3, BroodNew.DILO: 2.8, BroodNew.PTERO: 1.57}
	for fk in [BroodNew.FATHER, BroodNew.DILO, BroodNew.PTERO]:
		var spot := _father_spot(q, fk, float(ang[fk]))
		var gr: Unit = mine("grub").filter(func(u) -> bool: return u.order != "nb_morph")[0]
		gr.give({"o": "nb_morph", "k": fk, "p": spot})
		await wait(0.1)
		check(BroodRoot.morph_problem(g, 0, fk).begins_with("Only one"), "    a grub on its way to turn into a %s: one at a time (%s)" % [Defs.UNITS[fk]["name"], BroodRoot.morph_problem(g, 0, fk)])
		var cocooned: bool = await wait_for(func() -> bool: return mine(fk).size() == 1, 25.0)
		if not cocooned:
			check(false, "    the grub never turned into a %s (spot %s: %s %s; supply %d of %d)" % [fk, str(spot), BroodRoot.place_problem(g, 0, fk, spot, gr), BroodRoot.morph_problem(g, 0, fk, gr), g.supply_used(0), int(p["cap"])])
			continue
		var c: Unit = mine(fk)[0]
		c.nb["coc"] = BroodRoot.cocoon_time(c) - 0.3          # (the morph's time is the father's own: not waited out here)
		var open: bool = await wait_for(func() -> bool: return not BroodRoot.in_cocoon(c), 2.0)
		check(open and BroodNew.rooted(c) and BroodNew.father_near(g, 0, fk), "    a grub turned into the %s: rooted on his nest beside her (%.1f tiles)" % [Defs.UNITS[fk]["name"], c.position.distance_to(q.position) / T])
		made[fk] = c
	if made.size() < 3:
		return
	var tr: Unit = made[BroodNew.FATHER]
	var di: Unit = made[BroodNew.DILO]
	var pt: Unit = made[BroodNew.PTERO]
	# the Pterodactyl rooted: a ground structure
	var shooter: Unit = g._add_unit("raptor", 1, pt.position + Vector2(0, 200))          # (a ground-only biter: no anti-air)
	var cell_solid: bool = g.solid[g.idx(g.cell_of(BroodRoot.rect_of(pt).get_center()))] != 0
	check(not pt.is_air() and shooter.can_hit(pt) and cell_solid, "    the Pterodactyl rooted is a ground structure: an enemy Raptor (ground only) can bite it, its footprint solid (air %s)" % pt.is_air())
	# pheromones stack
	var lr: Array = BroodNew.lay_rate(g, q)
	check(int(lr[2]) == 3 and absf(float(lr[0]) - float(lr[1]) * (1.0 + 3.0 * float(Defs.NB["father_rate"]) + float(Defs.NB["expansion_rate"]) * int(lr[3]))) < 0.001,
		"    three fathers near her: +%d%% (%s)" % [int(round(3.0 * float(Defs.NB["father_rate"]) * 100.0)), BroodNew.levers_text(g, q)])
	# each line's eggs go to its own father's nest, all at once
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var before: Array = mine(BroodNew.EGG)
	var why := ""
	for k in ["spitter", "spitter", "mist_toad", "hatchlings", "raptor"]:
		var w: String = q.cmd_lay(k)
		if w != "":
			why += k + ": " + w + " "
	await wait(0.1)
	var new_eggs: Array = mine(BroodNew.EGG).filter(func(e) -> bool: return not before.has(e))
	var right := 0
	for e in new_eggs:
		var fk2 := BroodNew.father_of(String(e.nb["k"]))
		var f2: Unit = made[fk2]
		if bool(e.nb.get("nest", false)) and e.position.distance_to(BroodNew.nest_point(f2)) < BroodNew.NEST_GAP * 3.0 and e.position.y > BroodRoot.rect_of(f2).end.y:
			right += 1
	check(why == "" and new_eggs.size() == 5 and right == 5, "    5 eggs (2 Spitters, a Toad, Hatchlings, Raptors): each in its own father's nest (%d of %d) %s" % [right, new_eggs.size(), why])
	check(BroodNew.nest_eggs(g, di).size() == 3 and BroodNew.nest_eggs(g, pt).size() == 1 and BroodNew.nest_eggs(g, tr).size() == 1,
		"    nests: Dilophosaurus %d, Pterodactyl %d, Tyrannosaur %d" % [BroodNew.nest_eggs(g, di).size(), BroodNew.nest_eggs(g, pt).size(), BroodNew.nest_eggs(g, tr).size()])
	await wait(float(Defs.NB["fert_time"]) * 0.5)
	var half := BroodNew.nest_eggs(g, di).filter(func(e) -> bool: return float(e.nb.get("redden", 0.0)) > 0.2 or int(e.nb.get("fert", 0)) == 2).size()
	var all_f: bool = await wait_for(func() -> bool: return new_eggs.all(func(e) -> bool: return e.dead or int(e.nb.get("fert", 0)) == 2), float(Defs.NB["fert_time"]) + 1.0)
	check(half == 3 and all_f, "    each father fertilises all the eggs of his nest at once (%d of 3 under the Dilophosaurus' breath together)" % half)
	var hatched: bool = await wait_for(func() -> bool: return mine("hatchlings").size() >= 2 and mine("spitter").size() >= 4 and mine("mist_toad").size() >= 1, 30.0)
	check(hatched, "    they hatch: %d Spitters, %d Toads, %d Hatchlings" % [mine("spitter").size(), mine("mist_toad").size(), mine("hatchlings").size()])
	# the Toad only staggers the fathers
	var small_one: Unit = mine("spitter")[0] if not mine("spitter").is_empty() else shooter
	check(Unit.too_heavy(tr) and Unit.too_heavy(di) and Unit.too_heavy(pt) and not Unit.too_heavy(small_one),
		"    the Toad's TONGUE only staggers each father (never pulls him)")
	# the Pterodactyl uprooted: a flyer again (flies over, lands on his nest again)
	var home := BroodRoot.rect_of(pt).get_center()
	pt.cmd_uproot(false)
	var up: bool = await wait_for(func() -> bool: return pt.tesla_mode == "packed", float(Defs.NB["father_switch"]) + 2.0)
	await wait(0.1)
	check(up and pt.is_air() and not shooter.can_hit(pt) and not BroodRoot.has_fp(pt) and g.solid[g.idx(g.cell_of(home))] == 0,
		"    UPROOT: the Pterodactyl takes off: a flyer (the Raptor can not reach it), his ground free")
	var spot2 := _father_spot(q, BroodNew.PTERO, 2.2)
	pt.give({"o": "nb_root", "p": spot2})
	var landed: bool = await wait_for(func() -> bool: return pt.tesla_mode == "deployed", 20.0)
	check(landed and not pt.is_air() and pt.position.distance_to(spot2) < 2.0, "    ROOT: he flies to the spot and lands on his nest there (air %s, %.0f px off)" % [pt.is_air(), pt.position.distance_to(spot2)])
	g.consume_unit(shooter)
	for k in ["spitter", "mist_toad", "skywing", "hatchlings", "raptor"]:
		for u in mine(k):
			g.consume_unit(u)


## A spot beside the Mother where a father of kind k may nest, looked for round her from the angle a.
## 19. YOUNG AND MATURE (the owner, 2026-10-29 12:40-14:40; scripts/brood_mature.gd): eggs lay only the young; MATURE
## locked until her stage; the price paid (the mature form's less the young one's share of its egg); the moult (it can't
## move or fight, its supply held); then it is the mature unit with its kills and health share; MATURE on a group as far
## as the food allows; both Challengers fight (the Venom Challenger's glob splashes); the MATURE button on the card; the
## Mother's own art at each stage; the computer matures its young when food piles up.
func _mature(q: Unit, p: Dictionary) -> void:
	var T := Defs.TILE
	for k in ["raptor", "spitter", "tyrant_challenger", "venom_challenger", "musketeer", BroodNew.EGG]:
		for u in g.units.filter(func(u) -> bool: return not u.dead and u.kind == k):
			g.consume_unit(u)
	p["gold"] = 5000
	p["res2"] = 500.0
	var st0 := BroodNew.stage(q)
	# eggs lay only the young
	check(not BroodNew.hatch_list().has("tyrant_challenger") and not BroodNew.hatch_list().has("venom_challenger")
		and BroodNew.lay_problem(g, q, "tyrant_challenger") != "" and BroodNew.lay_problem(g, q, "venom_challenger") != ""
		and BroodMature.mature_of("raptor") == "tyrant_challenger" and BroodMature.mature_of("spitter") == "venom_challenger",
		"19. eggs lay only the young: no Challenger on her card (%s)" % BroodNew.lay_problem(g, q, "tyrant_challenger"))
	var home := spot_near(q.position, 14.0)
	var r: Unit = g._add_unit("raptor", 0, home)
	q.nb["stage"] = 0
	var why0 := BroodMature.problem(r)
	check(why0 == "Needs the Brood Mother at stage 2.", "    MATURE locked until her stage 2 (%s)" % why0)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	await wait(0.2)
	# the price: the Tyrant Challenger's 100 + 10 less a third of a 75-food Raptor egg
	var pr := BroodMature.price(g, 0, "raptor")
	var pv := BroodMature.price(g, 0, "spitter")
	check(pr == [75, 10] and pv == [105, 17], "    the price: a Raptor %s, a Spitter %s (the mature form's less the young one's share of its egg)" % [str(pr), str(pv)])
	r.kills = 5
	r.hp = r.max_hp * 0.5
	var g0 := int(p["gold"])
	var e0 := float(p["res2"])
	var s0: int = g.supply_used(0)
	var w: String = g.mature_order([r])
	check(w == "" and r.moult_t >= 0.0 and int(p["gold"]) == g0 - 75 and absf(float(p["res2"]) - (e0 - 10.0)) < 0.01 and g.supply_used(0) == s0 + 1,
		"    MATURE: paid 75 food + 10 spoils, the moult begins, its supply held (+1: %d -> %d)" % [s0, g.supply_used(0)])
	var at := r.position
	r.cmd_move(at + Vector2(8.0 * T, 0.0))
	await wait(3.0)
	check(r.position.distance_to(at) < 2.0 and r.kind == "raptor" and not r.can_hit(BroodNew.queen(g, 0)) and r.moult_t > 2.5,
		"    moulting it can't move or fight (moved %.1f px in 3 s)" % r.position.distance_to(at))
	await wait_for(func() -> bool: return r.kind == "tyrant_challenger", float(Defs.NB["moult"]))
	check(r.kind == "tyrant_challenger" and r.kills == 5 and absf(r.hp / r.max_hp - 0.5) < 0.02 and r.art == "tyrant_challenger" and r.moult_t < 0.0,
		"    after %.0f s it IS a Tyrant Challenger: kills %d kept, health %.0f%% kept, its own art" % [float(Defs.NB["moult"]), r.kills, r.hp / r.max_hp * 100.0])
	# MATURE on a group: as far as the food allows
	var rs: Array = []
	for i in 4:
		rs.append(g._add_unit("raptor", 0, home + Vector2(20.0 * i, 30.0)))
	p["gold"] = 160
	var w2: String = g.mature_order(rs)
	var n2 := rs.filter(func(u) -> bool: return u.moult_t >= 0.0).size()
	check(w2 == "" and n2 == 2 and int(p["gold"]) == 10, "    MATURE on 4 Raptors with 160 food: %d moult (each pays for itself), %d food left" % [n2, int(p["gold"])])
	# the MATURE button on a young unit's card
	g.selection.clear()
	for u in rs:
		u.selected = true
		g.selection.append(u)
	var labs := card_labels()
	check(labs.has("MATURE"), "    the MATURE button on the Raptors' card (%s)" % ", ".join(labs))
	g.selection.clear()
	for u in rs:
		u.selected = false
	# the Venom Challenger
	p["gold"] = 5000
	var sp: Unit = g._add_unit("spitter", 0, home + Vector2(0.0, -40.0))
	g.mature_order([sp])
	await wait_for(func() -> bool: return sp.kind == "venom_challenger", float(Defs.NB["moult"]) + 1.0)
	check(sp.kind == "venom_challenger" and sp.art == "venom_challenger", "    a Spitter matures into a Venom Challenger")
	# both fight: the Tyrant Challenger bites a Musketeer; the Venom Challenger's glob splashes on a cluster
	var tc: Unit = r
	var foe_at := home + Vector2(5.0 * T, 0.0)
	var m1: Unit = g._add_unit("musketeer", 1, foe_at)
	var cl: Array = []
	for i in 3:
		cl.append(g._add_unit("musketeer", 1, home + Vector2(-5.0 * T, -40.0) + Vector2(10.0 * i, 6.0 * (i % 2))))
	for u in [m1] + cl:
		u.cmd_stop()
	tc.cmd_attack(m1)
	sp.cmd_attack(cl[1])
	var hp_m := m1.hp
	var hp_c: Array = cl.map(func(u) -> float: return u.hp)
	await wait(6.0)
	var hit_c := 0
	for i in cl.size():
		if cl[i].dead or cl[i].hp < hp_c[i] - 0.5:
			hit_c += 1
	check(m1.dead or m1.hp < hp_m - 10.0, "    the Tyrant Challenger bites (the Musketeer %.0f -> %.0f)" % [hp_m, m1.hp if not m1.dead else 0.0])
	check(hit_c >= 2, "    the Venom Challenger's glob splashes: %d of 3 clustered Musketeers hurt" % hit_c)
	for u in [m1] + cl:
		if not u.dead:
			g.consume_unit(u)
	# the Mother's own art at each stage
	var arts := []
	for st in 3:
		q.nb["stage"] = st
		BroodNew.apply_stage(q)
		arts.append(q.art)
	check(arts == ["brood_mother", "brood_mother_2", "brood_mother_3"], "    the Mother's own art at each stage: %s" % str(arts))
	q.nb["stage"] = st0
	BroodNew.apply_stage(q)
	# the computer matures its young when food piles up (its plan run for side 0 here)
	q.nb["stage"] = 1
	for u in mine("raptor"):
		g.consume_unit(u)
	var ys: Array = []
	for i in 6:
		ys.append(g._add_unit("raptor", 0, home + Vector2(15.0 * i, -70.0)))
	p["gold"] = 900
	var ai = AIBroodNew.new()
	ai.game = g
	ai.team = 0
	ai._nb_mature(q)
	var na := ys.filter(func(u) -> bool: return u.moult_t >= 0.0).size()
	check(na >= 1 and int(p["gold"]) >= AIBroodNew.MATURE_KEEP, "    the computer matures young units when food piles up: %d of 6 Raptors, %d food kept" % [na, int(p["gold"])])
	ai.free()
	q.nb["stage"] = st0
	BroodNew.apply_stage(q)


## 20. THE SIRE LURES (the owner, 2026-10-29 18:03-18:31; docs/sire_lure.md): a grub turns into a Sire's LURE, not into
## the grown Sire: rooted, its footprint, not working, the lure's pictures, his card name; one Sire at a time counts
## the lure; the same total time (grow, ~2.6 s arrival, settle); ripe, it pulses; the Sire arrives in its animation and
## nests on its spot; his eggs lie in front of his footprint; a lure killed early (no refund, its ground free, another
## may grow); the computer makes a Sire through a lure; a match saved mid-lure (resumed at the end of the run).
var lure_saved = null
var lure_spot := Vector2.ZERO
var lure_coc := 0.0


func _lures(q: Unit, p: Dictionary) -> void:
	var T := Defs.TILE
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)
	for u in mine(BroodNew.EGG):
		g.consume_unit(u)
	p["gold"] = 5000
	p["res2"] = 500.0
	var tsup := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 16.0))
	tsup.nb.erase("coc")               # (a rooted turtle: supply)
	BroodNew.recount(g, 0)
	while mine("grub").size() < 12:
		g._add_unit("grub", 0, spot_near(q.position, 6.0))
	await wait(0.2)
	var fk := BroodNew.DILO
	var spot := _father_spot(q, fk, 0.9)
	var gold0 := int(g.stats[0]["spent"])
	var gr: Unit = mine("grub").filter(func(u) -> bool: return u.order != "nb_morph")[0]
	gr.give({"o": "nb_morph", "k": fk, "p": spot})
	var grown: bool = await wait_for(func() -> bool: return mine(fk).size() == 1, 25.0)
	var lu: Unit = mine(fk)[0] if grown else null
	check(grown and BroodRoot.is_lure(lu) and BroodRoot.lure_phase(lu) == "grow" and lu.position.distance_to(BroodRoot.snap(fk, spot)) < 1.0
		and BroodRoot.has_fp(lu) and not BroodNew.rooted(lu) and int(g.stats[0]["spent"]) - gold0 == int(g.unit_price(0, fk)[0]),
		"20. a grub walks to the spot, pays %d and swells into the Venom Sire's LURE there: rooted (its footprint), not working" % (int(g.stats[0]["spent"]) - gold0))
	if not grown:
		return
	await wait(0.2)
	var cs := BroodRoot._pic(lu, BroodRoot.COC) as Sprite2D
	check(cs != null and cs.texture != null and cs.texture.resource_path.ends_with("lure_dilophosaurus/grow_se.png") and lu.sprite.self_modulate.a < 0.01
		and String(BroodNew.progress(g, lu).get("label", "")) == "LURE RIPENING" and BroodRoot.lure_name(fk) == "Venom Lure",
		"    the lure's growing pictures, the Sire not seen yet; LURE RIPENING; named %s" % BroodRoot.lure_name(fk))
	check(BroodRoot.morph_problem(g, 0, fk).begins_with("Only one") and BroodNew.lay_problem(g, q, "spitter").contains("rooted"),
		"    one Sire at a time: his lure counts (%s); it fathers nothing yet" % BroodRoot.morph_problem(g, 0, fk))
	var lt := BroodRoot.lure_times(fk)
	check(absf(float(lt[0]) + float(lt[1]) + float(lt[2]) - BroodNew.egg_time(fk)) < 0.01 and float(lt[1]) >= 2.0 and float(lt[1]) <= 3.0,
		"    the old morph's time in all (%d s): the lure %.1f s, his arrival %.1f s, settling %.1f s" % [int(BroodNew.egg_time(fk)), float(lt[0]), float(lt[1]), float(lt[2])])
	lu.nb["coc"] = float(lt[0]) * 0.9
	await wait(0.15)
	cs = BroodRoot._pic(lu, BroodRoot.COC) as Sprite2D
	var s1 := cs.scale if cs else Vector2.ZERO
	await wait(0.4)
	check(cs != null and cs.texture.resource_path.ends_with("ripe_se.png") and cs.scale != s1, "    ripe: the ripe lure, breathing (%s -> %s)" % [str(s1), str(cs.scale if cs else Vector2.ZERO)])
	# a match saved now (mid-lure): resumed at the end of the run
	lure_spot = lu.position
	lure_coc = float(lu.nb["coc"])
	lure_saved = JSON.parse_string(JSON.stringify(SaveGame.capture(g, main.last_cfg)))
	# the arrival
	lu.nb["coc"] = float(lt[0]) - 0.05
	await wait(0.4)
	cs = BroodRoot._pic(lu, BroodRoot.COC) as Sprite2D
	check(BroodRoot.lure_phase(lu) == "arrive" and String(BroodNew.progress(g, lu).get("label", "")) == "THE SIRE ARRIVES" and cs != null
		and cs.texture.resource_path.ends_with("arrive_se.png") and cs.hframes == 12 and lu.sprite.self_modulate.a < 0.01,
		"    ripe: the Sire ARRIVES in the lure's animation (12 frames; frame %d)" % (cs.frame if cs else -1))
	var opened: bool = await wait_for(func() -> bool: return not BroodRoot.in_cocoon(lu), float(lt[1]) + float(lt[2]) + 2.0)
	await wait(0.1)
	check(opened and BroodNew.rooted(lu) and lu.position.distance_to(BroodRoot.snap(fk, spot)) < 1.0 and BroodNew.father_near(g, 0, fk)
		and lu.sprite.self_modulate.a > 0.99 and BroodRoot._pic(lu, BroodRoot.COC) == null and BroodRoot._pic(lu, BroodRoot.PUFF) == null,
		"    he ate the lure and nests on its spot: rooted beside her, seen, the lure's pictures gone")
	# his eggs in front of his footprint
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var w1: String = q.cmd_lay("spitter")
	var w2: String = q.cmd_lay("spitter")
	await wait(0.1)
	var ne: Array = BroodNew.nest_eggs(g, lu)
	var fr := BroodRoot.rect_of(lu)
	var front := ne.filter(func(e) -> bool: return e.position.y > fr.end.y and e.position.y < fr.end.y + 2.0 * T and absf(e.position.x - fr.get_center().x) < fr.size.x * 0.5 and e.sprite.visible and e.z_index == BroodNew.EGG_Z)
	check(w1 == "" and w2 == "" and ne.size() == 2 and front.size() == 2 and ne[0].position.distance_to(ne[1].position) >= BroodNew.NEST_GAP - 0.5,
		"    his eggs lie IN FRONT of his footprint, side by side, seen on the top layer (%d of %d) %s %s" % [front.size(), ne.size(), w1, w2])
	var fert: bool = await wait_for(func() -> bool: return ne.all(func(e) -> bool: return e.dead or int(e.nb.get("fert", 0)) == 2), float(Defs.NB["fert_time"]) + 1.0)
	check(fert and BroodNew.producing(g, lu), "    he fertilises them there, in his production loop")
	# (the owner, 20:09) HIS EGGS TAKE HIS LURE'S COLOUR, FAINTLY; the plain eggs keep theirs
	await wait(0.1)
	var wsh: Array = ne.filter(func(e) -> bool: return not e.dead).map(func(e) -> Color: return (e.sprite.material as ShaderMaterial).get_shader_parameter("wash"))
	var vcol := BroodNew.egg_col("spitter")
	check(not wsh.is_empty() and wsh.all(func(c) -> bool: return absf(c.a - float(Defs.NB["egg_wash"])) < 0.02 and c.a < 0.5 and Color(c.r, c.g, c.b).is_equal_approx(vcol)),
		"22. his fertilised eggs wear the Venom lure's faint yellow-green (%s)" % str(wsh))
	var tcol := BroodNew.egg_col("raptor")
	var scol := BroodNew.egg_col("hatchlings")
	check(tcol.r > 0.8 and tcol.g < 0.4 and tcol.b < 0.4 and scol.r > 0.9 and scol.g > 0.9 and scol.b - scol.r < 0.05 and vcol.g > vcol.b + 0.5,
		"    the Tyrant's eggs a faint red %s, the Storm's a faint storm-cloud white %s (no blue)" % [str(tcol), str(scol)])
	var lc0 := BroodRoot.lure_col(BroodNew.PTERO)
	check(lc0.b - lc0.r < 0.1 and lc0.r > 0.8, "    the Storm Lure's haze storm-cloud white too, not blue (%s)" % str(lc0))
	var ge: Unit = g._add_unit(BroodNew.EGG, 0, spot_near(q.position, 4.0))
	ge.nb["k"] = "grub"
	var we: Unit = g._add_unit(BroodNew.EGG, 0, spot_near(q.position, 4.0))
	we.nb["k"] = "raptor"
	we.nb["fert"] = 1
	var wn: Unit = g._add_unit(BroodNew.EGG, 0, spot_near(q.position, 4.0))
	wn.nb["k"] = "raptor"
	wn.nb["fert"] = 1
	wn.nb["nest"] = true
	await wait(0.15)
	check(BroodNew.egg_tint(ge) == 0.0 and BroodNew.egg_tint(we) == 0.0 and absf(BroodNew.egg_tint(wn) - float(Defs.NB["egg_nest"])) < 0.01
		and ((ge.sprite.material as ShaderMaterial).get_shader_parameter("wash") == null or float(((ge.sprite.material as ShaderMaterial).get_shader_parameter("wash") as Color).a) == 0.0),
		"    a grub egg and a warrior egg not yet with him keep their colour; one lying in a Sire's nest starts faintly tinted (%.2f)" % BroodNew.egg_tint(wn))
	for e in [ge, we, wn]:
		g.consume_unit(e)
	for e in mine(BroodNew.EGG):
		g.consume_unit(e)
	# a lure killed early: no refund, its ground free, another may grow
	var gr2: Unit = mine("grub").filter(func(u) -> bool: return u.order != "nb_morph")[0]
	var spot2 := _father_spot(q, BroodNew.FATHER, 3.6)
	gr2.give({"o": "nb_morph", "k": BroodNew.FATHER, "p": spot2})
	var g2: bool = await wait_for(func() -> bool: return mine(BroodNew.FATHER).size() == 1, 25.0)
	if g2:
		var l2: Unit = mine(BroodNew.FATHER)[0]
		var mid := BroodRoot.rect_of(l2).get_center()
		var gold1 := int(p["gold"])
		check(BroodRoot.is_lure(l2) and l2.hp < l2.max_hp * 0.5 and BroodNew.progress(g, l2).get("label") == "LURE RIPENING", "    a Tyrant Lure grows (health %d of %d: it grows with it)" % [int(l2.hp), int(l2.max_hp)])
		l2.take_damage(99999.0, null)
		await wait(0.3)
		check(l2.dead and BroodNew.count_of(g, 0, BroodNew.FATHER) == 0 and BroodRoot.morph_problem(g, 0, BroodNew.FATHER) == "" and int(p["gold"]) - gold1 < 40
			and g.solid[g.idx(g.cell_of(mid))] == 0,
			"    killed before he came: the lure is lost (no refund, as a cocoon: food %+d), its ground free, another may grow (%s)" % [int(p["gold"]) - gold1, BroodRoot.morph_problem(g, 0, BroodNew.FATHER)])
		var lc := BroodRoot._pic(l2, BroodRoot.COC) as Sprite2D if is_instance_valid(l2) else null
		check(lc == null or lc.has_meta("d0"), "    the dead lure bursts (its picture shrinks away)")
	else:
		check(false, "    the grub never grew the Tyrant Lure")
	# the computer makes a Sire through a lure
	while BroodNew.count_of(g, 0, BroodNew.MAW) < 2:
		var mm := BroodRoot.cocoon(g, 0, BroodNew.MAW, free_spot(BroodNew.MAW, q.position, 12.0, null, false))
		mm.nb.erase("coc")
	while mine("grub").size() < 12:
		g._add_unit("grub", 0, spot_near(q.position, 6.0))
	var ai = AIBroodNew.new()
	ai.game = g
	ai.team = 0
	ai._nb_morphs(q)
	var ag: bool = await wait_for(func() -> bool: return mine(BroodNew.FATHER).filter(func(u) -> bool: return not u.dead).size() == 1, 25.0)
	var al: Array = mine(BroodNew.FATHER).filter(func(u) -> bool: return not u.dead)
	check(ag and BroodRoot.is_lure(al[0]), "    the computer makes its Tyrant Sire through a lure too")
	ai.free()
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)


## 22. (the owner, 2026-10-29 20:09) THE STORM SIRE FLIES IN: from a few tiles away in his flying frames with his air
## shadow, gliding down into the arrival sheet's frames 3-6 (dive, brake, land), then eats and stands; his total time
## unchanged.
func _storm_arrival(q: Unit) -> void:
	var k := BroodNew.PTERO
	for u in mine(k):
		g.consume_unit(u)
	var u: Unit = BroodRoot.cocoon(g, 0, k, _father_spot(q, k, 1.2))
	var lt := BroodRoot.lure_times(k)
	var fl := BroodRoot.fly_time(k)
	check(absf(float(lt[0]) + float(lt[1]) + float(lt[2]) - BroodNew.egg_time(k)) < 0.01 and fl >= 2.0 and absf(float(lt[1]) - fl - float(Defs.NB["lure_arrive"])) < 0.01,
		"22. the Storm Sire's time in all still %d s: the lure %.1f s, his flight in %.1f s and arrival %.1f s, settling %.1f s" % [int(BroodNew.egg_time(k)), float(lt[0]), fl, float(lt[1]) - fl, float(lt[2])])
	u.nb["coc"] = float(lt[0]) + fl * 0.3
	await wait(0.1)
	var fn := BroodRoot._pic(u, BroodRoot.FLY) as Node2D
	var body := fn.get_node_or_null("Body") as Sprite2D if fn else null
	var cs := BroodRoot._pic(u, BroodRoot.COC) as Sprite2D
	var shp: Vector2 = fn.get_meta("sh", Vector2.ZERO) if fn else Vector2.ZERO
	check(BroodRoot.flying_in(u) and fn != null and fn.visible and body != null and body.visible and body.texture.resource_path.ends_with("pterodactyl/walk_se.png")
		and cs.texture.resource_path.ends_with("ripe_se.png") and body.position.y < shp.y - 80.0 and shp.distance_to(cs.position) > Defs.TILE * 2.0
		and String(BroodNew.progress(g, u).get("label", "")) == "THE SIRE ARRIVES",
		"    he FLIES IN: his flying frames high over his shadow (%.0f px up), a few tiles off (%.0f px), the ripe lure below" % [shp.y - (body.position.y if body else 0.0), shp.distance_to(cs.position if cs else Vector2.ZERO)])
	var y0 := body.position.y - shp.y if body else 0.0
	var d0 := shp.distance_to(cs.position) if cs else 0.0
	u.nb["coc"] = float(lt[0]) + fl * 0.9
	await wait(0.05)
	shp = fn.get_meta("sh", Vector2.ZERO)
	check(body.position.y - shp.y > y0 and shp.distance_to(cs.position) < d0, "    he glides down and in (%.0f -> %.0f px up)" % [-y0, shp.y - body.position.y])
	u.nb["coc"] = float(lt[0]) + fl + 0.05
	await wait(0.05)
	check(not BroodRoot.flying_in(u) and cs.texture.resource_path.ends_with("arrive_se.png") and cs.frame == 2 and not body.visible,
		"    then the sheet's frame 3: his dive (frame %d)" % (cs.frame + 1))
	var seen := {}
	while BroodRoot.lure_phase(u) == "arrive":
		seen[cs.frame] = true
		await physics_frame
	check(seen.has(3) and seen.has(4) and seen.has(5) and not seen.has(0) and not seen.has(1) and seen.has(11),
		"    brake, land, eat and stand: frames %s (not the ripe-only frames 1-2)" % str(seen.keys().map(func(x) -> int: return x + 1)))
	var opened: bool = await wait_for(func() -> bool: return not BroodRoot.in_cocoon(u), float(lt[2]) + 1.0)
	await wait(0.1)
	check(opened and BroodNew.rooted(u) and not u.is_air() and BroodRoot._pic(u, BroodRoot.FLY) == null, "    LANDED: rooted on his nest, a ground creature, his flight's pictures gone")
	g.consume_unit(u)


## The match saved mid-lure, resumed: the lure is still there, as far on, its ground taken; it ripens and he comes.
func _lure_resumed() -> void:
	if not (lure_saved is Dictionary) or (lure_saved as Dictionary).is_empty():
		check(false, "20. the match saved mid-lure")
		return
	var cfg: Dictionary = (lure_saved["cfg"] as Dictionary).duplicate(true)
	cfg["resume"] = lure_saved
	main.start(cfg)
	await process_frame
	await process_frame
	g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
	await wait(0.5)
	var l: Array = g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == BroodNew.DILO)
	var lu: Unit = l[0] if not l.is_empty() else null
	check(lu != null and BroodRoot.is_lure(lu) and lu.position.distance_to(lure_spot) < 1.0 and BroodRoot.has_fp(lu)
		and absf(float(lu.nb["coc"]) - lure_coc) < 2.0 and g.solid[g.idx(g.cell_of(BroodRoot.rect_of(lu).get_center()))] != 0,
		"20. saved mid-lure and continued: the Venom Lure there, as ripe (%.1f s, was %.1f s), its ground taken" % [float(lu.nb.get("coc", -1.0)) if lu else -1.0, lure_coc])
	if lu == null:
		return
	lu.nb["coc"] = BroodRoot.cocoon_time(lu) - 0.5
	var opened: bool = await wait_for(func() -> bool: return not BroodRoot.in_cocoon(lu), 3.0)
	check(opened and BroodNew.rooted(lu), "    then he comes and nests there")


func _father_spot(q: Unit, k: String, a: float) -> Vector2:
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	for frac in [0.75, 0.6, 0.9, 0.5]:
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * reach * frac)
			if g.region_of(g.cell_of(p)) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return q.position


## 21. THE BROOD'S RESEARCH (scripts/brood_research.gd, docs/brood_research.md).
var rs_saved = null
var rs_t0 := 0.0


func _sire(q: Unit, k: String, a: float) -> Unit:
	var f := BroodRoot.cocoon(g, 0, k, _father_spot(q, k, a))
	f.nb.erase("coc")
	f.hp = f.max_hp
	BroodNew.recount(g, 0)
	return f


## 22. (the owner, 2026-10-29 20:09) WHAT A SIRE RESEARCHES is shown to his own side, its allies and spectators,
## never to an enemy: no bar or label over him, nothing on his card or its tooltips; the enemy sees only his loop.
func _research_hidden(f: Unit) -> void:
	var own := BroodNew.bar_over(g, f)
	g.set_selection([f])
	await wait(0.2)
	check(String(own.get("label", "")).begins_with("RESEARCHING") and String(g.hud.nb_prog.get("label", "")).begins_with("RESEARCHING"),
		"22. his own side sees RESEARCHING over him and on his card (%s)" % str(own.get("label", "")))
	# the enemy (the Crown, team 1) looks at him
	var h0: int = g.human
	g.human = 1
	g.set_selection([f])
	await wait(0.25)
	var labs := card_labels()
	var leak := labs.filter(func(l) -> bool: return String(l).contains("RESEARCH") or String(l).contains("CLUTCH") or String(l).contains("PACK"))
	var tips := ""
	for k in g.hud._tip_for:
		tips += str(g.hud._tip_for[k])
	var fog_vis: bool = f.visible
	g.reveal = true          # (where he can see him: his loop)
	var frames := {}
	for i in 30:
		await physics_frame
		frames[f.sprite.frame] = true
	g.reveal = false
	check(g.selection.has(f) and BroodNew.bar_over(g, f).is_empty() and g.hud.nb_prog.is_empty() and leak.is_empty() and not tips.contains("Bigger Clutch")
		and not BroodResearch.shown_to(g, f),
		"    an ENEMY selecting him sees no research: no bar or label over him, nothing on his card (%s) or its tooltips" % str(labs))
	check(BroodNew.producing(g, f) and frames.size() >= 2, "    ...only his production loop playing where the enemy sees him (%d frames; under fog: hidden %s)" % [frames.size(), str(not fog_vis)])
	# an ally of his (no frame passes: one side alone would have won)
	var s1 = g.sides[1]
	g.sides[1] = g.sides[0]
	check(BroodResearch.shown_to(g, f) and String(BroodNew.bar_over(g, f).get("label", "")).begins_with("RESEARCHING"), "    an ALLY sees what he researches")
	g.sides[1] = s1
	g.demo = true
	check(BroodResearch.shown_to(g, f) and not BroodNew.bar_over(g, f).is_empty(), "    a spectator sees it too")
	g.demo = false
	g.human = h0
	g.set_selection([f])
	await wait(0.1)


func _research(q: Unit, p: Dictionary) -> void:
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)
	for k0 in [BroodNew.EGG, "raptor", "spitter", "brute", "skywing", "tyrant_challenger", "venom_challenger"]:
		for u in mine(k0):
			g.consume_unit(u)
	for k0 in p["tech"].keys():
		if String(k0).begins_with("nb_"):
			p["tech"].erase(k0)
	p["gold"] = 5000
	p["res2"] = 500.0
	q.nb["stage"] = 0
	BroodNew.apply_stage(q)
	q.nb["grow_t"] = 0.0
	while int(g.players[0]["cap"]) - g.supply_used(0) < 30:
		var tt := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 18.0))
		tt.nb.erase("coc")
		BroodNew.recount(g, 0)
	await wait(0.2)
	# the young: two to an egg
	check(int(Defs.UNITS["raptor"]["spawn"]) == 2 and g.unit_price(0, "raptor") == [50, 0] and int(Defs.UNITS["spitter"]["spawn"]) == 2
		and g.unit_price(0, "spitter") == [90, 5] and BroodNew.young(g, 0, "raptor") == 2,
		"21. young TWO to an egg: a Raptor egg %s, a Spitter egg %s" % [str(g.unit_price(0, "raptor")), str(g.unit_price(0, "spitter"))])
	check(not bool(Defs.UNITS["spitter"].get("anti_air", false)) and bool(Defs.UNITS["venom_challenger"].get("anti_air", false))
		and float(Defs.UNITS["raptor"]["speed"]) == 96.0 and float(Defs.UNITS["tyrant_challenger"]["speed"]) == 84.0,
		"    Spitters can't shoot flyers, the Venom Challenger can; the standard speeds lowered (Raptor 96, Challenger 84)")
	var f := _sire(q, BroodNew.FATHER, 0.3)
	var d := _sire(q, BroodNew.DILO, 2.4)
	await wait(0.3)
	check(BroodNew.father_near(g, 0, BroodNew.FATHER) and BroodNew.father_near(g, 0, BroodNew.DILO), "    the Tyrant and Venom Sires rooted beside her")
	# the Sire's card
	g.set_selection([f])
	await wait(0.1)
	var labs := card_labels()
	var horns := _item("BATTERING HORNS")
	check(labs.has("BIGGER CLUTCH") and labs.has("PACK HUNT") and labs.has("BATTERING HORNS") and not horns.is_empty() and not bool(horns[3])
		and String(horns[4]).contains("stage 3"), "    his card: BIGGER CLUTCH, PACK HUNT, BATTERING HORNS (greyed: %s)" % (str(horns[4]) if not horns.is_empty() else "-"))
	var tip: Dictionary = g.hud._card_tip(_item("PACK HUNT") + ["", "", ""]) if not _item("PACK HUNT").is_empty() else {}
	check(String(tip.get("stats", "")).contains("75") and String(tip.get("stats", "")).contains("35 s") and String(tip.get("body", "")).contains("114"),
		"    its tooltip: name, effect, cost, time (%s | %s)" % [tip.get("title", ""), tip.get("stats", "")])
	# BIGGER CLUTCH on the Tyrant Sire
	var gold0 := int(p["gold"])
	var sp0 := float(p["res2"])
	var w: String = f.cmd_nb_research("nb_clutch_raptor")
	await wait(0.1)
	check(w == "" and BroodResearch.current(f) == "nb_clutch_raptor" and gold0 - int(p["gold"]) == 100 and absf(sp0 - float(p["res2"]) - 15.0) < 0.01,
		"    BIGGER CLUTCH started: paid 100 food and 15 spoils %s" % w)
	var pg := BroodNew.progress(g, f)
	check(String(pg.get("label", "")).begins_with("RESEARCHING") and float(pg.get("left", 0.0)) > 38.0, "    his card shows %s (%.0f s)" % [pg.get("label", ""), float(pg.get("left", 0.0))])
	await _research_hidden(f)
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var why := BroodNew.lay_problem(g, q, "raptor")
	check(why.contains("researching") and BroodNew.lay_problem(g, q, "spitter") == "", "    no Raptor eggs while he researches (%s); the Venom line still lays" % why)
	labs = card_labels()
	check(labs.has("STOP RESEARCH") and labs.has("PACK HUNT") and not labs.has("BIGGER CLUTCH"), "    STOP RESEARCH, and his other research kept to QUEUE (the owner, 2026-10-30 19:38)")
	var frames := {}
	for i in 30:
		await physics_frame
		frames[f.sprite.frame] = true
	check(BroodNew.producing(g, f) and frames.size() >= 2, "    researching he lays no eggs but his fertilising loop plays on (%d frames seen)" % frames.size())
	# done
	f.nb["rs_t"] = float(Defs.RESEARCH["nb_clutch_raptor"]["time"]) - 0.1
	var dn: bool = await wait_for(func() -> bool: return g.has_tech(0, "nb_clutch_raptor"), 1.0)
	check(dn and not BroodResearch.busy(f) and g.unit_price(0, "raptor") == [75, 0] and BroodNew.lay_problem(g, q, "raptor") == "",
		"    done: Raptors THREE to an egg for %s (25 each still)" % str(g.unit_price(0, "raptor")))
	var r0 := mine("raptor").size()
	var gl := int(p["gold"])
	q.cmd_lay("raptor")
	var paid := gl - int(p["gold"])          # (read at once: grubs delivering food in the wait would change it)
	await wait(0.1)
	var eg: Array = BroodNew.nest_eggs(g, f)
	check(paid == 75 and eg.size() == 1 and int(eg[0].nb.get("n", 0)) == 3, "    an egg paid 75, holding 3 (paid %d, %d in his nest, holding %s; %s)" % [paid, eg.size(), str(eg[0].nb.get("n", 0)) if eg.size() > 0 else "-", BroodNew.lay_problem(g, q, "raptor")])
	var h3: bool = await wait_for(func() -> bool: return mine("raptor").size() >= r0 + 3, float(Defs.UNITS["raptor"]["time"]) + 4.0)
	check(h3 and mine("raptor").size() == r0 + 3, "    it hatches 3 Raptors (%d)" % (mine("raptor").size() - r0))
	check(BroodMature.price(g, 0, "raptor") == [75, 10], "    maturing a Raptor still costs %s (its share of the egg the same)" % str(BroodMature.price(g, 0, "raptor")))
	# the Venom line: Spitters 3 to an egg, 135 + 8
	g.players[0]["tech"]["nb_clutch_spitter"] = true
	check(g.unit_price(0, "spitter") == [135, 8] and BroodMature.price(g, 0, "spitter") == [105, 17], "    the Venom Sire's BIGGER CLUTCH: a Spitter egg %s, maturing still %s" % [str(g.unit_price(0, "spitter")), str(BroodMature.price(g, 0, "spitter"))])
	var hk := "hatchlings"
	var hwhy := BroodResearch.problem(g, _sire(q, BroodNew.PTERO, 4.5), "nb_clutch_hatchlings")
	check(BroodResearch.clutch_key(hk) == "nb_clutch_hatchlings" and BroodResearch.base_clutch(hk) == 2 and hwhy == "Needs the Brood Mother at stage 2.",
		"    the Storm Sire's BIGGER CLUTCH: Hatchlings 2 to an egg, 3 with it; at her stage 1 it waits for stage 2 (%s)" % hwhy)
	g.players[0]["tech"]["nb_clutch_hatchlings"] = true
	check(BroodResearch.clutch(g, 0, hk) == 3, "    with it the Hatchlings come 3 to an egg")
	g.players[0]["tech"].erase("nb_clutch_hatchlings")
	# PACK HUNT, SLITHER, UPDRAFT: speeds
	var ra: Unit = mine("raptor")[0]
	var tc: Unit = g._add_unit("tyrant_challenger", 0, spot_near(q.position, 14.0))
	var spt: Unit = g._add_unit("spitter", 0, spot_near(q.position, 14.0))
	var vc: Unit = g._add_unit("venom_challenger", 0, spot_near(q.position, 14.0))
	var sw: Unit = g._add_unit("skywing", 0, spot_near(q.position, 14.0))
	var br: Unit = g._add_unit("brute", 0, spot_near(q.position, 14.0))
	check(BroodResearch.speed_add(ra) == 0.0 and float(br.d["building_bonus"]) == 2.5 and float(spt.d["range"]) == 165.0 and float(vc.d["range"]) == 165.0
		and float(spt.d["range"]) < float(Defs.UNITS["musketeer"]["range"]),
		"    before: no speed added, a Brute x2.5 on buildings, a Spitter's and a Venom Challenger's range 165, under a Musketeer's %d" % int(Defs.UNITS["musketeer"]["range"]))
	for k in ["nb_pack_hunt", "nb_slither", "nb_updraft", "nb_battering_horns", "nb_long_spit", "nb_quick_roots", "nb_swamp_mending"]:
		BroodResearch.done(g, 0, k)
	check(is_equal_approx(96.0 + BroodResearch.speed_add(ra), 114.0) and is_equal_approx(84.0 + BroodResearch.speed_add(tc), 98.0),
		"    PACK HUNT: a Raptor %d, a Tyrant Challenger %d" % [int(96.0 + BroodResearch.speed_add(ra)), int(84.0 + BroodResearch.speed_add(tc))])
	await wait(0.1)
	check(ra.speed >= 113.9, "    ...and it runs at it (%.0f px/s now, swamp x1.3 included)" % ra.speed)
	check(is_equal_approx(68.0 + BroodResearch.speed_add(spt), 78.0) and is_equal_approx(58.0 + BroodResearch.speed_add(vc), 67.0), "    SLITHER: a Spitter 78, a Venom Challenger 67")
	check(is_equal_approx(BroodResearch.speed_add(sw), 18.0), "    UPDRAFT: a flying Skywing +18 (118 -> 136)")
	# (the owner, 20:09) PACK HUNT also speeds up the Tyrant Sire, UPDRAFT the Storm Sire (flying), by about the same share
	var stp: Unit = g._add_unit(BroodNew.PTERO, 0, spot_near(q.position, 14.0))
	BroodNew.set_sky(stp)
	var t_add := BroodResearch.speed_add(f)
	var s_add := BroodResearch.speed_add(stp)
	check(f.kind == BroodNew.FATHER and is_equal_approx(t_add, 11.0) and absf(t_add / float(Defs.UNITS[BroodNew.FATHER]["speed"]) - 18.0 / 96.0) < 0.03,
		"22. PACK HUNT speeds up the Tyrant Sire too: %d -> %d (+%.0f%%, a Raptor +%.0f%%)" % [int(Defs.UNITS[BroodNew.FATHER]["speed"]), int(float(Defs.UNITS[BroodNew.FATHER]["speed"]) + t_add), t_add / float(Defs.UNITS[BroodNew.FATHER]["speed"]) * 100.0, 18.0 / 96.0 * 100.0])
	check(stp.is_air() and is_equal_approx(s_add, 17.0) and absf(s_add / float(Defs.UNITS[BroodNew.PTERO]["speed"]) - 18.0 / 118.0) < 0.01,
		"    UPDRAFT speeds up the flying Storm Sire too: 110 -> %d (+%.1f%%, a Skywing +%.1f%%)" % [int(110.0 + s_add), s_add / 110.0 * 100.0, 18.0 / 118.0 * 100.0])
	g.consume_unit(stp)
	sw.cmd_land()
	await wait(1.6)
	check(BroodResearch.speed_add(sw) == 0.0, "    ...landed, nothing (only while flying)")
	var br2: Unit = g._add_unit("brute", 0, spot_near(q.position, 14.0))
	check(float(br.d["building_bonus"]) == 3.5 and float(br2.d["building_bonus"]) == 3.5 and float(Defs.UNITS["brute"]["building_bonus"]) == 2.5,
		"    BATTERING HORNS: the Brutes x3.5 on buildings (a new one too; Defs untouched)")
	var spt2: Unit = g._add_unit("spitter", 0, spot_near(q.position, 14.0))
	var mr := float(Defs.UNITS["musketeer"]["range"])
	check(float(spt.d["range"]) == mr and float(spt2.d["range"]) == mr and float(vc.d["range"]) == mr and float(Defs.UNITS["spitter"]["range"]) == 165.0,
		"    LONG SPIT: a Spitter and a Venom Challenger reach a Musketeer's range, not beyond (%d, %d, %d)" % [int(spt.d["range"]), int(vc.d["range"]), int(mr)])
	var yt: Unit = g._add_unit("spitter", 0, spot_near(q.position, 14.0))
	yt.morph("venom_challenger")
	check(float(yt.d["range"]) == mr, "    ...and a Spitter matured into a Venom Challenger keeps it (%d)" % int(yt.d["range"]))
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, spot_near(q.position, 14.0))
	check(is_equal_approx(tu.switch_time(), 1.25) and is_equal_approx(q.switch_time(), 2.0), "    QUICK ROOTS: a turtle roots in %.2f s, the Mother in %.1f s" % [tu.switch_time(), q.switch_time()])
	ra.hit_clock = -99.0
	br.hit_clock = -99.0
	f.hit_clock = -99.0
	check(is_equal_approx(BroodResearch.mend(ra), 1.0) and is_equal_approx(BroodResearch.mend(br), 2.88) and is_equal_approx(BroodResearch.mend(f), 6.0),
		"    SWAMP MENDING: a Raptor +%.1f hp/s, a Brute +%.2f, the Tyrant Sire +%.1f (capped)" % [BroodResearch.mend(ra), BroodResearch.mend(br), BroodResearch.mend(f)])
	ra.hit_clock = g.clock
	check(BroodResearch.mend(ra) == 0.0, "    ...not while it was hit in the last 4 s")
	var ra_hp := ra.max_hp - 10.0
	ra.hp = ra_hp
	ra.hit_clock = -99.0
	if g.on_swamp(0, ra.position):
		await wait(1.0)
		check(ra.hp - ra_hp > 2.5, "    a Raptor on the swamp heals %.1f in a second (2 + 1)" % (ra.hp - ra_hp))
	for u in [tc, spt, vc, sw, br, br2, spt2, yt, tu]:
		g.consume_unit(u)
	for k in ["nb_pack_hunt", "nb_slither", "nb_updraft", "nb_battering_horns", "nb_long_spit", "nb_quick_roots", "nb_swamp_mending", "nb_clutch_spitter"]:
		p["tech"].erase(k)
	# Spitters don't target flyers; the Venom Challenger does
	var bal: Unit = g._add_unit("balloon", 1, spot_near(q.position, 15.0))
	var sp3: Unit = g._add_unit("spitter", 0, bal.position + Vector2(60, 0))
	var vc3: Unit = g._add_unit("venom_challenger", 0, bal.position + Vector2(-60, 0))
	check(not sp3.can_hit(bal) and vc3.can_hit(bal), "    a Spitter can't hit a balloon; a Venom Challenger can")
	await wait(1.5)
	check(sp3.target != bal, "    the Spitter never takes the balloon for its target")
	for u in [bal, sp3, vc3]:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	# THE MOTHER keeps laying while she researches (and can't grow)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	await wait(0.2)
	g.set_selection([q])
	await wait(0.1)
	labs = card_labels()
	check(labs.has("QUICK ROOTS") and labs.has("SWAMP MENDING"), "    her card: QUICK ROOTS, SWAMP MENDING")
	w = q.cmd_nb_research("nb_quick_roots")
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var e0 := mine(BroodNew.EGG).size()
	var wl: String = q.cmd_lay("grub")
	await wait(0.1)
	check(w == "" and wl == "" and mine(BroodNew.EGG).size() == e0 + 1 and BroodNew.grow_problem(g, q) == "She is researching.",
		"    she researches QUICK ROOTS and still lays (%s); GROW waits (%s)" % [wl, BroodNew.grow_problem(g, q)])
	q.nb["egg_t"] = 0.0
	q.nb["eggs"] = 0
	await wait(float(Defs.NB["egg_time"]) / maxf(float(BroodNew.lay_rate(g, q)[0]), 0.1) + 0.5)
	check(int(q.nb.get("eggs", 0)) >= 1, "    her eggs keep growing while she researches (%d)" % int(q.nb.get("eggs", 0)))
	var gq := int(p["gold"])
	q.cmd_nb_research_stop()
	check(not BroodResearch.busy(q) and int(p["gold"]) - gq == 100, "    STOP RESEARCH: paid back")
	# a Sire killed mid-research: lost, paid back; finished research stays
	var wpk: String = f.cmd_nb_research("nb_pack_hunt")
	if wpk != "":
		print("    (pack hunt refused: %s, mode %s)" % [wpk, f.tesla_mode])
	f.nb["rs_t"] = 20.0
	var gk := int(p["gold"])
	f.take_damage(999999.0, null)
	await wait(0.2)
	check(f.dead and absi(int(p["gold"]) - gk - 75) < 15 and not g.has_tech(0, "nb_pack_hunt") and g.has_tech(0, "nb_clutch_raptor") and not BroodResearch.in_hand(g, 0, "nb_pack_hunt"),
		"    the Tyrant Sire killed mid-research: PACK HUNT lost (paid back %d), BIGGER CLUTCH stays" % (int(p["gold"]) - gk))
	# uprooted mid-research: it stops, paid back
	d.cmd_nb_research("nb_slither")
	var gu := int(p["gold"])
	d.cmd_uproot(true)
	await wait(0.2)
	check(not BroodResearch.busy(d) and absi(int(p["gold"]) - gu - 75) < 15, "    the Venom Sire got up mid-research: it stopped, paid back")
	var back: bool = await wait_for(func() -> bool: return d.tesla_mode == "packed", 5.0)
	d.cmd_deploy()
	var re2: bool = await wait_for(func() -> bool: return BroodNew.rooted(d), 6.0)
	check(back and re2 and BroodResearch.problem(g, d, "nb_long_spit") == "", "    rooted again: he can research")
	# saved mid-research: resumed at the end of the run
	d.cmd_nb_research("nb_long_spit")
	d.nb["rs_t"] = 10.0
	await wait(0.1)
	rs_t0 = float(d.nb["rs_t"])
	rs_saved = JSON.parse_string(JSON.stringify(SaveGame.capture(g, main.last_cfg)))
	# the snapshot (online and replays) carries it
	var row: Array = NetSnapshot.unit_vals(d)
	if true:
		check(str(row).contains("nb_long_spit"), "    the online/replay snapshot carries the research in hand")
	# THE COMPUTER researches
	BroodResearch.stop(g, d)
	p["tech"].erase("nb_clutch_raptor")
	var f2 := _sire(q, BroodNew.FATHER, 0.3)
	while mine("raptor").size() < 8:
		g._add_unit("raptor", 0, spot_near(q.position, 8.0))
	p["gold"] = 2000
	p["res2"] = 300.0
	var ck: float = g.clock
	if g.clock < 200.0:
		g.clock = 200.0
	var ai = AIBroodNew.new()
	ai.game = g
	ai.team = 0
	ai._attack_at = 24
	ai._nb_research(q)
	check(BroodResearch.current(f2) == "nb_clutch_raptor", "    the computer researches BIGGER CLUTCH on its Tyrant Sire early (%s)" % BroodResearch.current(f2))
	ai._nb_research(q)
	check(BroodResearch.current(d) == "", "    ...one Sire at a time (the Venom Sire waits)")
	check(ai._nb_warrior(2000) != "raptor", "    ...and lays the other lines meanwhile (%s)" % ai._nb_warrior(2000))
	ai.free()
	if g.clock == 200.0 and ck < 200.0:
		g.clock = ck
	BroodResearch.stop(g, f2)
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)
	q.nb["stage"] = 0
	BroodNew.apply_stage(q)
	g.set_selection([])


## The match saved mid-research, resumed: the research still in hand, as far on; it finishes.
func _research_resumed() -> void:
	if not (rs_saved is Dictionary) or (rs_saved as Dictionary).is_empty():
		check(false, "21. the match saved mid-research")
		return
	var cfg: Dictionary = (rs_saved["cfg"] as Dictionary).duplicate(true)
	cfg["resume"] = rs_saved
	main.start(cfg)
	await process_frame
	await process_frame
	g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
	await wait(0.5)
	var l: Array = g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == BroodNew.DILO)
	var d: Unit = l[0] if not l.is_empty() else null
	check(d != null and BroodResearch.current(d) == "nb_long_spit" and absf(float(d.nb.get("rs_t", 0.0)) - rs_t0) < 2.0,
		"21. saved mid-research and continued: the Venom Sire still researching LONG SPIT (%.1f s, was %.1f s)" % [float(d.nb.get("rs_t", -1.0)) if d else -1.0, rs_t0])
	if d == null:
		return
	d.nb["rs_t"] = float(Defs.RESEARCH["nb_long_spit"]["time"]) - 0.2
	var dn: bool = await wait_for(func() -> bool: return g.has_tech(0, "nb_long_spit"), 2.0)
	var sp: Unit = g._add_unit("spitter", 0, d.position + Vector2(0, 80))
	check(dn and float(sp.d["range"]) == float(Defs.UNITS["musketeer"]["range"]), "    then it finishes: Spitters reach %d (a Musketeer's)" % int(sp.d["range"]))


## 23. THE STORM LINE (0.21.0, docs/storm_line.md): the Storm Sire fathers HATCHLINGS (stage 2, two to an egg, three
## with his BIGGER CLUTCH) that bite only flyers; a Hatchling MATURES (stage 3) into a STORM CHALLENGER that hits flyers
## and the ground; UPDRAFT speeds both (flying); the Skywing is no longer laid (an older save's Skywing egg holds
## Hatchlings); the computer lays Hatchlings against flyers and matures them.
func _storm_line(q: Unit, p: Dictionary) -> void:
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)
	for k0 in [BroodNew.EGG, "raptor", "spitter", "brute", "skywing", "hatchlings", "storm_challenger", "tyrant_challenger", "venom_challenger", "mist_toad"]:
		for u in mine(k0):
			g.consume_unit(u)
	for k0 in p["tech"].keys():
		if String(k0).begins_with("nb_"):
			p["tech"].erase(k0)
	for u in g.units.filter(func(o) -> bool: return o.team == 1 and not o.dead and not o.is_building() and o.position.distance_to(q.position) < 30.0 * Defs.TILE):
		g.consume_unit(u)
	p["gold"] = 5000
	p["res2"] = 500.0
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	q.nb["grow_t"] = 0.0
	while int(g.players[0]["cap"]) - g.supply_used(0) < 30:
		var tt := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, free_spot(BroodNew.TURTLE, q.position, 18.0))
		tt.nb.erase("coc")
		BroodNew.recount(g, 0)
	await wait(0.2)
	# the data
	check(BroodNew.father_of("hatchlings") == BroodNew.PTERO and BroodNew.hatch_list().has("hatchlings") and not BroodNew.hatch_list().has("skywing")
		and BroodMature.mature_of("hatchlings") == "storm_challenger" and BroodNew.unit_stage("hatchlings") == 1 and BroodNew.unit_stage("storm_challenger") == 2
		and (Defs.NB["lines_later"] as Dictionary).is_empty(),
		"23. the Storm line: the Storm Sire fathers Hatchlings (stage 2), they mature into Storm Challengers (stage 3); no Skywing eggs")
	check(g.unit_price(0, "hatchlings") == [80, 10] and BroodNew.young(g, 0, "hatchlings") == 2 and BroodMature.price(g, 0, "hatchlings") == [110, 25],
		"    a Hatchling egg %s for 2; maturing one %s (the Challenger's 150 + 30 less its share)" % [str(g.unit_price(0, "hatchlings")), str(BroodMature.price(g, 0, "hatchlings"))])
	# targets: the Hatchlings air only, the Challenger air and ground
	var at := spot_near(q.position, 16.0)
	var ht: Unit = g._add_unit("hatchlings", 0, at)
	var sc: Unit = g._add_unit("storm_challenger", 0, at + Vector2(20, 0))
	var bal: Unit = g._add_unit("balloon", 1, at + Vector2(0, 60))
	var mus: Unit = g._add_unit("musketeer", 1, at + Vector2(60, 0))
	check(ht.is_air() and sc.is_air() and ht.can_hit(bal) and not ht.can_hit(mus) and sc.can_hit(bal) and sc.can_hit(mus),
		"    a Hatchling (a flyer) can bite a balloon, not a Musketeer; a Storm Challenger both")
	for u in [ht, sc, bal, mus]:
		g.consume_unit(u)
	# the Storm Sire fathers them: an egg in his nest, two Hatchlings fly out
	var pt := _sire(q, BroodNew.PTERO, 1.57)
	await wait(0.3)
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var h0 := mine("hatchlings").size()
	# (paid: counted by what she spent, not by the food left: the Rootmaws' food comes in during the wait, 74-75 seen)
	var gl := int(g.stats[0]["spent"])
	var w: String = q.cmd_lay("hatchlings")
	await wait(0.1)
	var paid := int(g.stats[0]["spent"]) - gl
	check(w == "" and paid == 80 and BroodNew.nest_eggs(g, pt).size() == 1, "    the Storm Sire rooted beside her: a Hatchling egg (80 food) in his nest %s (paid %d, nest %d, near %s)" % [w, paid, BroodNew.nest_eggs(g, pt).size(), BroodNew.father_near(g, 0, BroodNew.PTERO)])
	var two: bool = await wait_for(func() -> bool: return mine("hatchlings").size() >= h0 + 2, float(Defs.NB["fert_time"]) + BroodNew.egg_time("hatchlings") + 6.0)
	await wait(0.2)
	check(two and mine("hatchlings").size() == h0 + 2 and mine("hatchlings").all(func(u) -> bool: return u.is_air()), "    two Hatchlings hatch, flying (%d)" % (mine("hatchlings").size() - h0))
	# BIGGER CLUTCH: three to an egg
	var cw := BroodResearch.problem(g, pt, "nb_clutch_hatchlings")
	check(cw == "", "    his BIGGER CLUTCH can be researched now (was 'Not in the Brood yet'): %s" % cw)
	BroodResearch.done(g, 0, "nb_clutch_hatchlings")
	check(g.unit_price(0, "hatchlings") == [120, 15] and BroodMature.price(g, 0, "hatchlings") == [110, 25], "    with it: an egg %s for 3, maturing still %s" % [str(g.unit_price(0, "hatchlings")), str(BroodMature.price(g, 0, "hatchlings"))])
	var h1 := mine("hatchlings").size()
	q.cmd_lay("hatchlings")
	var three: bool = await wait_for(func() -> bool: return mine("hatchlings").size() >= h1 + 3, float(Defs.NB["fert_time"]) + BroodNew.egg_time("hatchlings") + 6.0)
	await wait(0.2)
	check(three and mine("hatchlings").size() == h1 + 3, "    an egg hatches 3 Hatchlings (%d)" % (mine("hatchlings").size() - h1))
	# MATURE: locked at stage 2, then a Storm Challenger (a flyer still)
	var hh: Unit = mine("hatchlings")[0]
	hh.kills = 4
	var mw := BroodMature.problem(hh)
	check(mw == "Needs the Brood Mother at stage 3.", "    MATURE at her stage 2: %s" % mw)
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	var g2 := int(p["gold"])
	var s2 := float(p["res2"])
	var ow := BroodMature.order(g, [hh])
	check(ow == "" and g2 - int(p["gold"]) == 110 and absf(s2 - float(p["res2"]) - 25.0) < 0.01, "    at stage 3 a Hatchling matures: paid 110 food and 25 spoils %s" % ow)
	hh.moult_t = float(Defs.NB["moult"]) - 0.1
	var grown: bool = await wait_for(func() -> bool: return hh.kind == "storm_challenger", 1.0)
	check(grown and hh.is_air() and hh.kills == 4 and hh.art == "storm_challenger", "    ...a Storm Challenger, flying, its 4 kills kept")
	# UPDRAFT: the line and the Storm Sire, flying only
	var hy: Unit = mine("hatchlings")[0]
	BroodResearch.done(g, 0, "nb_updraft")
	check(is_equal_approx(BroodResearch.speed_add(hy), 20.0) and is_equal_approx(BroodResearch.speed_add(hh), 18.0) and BroodResearch.speed_add(pt) == 0.0,
		"    UPDRAFT: Hatchlings 132 -> %d, a Storm Challenger 120 -> %d; the Storm Sire landed on his nest nothing" % [int(132.0 + BroodResearch.speed_add(hy)), int(120.0 + BroodResearch.speed_add(hh))])
	await wait(0.2)
	check(hy.speed >= 151.0, "    ...and the Hatchlings fly at it (%.0f px/s)" % hy.speed)
	p["tech"].erase("nb_updraft")
	# a Hatchling flock bites a flyer and leaves the ground alone
	var fa := spot_near(q.position, 18.0)
	var flock: Array = mine("hatchlings")
	for u in flock:
		u.position = fa + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		u.cmd_stop()
	var sw: Unit = g._add_unit("cuckoo", 1, fa + Vector2(90, 0))
	var mu2: Unit = g._add_unit("musketeer", 1, fa + Vector2(-60, 20))
	sw.cmd_stop()
	for u in flock:
		u.cmd_attack(sw)
	var bit: bool = await wait_for(func() -> bool: return sw.dead, 20.0)
	check(bit, "    %d Hatchlings bite an enemy Swift out of the air (dead %s, %d Hatchlings left)" % [flock.size(), sw.dead, flock.filter(func(u) -> bool: return not u.dead).size()])
	check(flock.all(func(u) -> bool: return u.dead or u.target != mu2), "    ...and never take the Musketeer on the ground for a target")
	if is_instance_valid(mu2) and not mu2.dead:
		g.consume_unit(mu2)
	# a Storm Challenger swoops on the ground
	var vic: Unit = g._add_unit("raptor", 1, hh.position + Vector2(50, 0))
	var vhp := vic.hp
	hh.cmd_attack(vic)
	var hit: bool = await wait_for(func() -> bool: return vic.dead or vic.hp < vhp, 8.0)
	check(hit, "    a Storm Challenger swoops on a Raptor on the ground (%.0f -> %.0f)" % [vhp, vic.hp])
	if is_instance_valid(vic) and not vic.dead:
		g.consume_unit(vic)
	# an older save's Skywing egg holds Hatchlings now
	var oe: Unit = g._add_unit(BroodNew.EGG, 0, spot_near(q.position, 6.0))
	BroodNew.unit_load(oe, {"k": "skywing", "t": 0.0, "fert": 1, "wait": 0.0})
	check(String(oe.nb["k"]) == "hatchlings", "    an older save's Skywing egg holds Hatchlings (%s)" % oe.nb["k"])
	g.consume_unit(oe)
	# THE COMPUTER: Hatchlings against flyers; at her stage 3 a few to mature even with none; it matures them
	var ai = AIBroodNew.new()
	ai.game = g
	ai.team = 0
	ai._attack_at = 24
	for u in mine("hatchlings") + mine("storm_challenger"):
		g.consume_unit(u)
	while mine("raptor").size() < 8:
		g._add_unit("raptor", 0, spot_near(q.position, 8.0))
	var foe: Array = []
	for i in 3:
		foe.append(g._add_unit("balloon", 1, spot_near(q.position, 40.0)))
	p["gold"] = 3000
	p["res2"] = 300.0
	var pick: String = ai._nb_warrior(3000)
	check(pick == "hatchlings", "    the computer lays Hatchlings against 3 enemy balloons (%s)" % pick)
	for u in foe:
		g.consume_unit(u)
	await wait(0.1)
	pick = ai._nb_warrior(3000)
	check(pick == "hatchlings", "    ...and at her stage 3 a few to mature, with no enemy flyers (%s)" % pick)
	for u in mine("raptor"):
		g.consume_unit(u)          # (else its Raptors mature first: two a think)
	for i in 3:
		g._add_unit("hatchlings", 0, spot_near(q.position, 6.0))
	await wait(0.1)
	ai._nb_mature(q)
	var moulting := mine("hatchlings").filter(func(u) -> bool: return u.moult_t >= 0.0).size()
	check(moulting >= 2, "    it matures its Hatchlings into Storm Challengers when nothing flies (%d moulting; %s, foe air %d)" % [moulting, BroodMature.problem(mine("hatchlings")[0]) if not mine("hatchlings").is_empty() else "none", ai._nb_foe_air()])
	ai.free()
	for u in mine("hatchlings") + mine("storm_challenger") + mine("raptor"):
		g.consume_unit(u)
	for fk0 in BroodNew.FATHERS:
		for u in mine(fk0):
			g.consume_unit(u)
	for k0 in p["tech"].keys():
		if String(k0).begins_with("nb_"):
			p["tech"].erase(k0)
	q.nb["stage"] = 0
	BroodNew.apply_stage(q)
	g.set_selection([])
