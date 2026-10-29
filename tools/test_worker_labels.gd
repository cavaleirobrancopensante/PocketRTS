extends SceneTree
## THE WORKER LABELS (scripts/worker_labels.gd; the owner, 2026-10-29):
##   godot --headless --fixed-fps 30 --script res://tools/test_worker_labels.gd
## A 2v2 on Jade Wilds: you the Crown, then the old Brood, the Clockwork (gear mode) and the new Brood.
##  1. every crewed thing of every faction gets a label with its job word (HAULERS, FARMERS, POWDER MAKERS, GRUBS,
##     WINDERS) and a tooltip with a title and a body, in English, Portuguese and Spanish (translated, not English);
##  2. HAULERS reads assigned / needed (the owner's rule): 0 with nothing to haul; a near wagon at low use 1; a far wagon
##     at heavy use several (2: the kegs-in-flight limit); a Horse Breeder +1; smoothed; capped at the hall's 6; the
##     colours (grey 0/0, white under, green at, orange over);
##  2b. the game rule: a far wagon under heavy use gets more than 2 kegs on the way at once; a full idle wagon none;
##  3. resting the mouse on a label gives the label's tooltip (HUD._hover_at -> _tip_of) and a click there still
##     picks the building (Game.entity_at).
## Prints PASS / FAIL lines and "worker_labels: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
const U := preload("res://tools/gear_test_util.gd")


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "jade_wilds", "seed": 77, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1},
			{"who": "easy", "faction": "clockwork", "colour": 2, "side": 0},
			{"who": "easy", "faction": Defs.BROOD_NEW, "colour": 3, "side": 1}]})
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


func _team_of(fac: String) -> int:
	for i in g.factions.size():
		if String(g.factions[i]) == fac and not BroodNew.on(g, i):
			return i
	return -1


func _nb_team() -> int:
	for i in g.factions.size():
		if BroodNew.on(g, i):
			return i
	return -1


func _first(team: int, kind: String) -> Building:
	for b in g.buildings:
		if b.team == team and b.kind == kind and not b.dead:
			return b
	return null


## A finished building of `kind` for team near its hall (gear mode: on a linking ring).
func _put(team: int, kind: String) -> Building:
	var hall: Building = g._own_hall(team)
	if String(g.factions[team]) == "clockwork":
		return U.put(g, team, kind, hall.cell)
	var c: Vector2i = g.find_spot(team, kind, hall, 3, 18)
	if c.x < 0:
		return null
	return g._add_building(kind, team, c, true)


## The label and the tooltip of e in each language.
func _check_label(e: Entity, word: String, what: String) -> void:
	var keep: int = g.human
	g.human = e.team if e.team >= 0 else keep
	for code in ["en", "pt", "es"]:
		Loc.set_lang(code)
		var L: Dictionary = WorkerLabels.layout(g, e)
		var tp: Dictionary = WorkerLabels.tip(g, e)
		var wd := String(L.get("word", ""))
		var ok_word: bool = wd == (word if code == "en" else Loc.t(word)) and wd != "" and (code == "en" or wd != word)
		var body := String(tp.get("body", ""))
		var ok_tip: bool = String(tp.get("title", "")) != "" and body.length() > 30
		if code != "en":
			Loc.set_lang("en")
			var en_body := String(WorkerLabels.tip(g, e).get("body", ""))
			Loc.set_lang(code)
			ok_tip = ok_tip and body != en_body
		check(ok_word and ok_tip, "%s (%s): \"%s %s\"  tip \"%s\" — %s" % [what, code, wd, L.get("count", ""), tp.get("title", ""), body.left(70)])
	Loc.set_lang("en")
	g.human = keep


