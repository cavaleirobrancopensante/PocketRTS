class_name StunMark
extends Node2D
## The STUN MARK: a little ring of stars circling over a stunned unit's head, the classic "seeing stars" (owner,
## 2026-10-29). Only REAL stuns show it (Unit.stun with show: a Mist Toad's tongue, a Cavalry charge's knock, a
## Stormcaller's storm), at least MIN_SHOW s long; internal holds (a run-down construct, the short holds of a
## ride) and a netted unit (its net shows) don't.
## One layer over every unit (Game.stun_layer, z 3: over the flyers, under the fog clouds), drawn only while a mark
## lasts, only for marked units in view and seen (Unit.visible: the fog), one texture for every star (one batch).
## The stars are drawn in code (an 11 px star, a dark outline so they read on any ground; docs/art_style_inconsistency.md);
## if assets/ui/stun_stars.png exists it is used instead: one square star, or a strip of square frames it steps through.

const MIN_SHOW := 0.3            # a stun shorter than this shows no mark (it would only flicker)
const FADE_IN := 0.08
const FADE_OUT := 0.2            # it fades out over the stun's last 0.2 s
const SPIN := 1.0                # turns a second
const ART := "res://assets/ui/stun_stars.png"

var game: Node = null
var marked := {}                 # Unit -> the game clock its mark began
var _drawn := false
var _ys := {}                    # Unit -> the ring's height last drawn (_over)

static var _tex: Texture2D = null
static var _frames := 1


## A unit's mark starts (or goes on): Unit.stun calls it.
static func add(g: Node, u: Unit) -> void:
	var l: StunMark = g.get("stun_layer")
	if l == null:
		return
	if not l.marked.has(u):
		l.marked[u] = float(g.clock)


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR      # (the star is scaled to the unit's size: smooth, not blocky)
	_load_tex()


func _process(_delta: float) -> void:
	if marked.is_empty():
		if _drawn:
			_drawn = false
			queue_redraw()
		return
	for u in marked.keys():
		if not is_instance_valid(u) or u.stun_left() <= 0.0:
			marked.erase(u)
			_ys.erase(u)
	_drawn = true
	queue_redraw()


func _draw() -> void:
	if marked.is_empty() or _tex == null:
		return
	var clk := float(game.clock)
	var vr: Rect2 = game.view_rect
	var fw := float(_tex.get_height())
	for u in marked:
		if not is_instance_valid(u) or not u.visible or u.off_field or u.modulate.a < 0.05:
			continue
		if vr.size != Vector2.ZERO and not vr.has_point(u.position):
			continue
		var left: float = u.stun_left()
		var a := minf(clampf(left / FADE_OUT, 0.0, 1.0), clampf((clk - float(marked[u])) / FADE_IN, 0.0, 1.0))
		if a <= 0.01:
			continue
		var lifted: float = Springer.lift(u) if not u.jump.is_empty() else 0.0
		var ph := float(u.get_instance_id() % 628) * 0.01      # (each unit's stars a little out of step)
		var rx := clampf(float(u.radius) * 0.9 + 3.0, 9.0, 20.0)
		var ry := rx * 0.38
		var c: Vector2 = u.position + Vector2(0.0, _over(u, lifted) - 3.0 - ry + sin(clk * 5.0 + ph))
		var n := 4 if u.radius >= 10.0 else 3
		var ang0 := clk * TAU * SPIN + ph
		var size := clampf(float(u.radius) * 0.35 + 6.0, 8.5, 13.0)
		# the stars behind its head first (smaller, dimmer), then the ones in front
		for front in [false, true]:
			for i in n:
				var an := ang0 + TAU * float(i) / float(n)
				var sn := sin(an)
				if (sn > 0.0) != front:
					continue
				var depth := (sn + 1.0) * 0.5
				var s := size * lerpf(0.7, 1.0, depth)
				var p := c + Vector2(cos(an) * rx, sn * ry)
				var col := Color(1, 1, 1, a * lerpf(0.65, 1.0, depth))
				if _frames > 1:
					var f := int(clk * 10.0 + float(i) * 2.0 + ph * 10.0) % _frames
					draw_texture_rect_region(_tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(f * fw, 0, fw, fw), col)
				else:
					draw_texture_rect(_tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)


## Where the ring goes, over the unit's position (up is negative): just over its picture as drawn now (the frame's used
## rect, cached per frame: BroodRoot.body_rect), or over its health bar while that shows (it is hurt) and is higher.
## Eased a little toward a new height so a frame change doesn't make the ring jump.
func _over(u: Unit, lifted: float) -> float:
	var y: float = u.bar_top(lifted)
	var br := BroodRoot.body_rect(u) if u.sprite != null else Rect2()
	if br.size.y > 2.0:
		var body := br.position.y - u.position.y - 2.0
		y = minf(body, y) if u.hp < u.max_hp else body
	var was = _ys.get(u)
	if was != null and absf(float(was) - y) < 40.0:
		y = lerpf(float(was), y, 0.25)
	_ys[u] = y
	return y


static func _load_tex() -> void:
	if _tex != null:
		return
	if ResourceLoader.exists(ART):
		_tex = load(ART)
		if _tex and _tex.get_height() > 0:
			_frames = maxi(1, _tex.get_width() / _tex.get_height())
			return
	_tex = ImageTexture.create_from_image(star_image(15))
	_frames = 1


## The code-drawn star: 15 x 15 (drawn 8.5 to 13 px wide), a five-pointed star, white in the middle going to warm yellow, a dark brown outline.
static func star_image(px := 11) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := px * 0.5
	var outer := _star_poly(Vector2(cx, cx + 0.3), px * 0.5 - 0.2, px * 0.26)
	var inner := _star_poly(Vector2(cx, cx + 0.3), px * 0.5 - 1.4, px * 0.17)
	var ss := 4
	for y in px:
		for x in px:
			var co := 0
			var ci := 0
			for sy in ss:
				for sx in ss:
					var q := Vector2(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss)
					if Geometry2D.is_point_in_polygon(q, outer):
						co += 1
					if Geometry2D.is_point_in_polygon(q, inner):
						ci += 1
			if co == 0:
				continue
			var fo := float(co) / (ss * ss)
			var fi := float(ci) / (ss * ss)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx)) / (px * 0.5)
			var fill := Color(1.0, 1.0, 0.92).lerp(Color(1.0, 0.82, 0.18), clampf(d * 1.3, 0.0, 1.0))
			var edge := Color(0.22, 0.13, 0.04)
			var col := edge.lerp(fill, fi / maxf(fo, 0.001))
			col.a = fo
			img.set_pixel(x, y, col)
	return img


static func _star_poly(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := r_out if k % 2 == 0 else r_in
		var an := -PI * 0.5 + PI * float(k) / 5.0
		pts.append(c + Vector2(cos(an), sin(an)) * r)
	return pts
