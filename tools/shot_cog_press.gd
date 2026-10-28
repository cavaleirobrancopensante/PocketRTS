extends SceneTree
## Screenshots of the COG PRESS in the CLOCKWORK LAB (scripts/cw_lab.gd's showcase: two presses, a Mainspring, an Escapement
## round the Clocktower): the field at normal zoom and close, each press close (working), a frame sequence of the working
## loop (0.09 s apart, a GIF: docs/shots/cog_press_new/press_cycle_game.gif), and the other pictures in a row below the field
## (an idle press with no Winders, a site being built, a damaged press, a wreck).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_cog_press.gd -- <outdir> [frames]
## Writes <outdir>/field.png, field_close.png, press_<n>.png, frame_00.png ... (frames, default 16), states.png (an idle press, a
## site, a damaged press, a wreck, in a row below the field) and press_idle.png.
var main: Node
var g
var out := ""
var frames := 16
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		frames = int(a[1])
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


func _snap(name: String, wait := 1.0) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	await create_timer(2.0).timeout
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var tower: Building = null
	var presses: Array = []
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			tower = b
		if b.team == g.human and b.kind == "cog_press":
			presses.append(b)
	g.camera.position = tower.center() + Vector2(0, 20)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("field")
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap("field_close")
	for i in presses.size():
		g.camera.position = presses[i].center() + Vector2(0, -20)
		g.camera.zoom = Vector2(2.4, 2.4)
		await _snap("press_%d" % i)
	if presses.is_empty():
		quit(1)
		return
	var p: Building = presses[0]
	g.camera.position = p.center() + Vector2(0, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	await create_timer(1.0).timeout
	for i in frames:
		await _snap("frame_%02d" % i, 0.09)
	# the other pictures in a row below the field: an idle press (no Winders: the built picture), a site, a damaged press, a wreck
	var put: Array = []
	for off in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(10, 0), Vector2i(15, 0)]:
		var c: Vector2i = p.cell + off + Vector2i(0, 8)
		put.append(g._add_building("cog_press", g.human, c, put.size() != 1))
	put[1].seeded = true
	put[1].progress = 0.6
	put[1]._update_sprite()
	put[2].hp = put[2].max_hp * 0.4
	put[2]._update_sprite()
	put[3].take_damage(999999.0, null)
	g.camera.position = (put[1].center() + put[2].center()) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(1.8, 1.8)
	await _snap("states", 1.5)
	g.camera.position = put[0].center() + Vector2(0, -20)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _snap("press_idle", 0.5)
	quit(0)
