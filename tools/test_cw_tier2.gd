extends SceneTree
## Tier 2 of the gear-mode Clockwork: the ESCAPEMENT and the SPRINGER (docs/clockwork_gear_prototype.md).
## An Escapement linked to the field but not meshed with a Mainspring is idle (NEEDS MAINSPRING: no research, no Springer);
## one meshed directly with a Mainspring works (an idler between them counts; a chain through another building does not)
## and a Springer trains, paying cogs AND Tension (refused when Tension is short); if the Mainspring dies the Escapement goes
## idle again (nothing else is lost). THE TENSION RULE (0.14.33, scripts/gear_econ.gd): the Springer is made only at a Movement
## Works whose ring meshes with a Mainspring's (one that does not refuses it). A Springer shoots and kills a ground unit and a flyer with its screws; JUMP on flat ground
## crouches in place, flies over its shadow and lands at the spot, cannot shoot in the air and then waits for its spring;
## jumping UP a cliff is refused before HIGH LEAP, refused after it where the side cannot see, and allowed with vision; down
## a cliff is always allowed; it never lands on a building.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_tier2.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var bl := Defs.build_list("clockwork")
	check("gear mode builds the Escapement", bl.has(Defs.CW_TECH))
	check("the Movement Works trains the Springer", (Defs.BUILDINGS[Defs.CW_WORKS]["trains"] as Array).has(Defs.SPRINGER))
	check("the Springer's price is cogs and Tension", g.unit_price(0, Defs.SPRINGER) == [int(Defs.UNITS[Defs.SPRINGER]["cost"]), int(Defs.UNITS[Defs.SPRINGER]["tension"])], str(g.unit_price(0, Defs.SPRINGER)))
	g.players[0]["gold"] = 20000
	g.players[0]["tension"] = 1000.0
	var hall := U.hall(g, 0)
	check("the Escapement needs a Movement Works", g.requirement_text(0, Defs.CW_TECH) != "")
	var works := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	check("a Movement Works links", works != null and g.gear_net.is_linked(works))
	if works == null:
		_end()
		return
	g._recount_supply(0)
	g.players[0]["cap"] = 100
	# ---- an Escapement linked to the field, with no Mainspring anywhere: idle (its ghost says so beforehand)
	var ec := U.linked_spot(g, 0, Defs.CW_TECH, hall.cell)
	check("the ghost of an Escapement with no Mainspring by it says it would stand idle", ec.x >= 0 and g.gear_net.spring_problem(0, Defs.CW_TECH, ec) != "")
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	check("an Escapement links to the field", esc != null and g.gear_net.is_linked(esc))
	if esc == null:
		_end()
		return
	U.step(g, 0.6)
	check("without a Mainspring it is idle (NEEDS MAINSPRING)", g.gear_net.speed_mult(esc) == 0.0 and g.gear_net.needs_spring(esc))
	var why := g.can_train(works, Defs.SPRINGER)
	check("the Springer cannot be trained (the Escapement is idle)", why != "", why)
	check("HIGH LEAP cannot be researched there", g.research_problem(esc, "high_leap") != "", g.research_problem(esc, "high_leap"))
	check("its working loop does not play", not esc.drill_anim)
	# ---- a chain is not a mesh: a Mainspring two hops away (through a Regulator) does not count
	var chain_ok := _chain_case(g, hall)
	check("a Mainspring reached only through another ring does not count", chain_ok)
	# ---- an idler between the two rings counts as meshing
	var idl := _idler_case(g, hall)
	check("an Escapement meshing with a Mainspring through an idler works", idl != "fail", idl)
	# ---- a Mainspring meshing with the Escapement's ring: it works
	var spring := _spring_beside(g, esc)
	check("a Mainspring was put meshing with the Escapement's ring", spring != null)
	if spring == null:
		_end()
		return
	U.step(g, 0.6)
	check("meshed with a Mainspring, the Escapement works", g.gear_net.speed_mult(esc) > 0.0 and g.gear_net.spring_for(esc) == spring and not g.gear_net.needs_spring(esc))
	check("it hangs on the Mainspring in the gear tree (the drawn mesh)", g.gear_net.parent_of.get(esc) == spring or g.gear_net.parent_of.get(spring) == esc)
	var ec2 := GearNet.ring_spot(g, 0, Defs.CW_TECH, spring, 180.0)
	check("the ghost of a second Escapement by the Mainspring says it meshes", ec2.x < 0 or g.gear_net.spring_problem(0, Defs.CW_TECH, ec2) == "")
	U.step(g, 0.5)
	check("its working loop plays while it works", esc.drill_anim and esc.sprite.texture != null and esc.sprite.texture.resource_path.contains("escapement_work_"))
	# ---- THE TENSION RULE at the Works: the Springer costs Tension, so it is made only where a Mainspring meshes
	if g.gear_net.spring_for(works) == null:
		var wn := g.can_train(works, Defs.SPRINGER)
		check("a Movement Works meshing with no Mainspring refuses the Springer", wn.contains("meshes with no Mainspring"), wn)
		var w2 := _works_beside(g, spring)
		check("a Movement Works was put meshing with the Mainspring", w2 != null and g.gear_net.spring_for(w2) != null)
		if w2 == null:
			_end()
			return
		works = w2
		g._recount_supply(0)
		g.players[0]["cap"] = 100
	# ---- Tension short: refused with a clear message
	g.players[0]["tension"] = 10.0
	why = g.can_train(works, Defs.SPRINGER)
	check("short of Tension, the Springer is refused", why.contains("Tension"), why)
	g.players[0]["tension"] = 1000.0
	# ---- a Springer trains: cogs and Tension spent
	var cogs0 := int(g.players[0]["gold"])
	var ten0 := g.tension(0)
	why = g.train(works, Defs.SPRINGER)
	check("the Movement Works takes a Springer order", why == "", why)
	check("cogs were spent", int(g.players[0]["gold"]) == cogs0 - int(Defs.UNITS[Defs.SPRINGER]["cost"]), "%d -> %d" % [cogs0, int(g.players[0]["gold"])])
	check("Tension was spent", is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[Defs.SPRINGER]["tension"])), "%.0f -> %.0f" % [ten0, g.tension(0)])
	U.step(g, float(Defs.UNITS[Defs.SPRINGER]["time"]) + 2.0)
	var springers := g.units.filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER and u.team == 0 and not u.dead)
	check("a Springer came out", springers.size() == 1, "%d" % springers.size())
	# (a cancelled order pays the Tension back)
	g.train(works, Defs.SPRINGER)
	var ten1 := g.tension(0)
	g.cancel_train(works)
	check("a cancelled Springer pays its Tension back", is_equal_approx(g.tension(0), ten1 + float(Defs.UNITS[Defs.SPRINGER]["tension"])))
	if springers.is_empty():
		_end()
		return
	var j: Unit = springers[0]
	j.cmd_stop()
	# ---- it shoots a ground unit dead
	var foot := _foe(g, "labourer", _open_near(g, j.position + Vector2(140, 20)))
	var t := _until_dead(g, foot, 30.0, j)
	check("a Springer shoots a ground unit dead", foot.dead, "%.1f s, %d screws" % [t, j.shots])
	check("its screw flew from the drill tip (the shot is a screw)", j.last_shot != null or j.shots > 0)
	# ---- and a flyer
	var n0 := j.shots
	var fly := _foe(g, "balloon", j.position + Vector2(-30, -110))
	t = _until_dead(g, fly, 60.0, j)
	check("a Springer shoots a flyer dead", fly.dead, "%.1f s, %d screws" % [t, j.shots - n0])
	# ---- JUMP on flat ground
	j.cmd_stop()
	U.step(g, 0.5)
	var p0 := j.position
	var dest := _flat_spot(g, j, 4)
	check("a flat spot about 4 tiles off was found", dest != Vector2.INF)
	if dest != Vector2.INF:
		var foe2 := _foe(g, "labourer", _open_near(g, p0 + (dest - p0).normalized() * -100.0))
		var shots_before := j.shots
		var w := Springer.jump_order(g, [j], dest)
		check("the jump order is taken", w == "", w)
		U.step(g, float(Defs.SPRINGER_JUMP["crouch"]) * 0.8)
		check("it crouches in place first", j.position.distance_to(p0) < 2.0 and not j.jump.is_empty() and Springer.frame(j) <= 2 and j._anim_name() == "jump",
				"%.1f px, frame %d" % [j.position.distance_to(p0), Springer.frame(j)])
		var peak := 0.0
		var mid_ok := false
		var shots_air := j.shots
		var tt := 0.0
		while not j.jump.is_empty() and tt < 3.0:
			U.step(g, 1.0 / 30.0)
			tt += 1.0 / 30.0
			peak = maxf(peak, Springer.lift(j))
			if Springer.airborne(j) and j.position.distance_to(p0) > 10.0 and j.position.distance_to(dest) > 10.0:
				mid_ok = true
		check("it flies along an arc (lifted over its shadow, moving between the spots)", mid_ok and peak > 30.0, "peak %.0f px" % peak)
		check("it cannot shoot in the air", j.shots == shots_air, "%d -> %d" % [shots_air, j.shots])
		check("it lands at the spot", j.position.distance_to(dest) < 3.0, "%.1f px off" % j.position.distance_to(dest))
		check("the jump took about crouch + flight + landing", tt > 0.5 and tt < 2.0, "%.2f s" % tt)
		check("the spring winds back: another jump is refused for now", Springer.problem(j, p0) != "", Springer.problem(j, p0))
		foe2.queue_free()
		g.units.erase(foe2)
		j.jump_cd = 0.0
		var _unused := shots_before
	# ---- never onto a building
	var onto := Springer.landing(j, works.center())
	var bad := onto.has("at") and works.rect().grow(-2.0).has_point(onto["at"])
	check("it never lands on a building", not bad, str(onto))
	# ---- UP a cliff: refused before HIGH LEAP; after it, refused where unseen, allowed with vision; DOWN always
	var pair := _cliff_pair(g, 0)
	check("a cliff to jump up was found (low ground, high ground within reach)", not pair.is_empty())
	if not pair.is_empty():
		var low: Vector2 = pair[0]
		var high: Vector2 = pair[1]
		var jk: Unit = g._add_unit(Defs.SPRINGER, 0, low)
		jk.cmd_stop()
		U.step(g, 0.5)
		check("the climber stands on low ground", g.level_of(jk.position) == 0)
		g.players[0]["tech"]["high_leap"] = false
		var l1 := Springer.landing(jk, high)
		check("UP before HIGH LEAP is refused", not l1.has("at") and String(l1.get("why", "")).contains("HIGH LEAP"), str(l1))
		g.players[0]["tech"]["high_leap"] = true
		U.step(g, 0.5)
		var seen0 := g.side_sees(0, high)
		var l2 := Springer.landing(jk, high)
		if not seen0:
			check("UP after HIGH LEAP but unseen is refused", not l2.has("at") and String(l2.get("why", "")).contains("see"), str(l2))
		# a spotter up there: the side sees the spot
		var spot: Unit = g._add_unit("clock_soldier", 0, high + Vector2(0, -8))
		spot.cmd_hold()
		U.step(g, 1.0)
		check("the spotter gives vision up there", g.side_sees(0, high))
		var l3 := Springer.landing(jk, high)
		check("UP after HIGH LEAP, with vision, is allowed", l3.has("at") and g.level_of(l3["at"]) == 1, str(l3))
		Springer.jump_order(g, [jk], high)
		var t2 := 0.0
		while not jk.jump.is_empty() and t2 < 4.0:
			U.step(g, 0.1)
			t2 += 0.1
		check("it jumped up onto the high ground", g.level_of(jk.position) == 1 and jk.position.distance_to(high) < 40.0, "level %d, %.0f px off" % [g.level_of(jk.position), jk.position.distance_to(high)])
		# down again, without the research (down is always allowed)
		g.players[0]["tech"]["high_leap"] = false
		jk.jump_cd = 0.0
		var l4 := Springer.landing(jk, low)
		check("DOWN a cliff is allowed (even without HIGH LEAP)", l4.has("at") and g.level_of(l4["at"]) == 0, str(l4))
		g.players[0]["tech"]["high_leap"] = true
	# ---- HIGH LEAP is researched at a working Escapement, for cogs and Tension
	g.players[0]["tech"].erase("high_leap")
	var ten2 := g.tension(0)
	var rw := g.start_research(esc, "high_leap")
	check("HIGH LEAP research starts at the working Escapement", rw == "", rw)
	check("it costs Tension", is_equal_approx(g.tension(0), ten2 - float(Defs.RESEARCH["high_leap"]["tension"])))
	U.step(g, 3.0)
	check("the research runs while the Escapement works", esc.prod_t > 2.0, "%.1f s" % esc.prod_t)
	# ---- the Mainspring dies: the Escapement goes idle (the research pauses, the Springers stay)
	spring.take_damage(99999.0, null)
	U.step(g, 1.0)
	check("its Mainspring destroyed, the Escapement is idle again", g.gear_net.speed_mult(esc) == 0.0 and g.gear_net.needs_spring(esc))
	var before_t := esc.prod_t
	U.step(g, 3.0)
	check("the research pauses meanwhile (not lost)", is_equal_approx(esc.prod_t, before_t) and esc.queue.has("@high_leap"), "%.1f -> %.1f" % [before_t, esc.prod_t])
	check("the Springers are still there", not j.dead)
	check("no new Springer while it is idle", g.can_train(works, Defs.SPRINGER) != "")
	# ---- the CLOCKWORK LAB (its own map): an Escapement built, linked and meshed with the Mainspring, three Springers,
	# Tension to spare, room in the supply for a Springer
	var g2 := U.make(root, ["clockwork", "crown"], "greenhold")
	await process_frame
	await process_frame
	CwLab.setup(g2)
	var lab_esc: Building = null
	var lab_spring: Building = null
	for b in g2.buildings:
		if b.team == g2.human and not b.dead and b.kind == Defs.CW_TECH:
			lab_esc = b
		if b.team == g2.human and not b.dead and b.kind == "mainspring":
			lab_spring = b
	g2.gear_net.solve()
	check("the Lab has a built Escapement", lab_esc != null and lab_esc.built)
	check("the Lab's Escapement is linked and meshed with a Mainspring (it works)", lab_esc != null and lab_spring != null and g2.gear_net.is_linked(lab_esc) \
			and g2.gear_net.spring_for(lab_esc) != null and g2.gear_net.speed_mult(lab_esc) > 0.0)
	var lab_springers := g2.units.filter(func(u: Unit) -> bool: return u.team == g2.human and u.kind == Defs.SPRINGER and not u.dead)
	check("the Lab has three Springers", lab_springers.size() == 3, "%d" % lab_springers.size())
	check("the Lab has Tension to spare", g2.tension(g2.human) >= 300.0, "%.0f" % g2.tension(g2.human))
	g2._recount_supply(g2.human)
	var lab_works: Building = null
	for b in g2.buildings:
		if b.team == g2.human and b.kind == Defs.CW_WORKS:
			lab_works = b
	check("in the Lab a Springer can be trained at once", lab_works != null and g2.can_train(lab_works, Defs.SPRINGER) == "",
			g2.can_train(lab_works, Defs.SPRINGER) if lab_works else "no Works")
	_end()


