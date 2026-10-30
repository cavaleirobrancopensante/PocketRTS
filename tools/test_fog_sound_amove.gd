extends SceneTree
## The owner's playtest of 2026-10-30 (branch fog-sound-amove):
##   godot --headless --fixed-fps 30 --script res://tools/test_fog_sound_amove.gd
##  1. SOUNDS THROUGH THE FOG: a sound at a spot the player can't see is not heard (Sfx.heard / Sfx.play);
##     in sight it is; his own base always; the interface and spotless sounds always; FOG: OFF hears all.
##  2. THE COMPUTER (ALMOST) NEVER USES PLAIN MOVE: a soldier scout goes on attack-move (and ignores halls on its
##     loop), turns on a Raptor it can't outrun, walks home on attack-move unless driven off; retreats are plain moves.
var main: Node
var g: Game
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hall(t: int) -> Building:
	for b in g.buildings:
		if b.team == t and not b.dead and b.kind == g.faction_hall(t):
			return b
	return null


func _played(name: String, pos: Vector2) -> bool:
	Sfx.me._last.erase(name)
	Sfx.me._starts.clear()
	Sfx.play(name, pos)
	return Sfx.me._last.has(name)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(77)
	main.start({"map": "greenhold", "seed": 77, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(20)
	var mine := _hall(0)
	var theirs := _hall(1)
	Sfx.me.camera = null          # (no distance fade: only the fog decides here)
	check(Sfx.me.game == g, "the sound system knows the match")
	check(Sfx.has("work/crown_build"), "the hammer sound exists")
	# ---- 1. the fog
	check(not _played("work/crown_build", theirs.center()), "an enemy hall hammering in the fog: no sound")
	check(_played("work/crown_build", mine.center()), "my own hall hammering: heard")
	var spy: Unit = g._add_unit("musketeer", 0, theirs.center() + Vector2(0, theirs.rect().size.y * 0.5 + 60.0))
	await _frames(12)
	check(_played("work/crown_build", theirs.center()), "the enemy hall hammering with my Musketeer by it: heard")
	spy.queue_free()
	g.units.erase(spy)
	await _frames(12)
	check(not _played("work/crown_build", theirs.center()), "the Musketeer gone: the fog hides the hammer again")
	check(_played("ui/click", theirs.center()) or not Sfx.has("ui/click"), "an interface sound at a fogged spot still plays")
	check(Sfx.heard("work/crown_build", Vector2.INF), "a sound with no spot (an alert) always plays")
	g.reveal = true
	check(Sfx.heard("work/crown_build", theirs.center()), "FOG: OFF (all vision): the fogged hammer is heard")
	g.reveal = false
	# ---- 2. the computer's orders
	var ai: AI = null
	for a in g.ais:
		if a.team == 1:
			ai = a
	var scout: AIScout = ai.scout
	var m: Unit = g._add_unit("musketeer", 1, theirs.center() + Vector2(0, 200))
	scout.unit = m
	scout._wps = [mine.center()]
	scout._wp_i = 0
	scout._go(m, mine.center())
	check(m.order == "amove", "a soldier scout goes on ATTACK-MOVE (order %s)" % m.order)
	check(m.has_meta("ai_scout"), "... marked as a scout")
	# it fires at what fights back, not at a hall on its loop
	m.position = mine.center() + Vector2(0, mine.rect().size.y * 0.5 + 120.0)
	g.note_move(m)
	await _frames(15)
	check(not (m.target is Building), "the scout does not stop to shoot a hall (target %s)" % [m.target])
	# one Raptor at it: it can't outrun it, it turns and fights
	var r: Unit = g._add_unit("raptor", 0, m.position + Vector2(60, 0))
	await _frames(3)
	scout._avoid()
	check(m.order == "attack" and m.order_target == r, "a Raptor it can't outrun: the scout fights it (order %s)" % m.order)
	r.queue_free()
	g.units.erase(r)
	scout._finish("done")
	check(m.order == "amove" and not m.has_meta("ai_scout"), "trip done: home on attack-move, unmarked (order %s)" % m.order)
	var m2: Unit = g._add_unit("musketeer", 1, theirs.center() + Vector2(0, 220))
	scout.unit = m2
	scout._finish("driven off")
	check(m2.order == "move", "driven off: home on a plain MOVE, a retreat (order %s)" % m2.order)
	# a worker scout still walks
	var lab: Unit = g._add_unit("labourer", 1, theirs.center() + Vector2(0, 240))
	scout._go(lab, mine.center())
	check(lab.order == "move", "a worker scout walks (no fighting worker): order %s" % lab.order)
	# retreats stay plain moves
	var w: Unit = g._add_unit("musketeer", 1, mine.center() + Vector2(0, 300))
	ai._rush_recall([w])
	check(w.order == "move", "a recalled rush retreats on a plain MOVE (order %s)" % w.order)
	# the Brood computer's Raptor scout
	var bai := AIBroodNew.new()
	var rr: Unit = g._add_unit("raptor", 1, theirs.center() + Vector2(0, 260))
	bai._scout_go(rr, mine.center())
	check(rr.order == "amove" and rr.has_meta("ai_scout"), "a Brood Raptor scout goes on attack-move (order %s)" % rr.order)
	bai.free()
	# ---- UI (owner, 19:33): the resource tooltips, Ctrl+A, refits one at a time
	var hud = g.hud
	var t0: Dictionary = hud._res_tip(0)
	var t1: Dictionary = hud._res_tip(1)
	check(String(t0.get("body", "")).contains("Income: about") and String(t0["body"]).contains("soil"), "the gold tooltip: what, how, exhaustion, income")
	check(String(t1.get("body", "")).contains("15%") and String(t1["body"]).contains("Income: about"), "the powder tooltip: the 15% floor and income")
	check(String(t0["body"]).contains("Workers: ") and String(t0["body"]).contains("Farms"), "the gold tooltip counts the workers on the Farms: " + String(t0["body"]).get_slice("\n", 1))
	check(String(t1["body"]).contains("Powder Mills"), "the powder tooltip counts the Mills' workers: " + String(t1["body"]).get_slice("\n", 1))
	check(String(hud.CTRL_KEYS["ATTACK GROUND"]) == "Ctrl+A", "ATTACK GROUND's key reads Ctrl+A")
	g.players[0]["tech"]["pouch"] = true
	var men: Array = []
	for i in 3:
		men.append(g._add_unit("musketeer", 0, mine.center() + Vector2(-60 + 60 * i, mine.rect().size.y * 0.5 + 90.0)))
	g.set_selection(men)
	var one: Array = hud._refit_one("pouch")
	check(one.size() == 1, "a plain REFIT click picks ONE man of three (%d)" % one.size())
	g.set_selection([])
	for u in men:
		g.units.erase(u)
		u.queue_free()
	# ---- 3. the fog of a CONTINUED match is in place through the 3-2-1 countdown (it vanished till GO)
	for u in [m, m2, lab, w, rr]:
		if is_instance_valid(u):
			g.units.erase(u)
			u.queue_free()
	await _frames(10)
	main._autosave()
	main._to_menu()
	await process_frame
	await process_frame
	var save := SaveGame.peek()
	check(not save.is_empty(), "the match was saved")
	var cfg: Dictionary = save["cfg"].duplicate(true)
	cfg["resume"] = save
	main.start(cfg)
	await process_frame
	await process_frame
	g = main.game
	check(g.hud != null and g.hud.countdown > 0.0, "the continued match is in its countdown")
	var foes: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 1 and not u.dead and not g.is_visible_to(0, u.position))
	var shown: Array = foes.filter(func(u: Unit) -> bool: return u.visible)
	check(not foes.is_empty() and shown.is_empty(), "during the countdown the enemy's units in the fog are hidden (%d of %d shown)" % [shown.size(), foes.size()])
	check(g.fog_sprite.visible, "during the countdown the fog is drawn")
	check(not Sfx.heard("work/crown_build", _hall(1).center()), "and the fogged enemy hall is not heard")
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	main.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)
