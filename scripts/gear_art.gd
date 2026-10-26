class_name GearArt
extends RefCounted
## The painted gear rings of the Clockwork gear field (scripts/gear.gd), rebuilt for any tooth count from the strips of the
## ChatGPT rings (assets/gear: tooth.png = one tooth period, row 0 the tip; band_<kind>.png = a quarter turn of the band,
## row 0 just under the tooth roots, the last row the hole's edge). The GDScript port of tools/gear_art/rebuild_ring.py.
##
## ring(kind, n) bakes ONCE per (kind, n) and caches: [face texture, silhouette texture (white, for the thick edge), tip
## radius px]. The texture is BAKE times the ring's size in game px, a tooth centred at angle 0 (+x) and the others every
## TAU/n, so a ring drawn rotated by `phase` has its tooth centres at phase + TAU*k/n. Kinds: "small", "big", "tower" (the
## band strips) and "idler" (the small band round a filled hub: a free cog between two rings, the hub drawn here in code,
## docs/art_style_inconsistency.md).

const BAKE := 2.0
## from art/clockwork/gear/gear_strips.json (tools/gear_art/unwrap_rings.py): the band's inner edge and tooth-root radius as
## fractions of the painted ring's tip radius, and the tooth strip's height against the painted pitch.
const META := {
	"tower": {"r_in": 0.5796064400715564, "r_root": 0.8855098389982111},
	"small": {"r_in": 0.5753968253968254, "r_root": 0.8690476190476191},
	"big": {"r_in": 0.5936739659367397, "r_root": 0.8978102189781022},
	"idler": {"r_in": 0.5753968253968254, "r_root": 0.8690476190476191},
}
const TOOTH_ROWS := 35
const TOOTH_PITCH_PX := 71.97103170042072      # the painted pitch the tooth strip was cut from (its rows are px of that)

static var _cache := {}
static var _src := {}
static var disabled := false        # (headless tests: no pixel work)


static func _strip(name: String) -> Image:
	if not _src.has(name):
		var img: Image = null
		var path := "res://assets/gear/%s.png" % name
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			if t != null:
				img = t.get_image()
				if img != null:
					if img.is_compressed():
						img.decompress()
					img.convert(Image.FORMAT_RGBA8)
		_src[name] = img
	return _src[name]


## The tooth height (tip to root) for this pitch, px: as tall against its width as the painted teeth.
static func tooth_h(pitch: float) -> float:
	return pitch * float(TOOTH_ROWS) / TOOTH_PITCH_PX


## The tip radius of a ring whose pitch circle (mid tooth) is rp.
static func tip_r(rp: float, pitch: float) -> float:
	return rp + tooth_h(pitch) * 0.5


## [face, silhouette, tip radius, half the texture's side in game px] for a ring of n teeth of this kind, or [] when the strips are missing.
static func ring(kind: String, n: int) -> Array:
	var key := "%s:%d" % [kind, n]
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	if not disabled:
		out = _bake(kind, n)
	_cache[key] = out
	return out


