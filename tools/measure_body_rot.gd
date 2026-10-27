extends SceneTree
## How many bodies lie on the field at once, and what they cost, now that every body rots (Defs.ROT) instead of going
## after 30 s in a match without the Brood. Works on older builds too (it only reads Game.bodies), to compare.
##   godot --headless --fixed-fps 30 --script res://tools/measure_body_rot.gd -- [map] [minutes:20] [a:crown] [b:clockwork]
##       [diff:hard]
## Prints "ROTCOUNT" lines each minute: the bodies lying now and the most so far, the living units, and the real
## milliseconds a simulated frame took that minute.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/measure_body_rot.gd -- lab n:300
## lab: no fight; n bodies laid out in the camera's view, then the drawn frame's cost with them and without them
## ("ROTLAB" lines; with a renderer, so the bodies' sprites and bars are drawn).
var main: Node
var t := 0.0
var stop_at := 1200.0
var map := "ashford_crossing"
var fa := "crown"
var fb := "clockwork"
var diff := "hard"
var lab := false
var lab_n := 300
var done := false
var most := 0
var next_min := 60.0
var _frames := 0
var _us := 0
var _last := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("minutes:"):
			stop_at = float(a.substr(8)) * 60.0
		elif a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)
		elif a.begins_with("diff:"):
			diff = a.substr(5)
		elif a == "lab":
			lab = true
		elif a.begins_with("n:"):
			lab_n = int(a.substr(2))
		elif MapGen.all_ids().has(a):
			map = a
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _lying(g: Game) -> int:
	var n := 0
	for b in g.bodies:
		if is_instance_valid(b) and b.dead and b.modulate.a > 0.99:
			n += 1
	return n


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		if lab:
			main.start({"map": map, "seed": 4242, "slots": [
				{"who": "you", "faction": fa, "colour": 0, "side": 0},
				{"who": "easy", "faction": fb, "colour": 1, "side": 1}]})
		else:
			main.start({"map": map, "seed": 4242, "slots": [
				{"who": diff, "faction": fa, "colour": 0, "side": 0},
				{"who": diff, "faction": fb, "colour": 1, "side": 1}]})
		return false
	var g: Game = main.game
	if g == null or done:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	if lab:
		if t > 1.0:
			done = true
			_lab(g)
		return false
	var now := Time.get_ticks_usec()
	if _last > 0:
		_us += now - _last
		_frames += 1
	_last = now
	most = maxi(most, _lying(g))
	if g.clock >= next_min:
		next_min += 60.0
		print("ROTCOUNT %s %s-%s min %d bodies %d most %d units %d ms_per_frame %.2f" % [ProjectSettings.get_setting("application/config/version"),
			fa, fb, int(g.clock / 60.0), _lying(g), most, g.units.size(), _us / 1000.0 / maxf(_frames, 1)])
		_us = 0
		_frames = 0
	if g.clock >= stop_at or g.over:
		done = true
		print("ROTCOUNT end %s at %.0f s: most bodies lying at once %d" % [ProjectSettings.get_setting("application/config/version"), g.clock, most])
		quit()
	return false


func _frame_ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for k in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _lab(g: Game) -> void:
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	var c: Vector2 = g.cell_center(g.nearest_free(Vector2i(Game.W / 2, Game.H / 2), 10))
	g.camera.position = c
	g.camera.zoom = Vector2(0.6, 0.6)
	await _frame_ms(30)
	var base := await _frame_ms(300)
	var kinds := ["musketeer", "raptor", "clock_soldier", "brute", "labourer", "cuirassier"]
	var side := int(ceil(sqrt(float(lab_n))))
	for k in lab_n:
		var at := c + Vector2((k % side - side / 2) * 34.0, (k / side - side / 2) * 26.0)
		var u: Unit = g._add_unit(kinds[k % kinds.size()], k % 2, at)
		u.process_mode = Node.PROCESS_MODE_INHERIT
	await physics_frame
	for u in g.units.duplicate():
		if u.position.distance_to(c) < side * 40.0:
			u.take_damage(99999.0, null)
	await _frame_ms(90)          # (they fall and lie down)
	var with := await _frame_ms(300)
	print("ROTLAB %s bodies %d in view: %.2f ms a frame (%.2f without them)" % [ProjectSettings.get_setting("application/config/version"), _lying(g), with, base])
	quit()