## A Regulator touching a Mainspring, and an Escapement touching only the Regulator: the Escapement must stay idle. True when
## that holds (or when the ground had no room to set it up: then the case is skipped, true).
func _chain_case(g: Game, hall: Building) -> bool:
	var sp := U.put(g, 0, "mainspring", hall.cell + Vector2i(-14, 8))
	if sp == null:
		return true
	var reg_c := U.chain_spot(g, 0, "regulator", sp)
	if reg_c.x < 0:
		_remove(g, sp)
		return true
	var reg := g._add_building("regulator", 0, reg_c, true)
	g.gear_net.solve()
	var esc_c := Vector2i(-1, -1)
	# an Escapement spot whose ring touches the Regulator's but not the Mainspring's (nor any other)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var size: Vector2i = Defs.BUILDINGS[Defs.CW_TECH]["size"]
	var r := GearNet.ring_r(Defs.CW_TECH, size, false)
	for y in range(reg_c.y - 12, reg_c.y + 13):
		for x in range(reg_c.x - 12, reg_c.x + 13):
			var c := Vector2i(x, y)
			if esc_c.x >= 0 or not g.in_map(c) or g.placement_problem(0, Defs.CW_TECH, c) != "":
				continue
			var gc := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var others_far := true
			for o in g.buildings:
				if o == reg or o.team != 0 or o.dead or not GearNet.has_gear(o):
					continue
				if gc.distance_to(GearNet.b_c(o)) - (r + GearNet.b_r(o)) <= slack * 1.05:
					others_far = false
					break
			if others_far and gc.distance_to(GearNet.b_c(reg)) - (r + GearNet.b_r(reg)) <= slack * 0.9:
				esc_c = c
	var ok := true
	if esc_c.x >= 0:
		var e2 := g._add_building(Defs.CW_TECH, 0, esc_c, true)
		g.gear_net.solve()
		ok = g.gear_net.is_linked(e2) and g.gear_net.needs_spring(e2) and g.gear_net.speed_mult(e2) == 0.0 and g.gear_net.is_linked(reg) and g.gear_net.is_linked(sp)
		_remove(g, e2)
	_remove(g, reg)
	_remove(g, sp)
	g.gear_net.solve()
	return ok


