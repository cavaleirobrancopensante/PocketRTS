extends SceneTree
## The unit panel and command card frames stay up with nothing selected (scripts/ui/panel_art.gd):
##   godot --headless --fixed-fps 30 --script res://tools/test_hud_frames.gd 2>&1 | grep -E "FAIL|PASS|DONE"
##  - for each faction: with an empty selection the panel and the card frame are drawn, in the faction
##  - a click / right click / drag starting on the empty panels doesn't go to the map: nothing is selected,
##    a selected unit stays selected and gets no order
##  - with a window (xvfb-run -a godot --rendering-driver opengl3 --script ...): screenshots in
##    docs/shots/hud_frames/<faction>_empty.png; `-- art=DIR` also uses DIR/<faction>_panel.png and _card.png
##    (tools/import_panel_art.py --out DIR) and saves <faction>_art.png
var fails := 0
var art_dir := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("art="):
			art_dir = a.substr(4)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mouse(hud, p: Vector2, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = p * hud.ui_scale
	e.global_position = e.position
	root.push_input(e, true)


func _move(hud, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p * hud.ui_scale
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


func _redraw(hud) -> void:
	PanelArt.drawn.clear()
	hud._sig.clear()
	hud._check(["selection", "command card"])
	await _frames(3)


func _run() -> void:
	Settings.load_all()       # (main loads the shared settings file at start: read it first, or its device wins over ours)
	Settings.device = "pc"
	var shots := DisplayServer.get_name() != "headless"
	for fac in (["crown"] if OS.get_cmdline_user_args().has("quick") else ["crown", "clockwork", "brood"]):
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await _frames(2)
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
		await _frames(2)
		var g: Game = main.game
		var hud = g.hud
		hud.countdown = 0.0
		paused = false
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		g.set_selection([])
		await _frames(4)
		await _redraw(hud)
		check(PanelArt.drawn.get("panel", "?") == fac, "%s: the empty unit panel is drawn in the faction (%s)" % [fac, PanelArt.drawn.get("panel", "none")])
		check(PanelArt.drawn.get("card", "?") == fac, "%s: the empty command card frame is drawn (%s)" % [fac, PanelArt.drawn.get("card", "none")])
		var pr: Rect2 = hud.panel_rect()
		var cr: Rect2 = hud.card_rect()
		check(hud._hud_has(pr.get_center()) and hud._hud_has(cr.get_center()), "%s: the HUD owns both empty areas" % fac)
		# clicks on the empty panels: nothing selected
		for p in [pr.get_center(), cr.get_center(), pr.position + Vector2(20, pr.size.y - 10)]:
			_mouse(hud, p, MOUSE_BUTTON_LEFT, true)
			await _frames(2)
			_mouse(hud, p, MOUSE_BUTTON_LEFT, false)
			await _frames(2)
		check(g.selection.is_empty(), "%s: clicks on the empty panels select nothing" % fac)
		# a unit of ours, selected: clicks, a right click and a drag from the panel keep it and give no order
		# (a soldier standing still that thinks nothing by itself: an order would show at once)
		var kind: String = {"crown": "musketeer", "clockwork": "clock_soldier", "brood": "raptor"}[fac]
		var u: Unit = g._add_unit(kind, g.human, g.halls_of(g.human)[0].center() + Vector2(0, 160)) if not g.halls_of(g.human).is_empty() \
			else g._add_unit(kind, g.human, g.units.filter(func(x: Unit) -> bool: return x.team == g.human)[0].position + Vector2(60, 60))
		u.process_mode = Node.PROCESS_MODE_DISABLED
		if u:
			g.set_selection([u])
			await _frames(4)
			var pos0 := u.position
			var ord0: String = u.order
			var blank := Vector2(pr.end.x - pr.size.x * 0.3, pr.get_center().y)
			_mouse(hud, blank, MOUSE_BUTTON_LEFT, true)
			await _frames(2)
			_mouse(hud, blank, MOUSE_BUTTON_LEFT, false)
			await _frames(2)
			_mouse(hud, blank, MOUSE_BUTTON_RIGHT, true)
			await _frames(2)
			_mouse(hud, blank, MOUSE_BUTTON_RIGHT, false)
			await _frames(2)
			# a drag from the panel up onto the map: no box select
			_mouse(hud, blank, MOUSE_BUTTON_LEFT, true)
			await _frames(2)
			_move(hud, blank - Vector2(200, 300))
			await _frames(2)
			_mouse(hud, blank - Vector2(200, 300), MOUSE_BUTTON_LEFT, false)
			await _frames(4)
			check(g.selection.size() == 1 and g.selection[0] == u, "%s: clicks and a drag on the panel keep the selection" % fac)
			check(u.order == ord0 and u.position.distance_to(pos0) < 4.0, "%s: no order from a right click on the panel (%s -> %s)" % [fac, ord0, u.order])
		else:
			check(false, "%s: a unit to select" % fac)
		g.set_selection([])
		await _frames(4)
		if shots:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/shots/hud_frames"))
			await _redraw(hud)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/shots/hud_frames/%s_empty.png" % fac))
			# with a selection: one unit (its card and lines), then the hall (its train buttons)
			if u:
				g.set_selection([u])
				await _frames(6)
				await _redraw(hud)
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/shots/hud_frames/%s_unit.png" % fac))
			var many: Array = g.units.filter(func(x: Unit) -> bool: return x.team == g.human and not x.dead)
			if many.size() > 1:
				g.set_selection(many)
				await _frames(6)
				await _redraw(hud)
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/shots/hud_frames/%s_group.png" % fac))
			g.set_selection([])
			await _frames(4)
			if art_dir != "":
				for w in ["panel", "card"]:
					var img := Image.load_from_file(art_dir.path_join("%s_%s.png" % [fac, w]))
					if img:
						PanelArt.set_art(fac, w, ImageTexture.create_from_image(img))
				await _redraw(hud)
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/shots/hud_frames/%s_art.png" % fac))
				for w in ["panel", "card"]:
					PanelArt._boxes.erase(fac + "_" + w)
		main.queue_free()
		await _frames(3)
	print("DONE  %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
