extends SceneTree
## Films a man taking a horse by the reins (LEAD), frame by frame, into docs/shots/lead_anim/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_lead_anim.gd [-- <outdir> <prefix>]
## Cases: a Labourer told to LEAD (the button), a Labourer right-clicked on a horse, a Musketeer and an Officer told
## to LEAD (the button), and (for comparison) a Musketeer right-clicked on a horse: that one MOUNTS.
## Writes <prefix>_<case>_NNN.png (every 3rd frame, cropped round the pair) and prints, frame by frame, what each
## man shows: his kind, strip, frame, work, mounted or not. tools/lead_anim_gif.py makes the GIFs and sheets.
var main
var out := "res://docs/shots/lead_anim/frames"
var prefix := "after"
var only := ""
var g


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		prefix = a[1]
	if a.size() > 2:
		only = a[2]                   # (one case only)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String, focus: Vector2, size := Vector2i(420, 300)) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * focus
	sp *= Vector2(img.get_size()) / root.get_viewport().get_visible_rect().size
	var r := Rect2i(Vector2i(sp) - size / 2, size)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(ProjectSettings.globalize_path(out).path_join(name))


func wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear(around: Vector2) -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(around) < 900.0:
			g.consume_unit(u)
	await physics_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	g.reveal = true
	root.get_viewport().warp_mouse(Vector2(800, 110))
	var o := _open_area(20, 14)
	var mid := Vector2(o) * Defs.TILE + Vector2(320, 220)
	for c in [["labourer_lead", "labourer", "button"], ["labourer_click", "labourer", "click"],
			["musketeer_lead", "musketeer", "button"], ["officer_lead", "dismounted", "button"],
			["musketeer_click", "musketeer", "click"]]:
		if only != "" and c[0] != only:
			continue
		await _clear(mid)
		await _case(mid, c[0], c[1], c[2])
	quit()


func _case(mid: Vector2, name: String, kind: String, how: String) -> void:
	var man: Unit = g._add_unit(kind, 0, mid + Vector2(-110, 10))
	man.auto_work = false
	man.facing = Vector2.RIGHT
	var horse: Unit = g._add_unit("horse", 0, mid + Vector2(40, -10))
	horse.facing = Vector2(-1, 0.3).normalized()
	g.camera.position = mid
	g.camera.zoom = Vector2(2.2, 2.2)
	await wait_frames(30)
	if how == "button":
		g.lead_order([man])
	else:
		g._horse_command([man], horse, horse.position, false)
	var k := 0
	var seen := {}
	var log: Array = []
	var walk_off := false
	var t0: float = g.clock
	for f in 150:
		await physics_frame
		var m: Unit = man
		if not is_instance_valid(horse):
			horse = null           # (got on: the horse is part of the rider now)
		if not is_instance_valid(m):
			# he became another unit (mounted): find him
			for u in g.units:
				if u.team == 0 and u.kind != "horse" and u.position.distance_to(mid) < 200.0:
					man = u
					m = u
					break
		if m == null or not is_instance_valid(m):
			continue
		if horse == null:
			horse = m             # (the mounted man stands in for the pair)
		if not walk_off and horse.leader == m and m.order != "lead" and m.work == "":
			walk_off = true
			m.cmd_move(mid + Vector2(-200, 90))      # he walks away with it
		var s := "%s %s:%d work=%s mounted=%s order=%s horse_led=%s horse_vis=%.1f" % [m.kind, m.anim, m.sprite.frame if m.sprite else -1, m.work, m.is_mounted(), m.order, horse.leader == m, horse.modulate.a]
		if not seen.has(s.get_slice(" ", 1) + m.work):
			seen[s.get_slice(" ", 1) + m.work] = true
		log.append("%5.2f %s" % [g.clock - t0, s])
		if f % 3 == 0:
			await process_frame
			_snap("%s_%s_%03d.png" % [prefix, name, k], (m.position + horse.position) * 0.5 + Vector2(0, -16))
			k += 1
	print("== %s (%s, %s)" % [name, kind, how])
	var last := ""
	for l in log:
		var body: String = l.substr(6)
		if body != last:
			print(l)
			last = body
	print("   strips seen: ", seen.keys())
