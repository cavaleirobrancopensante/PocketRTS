class_name CliffArt
extends RefCounted
## How cliffs read (drawn once into the baked ground pictures: Game._render_ground, no per-frame
## cost, and nothing here touches the height map, the ramps or what is solid).
##
## A cliff cell is a ring cell of a plateau (Game.cliff): solid, never walked. This paints, over
## the cell's ordinary ground picture and by what is open beside it:
##   * LOW GROUND side, the cell has low ground to its south: a clean vertical rock wall. The cell
##     is one straight-edged strip of rock (a light upper lip, a dark crease under it, vertical
##     streaks of a few shades, a shade that darkens toward a dark foot line) instead of one
##     ragged tile picture per cell; steps in the wall get a dark edge where it ends; a soft
##     shadow lies on the low ground under it.
##   * HIGH GROUND side, a cell with low ground to its north, east or west (and every wall's
##     top): a narrow dark contour along the rim, a lighter lip beside it, and a soft shadow
##     (ambient occlusion) on the low ground right below the edge.
## A side that opens on a ramp gets none of it (a ramp must still read as a ramp). Colours come
## from each biome's own tiles (its cliff face, its ground), so every theme keeps its look.

const T := Defs.TILE
const VARIANTS := 6
const SHADOW_FACE := 15       # px of shadow under a wall
const SHADOW_AO := 9          # px of shadow beside the other rims

var g: Game
var _cache := {}              # biome name -> piece images


func _init(game: Game) -> void:
	g = game