## A Mainspring and an Escapement whose rings are a little apart (more than a direct mesh, within the link gap: an idler
## sits between them): the Escapement must work. "ok", "skipped" (no room) or "fail".
func _idler_case(g: Game, hall: Building) -> String:
	var sp := U.put(g, 0, "mainspring", hall.cell + Vector2i(10, -10))
	if sp == null:
		return "skipped"
	var size: Vector2i = Defs.BUILDINGS[Defs.CW_TECH]["size"]
	var r := GearNet.ring_r(Defs.CW_TECH, size, false)
	var tol := float(Defs.GEAR["mesh_tol"])
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var pick := Vector2i(-1, -1)
	for y in range(sp.cell.y - 12, sp.cell.y + 13):
		for x in range(sp.cell.x - 12, sp.cell.x + 13):
			var c := Vector2i(x, y)
			if pick.x >= 0 or not g.in_map(c) or g.placement_problem(0, Defs.CW_TECH, c) != "" or not g.margin_free(c, size):
				continue
			var gc := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var gap := gc.distance_to(GearNet.b_c(sp)) - (r + GearNet.b_r(sp))
			if gap > tol + 6.0 and gap < slack - 6.0:
				pick = c
	if pick.x < 0:
		_remove(g, sp)
		g.gear_net.solve()
		return "skipped"
	var e2 := g._add_building(Defs.CW_TECH, 0, pick, true)
	g.gear_net.solve()
	var works := g.gear_net.speed_mult(e2) > 0.0 and g.gear_net.spring_for(e2) == sp
	var idler := not (g.gear_net.idler_of.get(e2, {}) as Dictionary).is_empty() or not (g.gear_net.idler_of.get(sp, {}) as Dictionary).is_empty()
	_remove(g, e2)
	_remove(g, sp)
	g.gear_net.solve()
	return "ok" if works and idler else "fail"


