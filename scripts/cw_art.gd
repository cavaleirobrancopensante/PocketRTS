class_name CwArt
extends RefCounted
## Art of the Clockwork roster prototype (docs/clockwork_units_prototype.md). Every picture is read from a PNG
## under assets/units/<kind>/<anim>_<dir>.png when the file exists (the same strips as the other units: frames side
## by side, cell width = SHEETS' first number; drop real sheets in and the frame counts are read from them) and
## drawn here, in code, when it does not (docs/art_style_inconsistency.md). Placeholders: idle (1 frame), walk
## (2), death (1), in the five directions s se e ne n; the west views are the east ones mirrored by the sprite.
## Also the command-card icons (64 x 64) of the new units and abilities, drawn the same way.

const DIRS := ["s", "se", "e", "ne", "n"]
const ANIMS := ["idle", "walk", "attack", "death", "jump", "attack_up", "bomb"]
## kind -> [cell width, cell height, anchor x, anchor y (the feet)]
const SHEETS := {
	"tin_militia": [36, 40, 18, 36],
	"scrapper": [48, 50, 24, 45],
	"rail_rifleman": [36, 42, 18, 38],
	"work_car": [84, 56, 42, 48],
	"plate_wagon": [88, 58, 44, 50],
	"heavy_loco": [96, 66, 48, 56],
	"carrier_car": [92, 58, 46, 50],
	"tesla_loco": [88, 66, 44, 56],
	"storm_engine": [92, 70, 46, 58],
	# the new-style army (gear mode): real sheets only (tools/import_clock_soldier.py prints this line)
	"clock_soldier": [104, 83, 52, 70],
	# tier 2: the Jack (tools/import_jack.py prints this line); its walk is a hop, plus a JUMP strip (8 frames) and the raised
	# arm for shooting at flyers (attack_up)
	"jack": [108, 80, 54, 69],
	# the air (tools/import_cuckoo.py prints these): the Swift (fly loop as idle and walk, attack, death) and the Ticking Owl
	# (the same, its swoop as the attack, and the bomb drop)
	"cuckoo": [74, 55, 37, 44],
	"ticking_owl": [94, 81, 47, 69],
	# tier 3 (tools/import_tier3.py prints these): the Pendulum (idle sway, walk, the swing as its attack, death) and the
	# Netter (its walk's first frame as the idle, the trot, the recoil as its attack, death)
	"pendulum": [84, 93, 42, 84],
	"netter": [84, 58, 42, 54],
}

const TIN := Color(0.68, 0.72, 0.76)
const TIN_D := Color(0.42, 0.46, 0.52)
const STEEL := Color(0.30, 0.32, 0.37)
const STEEL_D := Color(0.17, 0.18, 0.21)
const RUST := Color(0.58, 0.32, 0.16)
const BRASS := Color(0.84, 0.66, 0.26)
const TEAM := Color(1.0, 0.0, 0.0)
const TEAM_D := Color(150.0 / 255.0, 0.0, 0.0)
const SPARK := Color(0.55, 0.85, 1.0)
const INK := Color(0.07, 0.07, 0.09)

static var _cache := {}


# ------------------------------------------------------------------ the loader

## The ArtData.UNITS entries of the new kinds: cell, anchor and the frame count of every strip (from the real
## file when there is one, else the placeholder's).
static func units() -> Dictionary:
	var out := {}
	for k in SHEETS:
		var sh: Array = SHEETS[k]
		var frames := {}
		for a in ANIMS:
			for dr in DIRS:
				var p := _path(k, a, dr)
				if ResourceLoader.exists(p):
					var t := load(p) as Texture2D
					if t != null:
						frames["%s_%s" % [a, dr]] = maxi(1, t.get_width() / int(sh[0]))
				elif a == "idle" or a == "death":
					frames["%s_%s" % [a, dr]] = 1
				elif a == "walk":
					frames["%s_%s" % [a, dr]] = 2
		out[k] = {"cell": Vector2i(int(sh[0]), int(sh[1])), "anchor": Vector2(float(sh[2]), float(sh[3])), "frames": frames}
	return out


static func _path(kind: String, anim: String, dir: String) -> String:
	return "res://assets/units/%s/%s_%s.png" % [kind, anim, dir]


