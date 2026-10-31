class_name SpeakerIcon
extends Control
## A small loudspeaker drawn in code: sound waves when on, a red cross when muted. The mute
## buttons beside the volume bars (Settings > SOUND and the match menu) use it.

var muted := false
var col := UiStyle.TEXT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_icon(self, Rect2(Vector2.ZERO, size), muted, col)


## The icon fitted in r (square-ish), on any canvas item (the HUD draws it too).
static func draw_icon(ci: CanvasItem, r: Rect2, is_muted: bool, c: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center() - Vector2(s, s) * 0.5
	var u := s / 24.0
	var body := PackedVector2Array([o + Vector2(3, 9) * u, o + Vector2(7, 9) * u, o + Vector2(12, 4) * u,
		o + Vector2(12, 20) * u, o + Vector2(7, 15) * u, o + Vector2(3, 15) * u])
	ci.draw_colored_polygon(body, Color(c, 0.45) if is_muted else c)
	if is_muted:
		var red := Color(0.9, 0.3, 0.25)
		ci.draw_line(o + Vector2(15, 8) * u, o + Vector2(22, 16) * u, red, maxf(2.0, 2.2 * u))
		ci.draw_line(o + Vector2(22, 8) * u, o + Vector2(15, 16) * u, red, maxf(2.0, 2.2 * u))
	else:
		ci.draw_arc(o + Vector2(12, 12) * u, 4.5 * u, -0.9, 0.9, 10, c, maxf(1.5, 1.6 * u))
		ci.draw_arc(o + Vector2(12, 12) * u, 8.5 * u, -0.9, 0.9, 14, c, maxf(1.5, 1.6 * u))
