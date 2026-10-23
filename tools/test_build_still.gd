extends SceneTree
## The labourer's hammering keeps his body still (tools/import_build_still.py): in every
## build_<dir> strip the legs, torso and head (everything outside the arm box) are
## pixel-identical in all frames, and only the arm region differs between frames.
##   godot --headless --script res://tools/test_build_still.gd
const ARM := {"s": Rect2i(21, 12, 15, 18), "se": Rect2i(21, 12, 15, 10), "e": Rect2i(21, 9, 17, 14),
	"ne": Rect2i(26, 0, 16, 28), "n": Rect2i(21, 12, 15, 16)}
const STAKE := {"s": Rect2i(25, 24, 8, 11), "se": Rect2i(24, 22, 9, 13), "e": Rect2i(22, 23, 8, 12)}
var fails := 0


func _initialize() -> void:
	for d in ["s", "se", "e", "ne", "n"]:
		var im: Image = (load("res://assets/units/labourer/build_%s.png" % d) as Texture2D).get_image()
		var n: int = im.get_width() / 42
		var frames: Array = []
		for i in n:
			frames.append(im.get_region(Rect2i(i * 42, 0, 42, 35)))
		var ref := 1 if d in ["ne", "n"] else 0
		var outside := 0
		var inside := 0
		for i in range(n):
			if i == ref:
				continue
			for y in 35:
				for x in 42:
					var p := Vector2i(x, y)
					var a: Color = frames[ref].get_pixelv(p)
					var b: Color = frames[i].get_pixelv(p)
					if a.is_equal_approx(b) or (a.a == 0.0 and b.a == 0.0):
						continue
					if ARM[d].has_point(p) and not (STAKE.has(d) and STAKE[d].has_point(p)):
						inside += 1
					else:
						outside += 1
		var ok := outside == 0 and inside > 8
		print(("PASS  " if ok else "FAIL  ") + "build_%s: %d frames, %d px differ outside the arm box, %d inside it" % [d, n, outside, inside])
		if not ok:
			fails += 1
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