func _low(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= g.W or y >= g.H:
		return false
	var i := y * g.W + x
	return g.height[i] == 0 and g.ramp[i] == 0


func _cliff(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < g.W and y < g.H and g.cliff[y * g.W + x] == 1


## True for a cell drawn as a wall: a cliff cell with low ground (not a ramp) to its south.
func is_wall(x: int, y: int) -> bool:
	return _cliff(x, y) and _low(x, y + 1)


## Paints the cliffs of every cell in `cr` (and the shadows that fall into it from the
## cells round it) onto img, which holds exactly the cells of cr.
func paint(img: Image, cr: Rect2i) -> void:
	var area := cr.grow(1).intersection(Rect2i(0, 0, g.W, g.H))
	var full := Rect2i(0, 0, T, T)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if g.cliff[y * g.W + x] != 1:
				continue
			var p := _pieces(g.mapgen.biome_at(x, y))
			var at := (Vector2i(x, y) - cr.position) * T
			var n := _low(x, y - 1)
			var s := _low(x, y + 1)
			var w := _low(x - 1, y)
			var e := _low(x + 1, y)
			# the shadows on the low ground first (the cell's own picture goes over nothing of them)
			if s:
				img.blend_rect(p["shadow_s"], full, at + Vector2i(0, T))
			if n:
				img.blend_rect(p["ao_n"], full, at + Vector2i(0, -T))
			if w:
				img.blend_rect(p["ao_w"], full, at + Vector2i(-T, 0))
			if e:
				img.blend_rect(p["ao_e"], full, at + Vector2i(T, 0))
			if s:
				# the wall, its ends: dark where the wall ends against low ground, lighter where
				# it steps against the plateau (a wall next to it is just as high: no end)
				img.blit_rect(p["wall"][(x * 7 + y * 3 + (x >> 2)) % VARIANTS], full, at)
				var wl := is_wall(x - 1, y)
				var wr := is_wall(x + 1, y)
				if not wl:
					img.blend_rect(p["cap_l_open"] if w else p["cap_l_step"], full, at)
				if not wr:
					img.blend_rect(p["cap_r_open"] if e else p["cap_r_step"], full, at)
			if n:
				img.blend_rect(p["rim_n"], full, at)
			if w and not s:
				img.blend_rect(p["rim_w"], full, at)
			if e and not s:
				img.blend_rect(p["rim_e"], full, at)
			if not (n or s or w or e):
				# a corner open only on its diagonal
				if _low(x - 1, y - 1):
					img.blend_rect(p["dot_tl"], full, at)
				if _low(x + 1, y - 1):
					img.blend_rect(p["dot_tr"], full, at)
				if _low(x - 1, y + 1):
					img.blend_rect(p["dot_bl"], full, at)
				if _low(x + 1, y + 1):
					img.blend_rect(p["dot_br"], full, at)


# ------------------------------------------------------------------ the pieces

func _pieces(bn: String) -> Dictionary:
	if _cache.has(bn):
		return _cache[bn]
	var b: Dictionary = MapGen.BIOMES[bn]
	var face_key: String = g._tile_key(b["face"], 0)
	g._tile(b["face"], 0)
	var fa: Color = g._tile_avg.get(face_key, Color(0.45, 0.38, 0.3))
	var low: Array = b["low"]
	var top_key: String = g._tile_key(low[0], 1)
	g._tile(low[0], 1)
	var ta: Color = g._tile_avg.get(top_key, Color(0.3, 0.5, 0.2))
	# the wall's own colour: the face picture's mean, a little richer and not lighter than the
	# plateau it holds up (a pale face on dark ground, or the reverse, would not read as a wall)
	fa = _rock_colour(g._tile(b["face"], 0), fa)
	var wall := Color.from_hsv(fa.h, clampf(fa.s * 1.1, 0.0, 0.6), clampf(fa.v * 1.0, 0.3, 0.6))
	var lip := ta.lerp(Color.WHITE, 0.32)
	lip = Color(minf(lip.r * 1.12, 1.0), minf(lip.g * 1.12, 1.0), minf(lip.b * 1.12, 1.0))
	var dark := Color(wall.r * 0.22, wall.g * 0.22, wall.b * 0.22)
	var p := {}
	var walls: Array = []
	for v in VARIANTS:
		walls.append(_wall(wall, lip, dark, v))
	p["wall"] = walls
	p["cap_l_open"] = _cap(dark, true, true)
	p["cap_l_step"] = _cap(dark, true, false)
	p["cap_r_open"] = _cap(dark, false, true)
	p["cap_r_step"] = _cap(dark, false, false)
	p["rim_n"] = _rim(dark, lip, 0)
	p["rim_e"] = _rim(dark, lip, 1)
	p["rim_w"] = _rim(dark, lip, 2)
	p["dot_tl"] = _dot(dark, 0)
	p["dot_tr"] = _dot(dark, 1)
	p["dot_bl"] = _dot(dark, 2)
	p["dot_br"] = _dot(dark, 3)
	p["shadow_s"] = _shadow_s()
	p["ao_n"] = _ao(0)
	p["ao_e"] = _ao(1)
	p["ao_w"] = _ao(2)
	_cache[bn] = p
	return p


## The rock of a face picture: the mean of its darker half (the moss, grass or snow that
## fringes the picture is the lighter and brighter part).
static func _rock_colour(im: Image, fallback: Color) -> Color:
	var lums: Array = []
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.5:
				lums.append(c.get_luminance())
	if lums.is_empty():
		return fallback
	lums.sort()
	var cut: float = lums[lums.size() / 2]
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() <= cut:
				sum += c
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0) if n > 0 else fallback


static func _blank() -> Image:
	return Image.create(T, T, false, Image.FORMAT_RGBA8)


static func _vnoise(x: float) -> float:
	var ix := int(floor(x))
	var f := x - ix
	f = f * f * (3.0 - 2.0 * f)
	var a := fposmod(sin(ix * 127.1) * 43758.5453, 1.0)
	var b := fposmod(sin((ix + 1) * 127.1) * 43758.5453, 1.0)
	return lerpf(a, b, f)


## One 32 x 32 wall: lip rows, a dark crease, vertical streaks (their own shades column by column),
## a shade that darkens down to a dark foot line, a few strata cracks.
func _wall(wall: Color, lip: Color, dark: Color, v: int) -> Image:
	var im := _blank()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 9000 + v
	var cracks: Array = []
	for k in 3:
		cracks.append([rnd.randi_range(8, 24), rnd.randi() % 7, rnd.randi_range(5, 11)])
	for x in T:
		var s := 0.55 * _vnoise(x * 0.42 + v * 17.3) + 0.45 * _vnoise(x * 0.13 + v * 5.1 + 40.0)
		var mult := 0.78 + 0.44 * s
		for y in T:
			var c: Color
			if y < 3:
				c = lip * (0.96 + 0.1 * s) if y > 0 else lip * 0.8
			elif y < 5:
				c = wall * 0.5
			elif y < T - 4:
				var t := float(y - 5) / float(T - 10)
				c = wall * (1.1 - 0.46 * t) * mult
				for cr in cracks:
					if y == cr[0] and ((x / int(cr[2])) + int(cr[1])) % 3 == 0:
						c = c * 0.78
			elif y < T - 1:
				c = wall * 0.5 * mult
			else:
				c = dark
			if y >= 5 and y < T - 4:
				# rock: blotches that run vertically, and a grain
				var bl := _vnoise(x * 0.55 + _vnoise(y * 0.16 + v * 3.0) * 3.0 + v * 7.0)
				c = c * (0.88 + 0.26 * bl)
			c = c * (0.95 + 0.1 * rnd.randf())
			im.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), 1.0))
	# a few chips (lighter, catching the light) and pits (darker)
	for k in 7:
		var cx := rnd.randi_range(1, T - 3)
		var cy := rnd.randi_range(7, T - 8)
		var f := 1.3 if k % 2 == 0 else 0.62
		for dx in 2:
			var c := im.get_pixel(cx + dx, cy)
			im.set_pixel(cx + dx, cy, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), 1.0))
	return im