## Is this `res://assets/units/<kind>/<anim>_<dir>.png` one of ours that has no file (so it is drawn here)?
static func is_placeholder(path: String) -> bool:
	if not path.begins_with("res://assets/units/"):
		return false
	var parts := path.trim_prefix("res://assets/units/").split("/")
	return parts.size() == 2 and SHEETS.has(parts[0]) and not ResourceLoader.exists(path)


## The strip for a placeholder path (cached).
static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var parts := path.trim_prefix("res://assets/units/").split("/")
	var kind := parts[0]
	var stem := parts[1].trim_suffix(".png")
	var us := stem.rfind("_")
	var anim := stem.substr(0, us)
	var dir := stem.substr(us + 1)
	var sh: Array = SHEETS[kind]
	var frames := 2 if anim == "walk" else 1
	var img := Image.create(int(sh[0]) * frames, int(sh[1]), false, Image.FORMAT_RGBA8)
	for f in frames:
		var cell := Image.create(int(sh[0]), int(sh[1]), false, Image.FORMAT_RGBA8)
		_paint(cell, kind, dir, f, anim == "death", sh)
		_outline(cell)
		img.blit_rect(cell, Rect2i(0, 0, int(sh[0]), int(sh[1])), Vector2i(f * int(sh[0]), 0))
	var t := ImageTexture.create_from_image(img)
	_cache[path] = t
	return t


# ------------------------------------------------------------------ the painter

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for yy in range(int(cy - r) - 1, int(cy + r) + 2):
		for xx in range(int(cx - r) - 1, int(cx + r) + 2):
			if Vector2(xx - cx, yy - cy).length() <= r:
				_px(img, xx, yy, c)


static func _ln(img: Image, a: Vector2, b: Vector2, c: Color, th := 1) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, float(n)))
		_fill(img, int(round(p.x)), int(round(p.y)), th, th, c)


## A dark rim round everything drawn (the other sprites have one).
static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5 and src.get_pixel(nx, ny) != INK:
					img.set_pixel(x, y, INK)
					break


## Which way the figure looks: x -1/0/1 (east, front or back, east), y -1 away / 1 toward the viewer.
static func _face(dir: String) -> Vector2:
	match dir:
		"s": return Vector2(0, 1)
		"se": return Vector2(1, 1)
		"e": return Vector2(1, 0)
		"ne": return Vector2(1, -1)
	return Vector2(0, -1)


static func _paint(img: Image, kind: String, dir: String, frame: int, dead: bool, sh: Array) -> void:
	var ax := float(sh[2])
	var ay := float(sh[3])
	var f := _face(dir)
	var bob := 1 if frame == 1 else 0
	if SHEETS[kind][0] >= 80:
		_paint_vehicle(img, kind, f, ax, ay, bob, dead)
	else:
		_paint_foot(img, kind, f, ax, ay, bob, dead)


# ------------------------------------------------------------------ foot units

