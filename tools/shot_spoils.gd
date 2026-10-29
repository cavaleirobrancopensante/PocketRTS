extends SceneTree
## The Brood's second resource named SPOILS (was essence, 2026-10-29): the top bar with the Spoils
## tooltip, the Brood Pen card, and a "Not enough spoils." refusal, for the old
## Brood, plus the new Brood's top bar:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_spoils.gd -- docs/shots/spoils [en|pt|es]
var main
var g: Game
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "docs/shots/spoils"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	var lang: String = a[1] if a.size() > 1 else "en"
	Settings.language = lang
	Loc.set_lang(lang)
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _start(fac: String) -> void:
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, Loc.lang, name])
	print("saved ", name)


## Hold a tooltip on screen for the picture.
func _hold_tip(tip: Dictionary, at: Vector2, name: String) -> void:
	for i in 8:
		g.hud._tip = tip
		g.hud._tip_at = at
		g.hud._tip_ms = Time.get_ticks_msec()
		g.hud.queue_redraw()
		await process_frame
	_save(name)
	g.hud._tip = {}


func _run() -> void:
	await process_frame
	await _start("brood")
	g.players[0]["res2"] = 37.0
	var hall: Building = g.halls_of(0)[0]
	g.camera.position = hall.center() + Vector2(0, 60)
	var pen: Building = g._add_building("brood_pen", 0, g.find_spot(0, "brood_pen", hall, 3, 8), true)
	g.selection = [pen]
	for i in 20:
		await process_frame
	# the top bar's Spoils pill and its tooltip
	var r: Rect2 = Rect2()
	for pr in g.hud._pill_rects:
		if int(pr[1]) == 1:
			r = pr[0]
	await _hold_tip(g.hud._res_tip(1), r.get_center(), "topbar_tip")
	# the Pen's SACRIFICE tooltip on its card
	var item = null
	for b in g.hud._card_buttons:
		if String(b["item"][1]).to_upper().contains("SACRIFICE") or String(b["item"][1]).to_upper().contains(Loc.t("SACRIFICE").to_upper()):
			item = b
	if item:
		await _hold_tip(g.hud._card_tip(item["item"]), (item["rect"] as Rect2).get_center(), "pen_card_tip")
	else:
		print("no SACRIFICE button on the Pen card: ", g.hud._card_buttons.map(func(b): return String(b["item"][1])))
	g.players[0]["res2"] = 0.0
	g.hud.toast("Not enough spoils.")
	for i in 20:
		await process_frame
	_save("refusal")
	# the new Brood's top bar
	main.game.queue_free()
	main.game = null
	await process_frame
	await _start("brood_new")
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["res2"] = 12.0
	g.camera.position = q.position + Vector2(0, 60)
	g.selection = [q]
	for i in 20:
		await process_frame
	for pr in g.hud._pill_rects:
		if int(pr[1]) == 1:
			r = pr[0]
	await _hold_tip(g.hud._res_tip(1), r.get_center(), "new_brood_topbar_tip")
	quit()
