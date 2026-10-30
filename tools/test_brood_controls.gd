extends SceneTree
## THE OWNER'S PLAYTEST OF 2026-10-30 19:13 (the Brood's controls, 0.24.1):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_controls.gd
##   pictures: xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/test_brood_controls.gd -- docs/shots/brood_controls
##  1. a grub carrying food delivers at the NEAREST edge of the rooted Mother (her back, her sides), never round her front
##  2. units hidden behind a bigger picture (the Mother, a building) are drawn as silhouettes (only your own / selected)
##  3. a creature UPROOTING has its card (MOVE...): orders and Shift-queued orders kept, started once it is up
##  4. a grub ordered to turn into a structure-unit PAYS AT ONCE; paid back if stopped, re-ordered, killed, or it can't
##     morph there; once only when it does
##  5. the Mother's TWO RALLIES: her right-clicks take turns, grubs' rally (gold) first, then warriors' (green), the
##     WORKERS button (with a key); grubs to hers, warriors (also from a Sire's nest) to hers, before the Sire's
##  6. F2 (ARMY) leaves out rooted creatures; uprooted ones are in; F3 (MAKE) selects the Mother
## Prints PASS / FAIL lines and "brood_controls: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = String(args[0])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out) if not out.begins_with("/") else out)
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


func free_spot(k: String, p: Vector2, tiles: float) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles - 1.0, tiles + 2.0, tiles + 3.0, tiles + 4.0, tiles + 6.0]:
		for i in 32:
			var s: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 32.0) * maxf(r, 0.0) * Defs.TILE)
			if g.region_of(g.cell_of(s)) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, 0, k, s, null, false, 1.0) == "":
				return s
	return Vector2.INF


func card_labels() -> Array:
	var labs: Array = []
	for it in g.hud._build_card():
		labs.append(String(it[1]))
	return labs


func _snap(name: String) -> void:
	if out == "":
		return
	await create_timer(0.6).timeout
	var dir := out if out.begins_with("/") else ProjectSettings.globalize_path("res://" + out)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("shot %s" % name)


