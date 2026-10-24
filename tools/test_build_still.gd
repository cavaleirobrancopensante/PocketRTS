extends SceneTree
## The labourer's hammering keeps his legs and the stake still (tools/import_labourer_redraw.py,
## BUILD_PIN): in every build_<dir> strip the rows from PIN down (boots, trousers, stake) are
## pixel-identical in all four frames, and the rows above them (head, arm, hammer) do move, with
## the hammer raised high in frame 0 and on the stake in frame 2.
##   godot --headless --script res://tools/test_build_still.gd
const PIN := 24
var fails := 0


func _initialize() -> void:
	for d in ["s", "se", "e", "ne", "n"]:
		var im: Image = (load("res://assets/units/labourer/build_%s.png" % d) as Texture2D).get_image()
		var n: int = im.get_width() / 42
		var frames: Array = []
		for i in n:
			frames.append(im.get_region(Rect2i(i * 42, 0, 42, 35)))
		var below := 0
		var above := 0
		for i in range(n):
			if i == 2:
				continue
			for y in 35:
				for x in 42:
					var p := Vector2i(x, y)
					var a: Color = frames[2].get_pixelv(p)
					var b: Color = frames[i].get_pixelv(p)
					if a.is_equal_approx(b) or (a.a == 0.0 and b.a == 0.0):
						continue
					if y >= PIN:
						below += 1
					else:
						above += 1
		# the raised hammer: the top of frame 0's figure is well above the strike frame's
		var top0 := _top(frames[0])
		var top2 := _top(frames[2])
		var ok := n == 4 and below == 0 and above > 40 and top0 <= top2 - 3
		print(("PASS  " if ok else "FAIL  ") + "build_%s: %d frames, %d px differ in the pinned rows, %d above them, hammer top row %d raised vs %d on the stake" % [d, n, below, above, top0, top2])
		if not ok:
			fails += 1
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _top(im: Image) -> int:
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.0:
				return y
	return im.get_height()
