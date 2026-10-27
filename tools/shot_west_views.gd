extends SceneTree
## Clock Soldiers facing all eight ways in a match (the CLOCKWORK LAB), left to right S SE E NE N NW W SW: the west views
## are their own strips (sword in the right hand; Unit.WEST_OF), not the east ones mirrored. Shots at the game's 1x and
## zoomed 3x, idle, then frozen on the attack's strike frame (3) and on a walk frame:
##   <outdir>/eight_ways_{idle,attack,walk}_{1x,3x}.png
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_west_views.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const ORDER := [2, 1, 0, 7, 6, 5, 4, 3]     # facing octants (x right, y down): S SE E NE N NW W SW


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
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
	for r in range(8, 40):
		for k in 16:
			var p: Vector2 = hall.center() + Vector2.from_angle(TAU * k / 16.0) * float(r) * Defs.TILE
			var c: Vector2i = g.cell_of(p)
			var ok := true
			for y in range(c.y - 4, c.y + 5):
				for x in range(c.x - 10, c.x + 11):
					var cc := Vector2i(x, y)
					if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				return p
	return hall.center() + Vector2(0, 300)


func _pose(us: Array, a: String, f: int) -> void:
	for i in us.size():
		var u: Unit = us[i]
		u.set_physics_process(true)
		u.facing = Vector2.from_angle(float(ORDER[i]) * PI / 4.0)
		u._set_anim(a, true)
		u.sprite.frame = mini(f, u.sprite.hframes - 1)
		u.set_physics_process(false)
		u.set_process(false)


func _run() -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	g.reveal = true
	var spot := _open_spot()
	var us: Array = []
	for u in g.units:
		if u.team == g.human and u.kind == "clock_soldier" and not u.dead:
			u.position = spot + Vector2(0, 600)      # (the Lab's own soldiers out of the picture)
	for i in 8:
		var u: Unit = g._add_unit("clock_soldier", g.human, spot + Vector2((float(i) - 3.5) * 44.0, 0))
		u.cmd_stop()
		us.append(u)
	await create_timer(0.4).timeout
	for pose in [["idle", 0], ["attack", 3], ["walk", 2]]:
		_pose(us, pose[0], pose[1])
		g.camera.position = spot + Vector2(0, -18)
		g.camera.zoom = Vector2(1.0, 1.0)
		await _snap("eight_ways_%s_1x" % pose[0])
		g.camera.zoom = Vector2(3.0, 3.0)
		await _snap("eight_ways_%s_3x" % pose[0])
	quit(0)
