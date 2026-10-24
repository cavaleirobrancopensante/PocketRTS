extends SceneTree
## The Officer's sabre and the foot soldiers' walk cadence (docs/animation_audit_units.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_unit_walk_audit.gd
##  1. the Officer's melee strips (light 3 frames, armoured 4, every view) carry a long sabre:
##     in every frame a steel blade at least 12 px across (the sheet's was 8 to 10 px; the armoured cocked frame has it behind the helm)
##  2. the Officer's walk strip has no oversized frame (head to boots within 2 px of the
##     median height in every view) and every strip's width divides by its frame count
##  3. men on foot walk at their own cadence (Unit.walk_fps_for), everything else at WALK_FPS
var fails := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		print("FAIL ", what)
		fails += 1


func strip(art: String, anim: String, d: String) -> Image:
	return Image.load_from_file("res://assets/units/%s/%s_%s.png" % [art, anim, d])


## widest span (px) of the steel blade right of the red coat in one cell of a strip
func blade_span(img: Image, cell: Vector2i, i: int) -> int:
	var red_x := -1
	for y in cell.y:
		for x in cell.x:
			var c := img.get_pixel(i * cell.x + x, y)
			if c.a > 0.5 and c.r > 0.47 and c.g < 0.28 and c.b < 0.28:
				red_x = maxi(red_x, x)
	var x0 := 999
	var x1 := -1
	var y0 := 999
	var y1 := -1
	for y in cell.y:
		for x in range(red_x + 1, cell.x):
			var c := img.get_pixel(i * cell.x + x, y)
			if c.a > 0.5 and c.get_luminance() > 0.7 and absf(c.r - c.b) < 0.12:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return 0
	return maxi(x1 - x0, y1 - y0) + 1


func body_height(img: Image, cell: Vector2i, i: int) -> int:
	var top := 999
	var bot := -1
	for y in cell.y:
		for x in cell.x:
			if img.get_pixel(i * cell.x + x, y).a > 0.5:
				top = mini(top, y)
				bot = maxi(bot, y)
				break
	return bot - top + 1


func _initialize() -> void:
	var cell := Vector2i(90, 36)
	for art in ["dismounted", "dismounted_armoured"]:
		var want: int = 3 if art == "dismounted" else 4
		for d in ["s", "se", "e", "ne", "n"]:
			var key: String = "melee_" + d
			var n: int = ArtData.UNITS[art]["frames"][key]
			var img := strip(art, "melee", d)
			check(n == want and img.get_width() == n * cell.x, "%s %s: %d frames, width fits" % [art, key, n])
			var short := 0
			for i in n:
				if blade_span(img, cell, i) < (0 if i == 0 and art == "dismounted_armoured" else 12):
					short += 1
			check(short == 0, "%s %s: a long sabre in every frame (%d short)" % [art, key, short])
			var wn: int = ArtData.UNITS[art]["frames"]["walk_" + d]
			var w := strip(art, "walk", d)
			check(w.get_width() == wn * cell.x, "%s walk_%s: width fits %d frames" % [art, d, wn])
			var hs: Array = []
			for i in wn:
				hs.append(body_height(w, cell, i))
			var sorted: Array = hs.duplicate()
			sorted.sort()
			var med: int = sorted[sorted.size() / 2]
			var worst := 0
			for h in hs:
				worst = maxi(worst, absi(int(h) - med))
			check(worst <= 2, "%s walk_%s: no oversized frame (worst %d px off the median)" % [art, d, worst])
	check(ArtData.UNITS["dismounted"]["frames"]["walk_e"] == 8, "Officer walks in 8 frames")
	for art in ["musketeer", "musketeer_armoured", "dismounted", "dismounted_armoured"]:
		check(Unit.walk_fps_for(art) == 12.0, "%s walks at 12 fps" % art)
	check(Unit.walk_fps_for("pikeman") == Unit.WALK_FPS, "the Pikeman keeps WALK_FPS")
	check(Unit.walk_fps_for("labourer") == Unit.WALK_FPS, "the Labourer keeps WALK_FPS")
	print("ALL PASS" if fails == 0 else "FAILED: %d" % fails)
	quit(1 if fails else 0)
