class_name UiStyle
## The look of every menu and the in-game HUD: warm dark panels with brass trim,
## Cinzel for headings and Alegreya Sans for text, and a colour accent per faction.

const BG := Color("#15120e")
const PANEL := Color(0.105, 0.09, 0.07, 0.92)
const PANEL_LIGHT := Color(0.16, 0.135, 0.105, 0.95)
const TRIM := Color("#c9a24a")
const TRIM_DIM := Color(0.79, 0.64, 0.29, 0.45)
const TEXT := Color("#f1e6c8")
const MUTED := Color(0.95, 0.9, 0.78, 0.6)
const GOOD := Color("#9fd36b")
const BAD := Color("#e8735a")
const ACCENT := {
	"crown": Color("#d9473a"),
	"brood": Color("#7fb446"),
	"clockwork": Color("#4aa3d9"),
}
const FACTION_TAG := {
	"crown": "Pike, shot and black powder",
	"brood": "Swarm, swamp and hunger",
	"clockwork": "Gears, steam and lightning",
}

static var _title: Font
static var _body: Font
static var _bold: Font


static func title_font() -> Font:
	if _title == null:
		var base: FontFile = load("res://assets/fonts/Cinzel.ttf")
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {"wght": 700}
		_title = v
	return _title


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	return _body


static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	return _bold


static func accent(faction: String) -> Color:
	return ACCENT.get(faction, TRIM)


## Make the body font the default everywhere (HUD text is drawn with the fallback font).
static func install() -> void:
	ThemeDB.fallback_font = body_font()


static func box(bg: Color, border := TRIM_DIM, bw := 2, radius := 10, margin := 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.5
	sb.content_margin_bottom = margin * 0.5
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", box(Color(0.17, 0.14, 0.105), TRIM_DIM))
	t.set_stylebox("hover", "Button", box(Color(0.23, 0.19, 0.13), TRIM))
	t.set_stylebox("pressed", "Button", box(Color(0.33, 0.26, 0.14), TRIM, 3))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.36, 0.28, 0.15), TRIM, 3))
	t.set_stylebox("disabled", "Button", box(Color(0.11, 0.1, 0.085, 0.8), Color(1, 1, 1, 0.08)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", bold_font())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", Color(1, 0.93, 0.7))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, TRIM_DIM, 2, 14, 22.0))
	t.set_stylebox("panel", "Panel", box(PANEL, TRIM_DIM, 2, 14))
	var grab := StyleBoxFlat.new()
	grab.bg_color = TRIM_DIM
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


## A heading in Cinzel with a soft drop shadow.
static func heading(text: String, size: int, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


static func text(t: String, size: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## A big call-to-action button tinted with an accent colour.
static func primary(b: Button, col := Color("#3f7d3a")) -> void:
	b.add_theme_stylebox_override("normal", box(col.darkened(0.15), TRIM, 2))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.05), Color(1, 0.88, 0.55), 3))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.3), Color(1, 0.88, 0.55), 3))
	b.add_theme_font_override("font", title_font())


## Mark a toggle/choice button as the chosen one.
static func chosen(b: Button, col := TRIM) -> void:
	var sb := box(Color(0.3, 0.24, 0.13), col, 3)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)


# ------------------------------------------------------------------ drawing (HUD)

static var _boxes := {}


## The same style box every frame instead of a new one (the HUD draws dozens a frame).
static func cached_box(bg: Color, border: Color, bw: int, radius: int, shadow: int) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d|%d" % [bg.to_html(), border.to_html(), bw, radius, shadow]
	if not _boxes.has(key):
		var sb := box(bg, border, bw, radius, 0.0)
		sb.shadow_size = shadow
		_boxes[key] = sb
	return _boxes[key]


## A rounded panel with brass trim, drawn on any CanvasItem.
static func draw_panel(ci: CanvasItem, r: Rect2, accent_col := Color(0, 0, 0, 0), alpha := 0.88) -> void:
	cached_box(Color(PANEL.r, PANEL.g, PANEL.b, alpha), TRIM_DIM, 2, 9, 6).draw(ci.get_canvas_item(), r)
	if accent_col.a > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2(10, 2), Vector2(r.size.x - 20, 2)), Color(accent_col.r, accent_col.g, accent_col.b, 0.8))


## A small button face: hover/pressed/disabled looks.
static func draw_button(ci: CanvasItem, r: Rect2, hover := false, on := false, enabled := true) -> void:
	var bg := Color(0.17, 0.14, 0.105, 0.95)
	var bd := TRIM_DIM
	if not enabled:
		bg = Color(0.1, 0.09, 0.08, 0.85)
		bd = Color(1, 1, 1, 0.08)
	elif on:
		bg = Color(0.33, 0.26, 0.14, 0.95)
		bd = TRIM
	elif hover:
		bg = Color(0.23, 0.19, 0.13, 0.95)
		bd = TRIM
	cached_box(bg, bd, 2, 7, 2).draw(ci.get_canvas_item(), r)
