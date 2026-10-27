extends SceneTree
## A crowded Powder Mill with its six labourers (the owner, 0.14.26: "the workers on powder mill
## are most of the time stuck, their animation stuck also"), for before/after pictures:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_mill_crowded.gd -- /abs/out.png [A|D] [seconds]
## Layout A (the owner's screenshot): Cottages tight on the mill's front and left, a Barracks
## behind it; D: shut in by Cottages on the front and both sides. Six labourers are sent to it
## from a few tiles away; after `seconds` of game time (default 25), once the mill's horse walks
## the near right of its track (in sight), the screen round the mill is saved, cropped (the HUD
## hidden). Runs on builds from before the work yard too.
var main: Node
var g
var out := ""
var layout := "A"
var wait_s := 25.0
var t := 0.0
var started := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	if args.size() > 1:
		layout = String(args[1]).to_upper()
	if args.size() > 2:
		wait_s = float(args[2])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


## An open level area of w x h cells away from the start bases.
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


func _run() -> void:
	seed(7)
	var o := _open_area(16, 15)
	g.reveal = true
	g.explored.fill(1)
	g.players[0]["gold"] = 50000
	var mc := o + Vector2i(6, 5)
	var m: Building = g._add_building("powder_mill", 0, mc, true)
	g._add_building("cottage", 0, mc + Vector2i(0, 3), true)
	g._add_building("cottage", 0, mc + Vector2i(2, 3), true)
	g._add_building("cottage", 0, mc + Vector2i(-2, 0), true)
	g._add_building("cottage", 0, mc + Vector2i(-2, 2), true)
	var spawn := mc + Vector2i(7, 1)
	if layout == "D":
		g._add_building("cottage", 0, mc + Vector2i(3, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(3, 2), true)
		spawn = mc + Vector2i(0, -6)
	else:
		g._add_building("barracks", 0, mc + Vector2i(-1, -3), true)
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			b.lode = 1.0e7
	var us: Array = []
	for i in 6:
		var c: Vector2i = spawn + Vector2i(i % 3, i / 3)
		if not g.is_free(c):
			c = g.nearest_free(c, 6)
		us.append(g._add_unit("labourer", 0, g.cell_center(c) + Vector2(randf_range(-6, 6), randf_range(-6, 6))))
	g.camera.zoom = Vector2(3, 3)
	g.camera.position = m.center() + Vector2(0, 8)
	await physics_frame
	for u in us:
		u.auto_work = false
		u.cmd_gather(m)
	var t0: float = g.clock
	# (then on until the mill's horse walks the near right of its track, in front of the millstone
	# and in sight: not behind the post, nor behind the men tipping at the hopper; a few seconds)
	while g.clock - t0 < wait_s or ((sin(float(m.get("_mill_a"))) < 0.35 or cos(float(m.get("_mill_a"))) < -0.2) and g.clock - t0 < wait_s + 8.0):
		root.get_viewport().warp_mouse(Vector2(2, 2))       # (no hover marker on the crew: the corner shows grass)
		await process_frame
	await process_frame
	var im: Image = root.get_viewport().get_texture().get_image()
	# (the mill and its neighbours: the middle of the screen)
	var w := mini(im.get_width(), 720)
	var h := mini(im.get_height(), 520)
	im = im.get_region(Rect2i((im.get_width() - w) / 2, (im.get_height() - h) / 2, w, h))
	im.save_png(out)
	print("crew at work %d/6 · saved %s" % [m.working_crew(), out])
	quit()
