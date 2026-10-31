extends SceneTree
## Pictures for the owner's playtest notes of 2026-10-31 (docs/bars_ghost_sil.md), in the CLOCKWORK LAB:
##   1. bars.png: a small battle (Clock Soldiers half wound, Crown Musketeers), hurt and selected units, close up;
##   2. ghost.png: placing a Regulator between the gear field and an OFF (unlinked) Regulator;
##   3. press.png: Winders working at a Cog Press (in front of it); behind.png: a Clock Soldier behind the Clocktower.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_bars_ghost_sil.gd -- <outdir> [prefix]
## Prints the silhouettes found (OccludedLook.hidden_units) near the press and behind the tower.
var main: Node
var g
var out := ""
var pre := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		pre = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String, wait := 0.6) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out, pre, name])


func _look(p: Vector2, z: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(z, z)
	await process_frame
	g.camera.reset_smoothing()
	g.update_view_rect()


func _run() -> void:
	await create_timer(2.0).timeout
	g.reveal = true
	for cl in root.find_children("*", "CanvasLayer", true, false):
		cl.visible = false
	var tower: Building = null
	var press: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			tower = b
		if b.team == g.human and b.kind == "cog_press" and press == null:
			press = b
	# 3. Winders at the press, and a soldier behind the Clocktower
	await _look(press.center() + Vector2(0, -10), 3.0)
	await create_timer(1.5).timeout
	g.occluded_layer.scan()
	var at_press := 0
	for u in g.occluded_layer.hidden_units:
		if u.position.distance_to(press.center()) < 120.0:
			at_press += 1
	print("silhouettes at the press: %d" % at_press)
	await _snap("press")
	var sr: Rect2 = tower.sprite_rect()
	var cs: Unit = g._add_unit("clock_soldier", g.human, Vector2(sr.get_center().x + 6.0, tower.global_position.y - 40.0))
	cs.order = "hold"
	await _look(Vector2(sr.get_center().x, tower.global_position.y - 40.0), 3.0)
	await create_timer(0.3).timeout
	g.occluded_layer.scan()
	print("soldier behind the tower a silhouette: %s" % str(g.occluded_layer.hidden_units.has(cs)))
	await _snap("behind")
	g.consume_unit(cs)
	# 2. the ghost: a Regulator X meshing the field, an OFF Regulator Y beyond it; X removed, the ghost put at X's cell
	var gn = g.gear_net
	# (an OFF building in open ground: a new Clocktower out in the open, a Regulator two ring-widths from it (off), the
	# ghost Regulator in the gap between the two rings)
	var gk := "regulator"
	var sz: Vector2i = Defs.BUILDINGS[gk]["size"]
	var rr: float = GearNet.ring_r(gk, sz, g.gear_big_for(g.human, gk))
	var open := Vector2i(-1, -1)
	var mc := Vector2i(g.W / 2, g.H / 2)
	for rad in range(0, 40):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if open.x >= 0 or maxi(absi(dx), absi(dy)) != rad:
					continue
				var c := mc + Vector2i(dx, dy)
				var ok := true
				for yy in range(-5, 6):
					for xx in range(-13, 8):
						var cc := c + Vector2i(xx, yy)
						if not g.in_map(cc) or not g.is_free(cc) or GearNet.level_at(g, Vector2(cc) * Defs.TILE + Vector2(16, 16)) != GearNet.level_at(g, Vector2(c) * Defs.TILE):
							ok = false
							break
					if not ok:
						break
				if ok:
					open = c
	print("open ground at %s" % str(open))
	var tower2: Building = g._add_building("clocktower", g.human, open - Vector2i(10, 2), true)
	var p: Building = g._add_building("regulator", g.human, open, true)
	gn.solve()
	tower = tower2
	var tc: Vector2 = GearNet.b_c(tower)
	var dir: Vector2 = (GearNet.b_c(p) - tc).normalized()
	var gxc: Vector2 = tc + dir * (GearNet.b_r(tower) + rr)
	var gyc: Vector2 = tc + dir * (GearNet.b_r(tower) + 2.0 * rr + GearNet.b_r(p))
	var xc: Vector2i = g.cell_of(Vector2(gxc.x, gxc.y * GearNet.FY)) - sz / 2
	var yc: Vector2i = g.cell_of(Vector2(gyc.x, gyc.y * GearNet.FY)) - p.size / 2
	g._mark(p.cell, p.size, 0)
	g.buildings.erase(p)
	gn.solve()
	var x0 := xc
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-1, 0)]:
		if String(gn.candidate(g.human, gk, x0 + d)["state"]) == "ok":
			xc = x0 + d
			break
	var gx: Vector2 = GearNet.gpos(Vector2(xc) * Defs.TILE + Vector2(sz) * Defs.TILE * 0.5)
	var y0 := yc
	var bestg := INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c2 := y0 + Vector2i(dx, dy)
			var gy: Vector2 = GearNet.gpos(Vector2(c2) * Defs.TILE + Vector2(sz) * Defs.TILE * 0.5)
			var gap: float = gx.distance_to(gy) - 2.0 * rr
			var gapt: float = GearNet.b_c(tower).distance_to(gy) - GearNet.b_r(tower) - rr
			if gap >= 0.0 and gap < bestg and gapt > float(Defs.GEAR["slack"]) * Defs.TILE + 4.0 and absi(c2.y - xc.y) <= 1:
				bestg = gap
				yc = c2
	g.buildings.append(p)
	p.cell = yc
	g.buildings.erase(p)
	p.queue_free()
	var y: Building = g._add_building("regulator", g.human, yc, true)
	await process_frame
	gn.solve()
	print("ghost (%s) at %s, the off %s at %s (linked: %s)" % [gk, str(xc), y.kind, str(yc), str(gn.linked.has(y))])
	g.controls.begin_place(gk)
	g.controls.ghost_cell = xc
	var mid: Vector2 = (Vector2(xc) + Vector2(yc)) * 0.5 * Defs.TILE + Vector2(Defs.TILE, 0)
	await _look(mid, 1.3)
	await _snap("ghost")
	g.controls.cancel_mode()
	# 1. the bars: a small battle
	var c0: Vector2 = tower.center() + Vector2(0, 260)
	var mine: Array = []
	for i in 8:
		var u: Unit = g._add_unit("clock_soldier", g.human, c0 + Vector2((i % 4) * 26.0 - 40.0, (i / 4) * 26.0))
		u.hp = u.max_hp * [1.0, 0.85, 0.6, 0.35, 1.0, 0.75, 0.5, 0.2][i]
		u.wind = [1.0, 0.7, 0.45, 0.9, 0.3, 1.0, 0.6, 0.15][i]
		u.order = "hold"
		mine.append(u)
	for i in 8:
		var e: Unit = g._add_unit("musketeer", 1, c0 + Vector2((i % 4) * 26.0 - 40.0, 90.0 + (i / 4) * 26.0))
		e.hp = e.max_hp * [1.0, 0.9, 0.55, 0.3, 1.0, 0.8, 0.45, 1.0][i]
		e.order = "hold"
	g.set_selection(mine.slice(0, 4))
	await _look(c0 + Vector2(0, 55), 2.6)
	await _snap("bars", 1.0)
	quit(0)
