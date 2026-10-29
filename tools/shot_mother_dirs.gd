extends SceneTree
## The Brood Mother's three stages walking and swiping in all 8 directions, at game size (zoom 1, her stage scale),
## every frame: docs/shots/mother_dirs/stage<N>_<walk|attack>.png (rows: the 8 headings, columns: the frames) and
## turn.png (her three stages standing, a column per heading: her size as she turns).
##   xvfb-run -a -s "-screen 0 3700x3100x24" godot --rendering-driver opengl3 --resolution 3600x3040 --fixed-fps 30 --script res://tools/shot_mother_dirs.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const COL := 580.0
const ROW := 375.0
const LEFT := 150.0
# the headings, from east clockwise (Unit._set_anim's view index o: angle o * 45 degrees, y down)
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const ORDER := [2, 1, 0, 7, 6, 5, 4, 3]       # rows: S, SE, E, NE, N, NW, W, SW


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED       # (one world px a screen px at zoom 1: game size)
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


func _pose(u: Unit, stage: int, o: int, a: String, k: int) -> void:
	u.facing = Vector2.from_angle(float(o) * PI / 4.0)
	u._lab_view = -1
	u._set_anim(a, true)
	u.sprite.frame = clampi(k, 0, u.sprite.hframes - 1)
	var sc := float(Defs.NB["stages"][stage]["scale"])
	u.sprite.scale = Vector2(signf(u.sprite.scale.x) * sc, sc)


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var o0 := Vector2(250.0, 16.0)       # (the whole picture inside the map: Hollowfen is 4096 x 3072)
	var back := Polygon2D.new()
	back.polygon = PackedVector2Array([Vector2(-200, -200), Vector2(4000, -200), Vector2(4000, 3600), Vector2(-200, 3600)])
	back.color = Color(0.38, 0.47, 0.27)
	back.position = o0
	back.z_index = 90
	g.world.add_child(back)
	var labels := Node2D.new()
	labels.z_index = 200
	g.world.add_child(labels)
	var texts: Array = []
	labels.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		for tx in texts:
			labels.draw_string_outline(font, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.9))
			labels.draw_string(font, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.6)))
	var grid: Array = []
	for r in 8:
		for c in 6:
			var u: Unit = g._add_unit(BroodNew.QUEEN, 0, o0 + Vector2(LEFT + COL * (c + 0.5), ROW * (r + 1) - 40.0))
			u.process_mode = Node.PROCESS_MODE_DISABLED
			u.z_index = 100
			grid.append(u)
	g.camera.zoom = Vector2.ONE
	var vs: Vector2 = root.get_visible_rect().size
	g.camera.position = o0 + vs * 0.5
	for stage in 3:
		for a in ["walk", "attack"]:
			texts.clear()
			for r in 8:
				texts.append([o0 + Vector2(8.0, ROW * (r + 1) - 120.0), "%s" % NAMES[ORDER[r]]])
				for c in 6:
					var u: Unit = grid[r * 6 + c]
					u.nb["stage"] = stage
					u.art = BroodMature.stage_art(stage)
					_pose(u, stage, ORDER[r], a, c)
			texts.append([o0 + Vector2(8.0, 30.0), "Brood Mother stage %d: %s (game size; west views mirrored)" % [stage + 1, a.to_upper()]])
			labels.queue_redraw()
			await create_timer(0.4).timeout
			root.get_viewport().get_texture().get_image().save_png("%s/stage%d_%s.png" % [out, stage + 1, a])
	# her three stages standing, a column per heading
	texts.clear()
	for u in grid:
		(u as Unit).position = o0 + Vector2(-5000.0, -5000.0)      # (out of the picture; the fog pass sets visible)
	for stage in 3:
		texts.append([o0 + Vector2(8.0, 330.0 + 400.0 * stage - 120.0), "Stage %d" % (stage + 1)])
		for i in 8:
			var u: Unit = grid[stage * 6 + (i % 6)] if i < 6 else grid[(3 + stage) * 6 + (i - 6)]
			u.position = o0 + Vector2(LEFT + 430.0 * (i + 0.5), 330.0 + 400.0 * stage)
			u.nb["stage"] = stage
			u.art = BroodMature.stage_art(stage)
			_pose(u, stage, ORDER[i], "idle", 0)
			if stage == 0:
				texts.append([o0 + Vector2(LEFT + 430.0 * (i + 0.5) - 10.0, 40.0), NAMES[ORDER[i]]])
	labels.queue_redraw()
	await create_timer(0.4).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/turn.png" % out)
	quit()