func _run() -> void:
	Defs.gear_mode = true
	await wait(1.0)
	var crown := 0
	var brood := _team_of("brood")
	var cw := _team_of("clockwork")
	var nbt := _nb_team()
	print("teams: crown %d, brood %d, clockwork %d, new brood %d" % [crown, brood, cw, nbt])

	# --- 2. the hauler need (the owner's rule, 07:49): +1 a Horse Breeder; a wagon on SUPPLY: kegs a second x round trip
	var hall: Building = g._own_hall(crown)
	WorkerLabels.update(g, true)
	check(WorkerLabels.hauler_need(g, hall) == 0, "no breeder, no wagon: the hall needs 0 haulers (%d)" % WorkerLabels.hauler_need(g, hall))
	check(String(WorkerLabels.layout(g, hall)["count"]) == "0/0", "  the label reads HAULERS 0/0 (%s)" % WorkerLabels.layout(g, hall)["count"])
	var mill0 := _first(crown, "powder_mill")
	if mill0 == null:
		mill0 = _put(crown, "powder_mill")
	var toward: Vector2 = (Vector2(Game.W, Game.H) * Game.T * 0.5 - mill0.center()).normalized()
	# a near wagon (8 tiles from the Mill) drawn from a little: 10 shots in 25 s
	var near: Unit = g._add_unit("powder_wagon", crown, mill0.center() + toward * 8.0 * Game.T)
	near.supplying = true
	WorkerLabels._st(g)["use"][near.get_instance_id()] = [[g.clock - 25.0, 0.0]]
	near.powder_out = 10.0
	WorkerLabels.update(g, true)
	var wn: Dictionary = WorkerLabels.wagon_need(g, near)
	check(WorkerLabels.hauler_need(g, hall) == 1, "a near wagon at low use: 1 (%d; %.1f tiles, trip %.1f s, %.3f kegs/s)" % [WorkerLabels.hauler_need(g, hall), wn["dist"], wn["trip"], wn["rate"]])
	near.supplying = false
	WorkerLabels.update(g, true)
	check(WorkerLabels.hauler_need(g, hall) == 0, "  off SUPPLY it counts nothing (%d)" % WorkerLabels.hauler_need(g, hall))
	# a far wagon (28 tiles) under heavy use: 120 shots in 25 s (a line of Musketeers refilling)
	var far: Unit = g._add_unit("powder_wagon", crown, mill0.center() + toward * 28.0 * Game.T)
	far.supplying = true
	WorkerLabels._st(g)["use"][far.get_instance_id()] = [[g.clock - 25.0, 0.0]]
	far.powder_out = 120.0
	WorkerLabels.update(g, true)
	var wf: Dictionary = WorkerLabels.wagon_need(g, far)
	var kf := ceili(float(wf["want"]) - WorkerLabels.ROUND_SLACK)
	check(WorkerLabels.hauler_need(g, hall) == kf and kf >= 3 and kf <= 5,
		"a far wagon at heavy use: %d (%.1f tiles, trip %.1f s, a keg every %.1f s: %.1f haulers)" % [
			WorkerLabels.hauler_need(g, hall), wf["dist"], wf["trip"], 1.0 / float(wf["rate"]), wf["want"]])
	var br := _put(crown, "horse_breeder")
	WorkerLabels.update(g, true)
	check(br != null and WorkerLabels.hauler_need(g, hall) == kf + 1, "  and a Horse Breeder: +1 (%d)" % WorkerLabels.hauler_need(g, hall))
	Loc.set_lang("en")
	var hint := String(WorkerLabels.tip(g, hall).get("hint", ""))
	check(hint.begins_with("Needed %d: 1 for the Horse Breeder(s); %d for powder: 1 wagon(s) about" % [kf + 1, kf]), "  the tooltip explains the parts: %s" % hint)
	# smoothing: the far wagon goes quiet; the number holds for a few updates, then falls
	WorkerLabels._st(g)["use"][far.get_instance_id()] = [[g.clock - 25.0, far.powder_out]]
	var seen: Array = []
	for i in WorkerLabels.DROP_AFTER + 1:
		WorkerLabels.update(g)
		seen.append(WorkerLabels.hauler_need(g, hall))
	check(seen[0] == kf + 1 and seen.back() == 1, "  smoothed: a quiet wagon's haulers stay counted for %d updates (%s), then drop" % [WorkerLabels.DROP_AFTER, seen])
	for i in 6:
		_put(crown, "horse_breeder")
	WorkerLabels.update(g, true)
	var np: Dictionary = WorkerLabels.need_parts(g, hall)
	check(WorkerLabels.hauler_need(g, hall) == 6 and float(np["total"]) > 6.0, "7 breeders: capped at the hall's 6 (%d of %.0f)" % [WorkerLabels.hauler_need(g, hall), float(np["total"])])
	check(WorkerLabels.hauler_colour(0, 0) == Color(0.6, 0.6, 0.6) and WorkerLabels.hauler_colour(1, 2) == Color(1, 1, 1)
		and WorkerLabels.hauler_colour(2, 2) == Color(0.45, 1, 0.45) and WorkerLabels.hauler_colour(3, 2) == Color(1.0, 0.62, 0.2),
		"colours: grey 0/0, white under, green at, orange over the need")
	# assign two labourers as haulers: the first number counts them, the tooltip says how many are free
	var labs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == crown and u.kind == "labourer" and not u.dead).slice(0, 2)
	for u in labs:
		u.cmd_gather(hall)
	await wait(1.0)
	var hl: Dictionary = WorkerLabels.layout(g, hall)
	check(String(hl["count"]) == "%d/6" % hall.haulers().size() and hall.haulers().size() == 2, "two haulers assigned: HAULERS %s" % hl["count"])
	check(String(WorkerLabels.tip(g, hall)["stats"]).contains("of 2 free"), "  the tooltip says how many are free (%s)" % WorkerLabels.tip(g, hall)["stats"])

	# --- 2b. THE GAME RULE (the owner, 08:00 / 08:05): kegs go by the powder need, no limit of kegs in flight, not even
	# the wagon's room. Six haulers; the far wagon under heavy use gets more than 2 kegs on the way at once (more than its
	# room once it fills: they wait by it); a full wagon nobody draws from pulls none.
	for i in 4:
		var lb: Unit = g._add_unit("labourer", crown, hall.center() + Vector2(-40 + 20 * i, 90))
		lb.cmd_gather(hall)
	var idle: Unit = g._add_unit("powder_wagon", crown, far.position + Vector2(0, 90))
	idle.supplying = true
	idle.powder = float(Defs.WAGON["store"])          # (full, and nobody draws from it)
	far.powder = 0.0
	g.players[crown]["res2"] = 2000.0
	var most_far := 0
	var idle_most := 0
	for k in 8:
		WorkerLabels._st(g)["use"][far.get_instance_id()] = [[g.clock - 25.0, far.powder_out - 300.0]]   # (heavy use, kept up)
		await wait(0.5)
		for wg in [far, idle]:
			var fl: int = g.haulers_of(crown).filter(func(u: Unit) -> bool: return String(u.haul_job.get("k", "")) == "keg" and u.haul_job.get("wagon") == wg).size()
			if wg == far:
				most_far = maxi(most_far, fl)
			else:
				idle_most = maxi(idle_most, fl)
	print("  haulers %d; kegs on the way to the far wagon at most %d (need %.1f)" % [g.haulers_of(crown).size(), most_far, float(WorkerLabels.wagon_need(g, far)["want"])])
	check(most_far > 2, "a far wagon under heavy use gets more than 2 kegs on the way at once (%d)" % most_far)
	check(idle_most == 0, "  a full wagon nobody draws from pulls no kegs (%d)" % idle_most)
	for wg in [far, idle, near]:
		wg.supplying = false
	for u in g.haulers_of(crown):
		u.keg = false
		u.haul_job = {}

	# --- 1. every crewed kind of every faction
	_check_label(hall, "HAULERS", "Crown Town Hall")
	var farm := _first(crown, "farm")
	if farm == null:
		farm = _put(crown, "farm")
	_check_label(farm, "FARMERS", "Crown Farm")
	var mill := _first(crown, "powder_mill")
	if mill == null:
		mill = _put(crown, "powder_mill")
	_check_label(mill, "POWDER MAKERS", "Crown Powder Mill")
	if brood >= 0:
		var pit := _first(brood, "feeding_pit")
		check(pit != null, "the old Brood has a Feeding Pit")
		if pit:
			_check_label(pit, "GRUBS", "old Brood Feeding Pit")
	if cw >= 0:
		var press := _first(cw, Defs.GEAR_PRESS)
		check(press != null, "the Clockwork has a Cog Press")
		if press:
			_check_label(press, "WINDERS", "Clockwork Cog Press")
		var spring := _first(cw, "mainspring")
		if spring == null:
			spring = _put(cw, "mainspring")
		check(spring != null, "a Mainspring placed")
		if spring:
			_check_label(spring, "WINDERS", "Clockwork Mainspring")
		# a gear building with only its drive %: no word, but a tooltip
		var works := _put(cw, "movement_works")
		if works:
			var keep: int = g.human
			g.human = cw
			var L2: Dictionary = WorkerLabels.layout(g, works)
			check(not L2.is_empty() and String(L2["word"]) == "" and String(L2["pct"]) != "" and not WorkerLabels.tip(g, works).is_empty(), "a Light Works shows its drive %% (%s) and explains it" % L2.get("pct", ""))
			g.human = keep
	if nbt >= 0:
		await wait(4.0)       # (the Rootmaw roots)
		var maw: Unit = null
		for u in g.units:
			if u.team == nbt and u.kind == BroodNew.MAW and not u.dead:
				maw = u
		check(maw != null and BroodRoot.has_fp(maw) or maw != null, "the new Brood has a Rootmaw")
		if maw:
			_check_label(maw, "GRUBS", "new Brood Rootmaw")
			var pile: Unit = g._add_unit(BroodNew.PILE, -1, maw.position + Vector2(160, 60))
			pile.nb = {"food": 80.0, "start": 80.0, "rot": 0.0}
			var keep2: int = g.human
			g.human = nbt
			_check_label(pile, "GRUBS", "food pile")
			g.human = keep2

	# --- 3. hover: the mouse resting on a label gets its tooltip; a click there picks the building
	g.human = crown
	var hl2: Dictionary = WorkerLabels.layout(g, hall)
	var lc: Vector2 = (hl2["rect"] as Rect2).get_center()
	g.camera.position = lc
	await wait(0.3)
	var vp: Vector2 = g.get_viewport().get_visible_rect().size
	var hud = g.hud
	# screen point of the label: the camera is centred on it
	var sp: Vector2 = vp * 0.5
	var w: Vector2 = g.controls.to_world(sp)
	print("  label centre %s, screen centre -> world %s" % [lc, w])
	check(WorkerLabels.at(g, w) == hall, "the label is found under the point (WorkerLabels.at)")
	var c: Dictionary = hud._hover_at(sp / float(hud.ui_scale))
	check(c.has("lab") and c["lab"] == hall and float(c["delay"]) <= 0.6, "hovering the label: its tooltip is due after %.1f s" % float(c.get("delay", -1.0)))
	var tp: Dictionary = hud._tip_of(c) if not c.is_empty() else {}
	check(String(tp.get("title", "")).begins_with("Haulers"), "  and it is the haulers' tooltip (%s)" % tp.get("title", ""))
	var picked = g.entity_at(w)
	check(picked == hall, "a click on the label still picks the Town Hall (%s)" % (picked.kind if picked else "nothing"))
	check(hud.show_label_tip(hall, sp / float(hud.ui_scale)) and not hud._tip.is_empty(), "a long press on a phone shows the same tooltip (show_label_tip)")

	print("worker_labels: %d failures" % fails)
	quit(1 if fails > 0 else 0)
