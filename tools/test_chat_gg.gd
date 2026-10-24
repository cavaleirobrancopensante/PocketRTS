extends SceneTree
## The chat and the computer's gg, in real matches:
##   godot --headless --fixed-fps 30 --script res://tools/test_chat_gg.gd
##  - parsing: gg, GG!, gg wp, good game accepted; "no gg", "egg" not
##  - hopeless computer says gg (once the position has been hopeless for a minute), the log has the line
##  - no reply: the match goes on, one more gg a long time after at most, never a third
##  - the player's gg while one is pending: "gg wp", the computer resigns, the match ends as a win
##    for the player, the RESULT line says "AI resigned after gg"
##  - a gg from the player with none pending: no reaction
##  - a comeback position (income, production, no army) and the early game never resign
##  - the player's surrender goes to the log with who was ahead
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _match() -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI = g.ais[0]
	ai.process_mode = Node.PROCESS_MODE_DISABLED      # (the test drives its gg rule by hand)
	ai.gg_view()                                       # (notes its peaks: halls, workers)
	for i in 5:
		await physics_frame
	return [main, g, ai]


func _line_count(g: Game, needle: String) -> int:
	var n := 0
	for l in g.mlog.lines:
		if String(l).contains(needle):
			n += 1
	return n


## Run the clock on by `secs` in steps, the computer's gg rule looked at each step.
func _advance(g: Game, ai: AI, secs: float, step := 3.0) -> void:
	var t := 0.0
	while t < secs and not g.over:
		g.clock += step
		t += step
		ai._gg_tick()
		await physics_frame


func _hall_of(g: Game, t: int) -> Building:
	return g.halls_of(t)[0]


## The player's soldiers standing at the computer's hall, where it can see them.
func _enemy_army(g: Game, n: int) -> void:
	var c := _hall_of(g, 1).center()
	for i in n:
		var u := g._add_unit("musketeer", 0, c + Vector2(80 + (i % 4) * 24, (i / 4) * 24))
		u.process_mode = Node.PROCESS_MODE_DISABLED      # (they stand and are seen: they do not fight)


func _kill_army_and_workers(g: Game, t: int, workers := true) -> void:
	for u in g.units.duplicate():
		if u.team == t and not u.dead and (workers or not u.is_worker()):
			u.die()


func _kill_production(g: Game, t: int) -> void:
	for b in g.buildings.duplicate():
		if b.team != t or b.dead:
			continue
		for k in Defs.BUILDINGS[b.kind].get("trains", []):
			if not Defs.is_worker(String(k)):
				b.take_damage(99999, null)
				break


