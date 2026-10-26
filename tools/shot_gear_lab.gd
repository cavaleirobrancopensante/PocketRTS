extends SceneTree
## Screenshots of the CLOCKWORK LAB's gear field (scripts/cw_lab.gd): the start as the player sees it, a close-up, a frame
## sequence of the turning field (tools/gear_art/frames_to_gif.py makes a GIF of it) and the placement ghost (links with an
## idler, no link, clash).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_gear_lab.gd -- <outdir> [frames]
## Writes <outdir>/lab_start.png, lab_close.png, lab_far.png, lab_ghost_ok.png, lab_ghost_far.png, lab_ghost_clash.png and
## frame_00.png ... (frames, default 24, 0.12 s apart).
var main: Node
var g
var out := ""
var frames := 24
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		frames = int(a[1])
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
		g.hud.visible = true
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var tower: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			tower = b
	await _snap("lab_start", 2.5)
	g.reveal = true
	# the close-ups without the HUD, the hint and the SANDBOX panel
	var ui := root.find_children("*", "CanvasLayer", true, false)
	for c in ui:
		c.visible = false
	g.camera.position = tower.center() + Vector2(0, 20)
	g.camera.zoom = Vector2(1.8, 1.8)
	await _snap("lab_close", 0.6)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("lab_far", 0.6)
	g.camera.zoom = Vector2(1.6, 1.6)
	g.camera.position = tower.center() + Vector2(0, 20)
	await create_timer(1.0).timeout
	for i in frames:
		await _snap("frame_%02d" % i, 0.12)
	for c in ui:
		c.visible = true
	# the ghost: a spot that links (through an idler if it has one), one too far, one that clashes
	g.camera.zoom = Vector2(1.2, 1.2)
	g.controls.mode = "place"
	g.controls.place_kind = "mainspring"
	var ok_c := _spot(tower, "ok", true)
	if ok_c.x >= 0:
		g.controls.ghost_cell = ok_c
		g.camera.position = Vector2(ok_c) * Defs.TILE
		await _snap("lab_ghost_ok")
	var far_c := _spot(tower, "far", false)
	if far_c.x >= 0:
		g.controls.ghost_cell = far_c
		g.camera.position = Vector2(far_c) * Defs.TILE
		await _snap("lab_ghost_far")
	g.controls.ghost_cell = tower.cell + Vector2i(1, 5)
	g.camera.position = tower.center() + Vector2(0, 60)
	await _snap("lab_ghost_clash")
	g.controls.mode = ""
	# the Cog Press's other pictures: a site being built, a damaged one, a wreck (and a Mainspring site)
	var put: Array = []
	for k in ["cog_press", "cog_press", "mainspring", "cog_press"]:
		var c := _spot(tower, "ok", false, k)
		if c.x < 0:
			c = _spot(tower, "ok", true, k)
		if c.x >= 0:
			put.append(g._add_building(k, g.human, c, put.size() != 0 and put.size() != 2))
			g.gear_net.solve()
	for b in put:
		if not b.built:
			b.seeded = true
			b.progress = 0.6
			b._update_sprite()
	if put.size() > 1:
		put[1].hp = put[1].max_hp * 0.4
		put[1]._update_sprite()
	if put.size() > 3:
		put[3].take_damage(999999.0, null)
	var mid := Vector2.ZERO
	for b in put:
		mid += b.center() / float(put.size())
	for c in ui:
		c.visible = false
	g.camera.zoom = Vector2(1.1, 1.1)
	g.camera.position = mid
	await _snap("lab_states", 1.0)
	quit(0)


## A cell near the tower where a Mainspring's ghost has this state ("ok" with an idler if `idler`).
func _spot(tower: Building, state: String, idler: bool, kind := "mainspring") -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for r in range(4, 22):
		for y in range(tower.cell.y - r, tower.cell.y + r + 1):
			for x in range(tower.cell.x - r, tower.cell.x + r + 1):
				var c := Vector2i(x, y)
				if not g.in_map(c) or not g.margin_free(c, size):
					continue
				if state == "ok" and not g.margin_free(c, size):
					continue
				var st: Dictionary = g.gear_net.candidate(g.human, kind, c)
				if st["state"] != state:
					continue
				if state == "ok":
					var p: Building = st["with"]
					var gc := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
					var idl := GearNet.idler_for(GearNet.b_c(p), GearNet.b_r(p), gc, GearNet.ring_r(kind, size, false))
					if idler == idl.is_empty():
						continue
				return c
	return Vector2i(-1, -1)