func _remove(g: Game, b: Building) -> void:
	g._mark(b.cell, b.size, 0)
	g.buildings.erase(b)
	b.queue_free()


## A finished Mainspring whose ring meshes with the Escapement's (directly or through an idler), linked; null if none fits.
func _spring_beside(g: Game, esc: Building) -> Building:
	for deg in [0.0, 90.0, 180.0, -90.0, 45.0, 135.0, -45.0, -135.0]:
		var c := GearNet.ring_spot(g, 0, "mainspring", esc, deg)
		if c.x >= 0:
			var b := g._add_building("mainspring", 0, c, true)
			g.gear_net.solve()
			return b
	return null


## A finished Movement Works whose ring meshes with the Mainspring's (directly or through an idler), linked; null if none fits.
func _works_beside(g: Game, sp: Building) -> Building:
	for deg in [0.0, 90.0, 180.0, -90.0, 45.0, 135.0, -45.0, -135.0]:
		var c := GearNet.ring_spot(g, 0, Defs.CW_WORKS, sp, deg)
		if c.x >= 0:
			var b := g._add_building(Defs.CW_WORKS, 0, c, true)
			g.gear_net.solve()
			return b
	return null


## An enemy (team 1) standing still at p.
func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


func _until_dead(g: Game, u: Unit, limit: float, shooter: Unit) -> float:
	var t := 0.0
	shooter.cmd_attack(u)
	while t < limit and not u.dead:
		U.step(g, 0.2)
		t += 0.2
		if not shooter.dead and shooter.order == "idle" and not u.dead:
			shooter.cmd_attack(u)
	return t


