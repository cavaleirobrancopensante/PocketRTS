extends SceneTree
## Pictures of the STUN MARK (scripts/stun_mark.gd): a Field Cannon caught by a Mist Toad's tongue, a Musketeer knocked
## down by a Cavalry charge, a Balloon pulled through the air to a Toad, the Tyrannosaur staggered (not pulled), and the
## frames of a short GIF of the Tyrannosaur's stagger.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_stun_mark.gd -- <outdir>
## (<outdir>/gif/ gets the GIF's frames; tools/stun_mark_gif.py makes docs/shots/stun_mark/stun_stars.gif from them)
var g: Game
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif")
	_run.call_deferred()


## The picture: w x h around `at` (a world point; the middle of the screen if none).
func _snap(name: String, w := 640, h := 400, at := Vector2.INF) -> void:
	await process_frame
	await process_frame
	var full: Image = root.get_viewport().get_texture().get_image()
	var vs := Vector2i(full.get_width(), full.get_height())
	var c := Vector2(vs) * 0.5
	if at != Vector2.INF:
		# (the canvas is in the project's base size, the picture in the window's: scale between them)
		c = g.get_viewport().get_canvas_transform() * at * (Vector2(vs) / root.get_viewport().get_visible_rect().size)
	var x := clampi(int(c.x) - w / 2, 0, vs.x - w)
	var y := clampi(int(c.y) - h / 2, 0, vs.y - h)
	var img: Image = full.get_region(Rect2i(x, y, w, h))
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)


## The game stopped where it is (the marks too) for a picture, around `focus` (a little over its feet).
func _frozen(name: String, focus: Unit = null, w := 640, h := 400) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	var up: float = g.stun_layer._ys.get(focus, focus.bar_top()) if focus else 0.0      # (the ring's height, StunMark._over)
	await _snap(name, w, h, focus.position + Vector2(0, up * 0.55) if focus else Vector2.INF)
	g.process_mode = Node.PROCESS_MODE_INHERIT


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 30.0


func _dummy(kind: String, t: int, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, t, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.auto_work = false
	u.hold_fire = true
	u.cmd_hold()
	return u


func _away(us: Array) -> void:
	for u in us:
		if is_instance_valid(u):
			u.cmd_stop()
			u.position = Vector2(-3000, -3000)
			u.visible = false


## A sandbox game (no fog, no HUD, the starting workers out of the way); returns open ground by side 0's hall.
func _game(facs: Array) -> Vector2:
	if g != null:
		g.queue_free()
		await process_frame
	g = Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = facs
	g.sides = [0, 1]
	root.add_child(g)
	for i in 10:
		await process_frame
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var h: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0):
			h = b
	var at := h.center() + Vector2(0, h.rect().size.y * 0.5 + 110.0)
	for u in g.units.duplicate():
		u.auto_work = false
		u.cmd_stop()
		u.position = at + Vector2(900, 900)
	g.camera.zoom = Vector2(2.4, 2.4)
	return at


func _run() -> void:
	var at: Vector2 = await _game(["crown", "brood"])
	# ---- 1. a Field Cannon caught by a Mist Toad's tongue (4 supply: pulled, stunned 0.9 s; TONGUE "heavy" is 5)
	var gun := _dummy("cannon", 0, at)
	var toad := _dummy("mist_toad", 1, at + Vector2(110, 40))
	toad.charge = 200.0
	toad.cmd_tongue(gun)
	g.camera.position = at + Vector2(55, -10)
	await _wait(func() -> bool: return gun.stun_left() > 0.0, 8.0)
	await create_timer(0.35).timeout
	await _frozen("1_cannon_stunned_by_a_tongue", gun)
	_away([gun, toad])
	# ---- 2. a Musketeer knocked down by a Cavalry charge
	g.players[0]["tech"]["charge"] = true
	var foe := _dummy("musketeer", 1, at + Vector2(0, 0))
	var mate := _dummy("musketeer", 1, at + Vector2(-26, 8))
	var cav: Unit = g._add_unit("cuirassier", 0, at + Vector2(130, 0))
	cav.max_hp = 99999.0
	cav.hp = 99999.0
	cav.cmd_attack(foe)
	g.camera.position = at + Vector2(10, -10)
	while foe.stun_left() <= 0.0:
		cav.run_t = 10.0
		cav.rb_last = -99.0
		await process_frame
	cav.run_t = 0.0
	await create_timer(0.12).timeout
	await _frozen("2_musketeer_knocked_by_a_charge", foe)
	_away([cav, foe, mate])
	# ---- 3. a Balloon pulled through the air to just over a Toad (flyers can be tongued since 0.15.23)
	g.camera.zoom = Vector2(1.6, 1.6)
	var bal := _dummy("balloon", 0, at + Vector2(-20, -10))
	var toad3 := _dummy("mist_toad", 1, at + Vector2(130, 30))
	toad3.charge = 200.0
	toad3.cmd_tongue(bal)
	g.camera.position = at + Vector2(60, -30)
	await _wait(func() -> bool: return bal.stun_left() > 0.0, 8.0)
	await create_timer(0.25).timeout
	await _frozen("3_balloon_pulled_through_the_air", bal)
	await create_timer(0.45).timeout
	await _frozen("4_balloon_over_the_toad", toad3)
	_away([bal, toad3])
	# ---- 5. the Tyrannosaur (a father) staggered, not pulled, and the GIF
	at = await _game(["crown", "brood"])
	at += Vector2(0, 140)            # (clear of the Town Hall)
	var rex := _dummy("tyrannosaur", 1, at)
	rex.facing = Vector2(0.3, 1.0).normalized()      # (its head toward us)
	var toad2 := _dummy("mist_toad", 0, at + Vector2(120, 110))
	var crowd: Array = []
	for i in 4:
		crowd.append(_dummy("raptor", 0, at + Vector2(-70 + 40 * i, 60 + (i % 2) * 14)))
	toad2.charge = 200.0
	toad2.cmd_tongue(rex)
	g.camera.position = rex.position + Vector2(0, rex.bar_top() * 0.6)
	g.camera.zoom = Vector2(2.0, 2.0)
	g.camera.reset_smoothing()
	await _wait(func() -> bool: return toad2.tongue_stage == "windup" and toad2.tongue_t < 0.35, 8.0)
	var n := 0
	var vs: Vector2i = root.get_viewport().get_visible_rect().size
	for k in 48:
		await process_frame
		var full: Image = root.get_viewport().get_texture().get_image()
		vs = Vector2i(full.get_width(), full.get_height())
		var c := g.get_viewport().get_canvas_transform() * (rex.position + Vector2(0, float(g.stun_layer._ys.get(rex, rex.bar_top())) * 0.55)) * (Vector2(vs) / root.get_viewport().get_visible_rect().size)
		var img: Image = full.get_region(Rect2i(clampi(int(c.x) - 320, 0, vs.x - 640), clampi(int(c.y) - 200, 0, vs.y - 400), 640, 400))
		img.save_png("%s/gif/f%03d.png" % [out, n])
		n += 1
		if k == 20:
			await _frozen("5_tyrannosaur_staggered_not_pulled", rex)
	print("gif frames: %d" % n)
	quit(0)
