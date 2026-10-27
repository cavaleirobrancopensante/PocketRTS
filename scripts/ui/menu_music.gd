class_name MenuMusic
extends RefCounted
## The music player in the in-game MENU (beside its buttons): the piece playing (and how far into it), NEXT, and a
## paged list of the pieces to pick from, as the music setting has it (Music.player_pieces: your faction's, the
## enemy's too in the default mode, everything, or only the ticked ones). A picked piece plays to its end, then the
## music follows the match again; NEXT hands back at once (Music: PICKED-PIECE RULE). Local only: online each player
## hears their own. Drawn and pressed by the HUD (hud.gd), in the HUD's coordinates.

var page := 0
var rect := Rect2()
var rows := 5                # list rows that fit
var _hits: Array = []        # {rect, id, cb} of everything pressable, rebuilt by layout()


## Work out the panel's pieces inside `r`.
func layout(r: Rect2) -> void:
	rect = r
	_hits.clear()
	var pad := 12.0
	var x := r.position.x + pad
	var w := r.size.x - pad * 2.0
	var y := r.position.y + 64.0
	var bh := 36.0
	_add(Rect2(x, y, w, bh), "next", func() -> void:
		if Music.me:
			Music.me.skip())
	y += bh + 10.0
	var list: Array = Music.me.player_pieces() if Music.me else []
	var rp := 30.0                       # the list's row pitch
	var foot := 32.0
	rows = clampi(int((r.end.y - pad - foot - y) / rp), 1, 14)
	var pages := maxi(1, ceili(float(list.size()) / float(rows)))
	page = clampi(page, 0, pages - 1)
	for i in rows:
		var idx := page * rows + i
		if idx >= list.size():
			break
		var stem: String = list[idx]
		_add(Rect2(x, y + i * rp, w, rp - 3.0), "row:" + stem, func() -> void:
			if Music.me:
				Music.me.play_picked(stem))
	var fy := r.end.y - pad - 28.0
	if pages > 1:
		_add(Rect2(x, fy, 60, 28), "prev", func() -> void: page = maxi(page - 1, 0))
		_add(Rect2(r.end.x - pad - 60, fy, 60, 28), "more", func() -> void: page = mini(page + 1, pages - 1))


func _add(r: Rect2, id: String, cb: Callable) -> void:
	_hits.append({"rect": r, "id": id, "cb": cb})


## A press at `p`: true if it was on the panel (used up).
func press(p: Vector2) -> bool:
	if not rect.has_point(p):
		return false
	for h in _hits:
		if (h["rect"] as Rect2).has_point(p):
			(h["cb"] as Callable).call()
			Sfx.play_any(["ui/click", "click"])
			break
	return true


## For tests: the centre of the control with this id ("next", "prev", "more", "row:<stem>").
func centre_of(id: String) -> Vector2:
	for h in _hits:
		if h["id"] == id:
			return (h["rect"] as Rect2).get_center()
	return Vector2(-1, -1)


## What it shows, in short (the HUD redraws the menu when it changes).
func sig() -> Array:
	if Music.me == null:
		return []
	var len := Music.me.track_length()
	return [page, Music.me.current_stem(), int(Music.me.track_pos() * 2.0 / maxf(len, 1.0) * 100.0) if len > 0.0 else 0, Music.me.mode]


static func fmt(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func draw(hud: Control, ci: CanvasItem, hover: Vector2) -> void:
	if Music.me == null:
		return
	var m := Music.me
	var r := rect
	var pad := 12.0
	hud._text(UiStyle.bold_font(), Vector2(r.position.x + pad, r.position.y + 20), "MUSIC", 14, UiStyle.TRIM)
	var title := m.now_playing()
	if title == "":
		title = "(nothing playing)"
	var font := UiStyle.bold_font()
	var fs := 19
	while fs > 12 and font.get_string_size(Loc.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - pad * 2.0:
		fs -= 1
	hud._text(font, Vector2(r.position.x + pad, r.position.y + 42), title, fs, UiStyle.TEXT)
	var len := m.track_length()
	if len > 0.0:
		var pos := m.track_pos()
		hud._text(UiStyle.body_font(), Vector2(r.end.x - pad, r.position.y + 20), "%s / %s" % [fmt(pos), fmt(len)], 13, UiStyle.TEXT, 2)
		var bar := Rect2(r.position.x + pad, r.position.y + 50, r.size.x - pad * 2.0, 3)
		ci.draw_rect(bar, Color(1, 1, 1, 0.2))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(pos / len, 0.0, 1.0), bar.size.y)), UiStyle.TRIM)
	for h in _hits:
		var hr: Rect2 = h["rect"]
		var id: String = h["id"]
		if id.begins_with("row:"):
			var stem := id.substr(4)
			var on := stem == m.current_stem()
			UiStyle.draw_button(ci, hr, hr.has_point(hover), on, true, 0.5)
			var t: String = Loc.t(String(Music.titles().get(stem, stem)))
			var f2 := UiStyle.body_font()
			var s2 := 15
			while s2 > 11 and f2.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s2).x > hr.size.x - 28.0:
				s2 -= 1
			hud._text(f2, Vector2(hr.position.x + 8, hr.position.y + hr.size.y * 0.5 + 5.0), ("> " if on else "") + t, s2, UiStyle.TRIM if on else UiStyle.TEXT)
			continue
		var label: String = {"next": "NEXT", "prev": "<", "more": ">"}.get(id, id)
		UiStyle.draw_button(ci, hr, hr.has_point(hover), false, true, 0.45)
		hud._text(UiStyle.bold_font(), hr.get_center() + Vector2(0, 7), label, 18, UiStyle.TEXT, 1)
	var list: Array = m.player_pieces()
	var pages := maxi(1, ceili(float(list.size()) / float(rows)))
	if pages > 1:
		hud._text(UiStyle.body_font(), Vector2(r.get_center().x, r.end.y - pad - 9), "%d / %d" % [page + 1, pages], 14, UiStyle.TEXT, 1)