static func _paint_foot(img: Image, kind: String, f: Vector2, ax: float, ay: float, bob: int, dead: bool) -> void:
	var x := int(ax)
	var y := int(ay)
	if dead:
		# a heap of scrap on the ground
		_fill(img, x - 10, y - 5, 20, 5, TIN_D)
		_fill(img, x - 6, y - 8, 10, 4, STEEL)
		_fill(img, x + 2, y - 6, 8, 3, RUST)
		return
	var big := kind == "scrapper"
	var sc := 1.45 if big else 1.0
	var bw := int(round(10.0 * sc))
	var bh := int(round(13.0 * sc))
	var legs := int(round(8.0 * sc))
	# legs (a step on the second frame)
	_fill(img, x - bw / 2 + 1, y - legs + bob, 3, legs - bob, STEEL_D)
	_fill(img, x + bw / 2 - 4, y - legs + (1 - bob), 3, legs - (1 - bob), STEEL_D)
	# body
	var body := TIN if kind != "scrapper" else RUST
	_fill(img, x - bw / 2, y - legs - bh, bw, bh, body)
	_fill(img, x - bw / 2, y - legs - bh, bw, 2, TIN_D if kind != "scrapper" else STEEL)
	# the team's sash
	if f.y >= 0.0:
		_fill(img, x - bw / 2, y - legs - bh / 2, bw, 2, TEAM)
	else:
		_fill(img, x - bw / 2, y - legs - bh + 3, bw, 2, TEAM_D)
	# head
	var hy := y - legs - bh - 5
	_disc(img, x, hy + 2, 4.0 * (1.2 if big else 1.0), TIN)
	_fill(img, x - 4, hy - 1, 8, 2, TIN_D)
	if f.y > 0.0 or f.x != 0.0:
		_px(img, x + int(f.x) * 2 - 1, hy + 2, INK)
		_px(img, x + int(f.x) * 2 + 1, hy + 2, INK)
	# the weapon, held out the way it looks
	var hand := Vector2(x + f.x * 6.0, y - legs - bh * 0.6 + f.y * 2.0)
	match kind:
		"tin_militia":
			_ln(img, hand - Vector2(f.x, f.y * 0.5) * 6.0, hand + Vector2(f.x, f.y * 0.6) * 12.0 + Vector2(0, -3), BRASS)
			_disc(img, hand.x + f.x * 12.0, hand.y + f.y * 7.0 - 3.0, 1.6, TIN)
		"scrapper":
			# a big cutting arm: a slab of scrap with teeth
			var tip := hand + Vector2(f.x * 9.0 + (4.0 if f.x == 0.0 else 0.0), f.y * 4.0 - 2.0)
			_ln(img, hand, tip, STEEL, 4)
			for i in 3:
				_px(img, int(tip.x) + i * 2 - 2, int(tip.y) - 3, TIN)
			_fill(img, x - bw / 2 - 3, y - legs - bh - 1, 5, 6, STEEL)
		"rail_rifleman":
			_ln(img, hand - Vector2(f.x, f.y * 0.5) * 5.0, hand + Vector2(f.x, f.y * 0.5) * 14.0 + Vector2(0, -2), STEEL_D, 2)
			_disc(img, hand.x + f.x * 14.0, hand.y + f.y * 7.0 - 2.0, 1.8, SPARK)


# ------------------------------------------------------------------ the vehicles

static func _wheels(img: Image, x0: int, x1: int, y: int, n: int, bob: int, r := 4) -> void:
	for i in n:
		var cx := x0 + (x1 - x0) * i / maxi(1, n - 1)
		_disc(img, cx, y - r + 1, float(r), STEEL_D)
		_disc(img, cx, y - r + 1, float(r) - 2.0, TIN_D)
		_px(img, cx + (bob * 2 - 1), y - r + 1, BRASS)


