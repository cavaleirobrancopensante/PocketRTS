extends SceneTree
## Films the Horsemen fighting on the move (scripts/ride_by.gd) into docs/shots/ride_by/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_ride_by.gd [-- <outdir>]
## 1. worker_NN.png: three Horsemen ride through a line of Labourers at their work, slashing as they pass
## 2. cannon_NN.png: a Cuirassier told to attack a Cannon rides passes round it (his track drawn on the ground)
## 3. cannon_track.png: the whole track of the looping attack (a figure of eight), at the end
## Frames are cropped round the action; tools/shot_ride_by_gif.py (or ffmpeg) can make them a moving picture.
var main
var out := "res://docs/shots/ride_by"
var g
var frame_n := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String, focus: Vector2, size := Vector2i(900, 520)) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * focus
	sp *= Vector2(img.get_size()) / root.get_viewport().get_visible_rect().size      # (the window is the 1280x720 view stretched)
	var r := Rect2i(Vector2i(sp) - size / 2, size)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(ProjectSettings.globalize_path(out).path_join(name))
	print("wrote ", name)


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
		if u.position.distance_to(around) < 1200.0:
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
	root.get_viewport().warp_mouse(Vector2(800, 110))   # (no hover card over the picture; not at an edge: that scrolls)
	var o := _open_area(32, 22)
	var base := Vector2(o) * Defs.TILE
	await _clear(base + Vector2(500, 350))
	await _workers(base)
	await _clear(base + Vector2(500, 350))
	await _cannon(base)
	quit()


## 1. three Horsemen ride through a worker line (Labourers of the other side, bunched at their work)
func _workers(base: Vector2) -> void:
	var mid := base + Vector2(560, 340)
	var men: Array = []
	for i in 10:
		var m: Unit = g._add_unit("labourer", 1, mid + Vector2((i % 5) * 30.0 - 60.0, (i / 5) * 34.0 - 17.0))
		m.auto_work = false
		m.facing = Vector2.DOWN
		men.append(m)
	var riders: Array = []
	for i in 3:
		var r: Unit = g._add_unit("cuirassier", 0, mid + Vector2(-330, -40 + i * 40))
		r.pistol = false
		r.facing = Vector2.RIGHT
		riders.append(r)
	g.camera.position = mid
	g.camera.zoom = Vector2(1.6, 1.6)
	await wait_frames(30)
	await _snap("worker_00.png", mid)
	# a plain move straight through and out the far side: they slash what they pass
	for r in riders:
		r.cmd_move(r.position + Vector2(680, 0))
	var k := 1
	var t0: float = g.clock
	var last_n := 0
	while g.clock - t0 < 6.5 and k < 12:
		await physics_frame
		var n := 0
		for r in riders:
			n += (r as Unit).ride_n
		if n != last_n:
			last_n = n
			await wait_frames(2)        # (the arc half drawn)
			await _snap("worker_%02d.png" % k, mid)
			k += 1
	await wait_frames(20)
	await _snap("worker_%02d.png" % k, mid)
	var down := men.filter(func(m) -> bool: return not is_instance_valid(m) or m.dead or m.hp < m.max_hp).size()
	print("worker line: %d of %d hands hit in one ride-through" % [down, men.size()])


## 2. a Cuirassier told to attack a Cannon: passes round it, his track drawn on the ground
func _cannon(base: Vector2) -> void:
	var mid := base + Vector2(560, 340)
	var gun: Unit = g._add_unit("cannon", 1, mid)
	gun.max_hp = 9000.0
	gun.hp = 9000.0
	gun.stun_t = 99999.0          # (it doesn't fire back while we film)
	var c: Unit = g._add_unit("cuirassier", 0, mid + Vector2(-300, 30))
	c.put_on_armour()
	c.pistol = false
	c.facing = Vector2.RIGHT
	var track := Line2D.new()
	track.width = 2.5
	track.default_color = Color(1.0, 0.85, 0.3, 0.75)
	track.z_index = 1
	g.world.add_child(track)
	var hits := Line2D.new()      # (a little tick where each blow landed)
	g.camera.position = mid
	g.camera.zoom = Vector2(1.5, 1.5)
	await wait_frames(30)
	c.cmd_attack(gun)
	var t0: float = g.clock
	var k := 0
	var last_n := 0
	var marks: Array = []
	while g.clock - t0 < 12.0:
		await physics_frame
		gun.stun_t = 99999.0
		if Engine.get_physics_frames() % 2 == 0:
			track.add_point(c.position)
		if c.ride_n != last_n:
			last_n = c.ride_n
			marks.append(c.position)
			var m := Polygon2D.new()
			m.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5)])
			m.color = Color(1, 0.3, 0.2, 0.9)
			m.position = c.position
			m.z_index = 2
			g.world.add_child(m)
			if k < 6:
				await wait_frames(2)
				await _snap("cannon_%02d.png" % k, mid, Vector2i(820, 560))
				k += 1
	await _snap("cannon_track.png", mid, Vector2i(820, 560))
	print("cannon: %d passes in 12 s, %.0f damage; gun at %s (spawned %s), sprite %s, blows at %s" % [c.ride_n, 9000.0 - gun.hp, gun.position, mid, gun.sprite.global_position if gun.sprite else Vector2.ZERO, marks])
	hits.free()