func _run() -> void:
	# ---- parsing
	for s in ["gg", "GG", "gg!", "Gg wp", "ggwp", "good game", "Good game, well played", "gg wp ai", "ggs"]:
		check(Chat.is_gg(s), "'%s' is a gg" % s)
	for s in ["no gg", "egg", "not yet", "go go", "good luck", "gl hf", "i will not gg", "ggez i win lol this is a long one"]:
		check(not Chat.is_gg(s), "'%s' is not a gg" % s)
	check(Chat.clean("  hello   there \n") == "hello there", "chat text is tidied")
	check(Chat.clean("x".repeat(200)).length() == Chat.MAX_LEN, "chat text is capped")

	# ---- 1. a hopeless computer says gg, no reply: it plays on; a reply ends the match
	var r: Array = await _match()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	g.clock = 400.0
	_kill_army_and_workers(g, 1)
	_kill_production(g, 1)
	g.players[1]["gold"] = 0
	_enemy_army(g, 12)
	for i in 8:
		await physics_frame
	var v := ai.gg_view()
	print("view: ", v)
	check(AIResign.verdict(v) == "broken", "staged position is hopeless (broken)")
	await _advance(g, ai, 30.0)
	check(ai.gg_said == 0, "it waits: nothing said after 30 s of a hopeless position")
	await _advance(g, ai, 45.0)
	check(ai.gg_said == 1, "after a minute of it the computer says gg")
	check(_line_count(g, "P2 Crown says: gg") == 1, "match log: '[mm:ss] P2 Crown says: gg'")
	check(g.chat.lines.size() == 1 and g.chat.lines[0]["text"] == "gg", "the chat log holds its gg")
	check(ai.gg_pending(), "its gg is pending")
	# no reply for 70 s: it keeps playing, no spam
	await _advance(g, ai, 70.0)
	check(not g.over and not ai.resigned, "no reply: the match goes on")
	check(ai.gg_said == 1 and not ai.gg_pending(), "no second gg yet, the first no longer pending")
	# a player's gg now, with none pending: no reaction
	var lines_before := g.chat.lines.size()
	g.chat._last_player_ms = -10000
	g.chat.player_say("gg")
	await _advance(g, ai, 10.0)
	check(not ai.resigned and not g.over and g.chat.lines.size() == lines_before + 1, "a gg with none pending: no reaction at all")
	check(_line_count(g, "YOU says: gg") == 1, "match log: 'YOU says: gg'")
	# a long time later, still hopeless: one more gg, never a third
	await _advance(g, ai, AIResign.REPEAT_AFTER)
	check(ai.gg_said == 2, "after a long time it says gg once more")
	await _advance(g, ai, 500.0, 5.0)
	check(ai.gg_said == 2 and _line_count(g, "P2 Crown says: gg") == 2, "never more than two gg")
	# the player answers the second one
	await _advance(g, ai, 1.0)
	g.clock = ai.gg_last + 5.0
	check(ai.gg_pending(), "the second gg is pending")
	g.chat._last_player_ms = -10000
	g.chat.player_say("GG wp!")
	check(ai.resigned, "the player's gg wp: the computer resigns")
	check(_line_count(g, "P2 Crown says: gg wp") == 1, "it answers 'gg wp' in the log")
	for i in 90:
		await physics_frame
		if g.over:
			break
	check(g.over and g.winner == 0, "the match is over and the player won (winner %d)" % g.winner)
	await physics_frame
	var res := ""
	for l in g.mlog.lines:
		if String(l).begins_with("RESULT"):
			res = String(l)
	print(res)
	check(res.contains("winner YOU Crown") and res.contains("AI resigned after gg"), "RESULT line: AI resigned after gg")
	check(_line_count(g, "resigned after gg (army") == 1, "the log says what each side had when it resigned")
	main.queue_free()
	await process_frame

	# ---- 2. a comeback is possible: income, production, no army -> never resigns
	r = await _match()
	main = r[0]
	g = r[1]
	ai = r[2]
	g.clock = 400.0
	_kill_army_and_workers(g, 1, false)
	var spot := ai._find_spot("barracks")
	g._add_building("barracks", 1, spot, true)
	g.players[1]["gold"] = 100
	_enemy_army(g, 14)
	for i in 8:
		await physics_frame
	v = ai.gg_view()
	print("view: ", v)
	check(int(v["production"]) >= 1 and int(v["workers"]) > 0 and float(v["enemy_army"]) >= AIResign.MIN_ENEMY_ARMY, "staged: workers, a barracks, no army, a big enemy army seen")
	check(AIResign.verdict(v) == "", "comeback position: NOT hopeless")
	await _advance(g, ai, 400.0, 5.0)
	check(ai.gg_said == 0 and not ai.resigned, "comeback position: never says gg in 400 s")
	check(g.chat.lines.is_empty(), "nothing in the chat")
	main.queue_free()
	await process_frame

	# ---- 3. early game: broken before 5:00 never resigns; no hall and no workers may
	r = await _match()
	main = r[0]
	g = r[1]
	ai = r[2]
	g.clock = 200.0
	_kill_army_and_workers(g, 1)
	_kill_production(g, 1)
	g.players[1]["gold"] = 0
	_enemy_army(g, 12)
	for i in 8:
		await physics_frame
	check(AIResign.verdict(ai.gg_view()) == "", "before 5:00: not hopeless")
	await _advance(g, ai, 45.0)
	check(ai.gg_said == 0, "before 5:00 it does not say gg with a hall standing")
	# its hall falls too (a house is left, so it is still in the game): no hall, no workers
	_hall_of(g, 1).take_damage(99999, null)
	for i in 4:
		await physics_frame
	await _advance(g, ai, 30.0)
	print("view: ", ai.gg_view())
	check(ai.gg_said == 1 or g.eliminated[1], "no hall and no workers before 5:00: it says gg (or is already out)")
	main.queue_free()
	await process_frame

	# ---- 4. the player's surrender goes in the log with who was ahead
	r = await _match()
	main = r[0]
	g = r[1]
	ai = r[2]
	g.clock = 400.0
	_kill_army_and_workers(g, 0)
	g.player_surrender()
	var sl := ""
	for l in g.mlog.lines:
		if String(l).contains("surrendered while"):
			sl = String(l)
	print(sl)
	check(sl.contains("YOU Crown surrendered while behind (army 0 vs ") and sl.contains("workers 0 vs ") and sl.contains("buildings "), "log: 'surrendered while behind (army ..., workers ..., buildings ...)'")
	for i in 90:
		await physics_frame
		if g.over:
			break
	check(g.over and g.winner == 1, "surrender: the match is over, the computer won")
	await physics_frame
	for l in g.mlog.lines:
		if String(l).begins_with("RESULT"):
			res = String(l)
	print(res)
	check(res.contains("ended by surrender (player was behind)"), "RESULT: ended by surrender (player was behind)")
	main.queue_free()
	await process_frame

	# ---- 5. the typing box: Enter opens, keys go to the box (no hotkeys), Enter sends, Esc cancels
	Settings.device = "pc"
	r = await _match()
	main = r[0]
	g = r[1]
	ai = r[2]
	var mus: Array = []
	for i in 3:
		mus.append(g._add_unit("musketeer", 0, _hall_of(g, 0).center() + Vector2(100 + i * 20, 90)))
	g.set_selection(mus)
	await process_frame
	await _key(KEY_A, 97)
	check(g.controls.mode == "attack", "control: with no box open, A starts an attack-move")
	g.controls.cancel_mode()
	await _key(KEY_ENTER, 0)
	check(g.hud.chat_typing, "Enter opens the chat box")
	await _key(KEY_A, 97)
	check(g.controls.mode == "", "while typing, A is a letter, not the ATTACK hotkey")
	await _key(KEY_G, 103)
	await _key(KEY_G, 103)
	check(g.hud.chat_buf == "agg", "typed text '%s'" % g.hud.chat_buf)
	await _key(KEY_BACKSPACE, 0)
	await _key(KEY_BACKSPACE, 0)
	await _key(KEY_BACKSPACE, 0)
	await _key(KEY_G, 103)
	await _key(KEY_G, 103)
	await _key(KEY_ENTER, 0)
	check(not g.hud.chat_typing and g.chat.lines.size() == 1 and g.chat.lines[0]["text"] == "gg" and g.chat.lines[0]["team"] == 0, "Enter sends 'gg' as YOU and closes the box")
	check(_line_count(g, "YOU says: gg") == 1, "the sent line is in the match log")
	await _key(KEY_ENTER, 0)
	await _key(KEY_X, 120)
	await _key(KEY_ESCAPE, 0)
	check(not g.hud.chat_typing and g.chat.lines.size() == 1, "Esc cancels: nothing sent")
	check(not g.over and g.hud.paused == false, "Esc in the box does not pause or cancel anything else")
	# fading: shown for SHOW_SECS then gone, Enter shows the history again
	var born := int(g.chat.lines[0]["born"])
	check(g.chat.visible(born + 2000).size() == 1, "a line is shown for a while")
	check(g.chat.visible(born + int((Chat.SHOW_SECS + Chat.FADE_SECS) * 1000.0) + 500).is_empty(), "then it has faded")
	g.chat.reveal(5.0)
	check(g.chat.visible(born + 60000).size() == 1 or g.chat.visible(Time.get_ticks_msec()).size() == 1, "revealing shows the history again")
	main.queue_free()
	await process_frame

	# ---- 6. phone: the speech-bubble button opens QUICK CHAT, one tap sends and closes
	Settings.device = "mobile"
	r = await _match()
	main = r[0]
	g = r[1]
	ai = r[2]
	g.hud._fit()
	await process_frame
	var btn: Rect2 = g.hud.chat_btn_rect()
	check(btn.size.x > 0 and not g.hud.top_rect().intersects(btn) == false, "the chat button sits in the top bar")
	check(not g.hud.menu_rect().intersects(btn), "the chat button does not overlap the menu button")
	g.hud._press(btn.get_center())
	check(g.hud.quick_open, "tapping the bubble opens the quick-chat panel")
	check(g.hud._hud_has(Vector2(300, 300)), "while it is open, taps are the panel's (not the map's)")
	var qr: Array = g.hud.quick_rects()
	var ok_inside := true
	for q in qr:
		ok_inside = ok_inside and Rect2(Vector2.ZERO, g.hud._vs()).encloses(q) and (q as Rect2).size.y >= 50.0
	check(ok_inside, "six big buttons, on screen")
	g.hud._press((qr[0] as Rect2).get_center())
	check(not g.hud.quick_open and g.chat.lines.size() == 1 and g.chat.lines[0]["text"] == "gg", "one tap on GG sends 'gg' and closes the panel")
	g.hud._press(btn.get_center())
	g.hud._press(Vector2(g.hud._vs().x - 10, g.hud._vs().y - 10))
	check(not g.hud.quick_open, "a tap outside closes the panel")
	Settings.device = "pc"
	main.queue_free()
	await process_frame

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _key(code: int, uni: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = uni
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