static func _bake(kind: String, n: int) -> Array:
	var tooth := _strip("tooth")
	var band := _strip("band_" + ("small" if kind == "idler" else kind))
	if tooth == null or band == null:
		return []
	var pitch := float(Defs.GEAR["pitch"])
	var rp := float(n) * pitch / TAU
	var R := tip_r(rp, pitch)
	var th := tooth_h(pitch)
	var m: Dictionary = META[kind]
	var r_root := R - th
	var band_w := r_root * (1.0 - float(m["r_in"]) / float(m["r_root"]))
	var r_in := r_root - band_w
	var hub := kind == "idler"
	var size := int(ceil(2.0 * R * BAKE)) + 2
	var c := float(size) * 0.5
	var tw := tooth.get_width()
	var trows := tooth.get_height()
	var td := tooth.get_data()
	var bw := band.get_width()
	var brows := band.get_height()
	var bd := band.get_data()
	var face := PackedByteArray()
	face.resize(size * size * 4)
	var sil := PackedByteArray()
	sil.resize(size * size * 4)
	var Rb := R * BAKE
	var rin_b := (r_in if not hub else 0.0) * BAKE
	var hub_col := Color8(46, 40, 36)
	var boss_col := Color8(198, 150, 62)
	var boss_dark := Color8(92, 62, 24)
	var nf := float(n)
	for y in size:
		var dy := float(y) + 0.5 - c
		if absf(dy) > Rb:
			continue
		var span := sqrt(maxf(0.0, Rb * Rb - dy * dy))
		var x0 := maxi(0, int(floor(c - span)))
		var x1 := mini(size - 1, int(ceil(c + span)))
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - c
			var rb := sqrt(dx * dx + dy * dy)
			if rb >= Rb or rb < rin_b:
				continue
			var r := rb / BAKE
			var a := fposmod(atan2(dy, dx), TAU)
			var i := (y * size + x) * 4
			var got := false
			if r >= r_root:
				var tr := clampi(int((R - r) / th * float(trows)), 0, trows - 1)
				var tc := clampi(int(fposmod(a * nf / TAU + 0.5, 1.0) * float(tw)), 0, tw - 1)
				var j := (tr * tw + tc) * 4
				if td[j + 3] >= 128:
					face[i] = td[j]
					face[i + 1] = td[j + 1]
					face[i + 2] = td[j + 2]
					face[i + 3] = 255
					got = true
			if not got and r < r_root + 1.0 and r >= r_in:
				var br := clampi(int((r_root - r) / band_w * float(brows)), 0, brows - 1)
				var bc := clampi(int(fposmod(a / (PI * 0.5), 1.0) * float(bw)), 0, bw - 1)
				var j2 := (br * bw + bc) * 4
				if bd[j2 + 3] >= 128:
					face[i] = bd[j2]
					face[i + 1] = bd[j2 + 1]
					face[i + 2] = bd[j2 + 2]
					face[i + 3] = 255
					got = true
			if not got and hub and r < r_in + 0.5:
				# the idler's hub (code-drawn): a dark iron disc, a brass boss with a dark rim and a pin
				var col := hub_col
				if r < r_in * 0.5:
					col = boss_col if r < r_in * 0.42 else boss_dark
					if r < r_in * 0.14:
						col = boss_dark
				elif r > r_in - 1.2:
					col = boss_dark
				face[i] = col.r8
				face[i + 1] = col.g8
				face[i + 2] = col.b8
				face[i + 3] = 255
				got = true
			if got:
				sil[i] = 255
				sil[i + 1] = 255
				sil[i + 2] = 255
				sil[i + 3] = 255
	var fi := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, face)
	var si := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, sil)
	return [ImageTexture.create_from_image(fi), ImageTexture.create_from_image(si), R, float(size) / (2.0 * BAKE)]


## The radius (game px) of a ring's inner hole: the band's inner edge, as _bake cuts it.
static func hole_r(kind: String, n: int) -> float:
	var pitch := float(Defs.GEAR["pitch"])
	var rp := float(n) * pitch / TAU
	var r_root := tip_r(rp, pitch) - tooth_h(pitch)
	var m: Dictionary = META[kind]
	return r_root * float(m["r_in"]) / float(m["r_root"])


## THE FLOOR PLATE (art/clockwork/gear/floor_plate_src.png keyed by tools/gear_art/import_buildings.py to
## assets/gear/floor_plate.png): the flat, bolted iron deck that fills a ring's hole, `d` game px across. Resized ONCE per
## whole-px diameter (BAKE times, smooth) and cached; null without the art (or headless).
static func plate(d: int) -> Texture2D:
	var key := "plate:%d" % d
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = null
	if not disabled:
		var src := _strip("floor_plate")
		if src != null:
			var img := src.duplicate() as Image
			var side := maxi(8, int(round(float(d) * BAKE)))
			img.resize(side, side, Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


static func reset() -> void:
	_cache.clear()
	_src.clear()
