extends SceneTree
## Loose horses (a killed rider's horse that lives and bolts, belonging to nobody):
##   godot --headless --fixed-fps 30 --script res://tools/test_loose_horses.gd
##  1. a Dragoon shot by a Musketeer (the chance forced to 1): his horse lives, nobody's,
##     bolts away from the shooter and grazes there; his body is a Musketeer's, worth only him
##  2. forced 0: the mounted body as before (worth the man and his horse)
##  3. round shot (area) and a Raptor's bite (the Brood) never leave a horse
##  4. a Crown man of another side catches a loose horse by walking up; so does a Winder
##  5. a Brood Raptor with nothing else about kills one: its carcass is for the Brood
##  6. a raised rider walks back to his own loose horse and gets on
##  7. a cannon destroyed by musket fire: each horse of its team bolts loose
##  8. save and load with a loose horse
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
const CROWN := 0
const BROOD := 1
const CLOCK := 2
const CROWN2 := 3


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "twin_crowns", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1},
			{"who": "easy", "faction": "clockwork", "colour": 2, "side": 2},
			{"who": "easy", "faction": "crown", "colour": 3, "side": 3}]})
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


func unit(k: String, p: Vector2, team := CROWN) -> Unit:
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
				if p.distance_to(s) < 500.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Nobody else on the test ground (the last scene's men and horses too).
func _clear_units() -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(at(352, 256)) < 900.0:
			g.consume_unit(u)
	await physics_frame
	await physics_frame


## Shoot `e` with `s`'s musket until it's dead (a musket ball misses now and then).
func shoot_dead(s: Unit, e: Unit, dmg := 999.0) -> void:
	for i in 400:
		if e.dead:
			break
		s.facing = (e.center() - s.center()).normalized()
		g.musket_shot(s, e, dmg)
	await physics_frame


func n_loose() -> int:
	return g.units.filter(func(u: Unit) -> bool: return Game.loose_horse(u)).size()


## A loose horse at p (a Dragoon shot dead there by nobody in particular).
func loose_at(p: Vector2) -> Unit:
	Unit.bolt_force = 1.0
	var d := unit("dragoon", p)
	d.take_damage(9999.0, null, Entity.BLOW_RANGED)
	Unit.bolt_force = -1.0
	var h: Unit = d.loose_horse
	if h:
		h.bolt_t = 0.0          # (calm at once, where it stands)
		h.position = p + Vector2(20, 0)
		h.graze_at = h.position
	return h


func _run() -> void:
	origin = _open_area(22, 16)
	check(origin.x >= 0, "an open test ground (%s)" % origin)
	await _clear_units()
	var T := Defs.TILE
	# 1
	Unit.bolt_force = 1.0
	var d1 := unit("dragoon", at(250, 256))
	d1.coat = "grey"
	d1.horse_miles = 150.0
	var s1 := unit("musketeer", at(100, 256), CROWN2)
	s1.cmd_hold()
	await wait(0.3)
	await shoot_dead(s1, d1)
	Unit.bolt_force = -1.0
	var h1: Unit = d1.loose_horse
	check(d1.dead and h1 != null and h1.team == -1 and h1.kind == "horse", "a Dragoon shot dead: his horse lives, belonging to nobody")
	check(d1.kind == "musketeer" and d1.coat == "", "  he lies there on foot, a Musketeer (%s)" % d1.kind)
	check(Game.body_supply(d1) == int(Defs.UNITS["musketeer"]["supply"]) and g.corpse_value(d1) == int(Defs.UNITS["musketeer"]["supply"]),
		"  his body is worth only the man (%d)" % Game.body_supply(d1))
	check(g.fallen.has(d1), "  and a Missionary can still raise him")
	if h1:
		check(h1.coat == "grey" and Unit.horse_rank(h1.horse_miles) == 1 and h1.max_hp > 60.0, "  the horse keeps its coat and seasoning (%s, %.0f tiles)" % [h1.coat, h1.horse_miles])
		check(h1.bolt_t > 0.0, "  it bolts")
		var d_before: float = h1.position.distance_to(s1.position)
		await wait_for(func() -> bool: return h1.bolt_t <= 0.0, 10.0)
		var ran: float = h1.position.distance_to(d1.position) / T
		check(h1.position.distance_to(s1.position) > d_before + 3.0 * T and ran >= 3.5 and ran <= 8.0,
			"  away from the shooter, %.1f tiles from the body" % ran)
		var calm := h1.position
		await wait(6.0)
		check(h1.team == -1 and not h1.dead and h1.position.distance_to(calm) < 2.0 * T and h1.graze_at.distance_to(calm) < 20.0,
			"  then it calms and grazes there (still nobody's)")
		check(not g.horses_of(CROWN).has(h1) and not g.horses_of(CROWN2).has(h1), "  counted in nobody's horses")
	await _clear_units()
	# 2
	Unit.bolt_force = 0.0
	var d2 := unit("dragoon", at(250, 256))
	var s2 := unit("musketeer", at(100, 256), CROWN2)
	s2.cmd_hold()
	await wait(0.3)
	var n2 := n_loose()
	await shoot_dead(s2, d2)
	Unit.bolt_force = -1.0
	check(d2.dead and d2.kind == "dragoon" and d2.loose_horse == null and n_loose() == n2,
		"forced 0: the mounted body as before, no horse")
	check(Game.body_supply(d2) == int(Defs.UNITS["dragoon"]["supply"]) + 1, "  worth the man and his horse (%d)" % Game.body_supply(d2))
	await _clear_units()
	# 3
	Unit.bolt_force = 1.0
	var d3 := unit("dragoon", at(450, 130))
	var gun := unit("cannon", at(250, 130), CROWN2)
	var d4 := unit("cuirassier", at(450, 380))
	d4.hp = 1.0
	await physics_frame          # (in the spatial hash)
	var n3 := n_loose()
	g.round_shot_land(gun.position, d3.position, 999.0, CROWN2, gun)
	await physics_frame
	check(d3.dead and d3.kind == "dragoon" and d3.loose_horse == null and n_loose() == n3,
		"round shot (area) never leaves a horse (dead %s, %s, blow '%s')" % [d3.dead, d3.kind, d3.last_blow])
	var rp := unit("raptor", at(410, 380), BROOD)
	rp.cmd_attack(d4)
	await wait_for(func() -> bool: return d4.dead, 10.0)
	check(d4.dead and d4.kind == "cuirassier" and d4.loose_horse == null and d4.last_blow == Entity.BLOW_BROOD and n_loose() == n3,
		"a Raptor's bite never leaves a horse (%s, %s)" % [d4.kind, d4.last_blow])
	Unit.bolt_force = -1.0
	check(Unit.bolt_chance(Entity.BLOW_RANGED) == 0.4 and Unit.bolt_chance(Entity.BLOW_MELEE) == 0.25 and Unit.bolt_chance("") == 0.0 \
		and Unit.bolt_chance(Entity.BLOW_BROOD) == 0.0, "the chances: shot 40%, blow 25%, Brood and area 0")
	await _clear_units()
	# 4
	var h4 := loose_at(at(150, 130))
	check(h4 != null, "a loose horse to catch")
	if h4:
		var m4 := unit("musketeer", at(150, 290), CROWN2)
		m4.cmd_move(h4.position)
		await wait_for(func() -> bool: return h4.team == CROWN2, 10.0)
		check(h4.team == CROWN2 and g.horses_of(CROWN2).has(h4), "a Crown man of another side catches it by walking up")
		var cloth: Color = h4._mat.get_shader_parameter("team") if h4._mat else Color.BLACK
		check(cloth.is_equal_approx(g.team_colour(CROWN2)), "  its saddle cloth takes his side's colour")
	var h5 := loose_at(at(500, 130))
	if h5:
		var w5 := unit("winder", at(500, 290), CLOCK)
		w5.cmd_move(h5.position)
		await wait_for(func() -> bool: return h5.team == CLOCK, 12.0)
		check(h5.team == CLOCK, "a Clockwork Winder catches one too")
	var h6 := loose_at(at(300, 420))
	if h6:
		var lab := unit("labourer", at(420, 420), CROWN)
		check(lab.cmd_lead(h6), "LEAD takes a loose horse")
		await wait_for(func() -> bool: return h6.leader == lab, 10.0)
		check(h6.leader == lab and h6.team == CROWN, "  he leads it, his side's now")
	await _clear_units()
	# 5
	var h7 := loose_at(at(300, 180))
	if h7:
		var th := unit("thresher", at(300, 300), CLOCK)
		var hp7: float = h7.hp
		await wait(3.0)
		check(not h7.dead and h7.hp >= hp7 and th.target == null, "a Thresher leaves a loose horse alone (only the Brood goes for them)")
		g.consume_unit(th)
		unit("raptor", at(300, 330), BROOD)
		await wait_for(func() -> bool: return h7.dead, 20.0)
		check(h7.dead, "a Raptor with nothing else about kills a loose horse")
		await wait(0.5)
		check(g.corpses.has(h7), "  its carcass is for the Brood")
	await _clear_units()
	# 6
	var carcasses: int = g.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.kind == "horse").size()
	Unit.bolt_force = 1.0
	var d8 := unit("dragoon", at(350, 256))
	d8.coat = "spotted" if HorseCoat.COATS.has("spotted") else HorseCoat.pick()
	var coat8: String = d8.coat
	d8.take_damage(9999.0, null, Entity.BLOW_RANGED)
	Unit.bolt_force = -1.0
	var h8: Unit = d8.loose_horse
	check(d8.dead and h8 != null and d8.kind == "musketeer", "a Dragoon falls, his horse loose")
	await wait_for(func() -> bool: return h8 == null or h8.bolt_t <= 0.0, 10.0)
	var miss := unit("missionary", at(310, 300))
	miss.cmd_revive(d8)
	await wait_for(func() -> bool: return not d8.dead, 20.0)
	check(not d8.dead and d8.kind == "musketeer", "raised (on foot)")
	check(d8.order == "mount" and d8.order_target == h8, "  he goes back to his loose horse")
	await wait_for(func() -> bool: return d8.kind == "dragoon", 20.0)
	check(d8.kind == "dragoon" and d8.coat == coat8 and (h8 == null or not is_instance_valid(h8) or h8.dead), "  and rides it again (%s, %s)" % [d8.kind, d8.coat])
	check(g.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.kind == "horse").size() == carcasses,
		"  no dead horse was left by his body")
	await _clear_units()
	# 7
	var c9 := unit("cannon", at(450, 150))
	c9.team_horses = [{"coat": "bay", "hp": 1.0, "m": 0.0}, {"coat": "white", "hp": 0.9, "m": 120.0}]
	var s9 := unit("musketeer", at(250, 150), CROWN2)
	s9.cmd_hold()
	await physics_frame
	var before := n_loose()
	c9.hp = 2.0              # (one ball finishes it: its team horses take a share of every blow)
	Unit.bolt_force = 1.0
	await shoot_dead(s9, c9, 6.0)
	Unit.bolt_force = -1.0
	await physics_frame
	var bolted: int = n_loose() - before
	check(c9.dead and bolted == 3, "a cannon shot to pieces: its 3 horses bolt loose (%d)" % bolted)
	var wg := unit("powder_wagon", at(450, 420))
	wg.team_horses = [{"coat": "bay", "hp": 1.0, "m": 0.0}]
	wg.hp = 2.0
	await physics_frame
	var before2 := n_loose()
	Unit.bolt_force = 1.0
	await shoot_dead(s9, wg, 6.0)
	Unit.bolt_force = -1.0
	await physics_frame
	check(wg.dead and n_loose() <= before2, "a Powder Wagon blows up: no horse lives")
	await _clear_units()
	# 8
	var hs := loose_at(at(250, 256))
	check(hs != null, "a loose horse for the save")
	if hs:
		hs.coat = "white"
		hs.horse_miles = 210.0
		hs.apply_horse_vet()
	var nl := n_loose()
	SaveGame.save(g, {"map": "random", "seed": 4242})
	var sd := SaveGame.peek()
	SaveGame.restore(g, sd)
	await wait(0.5)
	var after: Array = g.units.filter(func(u: Unit) -> bool: return Game.loose_horse(u))
	check(after.size() == nl and nl > 0, "loaded: the loose horses still nobody's (%d/%d)" % [after.size(), nl])
	var wh: Array = after.filter(func(u: Unit) -> bool: return u.coat == "white" and Unit.horse_rank(u.horse_miles) == 2)
	check(wh.size() == 1, "  same coat and seasoning")
	if not wh.is_empty():
		var lh: Unit = wh[0]
		var cl: Color = lh._mat.get_shader_parameter("team") if lh._mat else Color.BLACK
		check(cl.is_equal_approx(Defs.NEUTRAL_CLOTH), "  its saddle cloth undyed (nobody's)")
		var m10 := unit("musketeer", lh.position + Vector2(140, 0), CROWN)
		m10.cmd_move(lh.position)
		await wait_for(func() -> bool: return lh.team == CROWN, 10.0)
		check(lh.team == CROWN, "  and it can still be caught")
	SaveGame.clear()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

