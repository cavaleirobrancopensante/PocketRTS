extends SceneTree
## THE MOTHER'S EGG TOOLTIP AND THE CARD'S WORKER CHIPS (scripts/egg_tip.gd, scripts/card_tips.gd; the owner,
## 2026-10-30 09:06; docs/egg_tooltips.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_egg_tooltips.gd
## Hollowfen, you the Brood against the Crown (computers off).
##  1. the egg tooltip of a Mother at stage 2 with a Sire near her, a Mound Turtle far out on new ground and 12
##     veterancy: her eggs and clutch, the next egg and a full clutch, her laying in all and each lever with its value
##     match BroodNew.lay_rate; in Portuguese and Spanish it is translated; full and growing say laying stops;
##  2. resting the mouse on her egg line on the map gives that tooltip (Hud._hover_at -> _tip_of), the whole line
##     ("4/10  4.8s · 00:35") is under the hover area, and her card's EGGS chip and LAYING button give the same text;
##  3. not for the enemy: the Crown player gets no egg tooltip and no chips on her;
##  4. the worker chips on the card: a Rootmaw's GRUBS and food, the Crown's Town Hall, Farm, Powder Mill and Horse
##     Breeder: the chip's count is the label's and its tooltip is the label's (WorkerLabels.tip).
## Prints PASS / FAIL lines and "egg_tooltips: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.tooltips = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
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


func _same(a: Dictionary, b: Dictionary) -> bool:
	for k in ["title", "stats", "body", "hint"]:
		if String(a.get(k, "")) != String(b.get(k, "")):
			return false
	return not a.is_empty()


## A rooted creature of kind k at p (out of its cocoon at once).
func _rooted(team: int, k: String, p: Vector2) -> Unit:
	var u: Unit = BroodRoot.cocoon(g, team, k, p)
	u.nb.erase("coc")
	u.hp = u.max_hp
	BroodNew.recount(g, team)
	return u


## A spot d tiles from the Mother on open ground (her home region or any walkable).
func _far_spot(q: Unit, tiles: float) -> Vector2:
	for i in 48:
		var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 48.0) * tiles * Defs.TILE
		var c: Vector2i = g.cell_of(p)
		if c.x > 3 and c.y > 3 and c.x < g.W - 4 and c.y < g.H - 4 and g.passable(c, 0):
			return p
	return q.position + Vector2(tiles * Defs.TILE, 0)


func _card_chip(title: String) -> Dictionary:
	for sr in g.hud._stat_rects:
		if String(sr[1].get("title", "")) == title and sr[1].has("tipf"):
			return sr[1]
	return {}


