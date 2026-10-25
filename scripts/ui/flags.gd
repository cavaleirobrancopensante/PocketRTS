class_name FlagIcon
extends Control
## A national flag drawn in code (no image files): "en" the United States, "pt" Brazil, "es" Spain.
## Used by the language buttons on the main menu and in Settings. Proportions follow the real
## flags (US 19:10, Brazil 10:7, Spain 3:2), fitted into the control's rect and centred.

var code := "en"


static func make(c: String, size: Vector2) -> FlagIcon:
	var f := FlagIcon.new()
	f.code = c
	f.custom_minimum_size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _draw() -> void:
	var ratio := {"en": 1.9, "pt": 10.0 / 7.0, "es": 1.5}[code] as float
	var w := size.x
	var h := w / ratio
	if h > size.y:
		h = size.y
		w = h * ratio
	var r := Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	match code:
		"en":
			_us(r)
		"pt":
			_brazil(r)
		_:
			_spain(r)
	draw_rect(r, Color(0, 0, 0, 0.55), false, 1.0)


func _us(r: Rect2) -> void:
	var red := Color("#b22234")
	var white := Color("#ffffff")
	var blue := Color("#3c3b6e")
	var sh := r.size.y / 13.0
	for i in 13:
		draw_rect(Rect2(r.position.x, r.position.y + i * sh, r.size.x, sh + 0.5), red if i % 2 == 0 else white)
	var cw := r.size.x * 0.4
	var ch := sh * 7.0
	draw_rect(Rect2(r.position, Vector2(cw, ch)), blue)
	# fifty stars: nine rows, alternately six and five
	for row in 9:
		var n := 6 if row % 2 == 0 else 5
		for k in n:
			var x := cw * (0.083 + (k * 2 + (0 if row % 2 == 0 else 1)) * 0.0833)
			var y := ch * (0.054 + row * 0.1135)
			_star(r.position + Vector2(x, y), maxf(1.0, r.size.x * 0.0155), white)


func _star(c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := rad if i % 2 == 0 else rad * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _brazil(r: Rect2) -> void:
	var green := Color("#009c3b")
	var yellow := Color("#ffdf00")
	var blue := Color("#002776")
	var c := r.get_center()
	draw_rect(r, green)
	var hx := r.size.x * 0.43
	var hy := r.size.y * 0.43
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hy), c + Vector2(hx, 0), c + Vector2(0, hy), c + Vector2(-hx, 0)]), yellow)
	var rad := r.size.y * 0.25
	draw_circle(c, rad, blue)
	# the white band across the globe, curving up in the middle (a thin arc strip)
	var band := PackedVector2Array()
	var steps := 14
	var th := rad * 0.17
	for i in steps + 1:
		var u := -1.0 + 2.0 * i / steps
		band.append(c + Vector2(u * rad * 0.97, rad * (0.30 - 0.55 * (1.0 - u * u)) * 0.9 - th))
	for i in range(steps, -1, -1):
		var u := -1.0 + 2.0 * i / steps
		band.append(c + Vector2(u * rad * 0.97, rad * (0.30 - 0.55 * (1.0 - u * u)) * 0.9 + th))
	# keep the band inside the circle
	var clipped := Geometry2D.intersect_polygons(band, _circle_poly(c, rad))
	for poly in clipped:
		draw_colored_polygon(poly, Color.WHITE)


func _circle_poly(c: Vector2, rad: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		p.append(c + Vector2(cos(a), sin(a)) * rad)
	return p


func _spain(r: Rect2) -> void:
	var red := Color("#aa151b")
	var yellow := Color("#f1bf00")
	draw_rect(r, red)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.25, r.size.x, r.size.y * 0.5), yellow)
	# the arms, simplified: a shield (red and gold quarters) under a small crown, left of centre
	var cx := r.position.x + r.size.x * 0.36
	var cy := r.position.y + r.size.y * 0.5
	var sw := r.size.y * 0.15
	var sh := r.size.y * 0.30
	var shield := PackedVector2Array([Vector2(cx - sw, cy - sh * 0.5), Vector2(cx + sw, cy - sh * 0.5),
		Vector2(cx + sw, cy + sh * 0.1), Vector2(cx + sw * 0.6, cy + sh * 0.38), Vector2(cx, cy + sh * 0.55),
		Vector2(cx - sw * 0.6, cy + sh * 0.38), Vector2(cx - sw, cy + sh * 0.1)])
	draw_colored_polygon(shield, Color("#e8d9a0"))
	draw_rect(Rect2(cx - sw, cy - sh * 0.5, sw, sh * 0.3), red)
	draw_rect(Rect2(cx, cy - sh * 0.2, sw, sh * 0.3), red)
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color("#7a1015"), 1.0)
	# crown
	var kw := sw * 1.2
	var ky := cy - sh * 0.5
	draw_rect(Rect2(cx - kw, ky - sh * 0.2, kw * 2, sh * 0.2), Color("#c8960a"))
	for i in 3:
		draw_circle(Vector2(cx - kw + kw * i, ky - sh * 0.27), maxf(1.0, sh * 0.07), Color("#c8960a"))
	# the two pillars
	for sx in [-1.0, 1.0]:
		draw_rect(Rect2(cx + sx * sw * 1.9 - sw * 0.2, cy - sh * 0.35, sw * 0.4, sh * 0.85), Color("#f4f0e6"))
		draw_rect(Rect2(cx + sx * sw * 1.9 - sw * 0.2, cy - sh * 0.35, sw * 0.4, sh * 0.85), Color("#7a1015"), false, 1.0)
