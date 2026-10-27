extends SceneTree
## SHIELD FORWARD at game scale (docs/clock_soldier_shield.md), in the CLOCKWORK LAB: two rows of eight Clock Soldiers
## facing the eight ways (left to right S SE E NE N NW W SW), the top row with the shield forward (the guard strips), the
## bottom row without; standing, then on a walk frame; then a block of six of each facing the camera's lower right, as a
## player sees a squad. At 1x and zoomed 3x:
##   <outdir>/rows_{idle,walk}_{1x,3x}.png, <outdir>/squads_{1x,3x}.png
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_clock_soldier_shield.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const ORDER := [2, 1, 0, 7, 6, 5, 4, 3]     # facing octants (x right, y down): S SE E NE N NW W SW


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
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


func _snap(name: String, wait := 0.4) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _open_spot() -> Vector2:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead:
			hall = b
			break
	for r in range(12, 60):
		for k in 16:
			var p: Vector2 = hall.center() + Vector2.from_angle(TAU * k / 16.0) * float(r) * Defs.TILE
			var c: Vector2i = g.cell_of(p)
			var ok := true
			for y in range(c.y - 6, c.y + 7):
				for x in range(c.x - 10, c.x + 11):
					var cc := Vector2i(x, y)
					if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			for bb in g.buildings:
				if not bb.dead and bb.center().distance_to(p) < 420.0:
					ok = false
			if ok:
				return p
	return hall.center() + Vector2(0, 300)


func _freeze(us: Array, walk: bool, f: int) -> void:
	for u in us:
		u.set_physics_process(true)
		var a: String = ("guard_walk" if walk else "guard") if u.shield_up else ("walk" if walk else "idle")
		u._set_anim(a, true)
		u.sprite.frame = mini(f, u.sprite.hframes - 1)
		u.set_physics_process(false)
		u.set_process(false)


func _run() -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	g.reveal = true
	g.players[g.human]["tech"][ShieldWall.TECH] = true
	var spot := _open_spot()
	for u in g.units:
		if u.team == g.human and u.kind == "clock_soldier" and not u.dead:
			u.position = spot + Vector2(0, 900)      # (the Lab's own soldiers out of the picture)
	var rows: Array = []
	for row in 2:
		for i in 8:
			var u: Unit = g._add_unit("clock_soldier", g.human, spot + Vector2((float(i) - 3.5) * 44.0, -30.0 + 62.0 * row))
			u.cmd_stop()
			u.facing = Vector2.from_angle(float(ORDER[i]) * PI / 4.0)
			if row == 0:
				u.set_shield(true)
			rows.append(u)
	await create_timer(1.0).timeout
	for i in rows.size():
		(rows[i] as Unit).facing = Vector2.from_angle(float(ORDER[i % 8]) * PI / 4.0)
	for pose in [["idle", false, 0], ["walk", true, 2]]:
		_freeze(rows, pose[1], pose[2])
		g.camera.position = spot + Vector2(0, -10)
		g.camera.zoom = Vector2(1.0, 1.0)
		await _snap("rows_%s_1x" % pose[0])
		g.camera.zoom = Vector2(3.0, 3.0)
		await _snap("rows_%s_3x" % pose[0])
	for u in rows:
		g.units.erase(u)
		u.queue_free()
	# two squads of six, facing down-right, shields forward on the left one
	var sq: Array = []
	for s in 2:
		for i in 6:
			var p: Vector2 = spot + Vector2(-110.0 + 220.0 * s + float(i % 3) * 30.0 - 30.0, float(i / 3) * 30.0 - 15.0)
			var u: Unit = g._add_unit("clock_soldier", g.human, p)
			u.cmd_stop()
			if s == 0:
				u.set_shield(true)
			sq.append(u)
	await create_timer(1.0).timeout
	for u in sq:
		u.facing = Vector2(1, 0.6).normalized()
	_freeze(sq, false, 0)
	g.camera.position = spot
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("squads_1x")
	g.camera.zoom = Vector2(3.0, 3.0)
	await _snap("squads_3x")
	quit(0)
