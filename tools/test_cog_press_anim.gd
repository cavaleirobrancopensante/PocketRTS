extends SceneTree
## The Cog Press's working loop and stamp (0.14.101, tools/import_cog_press.py):
##   godot --headless --fixed-fps 30 --script res://tools/test_cog_press_anim.gd
##  1. all Defs.GEAR "press_frames" work frames load, one size, the same size as the built picture (one anchor)
##  2. a crewed press in the CLOCKWORK LAB plays them all in order (frame 0 .. 11), and shows the built picture when idle
##  3. the stamp: work/cog_press_stamp has its two takes and plays from a press in view (on the stamp frame, every other
##     stroke), and none plays from a press out of the player's sight
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
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


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _run() -> void:
	var n := int(Defs.GEAR["press_frames"])
	var built: Texture2D = load("res://assets/buildings/cog_press_built.png")
	var same := true
	for i in n:
		var tx: Texture2D = load("res://assets/buildings/cog_press_work_%d.png" % i)
		if tx == null or tx.get_size() != built.get_size():
			same = false
	check(same, "%d work frames, each %s like the built picture" % [n, built.get_size()])
	check(not ResourceLoader.exists("res://assets/buildings/cog_press_work_%d.png" % n), "no stale frame %d" % n)
	check(Sfx.me != null and Sfx.me._find("work/cog_press_stamp").size() == 2, "work/cog_press_stamp has two takes")
	var p: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "cog_press" and b.working_crew() > 0:
			p = b
	check(p != null, "a crewed press in the lab")
	if p == null:
		_end()
		return
	await wait(2.0)
	var seen := {}
	var order_ok := true
	var last := -1
	for k in 60:
		await physics_frame
		var idx := int(Building._work_tex["cog_press"].find(p.sprite.texture))
		if idx < 0:
			continue
		if last >= 0 and idx != last and idx != (last + 1) % n:
			order_ok = false
		last = idx
		seen[idx] = true
	check(seen.size() == n, "the working press shows all %d frames (saw %d)" % [n, seen.size()])
	check(order_ok, "in order, one after another")
	# the stamp, from a press in view
	g.reveal = true
	Sfx.me._last.erase("work/cog_press_stamp")
	await wait(3.0)
	check(Sfx.me._last.has("work/cog_press_stamp"), "the stamp plays from a working press in view")
	# none out of sight: fog back on, the human's sight emptied
	g.reveal = false
	var heard := false
	var vis_before: Variant = g._human_vis.duplicate()
	for b in g.buildings:
		if b.kind == "cog_press":
			b._press_frame = -1
	Sfx.me._last.erase("work/cog_press_stamp")
	var hidden := true
	for k in 90:
		var hv: PackedByteArray = g._human_vis
		hv.fill(0)
		g._human_vis = hv
		if g.is_visible_to(g.human, p.center()):
			hidden = false
		await physics_frame
		if Sfx.me._last.has("work/cog_press_stamp"):
			heard = true
	g._human_vis = vis_before
	check(hidden and not heard, "no stamp from a press out of sight")
	# idle (no crew, or no brass): the built picture
	var r := p._gear_anim(false)
	check(r == -1 and p.sprite.texture.resource_path.ends_with("cog_press_built.png"), "idle, it shows the built picture")
	_end()


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails else 0)
