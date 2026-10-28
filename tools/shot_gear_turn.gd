extends SceneTree
## Film of TURNING GEARS (docs/gear_turn.md) for docs/shots/gear_turn/: frames of three scenes, made into GIFs by
## tools/gear_turn_gif.py.
##   hold:   six enemy Musketeers on HOLD on the Clocktower's band, carried round it while they shoot;
##   winder: a Winder walks in across the band to repair the Clocktower (not carried), a Clock Soldier left idle on the band
##           rides round beside him, and the GEAR VIEW's chevrons show which way each band turns;
##   raid:   a Crown raid (Musketeers and Horsemen) on a Clockwork base whose Clock Soldiers hold on the rings.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_gear_turn.gd -- docs/shots/gear_turn [only=hold]
const U := preload("res://tools/gear_test_util.gd")
var g: Game
var out := "docs/shots/gear_turn"
var only := ""
var t := 0.0
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	Defs.gear_turn = true
	seed(7)
	g = U.make(root, ["clockwork", "crown"], "ashford_crossing", true)


func _process(delta: float) -> bool:
	t += delta
	if not started and t > 0.5:
		started = true
		_run()
	return false


func _snap(path: String, wait := 0.0) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)


func _frames(name: String, n: int, every: float) -> void:
	var dir := "%s/gif_%s" % [out, name]
	DirAccess.make_dir_recursive_absolute(dir)
	for i in n:
		await _snap("%s/f%03d.png" % [dir, i], every)


func _band_spot(b: Building, deg: float, frac := 0.5, rad := 12.0) -> Vector2:
	var net := g.gear_net
	for bi in net.bands.size():
		if net.bands[bi][0] != b:
			continue
		var c: Vector2 = net.bands[bi][1]
		var r := lerpf(float(net.bands[bi][2]), float(net.bands[bi][3]), frac)
		for k in 36:
			var gp := c + Vector2.from_angle(deg_to_rad(deg + 4.0 * k)) * r
			var w := Vector2(gp.x, gp.y * GearNet.FY)
			if g.in_map(g.cell_of(w)) and g._clear_at(w, rad, 1) and net.band_at(w) == bi:
				return w
	return Vector2.INF


func _clear(team: int) -> void:
	for u in g.units.duplicate():
		if u.team == team and not u.is_worker():
			g.units.erase(u)
			u.queue_free()


func _run() -> void:
	g.reveal = true
	g.players[0]["gold"] = 50000
	var hall := U.hall(g, 0)
	var p1 := U.put(g, 0, Defs.GEAR_PRESS, hall.cell)
	var p2 := U.put(g, 0, Defs.GEAR_PRESS, hall.cell + Vector2i(-6, 4))
	var sp := U.put(g, 0, "mainspring", hall.cell + Vector2i(6, 4))
	for b in [p1, p2, sp]:
		if b == null:
			continue
		for k in 2:
			var w: Unit = g._add_unit("winder", 0, b.center() + Vector2(0, 110))
			w.cmd_gather(b)
	await create_timer(1.5).timeout
	# ---- hold
	if only == "" or only == "hold":
		var men: Array = []
		for k in 6:
			var p := _band_spot(hall, 60.0 * k + 10.0)
			if p == Vector2.INF:
				continue
			var m: Unit = g._add_unit("musketeer", 1, p)
			m.cmd_hold()
			m.max_hp = 5000.0
			m.hp = 5000.0
			men.append(m)
		g.camera.position = hall.center() + Vector2(0, 10)
		g.camera.zoom = Vector2(1.5, 1.5)
		await create_timer(1.0).timeout
		await _snap("%s/hold_start.png" % out)
		await _frames("hold", 48, 0.2)
		await _snap("%s/hold_end.png" % out)
		for m in men:
			if is_instance_valid(m):
				m.die()
		await create_timer(1.0).timeout
	# ---- winder
	if only == "" or only == "winder":
		hall.hp = hall.max_hp * 0.4
		var c: Vector2 = GearNet.b_c(hall)
		var far := Vector2.INF
		for k in 72:
			var gp := c + Vector2.from_angle(deg_to_rad(110.0 + 5.0 * k)) * (GearNet.b_r(hall) + 70.0)
			var w := Vector2(gp.x, gp.y * GearNet.FY)
			if g._clear_at(w, 10.0, 0) and g.gear_net.band_at(w, 12.0) < 0:
				far = w
				break
		var rp: Unit = g._add_unit("winder", 0, far)
		rp.auto_work = false
		rp.cmd_repair(hall)
		var rider: Unit = g._add_unit("clock_soldier", 0, _band_spot(hall, 200.0))
		rider.auto_work = false
		g.camera.position = (hall.center() + far) * 0.5
		g.camera.zoom = Vector2(1.6, 1.6)
		g.gear_net.view = true
		await _frames("winder", 44, 0.2)
		g.gear_net.view = false
		await _snap("%s/winder_end.png" % out)
		rider.die()
		rp.die()
		hall.hp = hall.max_hp
		await create_timer(1.0).timeout
	# ---- raid
	if only == "" or only == "raid":
		var defenders: Array = []
		for k in 5:
			var p := _band_spot(hall, 200.0 + 18.0 * k, 0.55)
			if p != Vector2.INF:
				var d: Unit = g._add_unit("clock_soldier", 0, p)
				d.cmd_hold()
				defenders.append(d)
		var from := hall.center() + Vector2(-620, 260)
		var cc := g.cell_center(g.nearest_free(g.cell_of(from), 8))
		for k in 10:
			var kind := "cuirassier" if k < 3 else "musketeer"
			var u: Unit = g._add_unit(kind, 1, g.cell_center(g.nearest_free(g.cell_of(cc + Vector2((k % 4) * 26.0, (k / 4) * 26.0)), 4)))
			u.cmd_move(hall.center(), true)
		g.camera.position = hall.center() + Vector2(-180, 90)
		g.camera.zoom = Vector2(1.05, 1.05)
		await _frames("raid", 60, 0.25)
		await _snap("%s/raid_end.png" % out)
	quit(0)
