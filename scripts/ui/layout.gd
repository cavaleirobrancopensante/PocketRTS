class_name UiLayout
## In-game interface layouts. Two built-in profiles that can't be changed (STANDARD and
## MINIMAP TOP RIGHT) and three CUSTOM slots where the player moves the minimap, the quick
## hotkey bar, the selection panel and the command card, and sets their own letter hotkeys.
## Saved in user://settings.cfg, section "layout".

const BUILT_IN := ["STANDARD", "MINIMAP TOP RIGHT"]
const CUSTOM := ["CUSTOM 1", "CUSTOM 2", "CUSTOM 3"]
const PARTS := ["mini", "hotbar", "panel", "card"]
const PART_NAMES := {"mini": "MINIMAP", "hotbar": "HOTKEY BAR", "panel": "SELECTION", "card": "COMMANDS"}
const TOP := 44.0          # below the top bar
const M := 8.0             # margin from the screen edge

static var active := "STANDARD"
static var profiles := {}  # custom name -> {"base", "pos": {part: [fx, fy]}, "panel_w", "keys": {id: letter}}
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(Settings.PATH) == OK:
		active = cfg.get_value("layout", "active", "STANDARD")
		profiles = cfg.get_value("layout", "profiles", {})
	if not (BUILT_IN.has(active) or CUSTOM.has(active)):
		active = "STANDARD"


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	cfg.set_value("layout", "active", active)
	cfg.set_value("layout", "profiles", profiles)
	cfg.save(Settings.PATH)


static func editable(name: String) -> bool:
	return CUSTOM.has(name)


static func data(name := "") -> Dictionary:
	load_all()
	if name == "":
		name = active
	if CUSTOM.has(name):
		if not profiles.has(name):
			profiles[name] = {"base": "STANDARD", "pos": {}, "keys": {}}
		return profiles[name]
	return {"base": name, "pos": {}, "keys": {}}


## Every part's rect for a HUD of size `hud` with parts of these sizes ({part: Vector2}).
static func rects(hud: Vector2, sizes: Dictionary, name := "") -> Dictionary:
	var d := data(name)
	var out := _preset(String(d.get("base", "STANDARD")), hud, sizes)
	var pos: Dictionary = d.get("pos", {})
	var area := Rect2(M, TOP, hud.x - 2 * M, hud.y - TOP - M)
	if d.has("panel_w"):
		var pr: Rect2 = out["panel"]
		pr.size.x = clampf(float(d["panel_w"]) * hud.x, 220.0, hud.x - 2 * M)
		out["panel"] = pr
	for part in PARTS:
		if pos.has(part):
			var sz: Vector2 = (out[part] as Rect2).size
			var f: Array = pos[part]
			out[part] = Rect2(area.position + (area.size - sz).max(Vector2.ZERO) * Vector2(float(f[0]), float(f[1])), sz)
	return out


## Where a part sits as fractions of the free space (what custom layouts store).
static func fraction(r: Rect2, hud: Vector2) -> Array:
	var area := Rect2(M, TOP, hud.x - 2 * M, hud.y - TOP - M)
	var free := (area.size - r.size).max(Vector2.ONE)
	var f := ((r.position - area.position) / free).clamp(Vector2.ZERO, Vector2.ONE)
	return [f.x, f.y]


static func _preset(base: String, hud: Vector2, sizes: Dictionary) -> Dictionary:
	var mini: Vector2 = sizes["mini"]
	var hb: Vector2 = sizes["hotbar"]     # least width, height
	var card: Vector2 = sizes["card"]
	var ph: float = sizes["panel"].y
	var out := {}
	out["card"] = Rect2(hud.x - card.x - M, hud.y - card.y - M, card.x, card.y)
	if base == "MINIMAP TOP RIGHT":
		out["mini"] = Rect2(hud.x - mini.x - M, TOP, mini.x, mini.y)
		out["panel"] = Rect2(M, hud.y - ph - M, maxf(220.0, (out["card"] as Rect2).position.x - 2 * M), ph)
	else:
		out["mini"] = Rect2(M, hud.y - mini.y - M, mini.x, mini.y)
		var l := M + mini.x + 8
		out["panel"] = Rect2(l, hud.y - ph - M, maxf(220.0, (out["card"] as Rect2).position.x - 8 - l), ph)
	# the hotkey bar: right above the selection panel, as far right as the command card begins
	# (on a narrow screen it reaches left over the minimap's column, then sits above that too)
	var pr: Rect2 = out["panel"]
	var w := minf(maxf(pr.size.x, hb.x), pr.end.x - M)
	var left := pr.end.x - w
	var bottom := pr.position.y
	for part in ["mini", "panel"]:
		var r: Rect2 = out[part]
		if r.end.y >= hud.y - M - 1.0 and r.end.x > left and r.position.x < pr.end.x:
			bottom = minf(bottom, r.position.y)
	out["hotbar"] = Rect2(left, bottom - 4.0 - hb.y, w, hb.y)
	return out


# ------------------------------------------------------------------ hotkeys

## Command ids that can be rebound, besides every unit and building kind.
const COMMANDS := ["MOVE", "ATTACK", "STOP", "HOLD", "BUILD", "ADVANCED", "WORK", "DEPLOY", "RALLY", "GRUBS", "CANCEL", "MORE", "PLACE", "CANISTER", "ROUND SHOT", "UNLIMBER", "LIMBER", "ROOT", "UPROOT", "STORM", "MIASMA", "HOLD GAS", "SPIT", "HARVEST", "LOAD", "UNLOAD", "DROP HERE", "COURIER", "OVERLOAD", "LAND", "TAKE OFF"]


## The player's own key for a command or a unit/building kind ("" = the default).
static func key_for(id: String) -> String:
	return String(data().get("keys", {}).get(id, ""))


static func set_key(name: String, id: String, letter: String) -> void:
	var d := data(name)
	var keys: Dictionary = d.get("keys", {})
	if letter == "":
		keys.erase(id)
	else:
		keys[id] = letter
	d["keys"] = keys
	save_all()
