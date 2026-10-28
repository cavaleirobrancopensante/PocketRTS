extends SceneTree
## The new Brood's Mother at her three growth stages, rooted side by side on clear ground, names above (code-drawn
## text): docs/shots/brood_new/mother_stages.png.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_mother_stages.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


## Clear ground (cells) 44 x 16 nearest the map's middle.
func _clear_spot() -> Vector2i:
	var mid := Vector2i(Game.W / 2 - 22, Game.H / 2 - 8)
	var best := Vector2i(10, 10)
	var bd := INF
	for y in range(1, Game.H - 17, 2):
		for x in range(1, Game.W - 45, 2):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in 16:
				for xx in 44:
					var cc := c + Vector2i(xx, yy)
					if not g._walkable(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)]:
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = dd
				best = c
	return best


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var o := _clear_spot()
	var ms: Array = []
	for i in 3:
		var m: Unit = g._add_unit(BroodNew.QUEEN, 0, Vector2((o.x + 6.0 + i * 16.0) * Defs.TILE, (o.y + 12.0) * Defs.TILE))
		m.nb["stage"] = i
		BroodNew.apply_stage(m)
		m.tesla_mode = "deployed"
		m.facing = BroodNew.SE
		m.cmd_hold()
		ms.append(m)
	var labels := Node2D.new()
	labels.z_index = 50
	g.world.add_child(labels)
	labels.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		for i in 3:
			var m: Unit = ms[i]
			var st: Dictionary = Defs.NB["stages"][i]
			var txt := "Stage %d: %d eggs, laying x%.1f" % [i + 1, int(st["eggs"]), float(st["rate"])]
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			var top: Vector2 = m.position - Vector2(w * 0.5, 230.0 * float(st["scale"]) + 10.0)
			labels.draw_string_outline(font, top, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.9))
			labels.draw_string(font, top, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.6)))
	labels.queue_redraw()
	g.camera.position = Vector2((o.x + 22.0) * Defs.TILE, (o.y + 8.0) * Defs.TILE)
	g.camera.zoom = Vector2(0.82, 0.82)
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/mother_stages.png" % out)
	quit()
