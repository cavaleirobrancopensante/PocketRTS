class_name PanelArt
## The faction frames behind the unit panel and the command card (docs/hud_panels.md).
## Drawn from assets/ui/panels/<faction>_panel.png and <faction>_card.png when they exist
## (tools/import_panel_art.py makes them from the owner's ChatGPT sheet), as a 9-slice: the
## corners keep their shape, the edges and middle stretch. Without the files: UiStyle.draw_panel.

const DIR := "res://assets/ui/panels/"

## The 9-slice margins in the art's own pixels: [left, top, right, bottom], set to hold each
## faction's corner ornaments (Crown crowns and fleurs-de-lis, Clockwork cogs and springs, Brood
## claws and eggs). The art is drawn at THIN of its height fit (panel art 220 px tall for a
## ~110 px panel, card art 400 px for the ~200 px card): a margin of 90 is ~32 screen pixels.
const MARGINS := {
	"crown": {"panel": [95, 75, 95, 75], "card": [95, 95, 95, 95]},
	"clockwork": {"panel": [85, 80, 85, 80], "card": [80, 80, 80, 80]},
	"brood": {"panel": [80, 110, 80, 75], "card": [80, 120, 80, 85]},
}
const DEFAULT_MARGIN := [60, 60, 60, 60]
const THIN := 0.7

static var _boxes := {}          # "crown_panel" -> StyleBoxTexture, or null when there is no art
static var drawn := {}           # "panel"/"card" -> the faction last drawn (tools/test_hud_frames.gd)


## The cached 9-slice box for a faction's "panel" or "card", or null (no art).
static func box(faction: String, which: String) -> StyleBoxTexture:
	var key := faction + "_" + which
	if _boxes.has(key):
		return _boxes[key]
	var sb: StyleBoxTexture = null
	var path := DIR + key + ".png"
	if faction != "" and ResourceLoader.exists(path):
		sb = make_box(load(path) as Texture2D, faction, which)
	_boxes[key] = sb
	return sb


static func make_box(tex: Texture2D, faction: String, which: String) -> StyleBoxTexture:
	if tex == null:
		return null
	var m: Array = MARGINS.get(faction, {}).get(which, DEFAULT_MARGIN)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	# the edges repeat (ropes, rivets, planks) instead of smearing over a wide screen
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


## For tests and previews: use this texture for a faction's panel or card (null clears it).
static func set_art(faction: String, which: String, tex: Texture2D) -> void:
	_boxes[faction + "_" + which] = make_box(tex, faction, which)


## Draws the frame: the art scaled to the rect's height (corners unstretched), else the flat panel.
static func draw(ci: CanvasItem, r: Rect2, faction: String, which: String) -> void:
	drawn[which] = faction
	var sb := box(faction, which)
	if sb == null:
		UiStyle.draw_panel(ci, r, UiStyle.accent(faction) if faction != "" else Color(0, 0, 0, 0))
		return
	# (THIN of the height fit: thinner borders, so the stats row and the buttons stay off the ornaments)
	var s := clampf(THIN * r.size.y / float(sb.texture.get_height()), 0.15, 2.0)
	# (the margins must fit the rect's width too)
	s = minf(s, r.size.x / float(sb.texture_margin_left + sb.texture_margin_right + 1))
	ci.draw_set_transform(r.position, 0.0, Vector2(s, s))
	sb.draw(ci.get_canvas_item(), Rect2(Vector2.ZERO, r.size / s))
	ci.draw_set_transform(Vector2.ZERO)


## The faction the HUD frames wear: yours; watching or a replay, the player looked through
## ("" = neutral, all vision).
static func faction_for(game: Game) -> String:
	var t := game.fog_team()
	return game.faction_of(t) if t >= 0 else ""


## The empty unit panel: the faction's name, faint, in the middle.
static func draw_empty_name(ci: CanvasItem, r: Rect2, faction: String) -> void:
	if faction == "" or not Defs.FACTIONS.has(faction):
		return
	var txt := Loc.t(String(Defs.FACTIONS[faction]["name"])).to_upper()
	var f := UiStyle.bold_font()
	var sz := 22
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var a := UiStyle.accent(faction)
	ci.draw_string(f, Vector2(r.get_center().x - w * 0.5, r.get_center().y + sz * 0.35), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(a.r, a.g, a.b, 0.22))
