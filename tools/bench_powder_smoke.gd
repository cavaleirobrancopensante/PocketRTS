extends "res://tools/shot_powder_smoke.gd"
## What the BLACK POWDER SMOKE costs (docs/powder_smoke.md): 32 Musketeers and 3 Field Cannons a side trading fire
## (no damage, so all of them fire all the while) for 60 s in view, every frame's real time measured:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 60 --script res://tools/bench_powder_smoke.gd -- <outdir> smoke:<0|1|2>
## (headless too: the game's side only.) Prints "BENCH smoke=<lv> avg ms, 1% low ms, smoke ms per frame, puffs".

var _ft := PackedFloat32Array()
var _last := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("smoke:"):
			lv = int(a.substr(6))
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	PowderSmoke.force = lv
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _run() -> void:
	seed(4242)
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "town_hall":
			hall = b
	var open := _open_ground(hall)
	g.reveal = true          # (everything in view: the worst case for drawing)
	var mine: Array = []
	var theirs: Array = []
	for i in 32:
		mine.append(_shooter("musketeer", 0, open + Vector2(-170 + (i % 2) * 14 - (i / 16) * 30, -240 + (i % 16) * 30), Vector2.RIGHT))
		theirs.append(_shooter("musketeer", 1, open + Vector2(170 - (i % 2) * 14 + (i / 16) * 30, -240 + (i % 16) * 30), Vector2.LEFT))
	for i in 3:
		mine.append(_shooter("cannon", 0, open + Vector2(-280, -120 + i * 120), Vector2.RIGHT))
		theirs.append(_shooter("cannon", 1, open + Vector2(280, -120 + i * 120), Vector2.LEFT))
	g.camera.position = open
	g.camera.zoom = Vector2(0.8, 0.8)
	for i in mine.size():
		mine[i].cmd_attack(theirs[i % theirs.size()])
		theirs[i].cmd_attack(mine[i % mine.size()])
	var e := 0.0
	var smoke0 := 0
	var peak := 0
	while e < 62.0:
		await process_frame
		var now := Time.get_ticks_usec()
		if e > 2.0:
			_ft.append((now - _last) / 1000.0)
		elif e > 1.9:
			Prof.flush()
			smoke0 = int(Prof.us.get("powder smoke", 0))
		_last = now
		e += 1.0 / 60.0
		if g.powder_smoke:
			peak = maxi(peak, g.powder_smoke.alive)
	Prof.flush()
	var smoke := int(Prof.us.get("powder smoke", 0)) - smoke0
	var s := _ft.duplicate()
	s.sort()
	var tot := 0.0
	for f in _ft:
		tot += f
	var k := maxi(1, s.size() / 100)
	var low := 0.0
	for i in k:
		low += s[s.size() - 1 - i]
	print("BENCH smoke=%d frames=%d avg %.2f ms, median %.2f ms, 1%% low %.2f ms, smoke %.3f ms a frame, puffs made %d, peak alive %d" % [
		lv, _ft.size(), tot / _ft.size(), s[s.size() / 2], low / k, smoke / 1000.0 / _ft.size(),
		g.powder_smoke.made if g.powder_smoke else 0, peak])
	await _snap("bench_smoke%d" % lv)
	quit(0)