## A spot on the Springer's own level, `tiles` tiles off, where it may land.
func _flat_spot(g: Game, j: Unit, tiles: int) -> Vector2:
	for k in 16:
		var a := TAU * float(k) / 16.0
		var p := j.position + Vector2.from_angle(a) * float(tiles) * Defs.TILE
		var l := Springer.landing(j, p)
		if l.has("at") and (l["at"] as Vector2).distance_to(p) < 4.0 and g.level_of(p) == g.level_of(j.position):
			return l["at"]
	return Vector2.INF


## [a low-ground spot at a cliff's foot, a high-ground spot 3 tiles away across the cliff], preferring high ground team t
## does not see; [] if the map has none near team t's hall.
func _cliff_pair(g: Game, t: int) -> Array:
	var h := U.hall(g, t)
	var best: Array = []
	var best_seen := true
	for y in range(h.cell.y - 40, h.cell.y + 41):
		for x in range(h.cell.x - 40, h.cell.x + 41):
			var c := Vector2i(x, y)
			if not g.in_map(c) or not g._walkable(c) or g.height[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.water[g.idx(c)] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c1: Vector2i = c + d
				var c3: Vector2i = c + d * 3
				if not g.in_map(c3) or g.cliff[g.idx(c1)] != 1:
					continue
				if not g._walkable(c3) or g.height[g.idx(c3)] != 1 or g.cliff[g.idx(c3)] != 0:
					continue
				if not g._walkable(c3 + d) or g.cliff[g.idx(c3 + d)] != 0:
					continue
				var lo := g.cell_center(c)
				var hi := g.cell_center(c3)
				if not g._clear_at(lo, 12.0) or not g._clear_at(hi, 12.0):
					continue
				var seen := g.side_sees(t, hi)
				if best.is_empty() or (best_seen and not seen):
					best = [lo, hi]
					best_seen = seen
	return best


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