static func _paint_vehicle(img: Image, kind: String, f: Vector2, ax: float, ay: float, bob: int, dead: bool) -> void:
	var x := int(ax)
	var y := int(ay)
	var side := f.x != 0.0                # a side view (else: seen from the front or the back)
	var lw := 34 if side else 14          # half-length on screen
	if dead:
		_fill(img, x - 24, y - 7, 48, 7, STEEL_D)
		_fill(img, x - 12, y - 12, 22, 6, RUST)
		_fill(img, x + 6, y - 9, 14, 4, TIN_D)
		return
	# the rail under it
	_fill(img, x - lw - 2, y - 2, lw * 2 + 4, 2, STEEL_D)
	var top := y - 8                       # the deck line
	var col := STEEL
	match kind:
		"work_car":
			_wheels(img, x - lw + 8, x + lw - 8, y, 3 if side else 2, bob)
			_fill(img, x - lw, top - 6, lw * 2, 7, RUST)
			_fill(img, x - lw, top - 6, lw * 2, 2, BRASS)
			if side:
				# the crew hut and crates
				_fill(img, x - lw + 4, top - 22, 22, 17, TIN_D)
				_fill(img, x - lw + 4, top - 24, 22, 3, TEAM)
				_fill(img, x - lw + 8, top - 18, 6, 6, INK)
				for i in 2:
					_fill(img, x + 4 + i * 11, top - 15, 9, 9, BRASS)
					_fill(img, x + 4 + i * 11, top - 15, 9, 1, RUST)
				_ln(img, Vector2(x + lw - 6, top - 6), Vector2(x + lw - 6, top - 26), STEEL_D, 2)
				_ln(img, Vector2(x + lw - 6, top - 26), Vector2(x + lw + 4, top - 18), STEEL_D)
			else:
				_fill(img, x - 8, top - 20, 16, 14, TIN_D)
				_fill(img, x - 8, top - 22, 16, 3, TEAM)
		"plate_wagon":
			_wheels(img, x - lw + 8, x + lw - 8, y, 3 if side else 2, bob)
			_fill(img, x - lw, top - 5, lw * 2, 6, STEEL_D)
			# the side plates: tall slabs of steel with rivets, shields up by day
			var ph := 22
			if side:
				_fill(img, x - lw + 2, top - 5 - ph, lw * 2 - 4, ph, col)
				_fill(img, x - lw + 2, top - 5 - ph, lw * 2 - 4, 3, TIN)
				for i in 6:
					_px(img, x - lw + 8 + i * 11, top - ph, TIN)
					_px(img, x - lw + 8 + i * 11, top - 12, TIN)
				_fill(img, x - lw + 2, top - 5 - ph + 8, lw * 2 - 4, 2, TEAM)
			else:
				_fill(img, x - 14, top - 5 - ph, 28, ph, col)
				_fill(img, x - 14, top - 5 - ph, 28, 3, TIN)
				_fill(img, x - 14, top - 5 - ph + 8, 28, 2, TEAM)
		"carrier_car":
			_wheels(img, x - lw + 8, x + lw - 8, y, 3 if side else 2, bob)
			_fill(img, x - lw, top - 5, lw * 2, 6, STEEL_D)
			# the landing deck: a wide flat top with yellow chevrons and an H
			var dw := lw + 8 if side else 24
			_fill(img, x - dw, top - 11, dw * 2, 6, TIN_D)
			_fill(img, x - dw, top - 12, dw * 2, 1, TIN)
			for i in 5:
				var cx := x - dw + 6 + i * (dw * 2 - 12) / 4
				_fill(img, cx, top - 10, 3, 3, BRASS)
			_fill(img, x - 5, top - 10, 2, 4, TEAM)
			_fill(img, x + 3, top - 10, 2, 4, TEAM)
			_fill(img, x - 5, top - 9, 10, 1, TEAM)
			if side:
				_ln(img, Vector2(x - dw, top - 11), Vector2(x - dw, top - 16), STEEL_D)
				_ln(img, Vector2(x + dw, top - 11), Vector2(x + dw, top - 16), STEEL_D)
		"heavy_loco", "tesla_loco", "storm_engine":
			_wheels(img, x - lw + 8, x + lw - 8, y, 4 if side else 2, bob, 5 if kind == "heavy_loco" else 4)
			var hull := STEEL_D if kind == "heavy_loco" else (Color(0.2, 0.26, 0.38) if kind == "tesla_loco" else Color(0.26, 0.2, 0.36))
			var hh := 18 if kind == "heavy_loco" else 15
			_fill(img, x - lw, top - hh, lw * 2, hh + 1, hull)
			_fill(img, x - lw, top - hh, lw * 2, 3, STEEL)
			_fill(img, x - lw, top - 3, lw * 2, 2, BRASS)
			_fill(img, x - lw, top - hh + 4, lw * 2, 2, TEAM)
			if side:
				# cab at the back (west), boiler front
				_fill(img, x - lw, top - hh - 12, 15, 13, STEEL)
				_fill(img, x - lw + 3, top - hh - 9, 5, 5, INK)
				_fill(img, x - lw, top - hh - 14, 15, 3, TEAM_D)
				_fill(img, x + 14, top - hh - 7, 5, 8, STEEL_D)      # chimney
			else:
				_fill(img, x - 10, top - hh - 10, 20, 11, STEEL)
				_fill(img, x - 4, top - hh - 7, 8, 5, INK)
			match kind:
				"heavy_loco":
					# turret and cannon barrel pointing the way it looks
					var tc := Vector2(x + (4 if side else 0), top - hh - 8)
					_disc(img, tc.x, tc.y, 9.0, STEEL)
					_disc(img, tc.x, tc.y - 2.0, 5.0, TIN_D)
					var muzzle := tc + Vector2(f.x * 20.0, f.y * 6.0 - 1.0)
					_ln(img, tc, muzzle, STEEL_D, 4)
					_disc(img, muzzle.x, muzzle.y, 2.2, INK)
				"tesla_loco":
					var tc2 := Vector2(x + (2 if side else 0), top - hh - 4)
					_fill(img, int(tc2.x) - 2, int(tc2.y) - 14, 4, 14, BRASS)
					_disc(img, tc2.x, tc2.y - 16.0, 5.0, SPARK)
					_disc(img, tc2.x, tc2.y - 16.0, 2.5, Color.WHITE)
					for i in 3:
						var a := float(i) * TAU / 3.0 + float(bob) * 0.5
						_ln(img, Vector2(tc2.x, tc2.y - 16.0), Vector2(tc2.x, tc2.y - 16.0) + Vector2.from_angle(a) * 8.0, SPARK)
				"storm_engine":
					var sc2 := Vector2(x + (2 if side else 0), top - hh - 4)
					_ln(img, sc2, sc2 + Vector2(0, -20), STEEL_D, 2)
					_disc(img, sc2.x, sc2.y - 22.0, 6.0, Color(0.55, 0.5, 0.75))
					_disc(img, sc2.x - 5.0, sc2.y - 19.0, 4.5, Color(0.42, 0.38, 0.62))
					_disc(img, sc2.x + 5.0, sc2.y - 19.0, 4.5, Color(0.42, 0.38, 0.62))
					_ln(img, sc2 + Vector2(0, -16), sc2 + Vector2(-3, -9), SPARK)


