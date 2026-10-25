extends SceneTree
## The Powder Mill's layering: labourers standing on the dirt at the right of the mill, with the
## ground layer (after) and with the old one-piece sprite (before: the structure and the ground
## put back together into one y-sorted picture), and the working crew a few moments later:
##   xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_mill_layers.gd -- <outdir>
## Writes <outdir>/mill_after.png, mill_before.png and mill_work_<n>.png.
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
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
	origin = _open_area(20, 14)
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.camera.zoom = Vector2(4, 4)
	g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	var m: Building = g._add_building("powder_mill", 0, origin + Vector2i(8, 4), true)
	var r := m.rect()
	var c := r.get_center().x
	var standers: Array = []
	for p in [Vector2(c + 56, r.end.y - 14), Vector2(c + 50, r.end.y - 5), Vector2(c + 60, r.end.y - 26), Vector2(c + 53, r.end.y - 34)]:
		var u: Unit = g._add_unit("labourer", 0, p)
		u.auto_work = false
		u.facing = Vector2(-1, 1)
		standers.append(u)
	g.camera.position = m.center() + Vector2(20, 14)
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/mill_after.png" % out)
	# before: the old one-piece sprite
	var full := (m.sprite.texture as Texture2D).get_image()
	full.convert(Image.FORMAT_RGBA8)
	full.blend_rect((m._mill_ground.texture as Texture2D).get_image(), Rect2i(Vector2i.ZERO, full.get_size()), Vector2i.ZERO)
	m.sprite.texture = ImageTexture.create_from_image(full)
	m._mill_ground.visible = false
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/mill_before.png" % out)
	# the crew at work (the normal sprites again)
	m._mill_ground.visible = true
	m.sprite.texture = null
	m._update_sprite()
	for u in standers:
		u.position = r.position + Vector2(-400, 400)
	for i in 6:
		var u: Unit = g._add_unit("labourer", 0, r.get_center() + Vector2(-70 + 28 * i, r.size.y * 0.5 + 30))
		u.auto_work = false
		u.cmd_gather(m)
	g.camera.position = m.center() + Vector2(0, 30)
	await create_timer(8.0).timeout
	for i in 4:
		root.get_viewport().get_texture().get_image().save_png("%s/mill_work_%d.png" % [out, i])
		await create_timer(0.7).timeout
	quit()
