class_name Settings
## Player settings kept in user://settings.cfg: which device the game is played on
## ("pc" or "mobile"; "" = not asked yet) and, on mobile, what a one-finger drag does.

const PATH := "user://settings.cfg"

static var device := ""
static var drag_mode := "box"        # mobile: "box" = drag selects, "pan" = drag moves the view
static var fullscreen := true         # web: play full screen (Esc no longer leaves it in Chrome/Edge)
static var ui_size := 0               # 0 = automatic, else a percentage (100-200)
static var grid_keys := true          # computer: command card keys by position (QWER / ASDF / ZXCV) instead of by name
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		device = cfg.get_value("input", "device", "")
		drag_mode = cfg.get_value("input", "drag_mode", "box")
		ui_size = cfg.get_value("input", "ui_size", 0)
		fullscreen = cfg.get_value("input", "fullscreen", true)
		grid_keys = cfg.get_value("input", "grid_keys", true)
	apply()


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)          # keep the other sections (audio)
	cfg.set_value("input", "device", device)
	cfg.set_value("input", "drag_mode", drag_mode)
	cfg.set_value("input", "ui_size", ui_size)
	cfg.set_value("input", "fullscreen", fullscreen)
	cfg.set_value("input", "grid_keys", grid_keys)
	cfg.save(PATH)


static func set_device(d: String) -> void:
	device = d
	apply()
	save_all()


## How big the in-game interface is drawn: phones get it 50% bigger unless set otherwise.
static func ui_scale_now() -> float:
	if ui_size > 0:
		return ui_size / 100.0
	return 1.0 if pc() else 1.5


static func pc() -> bool:
	return device == "pc"


## On a computer the mouse is a mouse; on a phone touches stay touches (and a mouse,
## if any, pretends to be a finger so the phone controls can be tried on a desktop).
static func apply() -> void:
	Input.emulate_touch_from_mouse = not pc()
