extends SceneTree
## Pictures of the AREA MARKS (docs/aoe_show.md) in the CLOCKWORK LAB: the Pendulum's wedge and smear mowing Raptors
## (and a GIF of a few blows), an enemy Mortar shell's warning and its landing ring, a Spore Mother's spit, and a Cog
## Press's "+N".
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_aoe_show.gd -- <outdir>
## (<outdir>/gif/ gets the GIF's frames; tools/aoe_gif.py makes the GIF from them)
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif")
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


func _snap(name: String, crop := Rect2i()) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if crop.size.x > 0:
		img = img.get_region(crop)
	img.save_png("%s/%s.png" % [out, name])


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 30.0


func _frozen(name: String, crop := Rect2i()) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.selection.clear()
	for u in g.units:
		u.selected = false
	await process_frame
	await process_frame
	await _snap(name, crop)
	g.process_mode = Node.PROCESS_MODE_INHERIT


func _dummy(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.auto_work = false
	u.cmd_hold()
	u.hold_fire = true
	u.d = u.d.duplicate()
	u.d["damage"] = 0
	u.d["range"] = 1
	return u


func _gone(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	g.selection.erase(u)
	if not u.dead:
		u.die()
	u.visible = false


func _open_ground(hall: Building) -> Vector2:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 34, hall.cell.y + 35):
		for x in range(hall.cell.x - 34, hall.cell.x + 35):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 12 or c.y < 12 or c.x > Game.W - 12 or c.y > Game.H - 12:
				continue
			var d := Vector2(c - hall.cell).length()
			if d >= bd or d < 14.0:
				continue
			var ok := true
			for yy in range(-6, 7):
				for xx in range(-8, 9):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 260)


## The middle of the screen, `w` x `h` (what the camera looks at).
func _mid(w: int, h: int) -> Rect2i:
	var vs: Vector2i = root.get_viewport().get_visible_rect().size
	return Rect2i((vs.x - w) / 2, (vs.y - h) / 2, w, h)


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "clocktower":
			hall = b
	_ui(false)
	g.reveal = true
	var open := _open_ground(hall)
	var pends: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == Defs.PENDULUM and not u.dead)
	for u in g.units.filter(func(u: Unit) -> bool: return u.team == g.human and not u.dead and u.kind != "winder"):
		if not (u in pends):
			u.position = open + Vector2(700, 700)
	for i in range(1, pends.size()):
		pends[i].position = open + Vector2(-500, 400)
		pends[i].cmd_stop()
	var pd: Unit = pends[0]
	pd.position = open
	pd.cmd_stop()
	# ---- the Pendulum among Raptors: a GIF of its blows, then the wedge and smear frozen just after a blow
	var crowd: Array = []
	for a in [-50.0, -15.0, 20.0, 55.0]:
		crowd.append(_dummy("raptor", pd.position + Vector2.from_angle(deg_to_rad(a)) * 36.0))
	g.camera.position = pd.position + Vector2(10, -20)
	g.camera.zoom = Vector2(2.5, 2.5)
	await create_timer(0.3).timeout
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(crowd[1])
	g.selection.clear()
	for u in g.units:
		u.selected = false
	await _wait(func() -> bool: return pd.swings >= 1, 10.0)
	await _wait(func() -> bool: return g.ground_marks.marks.is_empty(), 3.0)
	var n := 0
	var s0: int = pd.swings
	while pd.swings < s0 + 3 and n < 200:
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image().get_region(_mid(560, 340))
		img.save_png("%s/gif/f%03d.png" % [out, n])
		n += 1
	print("gif frames: %d" % n)
	var s1: int = pd.swings
	await _wait(func() -> bool: return pd.swings > s1, 4.0)
	await create_timer(0.08).timeout
	await _frozen("pendulum_wedge", _mid(560, 340))
	pd.cmd_stop()
	for u in crowd:
		_gone(u)
	await create_timer(0.6).timeout
	# ---- an enemy Mortar shell: its warning in the air, then the ring where it lands
	var spot := open + Vector2(-60, 120)
	for i in 5:
		var mm: Unit = g._add_unit("musketeer", g.human, spot + Vector2(-30 + i * 15, -6 + (i % 2) * 12))
		mm.cmd_hold()
	var mortar: Unit = _dummy("mortar", spot + Vector2(-420, -40))
	g.camera.position = spot + Vector2(0, -10)
	g.camera.zoom = Vector2(2.0, 2.0)
	await create_timer(0.3).timeout
	g.mortar_shot(mortar, spot, 1.0)
	await create_timer(0.45).timeout
	await _frozen("mortar_warning", _mid(520, 320))
	await _wait(func() -> bool: return g.ground_marks.marks.any(func(m: Dictionary) -> bool: return m["s"] == "ring" and not m["warn"]), 3.0)
	await create_timer(0.06).timeout
	await _frozen("mortar_land", _mid(520, 320))
	await create_timer(0.8).timeout
	# ---- a Spore Mother's spit: in the air, then where it lands
	var sp: Unit = _dummy("spore_mother", spot + Vector2(-260, 60))
	g.blob_shot(sp, spot + Vector2(10, 0), 1.0)
	await create_timer(0.3).timeout
	await _frozen("spore_spit_warning", _mid(520, 320))
	await _wait(func() -> bool: return g.ground_marks.marks.any(func(m: Dictionary) -> bool: return m["s"] == "oval" and not m["warn"]), 3.0)
	await create_timer(0.08).timeout
	await _frozen("spore_spit_land", _mid(520, 320))
	# ---- a Cog Press's "+N"
	var press: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "cog_press" and b.built and not b.dead:
			press = b
			break
	if press:
		g.camera.position = press.center() + Vector2(0, -20)
		g.camera.zoom = Vector2(1.6, 1.6)
		g._floats.clear()
		await _wait(func() -> bool: return g._floats.any(func(f: Array) -> bool: return (f[0] as Vector2).distance_to(press.center()) < 80.0), 12.0)
		await create_timer(0.25).timeout
		await _frozen("cog_press_plus", _mid(480, 320))
	else:
		print("no Cog Press in the lab")
	print("done")
	quit()
