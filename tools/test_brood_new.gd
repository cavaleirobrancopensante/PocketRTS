extends SceneTree
## THE NEW BROOD (experiment: scripts/brood_new.gd, docs/brood_new.md), its rules in a real match:
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_new.gd
##  0. the start: no buildings, the Brood Mother, a Rootmaw and 5 grubs; both finish rooting in a moment; supply 40 + 20
##  1. rooted: armour and less damage (the same blow on a rooted and an uprooted Rootmaw)
##  2. the Mother lays an egg while she walks (it drops behind her)
##  3. warriors' eggs are fertilised only by the father ROOTED on his nest near the Mother (refused without him, far
##     off or standing; rooted he takes less damage; her eggs go into his nest, 2 queued; fertilised by his breath;
##     they hatch there as 3 Raptors); when he gets up the egg lies on the ground and, never fertilised, hatches as a
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
	check(BroodNew.lay_problem(g, q, "raptor").contains("Tyrannosaur"), "3. no father: a Raptor's egg is refused (%s)" % BroodNew.lay_problem(g, q, "raptor"))
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
	check(re != null and int(re.nb["fert"]) == 1 and bool(re.nb.get("nest", false)) and re.position.distance_to(BroodNew.nest_point(f)) < 2.0, "   the Raptor egg goes into his nest")
	q.cmd_lay("raptor")
	await wait(0.1)
	check(BroodNew.nest_eggs(g, f).size() == 2, "   a second one: 2 eggs in the nest (%d)" % BroodNew.nest_eggs(g, f).size())
	var fert: bool = await wait_for(func() -> bool: return int(re.nb["fert"]) == 2, 6.0)
	check(fert, "   he breathes on it: fertilised (red)")
	var got3: bool = await wait_for(func() -> bool: return mine("raptor").size() >= r0 + 3, Defs.UNITS["raptor"]["time"] + 3.0)
	var at_nest := 0
	for rp in mine("raptor"):
		if rp.position.distance_to(BroodNew.nest_point(f)) < 60.0:
			at_nest += 1
	check(got3 and at_nest >= 3, "   it hatches as 3 Raptors, in the nest (%d, %d by it)" % [mine("raptor").size() - r0, at_nest])
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
	check(mine("grub").any(func(gr) -> bool: return gr.anim == "harvest" or gr.work == "feeding" or gr.carrying > 0), "   harvesting at its flank")
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
	# 11. SACRIFICE at the Mother: she devours it
	var r1: Unit = g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	var ess0: float = float(p["res2"])
	q.nb["eggs"] = 2
	q.nb["egg_t"] = -1000.0        # (no egg grows meanwhile: the count is the offering's)
	var eggs_s0: int = 2
	r1.cmd_sacrifice()
	var ate: bool = await wait_for(func() -> bool: return float(p["res2"]) > ess0, 8.0)
	check(ate and float(q.nb.get("devour", 0.0)) > 0.0 and BroodNew.anim(q, false) == "attack", "11. SACRIFICE at the Mother: essence %.0f -> %.0f, she devours it (a swipe)" % [ess0, float(p["res2"])])
	check(int(q.nb.get("eggs", 0)) == eggs_s0 + 1, "    and she gets 1 egg at once (%d -> %d)" % [eggs_s0, int(q.nb.get("eggs", 0))])
	q.nb["eggs"] = BroodNew.eggs_max(q)
	var r2: Unit = g._add_unit("raptor", 0, q.position + Vector2(q.radius + 30.0, 20.0))
	var ess1: float = float(p["res2"])
	r2.cmd_sacrifice()
	await wait_for(func() -> bool: return float(p["res2"]) > ess1, 8.0)
	check(int(q.nb.get("eggs", 0)) == BroodNew.eggs_max(q), "    her clutch full: no extra egg (%d)" % int(q.nb.get("eggs", 0)))
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
	check(nb_grown and BroodNew.eggs_max(q) == int(nb_stages[1]["eggs"]) and q.radius > nb_r_before * 1.1 and absf(float(BroodNew.lay_rate(g, q)[1]) - float(nb_stages[1]["rate"])) < 0.001,
		"    stage 2 after %d s: %d eggs held, laying x%.2f, body %.0f -> %.0f px" % [int(nb_stages[1]["time"]), BroodNew.eggs_max(q), float(BroodNew.lay_rate(g, q)[1]), nb_r_before, q.radius])
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
	g.smart_command([q], qrally)
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
	check(labs.has("ROOTMAW") and labs.has("MOUND TURTLE") and labs.has("TYRANNOSAUR") and not labs.has("CLUTCH MOUND") and not labs.has("BUILD"),
		"    a grub's card has the creatures it turns into, no old Brood buildings: %s" % str(labs))
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