func _run() -> void:
	await wait(0.5)
	g.reveal = true
	var hud = g.hud
	var q: Unit = BroodNew.queen(g, 0)
	check(q != null, "the Brood Mother is there")
	# --- 1. stage 2, a Sire near, a far turtle, 12 veterancy
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	q.nb["hvet"] = 12
	q.nb["eggs"] = 4
	var sire := _rooted(0, BroodNew.FATHER, q.position + Vector2(4.0 * Defs.TILE, 2.0 * Defs.TILE))
	var turtle := _rooted(0, BroodNew.TURTLE, _far_spot(q, 18.0))
	await wait(1.0)
	q.nb["eggs"] = 4
	var lr: Array = BroodNew.lay_rate(g, q)
	print("  lay_rate %s, turtle %.1f tiles away" % [lr, turtle.position.distance_to(q.position) / Defs.TILE])
	check(is_equal_approx(float(lr[1]), 1.3) and int(lr[2]) == 1 and int(lr[3]) == 1 and int(lr[4]) == 12, "the levers: stage x1.3, 1 Sire, 1 expansion, veterancy 12")
	var want := 1.3 * (1.0 + 0.2 + 0.15 + 0.12)
	check(absf(float(lr[0]) - want) < 0.001, "her laying x%.3f = 1.3 x 1.47" % float(lr[0]))
	var tp: Dictionary = EggTip.tip(g, q)
	var all := "%s\n%s\n%s\n%s" % [tp.get("title", ""), tp.get("stats", ""), tp.get("body", ""), tp.get("hint", "")]
	print(all)
	var every := 6.0 / float(lr[0])
	check(String(tp["stats"]).contains("4 eggs of 15"), "her eggs and her clutch: 4 of 15")
	check(String(tp["stats"]).contains("next egg in " + BroodNew.clock_text(BroodNew.next_egg_in(q), true)), "the next egg's clock, as over her")
	check(String(tp["stats"]).contains("clutch full in " + BroodNew.clock_text(BroodNew.full_in(q), false)), "the full clutch's clock, as over her")
	check(String(tp["stats"]).contains("Laying x%.2f: %.1f eggs a minute, one every %.1f s." % [float(lr[0]), 60.0 / every, every]), "her laying in all: x%.2f, %.1f a minute, one every %.1f s" % [float(lr[0]), 60.0 / every, every])
	var body := String(tp["body"])
	check(body.contains("Her stage 2: x1.3."), "the stage lever with its value")
	check(body.contains(String(sire.d["name"])) and body.contains(": +20%."), "the Sire named, +20%")
	check(body.contains("1 of 3: +15%."), "the far turtle: 1 of 3, +15%")
	check(body.contains("Her veterancy 12 of 50") and body.contains("+12%."), "her veterancy 12, +12%")
	check(body.contains("Her clutch holds 15 at stage 2") and body.contains("GROW"), "what raises the clutch: her stage (GROW)")
	check(body.contains("= x%.2f." % float(lr[0])), "the sum written out")
	check(String(tp["hint"]).contains("while she grows") and String(tp["hint"]).contains("researches"), "what stops laying: growing, a full clutch, a Sire researching")
	for code in ["pt", "es"]:
		Loc.set_lang(code)
		var tl: Dictionary = EggTip.tip(g, q)
		check(String(tl["body"]) != body and String(tl["title"]) != String(tp["title"]) and String(tl["hint"]) != String(tp["hint"]), "translated (%s): %s" % [code, String(tl["title"])])
	Loc.set_lang("en")
	q.nb["eggs"] = BroodNew.eggs_max(q)
	check(String(EggTip.tip(g, q)["hint"]).begins_with("NOW: her clutch is full"), "a full clutch says so first")
	q.nb["eggs"] = 4
	# --- 2. the map hover over her egg line, and her card
	var lrect: Rect2 = EggTip.label_rect(q)
	var font := ThemeDB.fallback_font
	var lw: float = font.get_string_size(EggTip.label_text(q), HORIZONTAL_ALIGNMENT_LEFT, -1, EggTip.SIZE).x
	check(lrect.size.x >= lw and EggTip.label_text(q).contains(" · "), "the hover area covers the whole line \"%s\" (%.0f px wide, text %.0f)" % [EggTip.label_text(q), lrect.size.x, lw])
	g.set_selection([])
	g.camera.position = lrect.get_center()
	await wait(0.3)
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * lrect.get_center()      # (the camera may stop at the map's edge)
	var wpt: Vector2 = g.controls.to_world(sp)
	check(EggTip.at(g, wpt) == q, "her egg line is found under the point (%s in %s)" % [wpt, lrect])
	var right_end: Vector2 = Vector2(lrect.end.x - EggTip.HIT_GROW - 2.0, lrect.get_center().y)
	check(EggTip.at(g, right_end) == q, "and at the end of the line (the full clutch's clock)")
	var c: Dictionary = hud._hover_at(sp / float(hud.ui_scale))
	check(c.has("egg") and c["egg"] == q and is_equal_approx(float(c["delay"]), hud.TIP_LABEL_DELAY), "hovering it: the egg tooltip is due after %.1f s (the labels' delay)" % float(c.get("delay", -1.0)))
	var tmap: Dictionary = hud._tip_of(c) if not c.is_empty() else {}
	check(_same(tmap, EggTip.tip(g, q)), "the map hover gives the egg tooltip")
	g.set_selection([q])
	hud._refresh_card()
	await process_frame
	await process_frame
	await process_frame
	var ch := _card_chip("Eggs")
	check(not ch.is_empty() and String(ch["text"]) == "4/15", "her card shows an EGGS chip: %s" % ch.get("text", "none"))
	if not ch.is_empty():
		var tcard: Dictionary = UnitStats.tip(ch)
		check(_same(tcard, EggTip.tip(g, q)), "her card's egg chip gives the same tooltip as the map")
		var hit := false
		for sr in hud._stat_rects:
			if sr[1] == ch:
				var hc: Dictionary = hud._hover_at((sr[0] as Rect2).get_center())
				hit = _same(hud._tip_of(hc), EggTip.tip(g, q))
		check(hit, "resting the mouse on the egg chip gives it (Hud._hover_at)")
	var fc := _card_chip("Grubs bringing food")
	check(not fc.is_empty() and String(UnitStats.tip(fc).get("title", "")) == "Grubs bringing her food", "her card's GRUBS chip: who brings her food")
	var lay_it: Array = []
	for b in hud._card_buttons:
		if String(b["item"][0]) == "brood_mother":
			lay_it = b["item"]
	check(not lay_it.is_empty() and _same(hud._card_tip(lay_it), EggTip.tip(g, q)), "her LAYING button's tooltip is the same text")
	# --- 3. not for the enemy
	g.human = 1
	check(EggTip.at(g, wpt) == null and EggTip.tip(g, q).size() > 0 and not EggTip.shown_to(g, q), "the enemy gets no egg tooltip over her")
	check(CardTips.chips(g, q).is_empty(), "nor egg chips on her card")
	g.human = 0
	# --- 4. the worker chips
	var maw: Unit = null
	for u in g.units:
		if u.team == 0 and u.kind == BroodNew.MAW and not u.dead and BroodNew.rooted(u):
			maw = u
	check(maw != null, "a rooted Rootmaw")
	if maw:
		_chips_match(maw, "Grubs", "the Rootmaw's GRUBS")
		_chips_match(maw, "Food", "the Rootmaw's food")
	g.human = 1
	var crown_hall: Building = g._own_hall(1)
	_chips_match(crown_hall, "Haulers", "the Town Hall's HAULERS")
	for k in ["farm", "powder_mill", "horse_breeder"]:
		var cc: Vector2i = g.find_spot(1, k, crown_hall, 3, 18)
		if cc.x < 0:
			cc = g.find_spot(1, k, crown_hall, 2, 30)
		var b: Building = g._add_building(k, 1, cc, true) if cc.x >= 0 else null
		if b == null:
			for ob in g.buildings:
				if ob.team == 1 and ob.kind == k and ob.built and not ob.dead:
					b = ob          # (the econ limit reached: one already there)
		check(b != null, "a %s placed" % k)
		if b:
			_chips_match(b, {"farm": "Farmers", "powder_mill": "Powder Makers", "horse_breeder": "Haulers"}[k], "the %s's workers" % k)
			if k != "horse_breeder":
				_chips_match(b, {"farm": "Soil", "powder_mill": "Saltpetre"}[k], "the %s's resource" % k)
	g.human = 0
	print("egg_tooltips: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## The chip `title` on e's card: there, its count the label's, its tooltip the label's.
func _chips_match(e: Entity, title: String, what: String) -> void:
	var chips: Array = CardTips.chips(g, e)
	var ch: Dictionary = {}
	for c in chips:
		if String(c["title"]) == title:
			ch = c
	var lab_e: Entity = CardTips.home_hall(g, e) if e is Building and (e as Building).kind == "horse_breeder" else e
	var L: Dictionary = WorkerLabels.layout(g, lab_e)
	var want: Dictionary = WorkerLabels.tip(g, lab_e)
	var ok: bool = not ch.is_empty() and _same(UnitStats.tip(ch), want)
	if ok and ch.has("pic"):
		ok = String(ch["text"]) == String(L.get("count", ""))
	check(ok, "%s: chip \"%s\" (label \"%s\"), tooltip \"%s\"" % [what, ch.get("text", "none"), L.get("count", ""), want.get("title", "")])
