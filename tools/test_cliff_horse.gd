extends SceneTree
## A horse unhitched from a gun at a cliff edge stays on the gun's level, and a line drawn with
## the mouse outside the window stays on the screen:
##   godot --headless --fixed-fps 30 --script res://tools/test_cliff_horse.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
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
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## High-ground cells with a free cliff-side neighbour two tiles away on the low ground:
## [cell, direction towards the low ground].
func _edges(limit: int) -> Array:
	var out: Array = []
	for y in range(6, g.H - 6):
		for x in range(6, g.W - 6):
			var c := Vector2i(x, y)
			if g.height[g.idx(c)] != 1 or g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var lo: Vector2i = c + d * 2
				var mid: Vector2i = c + d
				if g.height[g.idx(lo)] == 0 and g.solid[g.idx(lo)] == 0 and g.ramp[g.idx(lo)] == 0 and g.ramp[g.idx(mid)] == 0:
					out.append([c, d])
					break
			if out.size() >= limit:
				return out
	return out


func _run() -> void:
	g.explored.fill(1)
	var edges := _edges(40)
	check(edges.size() >= 5, "cliff edges found on the map (%d)" % edges.size())
	var bad := 0
	var tried := 0
	for e in edges:
		var cell: Vector2i = e[0]
		var d: Vector2i = e[1]
		var gun: Unit = g._add_unit("cannon", 0, g.cell_center(cell))
		await physics_frame
		if not gun.harnessed:
			gun.queue_free()
			continue
		# face so the horse is put down on the cliff side
		gun.facing = Vector2(float(d.y), -float(d.x))
		var h: Unit = gun.release_horse()
		if h == null:
			continue
		tried += 1
		if g.level_of(h.position) != g.level_of(gun.position):
			bad += 1
		g.consume_unit(h)
		g.consume_unit(gun)
	check(tried >= 5 and bad == 0, "unhitched at a cliff edge: the horse stays on the gun's level (%d tried, %d went down)" % [tried, bad])
	# the line: points far outside the window are brought back to the screen's edge
	g.hud.visible = true
	var ctl = g.controls if "controls" in g else g.hud.controls
	var vs: Vector2 = g.get_viewport().get_visible_rect().size
	ctl.line = PackedVector2Array()
	ctl._line_add(Vector2(-5000, vs.y * 0.5))
	ctl._line_add(Vector2(vs.x * 0.5, vs.y + 4000))
	var rect := Rect2(ctl.to_world(Vector2.ZERO), Vector2.ZERO).expand(ctl.to_world(vs)).grow(2.0)
	var inside := true
	for p in ctl.line:
		inside = inside and rect.has_point(p)
	check(ctl.line.size() == 2 and inside, "a line point outside the window is kept on the screen")
	print("cliff horse: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