func _run() -> void:
	var p: Dictionary = g.players[0]
	var q: Unit = BroodNew.queen(g, 0)
	await wait_for(func() -> bool: return q.tesla_mode == "deployed" and mine(BroodNew.MAW).any(func(m) -> bool: return m.tesla_mode == "deployed"), 12.0)
	check(q.tesla_mode == "deployed", "the Mother is rooted")
	var maw: Unit = mine(BroodNew.MAW)[0]
	p["gold"] = 5000
	await _deposit(q, maw, p)
	await _silhouette(q)
	await _pay_at_once(q, p)
	await _rallies(q, maw, p)
	await _army_rooted(q)
	await _extras(q, maw, p)
	await _uprooting(q)
	print("brood_controls: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## 1. the nearest edge of her: from behind and from each side it never walks under her front (her footprint's bottom)
func _deposit(q: Unit, maw: Unit, p: Dictionary) -> void:
	var r: Rect2 = BroodRoot.rect_of(q)
	var ap: Vector2 = g.approach_point(q, Vector2(r.get_center().x, r.position.y - 60.0))
	check(ap.y < r.get_center().y, "1. approach_point to the rooted Mother from behind: her back (%s, footprint %s)" % [str(ap.round()), str(r)])
	var sides := {"back": Vector2(r.get_center().x + 20.0, r.position.y - 40.0), "left": Vector2(r.position.x - 40.0, r.get_center().y - 10.0),
		"right": Vector2(r.end.x + 40.0, r.get_center().y - 10.0)}
	for side in sides:
		var at: Vector2 = g.cell_center(g.nearest_free(g.cell_of(sides[side]), 3))
		var gr: Unit = g._add_unit("grub", 0, at)
		await physics_frame
		gr.cmd_gather(maw)
		gr.carrying = 5
		gr.load_f = 5.0
		gr.work = "to_hall"
		var gold0 := int(p["gold"])
		var lowest := gr.position.y
		var t0: float = g.clock
		while g.clock < t0 + 8.0 and gr.carrying > 0:
			lowest = maxf(lowest, gr.position.y)
			await physics_frame
		check(gr.carrying == 0 and int(p["gold"]) > gold0 and lowest < r.end.y - 4.0,
			"   a grub at her %s delivers at her nearest edge in %.1f s (lowest y %d, her front edge %d)" % [side, g.clock - t0, int(lowest), int(r.end.y)])
		g.consume_unit(gr)


## 2. silhouettes: an own grub behind her (hidden), one in front (not), an enemy one behind (not), one behind a building
func _silhouette(q: Unit) -> void:
	var r: Rect2 = BroodRoot.rect_of(q)
	var behind: Unit = g._add_unit("grub", 0, Vector2(r.get_center().x, r.position.y - 8.0))
	var front: Unit = g._add_unit("grub", 0, Vector2(r.get_center().x + 30.0, r.end.y + 30.0))
	var foe: Unit = g._add_unit("raptor", 1, Vector2(r.get_center().x - 40.0, r.position.y - 8.0))
	behind.cmd_hold()
	foe.cmd_hold()
	g.camera.position = q.position + Vector2(0, -40)
	g.camera.zoom = Vector2(1.6, 1.6)
	await physics_frame
	await process_frame
	await process_frame
	var lay: OccludedLook = g.occluded_layer
	lay.scan()
	check(lay.hidden_units.has(behind), "2. a grub behind the rooted Mother is drawn as a silhouette (%d hidden)" % lay.hidden_units.size())
	check(not lay.hidden_units.has(front) and not lay.hidden_units.has(foe), "   not one in front of her, nor an enemy behind her")
	g.set_selection([foe])
	lay.scan()
	check(lay.hidden_units.has(foe), "   a selected enemy behind her is")
	g.set_selection([])
	behind.position = Vector2(r.get_center().x, r.position.y - 8.0)
	g.note_move(behind)
	await _snap("silhouette")
	OccludedLook.on = false
	await _snap("silhouette_off")
	OccludedLook.on = true
	# behind a building (the Crown's hall)
	var b = null
	for bb in g.buildings:
		if bb.team == 1 and not bb.dead:
			b = bb
			break
	if b != null:
		g.reveal = true
		await wait(0.5)
		var sr: Rect2 = b.sprite_rect()
		var gb: Unit = g._add_unit("grub", 0, Vector2(sr.get_center().x, b.rect().position.y - 12.0))
		g.camera.position = b.global_position
		await process_frame
		await process_frame
		g.camera.reset_smoothing()
		g.update_view_rect()
		lay.scan()
		check(lay.hidden_units.has(gb), "   a grub behind a Crown %s too" % b.d["name"])
		await _snap("silhouette_building")
		g.consume_unit(gb)
		g.reveal = false
	g.consume_unit(behind)
	g.consume_unit(front)
	g.consume_unit(foe)


## 4. pay at once; refunds
func _pay_at_once(q: Unit, p: Dictionary) -> void:
	var k := BroodNew.TURTLE
	var price: Array = g.unit_price(0, k)
	var spot := free_spot(k, q.position, 9.0)
	check(spot != Vector2.INF, "4. a spot for a Mound Turtle")
	var gr: Unit = g._add_unit("grub", 0, q.position + Vector2(0, 90))
	await physics_frame
	var g0 := int(p["gold"])
	gr.give({"o": "nb_morph", "k": k, "p": spot})
	check(int(p["gold"]) == g0 - int(price[0]) and gr.order == "nb_morph", "   ordered: paid at once (%d -> %d)" % [g0, int(p["gold"])])
	gr.cmd_stop()
	check(int(p["gold"]) == g0, "   stopped: paid back (%d)" % int(p["gold"]))
	gr.give({"o": "nb_morph", "k": k, "p": spot})
	gr.give({"o": "nb_morph", "k": k, "p": spot})
	check(int(p["gold"]) == g0 - int(price[0]), "   ordered twice: paid once (%d)" % int(p["gold"]))
	gr.give({"o": "move", "p": gr.position + Vector2(20, 0)})
	check(int(p["gold"]) == g0, "   re-ordered to move: paid back")
	gr.give({"o": "nb_morph", "k": k, "p": spot})
	gr.die()
	check(int(p["gold"]) == g0, "   killed on the way: paid back")
	# can't morph there (her own footprint): it walks there, can't, paid back
	var g2: Unit = g._add_unit("grub", 0, q.position + Vector2(0, 90))
	await physics_frame
	g2.give({"o": "nb_morph", "k": k, "p": q.position})
	check(int(p["gold"]) == g0 - int(price[0]), "   ordered onto her footprint: paid at once")
	await wait_for(func() -> bool: return g2.order != "nb_morph", 15.0)
	check(g2.order != "nb_morph" and int(p["gold"]) == g0, "   it can't morph there: paid back (%d)" % int(p["gold"]))
	# it does: paid once
	var n0 := mine(k).size()
	g2.give({"o": "nb_morph", "k": k, "p": spot})
	await wait_for(func() -> bool: return mine(k).size() > n0, 20.0)
	check(mine(k).size() > n0 and int(p["gold"]) >= g0 - int(price[0]) and int(p["gold"]) < g0 - int(price[0]) + 40, "   it morphs: paid once (%d, a cocoon)" % int(p["gold"]))
	# the computer's money: a grub on its way is no longer kept for (it has paid)
	check(not FileAccess.get_file_as_string("res://scripts/ai_brood_new.gd").contains("it pays when it gets there"), "   the computer counts the price once (paid at the order)")


## 5. her two rallies
func _rallies(q: Unit, maw: Unit, p: Dictionary) -> void:
	g.set_selection([q])
	var ground: Vector2 = q.position + Vector2(-60, 160)
	check(card_labels().has("> WORKERS") and card_labels().has("RALLY"), "5. her card: WORKERS shown pressed (the next right-click sets the grubs' rally)")
	g.smart_command([q], maw.position)
	check(BroodRoot.worker_rally_of(q).distance_to(maw.position) < 2.0 and BroodRoot.rally_of(q) == Vector2.INF, "   the FIRST right-click: her WORKER (grub) rally")
	check(card_labels().has("> RALLY"), "   then RALLY shown pressed")
	g.smart_command([q], ground)
	check(BroodRoot.rally_of(q).distance_to(ground) < 2.0 and BroodRoot.worker_rally_of(q).distance_to(maw.position) < 2.0, "   the SECOND right-click: her WARRIOR rally (the grub one kept)")
	check(card_labels().has("> WORKERS"), "   then the grubs' turn again")
	var keyed: Array = g.hud._with_keys(g.hud._build_card())
	var wk := ""
	for it in keyed:
		if String(it[1]).ends_with("WORKERS"):
			wk = String(it.back())
	check(wk != "", "   WORKERS on her card, key %s" % wk)
	var spot2: Vector2 = q.position + Vector2(100, 120)
	q.cmd_nb_rally(spot2, "worker")
	check(BroodRoot.worker_rally_of(q).distance_to(spot2) < 2.0, "   WORKERS sets the worker rally on the ground")
	q.cmd_nb_rally(maw.position, "worker")
	await _snap("two_rallies")
	# a grub hatches: to her worker rally (the Rootmaw: it gathers there)
	q.nb["eggs"] = maxi(2, int(q.nb.get("eggs", 0)))
	var grubs0 := mine("grub")
	check(q.cmd_lay("grub") == "", "   she lays a grub")
	await wait_for(func() -> bool: return mine("grub").size() > grubs0.size(), float(Defs.UNITS["grub"]["time"]) + 4.0)
	var newg: Array = mine("grub").filter(func(x) -> bool: return not grubs0.has(x))
	check(not newg.is_empty() and newg[0].order == "gather" and newg[0].home_mine == maw, "   the new grub goes to work at her worker rally's Rootmaw")
	# a warrior from a Sire's nest: to HER warrior rally, not the Sire's
	var fs := free_spot(BroodNew.FATHER, q.position, 5.0)
	var f: Unit = BroodRoot.cocoon(g, 0, BroodNew.FATHER, fs)
	f.nb["coc"] = 999.0
	await wait_for(func() -> bool: return not f.nb.has("coc"), 2.0)
	BroodRoot.set_rally(f, f.position + Vector2(200, -200))
	p["gold"] = 5000
	var r0 := mine("raptor")
	q.nb["eggs"] = maxi(2, int(q.nb.get("eggs", 0)))
	var lw: String = q.cmd_lay("raptor")
	check(lw == "", "   she lays a Raptor egg into the Tyrant Sire's nest (%s)" % lw)
	await wait_for(func() -> bool: return mine("raptor").size() > r0.size(), 40.0)
	var newr: Array = mine("raptor").filter(func(x) -> bool: return not r0.has(x))
	check(not newr.is_empty(), "   Raptors hatch (%d)" % newr.size())
	if not newr.is_empty():
		var d0: float = newr[0].position.distance_to(ground)
		await wait_for(func() -> bool: return newr[0].position.distance_to(ground) < 60.0, 12.0)
		check(newr[0].position.distance_to(ground) < 60.0, "   the Raptors walk to HER warrior rally (%d px -> %d px), not the Sire's" % [int(d0), int(newr[0].position.distance_to(ground))])


## 6. F2 leaves out rooted creatures; F3 selects her
func _army_rooted(q: Unit) -> void:
	var bar: HotkeyBar = g.hud.bar
	bar.select_army()
	var sel: Array = g.selection
	check(not sel.is_empty() and sel.all(func(u) -> bool: return not BroodRoot.fixed(u) and not BroodRoot.in_cocoon(u)),
		"6. F2: the warriors only, no rooted Mother, Rootmaw, Mound Turtle or Sire (%s)" % str(sel.map(func(u) -> String: return u.kind)))
	bar.select_production()
	check(g.selection.size() == 1 and g.selection[0] == q, "   F3 (MAKE) selects the Mother")


## 3. uprooting: her card has MOVE...; a right-click and a Shift-queued order wait till she is up; then F2 has her
func _uprooting(q: Unit) -> void:
	g.set_selection([q])
	q.cmd_uproot(true)
	await wait_for(func() -> bool: return q.tesla_mode == "packing", 2.0)
	check(q.tesla_mode == "packing", "3. she is uprooting")
	var labs := card_labels()
	check(labs.has("MOVE") and labs.has("ATTACK") and labs.has("STOP"), "   her card while uprooting: %s" % str(labs))
	var a: Vector2 = q.position + Vector2(0, 90)
	var b: Vector2 = q.position + Vector2(90, 90)
	g.smart_command([q], a)
	q.give({"o": "move", "p": b}, true)
	check(q.order in ["move", "amove"] and q.queue.size() == 1 and BroodRoot.rally_of(q).distance_to(a) > 2.0, "   a right-click is an order (not a rally), a Shift order queued (%s, %d queued)" % [q.order, q.queue.size()])
	var start: Vector2 = q.position
	await wait(0.3)
	check(q.position.distance_to(start) < 2.0 or q.tesla_mode == "packed", "   she stays put till she is up")
	await wait_for(func() -> bool: return q.position.distance_to(b) < 40.0, 25.0)
	check(q.position.distance_to(b) < 40.0, "   up: she walks to the first spot, then the queued one (%d px off)" % int(q.position.distance_to(b)))
	g.hud.bar.select_army()
	check(g.selection.has(q), "   F2 now has her (uprooted)")


## THE OWNER'S ADDITIONS (19:33-19:46): the Rootmaw's ground on its card and over its ROOT ghost, HARVEST autocast,
## MATURE one / all, the Sires' research queue, the Venom Challenger's size, the venom globs' sizes, the Mist Toad's
## start energy and its MIASMA
func _extras(q: Unit, maw: Unit, p: Dictionary) -> void:
	p["res2"] = 5000.0
	# 7. the Rootmaw's card: the food in its ground
	var chips: Array = CardTips.chips(g, maw)
	var gch: Array = chips.filter(func(c) -> bool: return String(c.get("title", "")) == "Ground")
	check(not gch.is_empty() and int(String(gch[0]["text"])) == int(BroodNew.ground_left(g, maw)), "7. the Rootmaw's card shows its ground: %s food" % (String(gch[0]["text"]) if not gch.is_empty() else "none"))
	# the ROOT ghost's ground: fresh, or the least of the old free ground it overlaps
	var far: Vector2 = maw.position + Vector2(40, 40) * Defs.TILE
	check(int(BroodNew.ground_at(g, far)) == int(Defs.PIT_GROUND), "   a ROOT ghost on fresh ground: %d food in the ground" % int(BroodNew.ground_at(g, far)))
	g.nb_spot_next += 1
	var sid: int = g.nb_spot_next
	g.nb_spots[sid] = {"p": far + Vector2(2, 0) * Defs.TILE, "left": 500.0, "maw": 0}
	check(int(BroodNew.ground_at(g, far)) == 500, "   over old, partly spent ground: %d" % int(BroodNew.ground_at(g, far)))
	g.nb_spots.erase(sid)
	# 8. HARVEST autocast
	var hg: Unit = g._add_unit("grub", 0, q.position + Vector2(-80, 140))
	hg.auto_work = false
	hg.auto_harvest = true
	var foe: Unit = g._add_unit("raptor", 1, hg.position + Vector2(40, 0))
	await physics_frame
	foe.take_damage(9999.0, null)
	await wait_for(func() -> bool: return hg.order == "harvest", 4.0)
	check(hg.order == "harvest", "8. HARVEST autocast: an idle grub harvests a body near it by itself")
	g.set_selection([hg])
	check(card_labels().has("~ HARVEST"), "   HARVEST glows on its card")
	# 9. MATURE: one, then all
	q.nb["stage"] = maxi(1, BroodNew.stage(q))
	BroodNew.apply_stage(q)
	var raps: Array = mine("raptor")
	for i in 2 - raps.size():
		raps.append(g._add_unit("raptor", 0, q.position + Vector2(60 + i * 20, 160)))
	g.set_selection(raps)
	g.hud._mature(false)
	check(raps.filter(func(u) -> bool: return u.moult_t >= 0.0).size() == 1, "9. MATURE (a click): ONE of %d moults" % raps.size())
	g.hud._mature(true)
	check(raps.filter(func(u) -> bool: return u.moult_t >= 0.0).size() == raps.size(), "   Ctrl+MATURE: all of them")
	# research queue at the Tyrant Sire
	var f: Unit = BroodNew.father(g, 0)
	check(f != null and BroodNew.rooted(f), "   the Tyrant Sire rooted on his nest")
	if f != null:
		g.set_selection([f])
		var k1 := "nb_pack_hunt"
		var k2 := "nb_clutch_raptor"
		var g0 := int(p["gold"])
		check(f.cmd_nb_research(k1) == "" and f.cmd_nb_research(k2) == "", "R. two research ordered at the Sire")
		check(BroodResearch.current(f) == k1 and BroodResearch.queued(f) == [k2] and int(p["gold"]) == g0 - 75 - 100, "   one in hand, one QUEUED, both paid (%d)" % (g0 - int(p["gold"])))
		var labs := card_labels()
		check(labs.has("STOP RESEARCH") and labs.has("BATTERING HORNS"), "   his other research stays on the card: %s" % str(labs))
		f.cmd_nb_research_cancel(1)
		check(BroodResearch.queued(f).is_empty() and int(p["gold"]) == g0 - 75, "   a queued one cancelled: paid back")
		f.cmd_nb_research(k2)
		f.cmd_nb_research_cancel(0)
		check(BroodResearch.current(f) == k2 and int(p["gold"]) == g0 - 100, "   the one in hand cancelled: paid back, the next starts")
		f.cmd_nb_research_cancel(0)
		check(not BroodResearch.busy(f) and int(p["gold"]) == g0, "   all cancelled: all paid back")
	# 10. the Venom Challenger smaller than the Tyrant Challenger, bigger than a Spitter
	var area := func(k: String) -> int:
		var im: Image = load("res://assets/units/%s/idle_se.png" % k).get_image()
		if im.is_compressed():
			im.decompress()
		var ur := im.get_used_rect()
		var n := 0
		for y in range(ur.position.y, ur.end.y):
			for x in range(ur.position.x, ur.end.x):
				if im.get_pixel(x, y).a > 0.16:
					n += 1
		return n
	var a_s: int = area.call("spitter")
	var a_v: int = area.call("venom_challenger")
	var a_t: int = area.call("tyrant_challenger")
	check(a_s < a_v and a_v < a_t, "10. sizes (drawn body): Spitter %d < Venom Challenger %d < Tyrant Challenger %d" % [a_s, a_v, a_t])
	# 12. the venom globs grow with the creature
	var sp: Unit = g._add_unit("spitter", 0, q.position + Vector2(0, 220))
	var vc: Unit = g._add_unit("venom_challenger", 0, q.position + Vector2(20, 220))
	var dl: Unit = g._add_unit(BroodNew.DILO, 0, q.position + Vector2(40, 220))
	check(g.venom_glob(dl) == "spitter_glob" and g.venom_glob_scale(sp) < g.venom_glob_scale(vc) and g.venom_glob_scale(vc) < g.venom_glob_scale(dl),
		"12. one glob, scaled: Spitter %.1f < Venom Challenger %.1f < Venom Sire %.1f" % [g.venom_glob_scale(sp), g.venom_glob_scale(vc), g.venom_glob_scale(dl)])
	for u in [sp, vc, dl]:
		g.consume_unit(u)
	# 13. the Mist Toad's start energy; 14. MIASMA
	var toad: Unit = g._add_unit("mist_toad", 0, q.position + Vector2(-40, 200))
	check(int(toad.charge) == 75, "13. a new Mist Toad has 75 energy (of %d)" % int(Defs.TOAD["max"]))
	g.set_selection([toad])
	check(card_labels().has("MIASMA"), "14. MIASMA on the Mist Toad's card: %s" % str(card_labels()))
	var hurt: Unit = g._add_unit("raptor", 0, toad.position + Vector2(30, 0))
	hurt.hp = hurt.max_hp * 0.4
	var hp0: float = hurt.hp
	toad.charge = 150.0
	g.cast_spell(toad, "miasma", hurt.position)
	check(int(toad.charge) == 150 - int(Defs.MIASMA["cost"]), "    it costs %d energy" % int(Defs.MIASMA["cost"]))
	await wait(3.0)
	check(hurt.hp > hp0 + 5.0, "    the Brood inside heal (%.0f -> %.0f)" % [hp0, hurt.hp])
	toad.charge = 10.0
	check(g.spell_problem(toad, "miasma").begins_with("Not enough energy"), "    without the energy: %s" % g.spell_problem(toad, "miasma"))
	g.set_selection([])
