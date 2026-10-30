extends "res://tools/shot_powder_smoke.gd"
## THE 30-MUSKETEER VOLLEY (docs/powder_smoke.md, "Clippy, blinky and too long", 0.24.2): 30 Musketeers and 4 Field
## Cannons fire at a line of dummies for 12 s, then stop; pictures 0.5 s apart at the start, then while the cloud clears,
## and once a second a line "CLOUD t=<s> alive=<n> peak=<the most smoke over one 64 px square, as summed alpha>":
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_powder_volley.gd -- <outdir> [light|thick]
## (THICK is the default level of the game, and of this tool.)


func _initialize() -> void:
	lv = PowderSmoke.THICK
	if "light" in OS.get_cmdline_user_args():
		lv = 1
	if "full" in OS.get_cmdline_user_args():
		lv = 2
	PowderSmoke.force = lv
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


var _clk := 0.0
var _next_cloud := 0.0


## The most smoke over one 64 px square: the drawn puffs' alpha summed by the square their centre is in.
func cloud_peak() -> float:
	var ps: PowderSmoke = g.powder_smoke
	var mm: MultiMesh = ps._mm
	var n := mm.visible_instance_count
	var b := ps._buf
	var cells := {}
	var top := 0.0
	for i in n:
		var o := i * 16
		var k := Vector2i(int(floor(b[o + 3] / 64.0)), int(floor(b[o + 7] / 64.0)))
		var s: float = cells.get(k, 0.0) + b[o + 11]
		cells[k] = s
		top = maxf(top, s)
	return top


func _step(secs: float) -> void:
	var e := 0.0
	while e < secs:
		await process_frame
		e += 1.0 / 30.0
		_clk += 1.0 / 30.0
		if _clk >= _next_cloud:
			_next_cloud += 1.0
			print("CLOUD t=%4.1f alive=%d peak=%.2f" % [_clk, g.powder_smoke.alive, cloud_peak()])


func _shot(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img = img.get_region(_mid(1200, 680))
	img.save_jpg("%s/%s.jpg" % [out, name], 0.85)


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "town_hall":
			hall = b
	_ui(false)
	var open := _open_ground(hall)
	for u in g.units.filter(func(u: Unit) -> bool: return not u.dead):
		u.position = hall.center() + Vector2(0, 60)
	var mine: Array = []
	var theirs: Array = []
	for i in 30:
		mine.append(_shooter("musketeer", 0, open + Vector2(-150 - (i / 15) * 26 + (i % 2) * 8, -210 + (i % 15) * 30), Vector2.RIGHT))
		theirs.append(_dummy("musketeer", open + Vector2(150, -210 + (i % 15) * 30 + (i / 15) * 15)))
	for i in 4:
		mine.append(_shooter("cannon", 0, open + Vector2(-250, -150 + i * 100), Vector2.RIGHT))
	g.camera.position = open
	g.camera.zoom = Vector2.ONE
	for f in 30:
		await process_frame
	_clk = 0.0
	for i in mine.size():
		mine[i].cmd_attack(theirs[i % theirs.size()])
	for k in 4:
		await _step(0.5)
		_shot("v%d_fire_%.1fs" % [k + 1, (k + 1) * 0.5])
	await _step(4.0)
	_shot("v5_fire_6s")
	await _step(6.0)
	_shot("v6_fire_12s")
	for u in theirs:
		_gone(u)
	for u in mine:
		u.cmd_stop()
	var shots := [[5.0, "v7_after_5s"], [5.0, "v8_after_10s"], [5.0, "v9_after_15s"], [5.0, "v10_after_20s"], [10.0, "v11_after_30s"]]
	for s in shots:
		await _step(s[0])
		_shot(s[1])
	print("VOLLEY lv=%d made %d, alive at the end %d" % [lv, g.powder_smoke.made, g.powder_smoke.alive])
	quit(0)