# ------------------------------------------------------------------ command-card icons (64 x 64)

## An icon for a new unit (its kind) or a new command (ab_*): a stand-in drawn in code, or null.
static func icon(name: String) -> Texture2D:
	var key := "icon:" + name
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if SHEETS.has(name):
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		_fill(img, 0, 0, 64, 64, Color(0.16, 0.15, 0.17))
		_fill(img, 0, 0, 64, 2, BRASS)
		_fill(img, 0, 62, 64, 2, BRASS)
		var sh: Array = SHEETS[name]
		var cell := Image.create(int(sh[0]), int(sh[1]), false, Image.FORMAT_RGBA8)
		_paint(cell, name, "e", 0, false, sh)
		_outline(cell)
		# the figure, doubled, centred
		var big := cell.duplicate() as Image
		var sc := 1.6 if int(sh[0]) < 80 else 0.62
		big.resize(int(cell.get_width() * sc), int(cell.get_height() * sc), Image.INTERPOLATE_NEAREST)
		var ox := (64 - big.get_width()) / 2
		var oy := 60 - big.get_height()
		img.blend_rect(big, Rect2i(0, 0, big.get_width(), big.get_height()), Vector2i(ox, oy))
		t = ImageTexture.create_from_image(img)
	elif name.begins_with("ab_cw_") or name == "ab_siding":
		var img2 := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		_fill(img2, 0, 0, 64, 64, Color(0.16, 0.15, 0.17))
		_fill(img2, 0, 0, 64, 2, SPARK)
		_fill(img2, 0, 62, 64, 2, SPARK)
		_ability_glyph(img2, name)
		t = ImageTexture.create_from_image(img2)
	_cache[key] = t
	return t