## The dark end of a wall (a side seen edge on): `open` where the wall ends against low ground,
## a lighter single line where it steps against the plateau.
static func _cap(dark: Color, left: bool, open: bool) -> Image:
	var im := _blank()
	var widths := 4 if open else 1
	for k in widths:
		var a := (0.95 if k == 0 else 0.5 if k == 1 else 0.25 if k == 2 else 0.12) if open else 0.6
		for y in T:
			var x := k if left else T - 1 - k
			im.set_pixel(x, y, Color(dark.r, dark.g, dark.b, a))
	return im


## A rim seen from the plateau: a dark contour on the border with the low ground and a lighter
## lip just inside. side 0 north, 1 east, 2 west.
static func _rim(dark: Color, lip: Color, side: int) -> Image:
	var im := _blank()
	var cont := [0.95, 0.7, 0.28]
	var light := [0.0, 0.0, 0.5, 0.42, 0.22, 0.1]
	for d in 6:
		for k in T:
			var px := Vector2i(k, d)
			if side == 1:
				px = Vector2i(T - 1 - d, k)
			elif side == 2:
				px = Vector2i(d, k)
			if d < 3:
				im.set_pixelv(px, Color(dark.r, dark.g, dark.b, cont[d]))
			else:
				im.set_pixelv(px, Color(lip.r, lip.g, lip.b, light[d]))
	return im


## A corner open on its diagonal only: a dark speck. 0 tl, 1 tr, 2 bl, 3 br.
static func _dot(dark: Color, corner: int) -> Image:
	var im := _blank()
	for dy in 4:
		for dx in 4:
			var a := clampf(1.0 - (dx + dy) / 5.0, 0.0, 1.0) * 0.9
			var x := dx if corner % 2 == 0 else T - 1 - dx
			var y := dy if corner < 2 else T - 1 - dy
			im.set_pixel(x, y, Color(dark.r, dark.g, dark.b, a))
	return im


## The shadow on the low ground under a wall (placed on the cell below it).
static func _shadow_s() -> Image:
	var im := _blank()
	for y in SHADOW_FACE:
		var a := 0.56 * pow(1.0 - float(y) / SHADOW_FACE, 1.6)
		for x in T:
			im.set_pixel(x, y, Color(0.02, 0.02, 0.04, a))
	return im


## The soft shadow on the low ground beside a rim, in the cell on the open side. 0: the cell
## north of the cliff, 1: east of it, 2: west of it.
static func _ao(side: int) -> Image:
	var im := _blank()
	for d in SHADOW_AO:
		var a := 0.32 * pow(1.0 - float(d) / SHADOW_AO, 1.6)
		for k in T:
			var px := Vector2i(k, T - 1 - d)
			if side == 1:
				px = Vector2i(d, k)
			elif side == 2:
				px = Vector2i(T - 1 - d, k)
			im.set_pixelv(px, Color(0.02, 0.02, 0.04, a))
	return im
