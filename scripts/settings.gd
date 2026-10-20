class_name Settings
## Player settings kept in user://settings.cfg: which device the game is played on
## ("pc" or "mobile"; "" = not asked yet) and, on mobile, what a one-finger drag does.

const PATH := "user://settings.cfg"

static var device := ""
static var drag_mode := "box"        # mobile: "box" = drag selects, "pan" = drag moves the view
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		device = cfg.get_value("input", "device", "")
		drag_mode = cfg.get_value("input", "drag_mode", "box")
	apply()


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)          # keep the other sections (audio)
	cfg.set_value("input", "device", device)
	cfg.set_value("input", "drag_mode", drag_mode)
	cfg.save(PATH)


static func set_device(d: String) -> void:
	device = d
	apply()
	save_all()


static func pc() -> bool:
	return device == "pc"


## On a computer the mouse is a mouse; on a phone touches stay touches (and a mouse,
## if any, pretends to be a finger so the phone controls can be tried on a desktop).
static func apply() -> void:
	Input.emulate_touch_from_mouse = not pc()