static func _ability_glyph(img: Image, name: String) -> void:
	match name:
		"ab_siding":
			_ln(img, Vector2(8, 40), Vector2(56, 40), TIN, 4)
			_ln(img, Vector2(20, 40), Vector2(30, 24), TIN, 4)
			_ln(img, Vector2(30, 24), Vector2(52, 24), TIN, 4)
			for i in 6:
				_fill(img, 10 + i * 8, 44, 3, 6, RUST)
		"ab_cw_couple":
			_fill(img, 4, 30, 24, 14, STEEL)
			_fill(img, 36, 30, 24, 14, RUST)
			_fill(img, 4, 30, 24, 3, TIN)
			_fill(img, 36, 30, 24, 3, BRASS)
			_ln(img, Vector2(26, 38), Vector2(38, 38), TIN, 4)
			_disc(img, 32, 38, 4.0, BRASS)
			_wheels(img, 10, 22, 48, 2, 0, 3)
			_wheels(img, 42, 54, 48, 2, 0, 3)
			_ln(img, Vector2(8, 52), Vector2(56, 52), SPARK, 2)
		"ab_cw_uncouple":
			_fill(img, 4, 30, 20, 14, STEEL)
			_fill(img, 40, 30, 20, 14, RUST)
			_fill(img, 4, 30, 20, 3, TIN)
			_fill(img, 40, 30, 20, 3, BRASS)
			_ln(img, Vector2(24, 38), Vector2(30, 38), TIN, 3)
			_ln(img, Vector2(34, 38), Vector2(40, 38), TIN, 3)
			_ln(img, Vector2(28, 20), Vector2(36, 28), SPARK, 3)
			_ln(img, Vector2(36, 20), Vector2(28, 28), SPARK, 3)
			_wheels(img, 8, 20, 48, 2, 0, 3)
			_wheels(img, 44, 56, 48, 2, 0, 3)
			_ln(img, Vector2(8, 52), Vector2(56, 52), SPARK, 2)
		"ab_cw_crew_out":
			_disc(img, 32, 20, 7.0, TIN)
			_fill(img, 24, 28, 16, 18, TIN_D)
			_ln(img, Vector2(14, 50), Vector2(50, 50), BRASS, 3)
			_ln(img, Vector2(44, 12), Vector2(54, 22), SPARK, 3)
		"ab_cw_crew_in":
			_fill(img, 12, 26, 40, 24, RUST)
			_fill(img, 12, 26, 40, 4, BRASS)
			_disc(img, 32, 14, 6.0, TIN)
			_ln(img, Vector2(32, 22), Vector2(32, 30), SPARK, 3)
		"ab_cw_plates":
			_fill(img, 8, 12, 14, 40, STEEL)
			_fill(img, 42, 12, 14, 40, STEEL)
			_fill(img, 24, 28, 16, 24, TIN_D)
			_fill(img, 8, 12, 14, 3, TIN)
			_fill(img, 42, 12, 14, 3, TIN)
		"ab_cw_setup":
			_fill(img, 12, 38, 40, 10, STEEL)
			_disc(img, 32, 32, 9.0, TIN_D)
			_ln(img, Vector2(32, 32), Vector2(54, 22), STEEL_D, 5)
			_ln(img, Vector2(10, 52), Vector2(54, 52), BRASS, 3)
		"ab_cw_pack":
			_fill(img, 12, 26, 40, 14, STEEL)
			_wheels(img, 18, 46, 46, 3, 0, 4)
			_ln(img, Vector2(8, 52), Vector2(56, 52), SPARK, 3)
		"ab_cw_board":
			_fill(img, 14, 22, 36, 26, STEEL)
			_disc(img, 32, 14, 6.0, TIN)
			_ln(img, Vector2(32, 6), Vector2(32, 20), SPARK, 3)
		"ab_cw_dock":
			_fill(img, 8, 44, 48, 8, TIN_D)
			_fill(img, 28, 46, 8, 3, TEAM)
			_ln(img, Vector2(14, 20), Vector2(32, 34), TIN, 3)
			_ln(img, Vector2(50, 20), Vector2(32, 34), TIN, 3)
			_disc(img, 32, 36, 5.0, BRASS)
		"ab_cw_carry":
			_disc(img, 32, 40, 8.0, TIN)
			_ln(img, Vector2(10, 18), Vector2(32, 28), TIN, 3)
			_ln(img, Vector2(54, 18), Vector2(32, 28), TIN, 3)
			_ln(img, Vector2(32, 28), Vector2(32, 36), BRASS, 2)
		"ab_cw_drop":
			_disc(img, 32, 20, 7.0, TIN)
			_ln(img, Vector2(32, 28), Vector2(32, 52), SPARK, 3)
			_ln(img, Vector2(24, 44), Vector2(32, 52), SPARK, 3)
			_ln(img, Vector2(40, 44), Vector2(32, 52), SPARK, 3)
		"ab_cw_thunder":
			_disc(img, 28, 20, 12.0, Color(0.5, 0.46, 0.7))
			_disc(img, 40, 22, 10.0, Color(0.42, 0.38, 0.62))
			_ln(img, Vector2(34, 32), Vector2(28, 44), SPARK, 3)
			_ln(img, Vector2(28, 44), Vector2(38, 44), SPARK, 3)
			_ln(img, Vector2(38, 44), Vector2(30, 58), SPARK, 3)
