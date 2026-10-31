class_name ReplaysMenu
extends Control
## The REPLAYS page of the main menu (docs/replays.md): every recorded match, newest first, with WATCH, KEEP, EXPORT
## and DELETE; IMPORT brings in a replay file from elsewhere. The files are ReplayFile's (user://replays).

const HELP := "Every match you play is recorded: skirmish and online (online, each player gets the host's whole replay at the end). A replay is not a video: move the camera, select units, switch the fog, and change the speed. The newest replays are kept (Settings > REPLAYS KEPT); KEEP one to keep it for good."

var main: Node                 # Main (its _button helper, start_replay, show_menu)
var _list: VBoxContainer
var _note: Label
var _confirm := ""             # the file a DELETE is waiting to be confirmed for
var _js_cb = null              # (web) the file picker's callback: kept, or the browser drops it


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mg := MarginContainer.new()
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 14)
	add_child(mg)
	var pn := PanelContainer.new()
	mg.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pn.add_child(v)
	v.add_child(UiStyle.heading("REPLAYS", 40, UiStyle.TRIM))
	var help := UiStyle.text(HELP, 16, UiStyle.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var back: Button = main._button("BACK", func() -> void: main.show_menu())
	main._set_back(back)
	back.custom_minimum_size = Vector2(160, 50)
	top.add_child(back)
	var imp: Button = main._button("IMPORT", func() -> void: _import())
	imp.custom_minimum_size = Vector2(160, 50)
	top.add_child(imp)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var fold: Button = main._button("OPEN FOLDER", func() -> void:
			ReplayFile.ensure_dir()
			OS.shell_open(ProjectSettings.globalize_path(ReplayFile.DIR)))
		fold.custom_minimum_size = Vector2(190, 50)
		top.add_child(fold)
	_note = UiStyle.text("", 16, UiStyle.GOOD)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	refresh()


func say(text: String, good := true) -> void:
	if _note:
		_note.text = text
		_note.add_theme_color_override("font_color", UiStyle.GOOD if good else UiStyle.BAD)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var all := ReplayFile.list()
	if all.is_empty():
		_list.add_child(UiStyle.text("No replays yet: play a match.", 20, UiStyle.MUTED))
	for m in all:
		_list.add_child(_row(m))


const RESULT_TEXT := {"victory": "VICTORY", "defeat": "DEFEAT", "draw": "DRAW", "watched": "WATCHED",
	"unfinished": "UNFINISHED", "left": "LEFT EARLY"}


func _row(m: Dictionary) -> Control:
	var path := String(m["path"])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL_LIGHT, UiStyle.TRIM_DIM, 2, 10, 8.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	h.add_child(info)
	# line 1: when, the map, how long, the version, the size, the result
	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", 10)
	info.add_child(l1)
	var res := String(m.get("result", ""))
	var rc := UiStyle.GOOD if res == "victory" else (UiStyle.BAD if res == "defeat" else UiStyle.TRIM)
	var rl := UiStyle.text(RESULT_TEXT.get(res, res.to_upper()), 17, rc, HORIZONTAL_ALIGNMENT_LEFT, true)
	l1.add_child(rl)
	var when := Time.get_datetime_string_from_unix_time(int(m.get("date", 0)) + _tz(), true).substr(0, 16)
	var bits: Array = [when, String(m.get("map_name", m.get("map", ""))), ReplayPlayer.clock_text(float(m.get("len", 0.0))),
		"v" + String(m.get("version", "?")), "%.1f MB" % (int(m.get("size", 0)) / 1048576.0) if int(m.get("size", 0)) >= 1048576 else "%d KB" % (int(m.get("size", 0)) / 1024)]
	var l1t := UiStyle.text("   ·   ".join(bits), 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l1t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1t.clip_text = true
	l1.add_child(l1t)
	if bool(m.get("view_only", false)):
		l1.add_child(UiStyle.text("YOUR VIEW ONLY", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, true))
	if bool(m.get("kept", false)):
		l1.add_child(UiStyle.text("KEPT", 14, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_RIGHT, true))
	# line 2: the players, team by team, in their colours
	var l2 := HFlowContainer.new()
	l2.add_theme_constant_override("h_separation", 14)
	info.add_child(l2)
	var by_side := {}
	for pl in m.get("players", []):
		var sd := int(pl.get("side", 0))
		if not by_side.has(sd):
			by_side[sd] = []
		by_side[sd].append(pl)
	var sides := by_side.keys()
	sides.sort()
	for si in sides.size():
		if si > 0:
			l2.add_child(UiStyle.text("vs", 15, UiStyle.MUTED))
		for pl in by_side[sides[si]]:
			var c := int(pl.get("colour", 0))
			var col: Color = Defs.PALETTE[c][1] if c >= 0 and c < Defs.PALETTE.size() else Color.WHITE
			var fac := String(pl.get("faction", ""))
			var raw := String(pl.get("name", ""))
			var nm := _local_name(raw)
			var lb := UiStyle.text("■ %s%s" % [nm, "" if raw.to_lower().contains(fac) else " (%s)" % Loc.t(fac.capitalize())], 15, col.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, true)
			l2.add_child(lb)
	# the buttons
	var bw := VBoxContainer.new()
	bw.add_theme_constant_override("separation", 4)
	h.add_child(bw)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	bw.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	bw.add_child(r2)
	var watch: Button = main._button("WATCH", func() -> void: main.start_replay(path))
	UiStyle.primary(watch)
	watch.custom_minimum_size = Vector2(130, 44)
	r1.add_child(watch)
	var kept := bool(m.get("kept", false))
	var keep: Button = main._button("UNKEEP" if kept else "KEEP", func() -> void:
		ReplayFile.set_kept(path, not kept)
		refresh())
	keep.custom_minimum_size = Vector2(130, 44)
	r1.add_child(keep)
	var ex: Button = main._button("EXPORT", func() -> void: _export(path))
	ex.custom_minimum_size = Vector2(130, 40)
	r2.add_child(ex)
	var del: Button = main._button("SURE?" if _confirm == path else "DELETE", func() -> void:
		if _confirm != path:
			_confirm = path
			refresh()
			return
		_confirm = ""
		ReplayFile.delete(path)
		refresh())
	del.custom_minimum_size = Vector2(130, 40)
	if _confirm == path:
		del.add_theme_color_override("font_color", UiStyle.BAD)
	r2.add_child(del)
	return p


## Seconds this computer's clock is off UTC (the dates are kept in UTC, shown in local time).
static func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# ------------------------------------------------------------------ export and import

func _export(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var fname := path.get_file()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, fname, "application/octet-stream")
		say(Loc.t("%s is downloading.") % fname)
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Export replay", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), fname, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.hfr ; " + GameName.title() + " replay"]),
			func(ok: bool, files: PackedStringArray, _f: int) -> void:
				if ok and not files.is_empty():
					_write_out(files[0], bytes))
		return
	if OS.has_feature("mobile"):
		say(Loc.t("This phone has no file picker here. The replay is in the game's own folder: %s") % ProjectSettings.globalize_path(path), false)
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	fd.current_file = fname
	fd.filters = PackedStringArray(["*.hfr ; " + GameName.title() + " replay"])
	fd.file_selected.connect(func(f: String) -> void: _write_out(f, bytes))
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))


func _write_out(dest: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		say(Loc.t("Could not write %s.") % dest, false)
		return
	f.store_buffer(bytes)
	f.close()
	say(Loc.t("Saved as %s.") % dest)


func _import() -> void:
	if OS.has_feature("web"):
		_web_pick()
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Import replay", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.hfr ; " + GameName.title() + " replay"]),
			func(ok: bool, files: PackedStringArray, _f: int) -> void:
				if ok and not files.is_empty():
					import_bytes(FileAccess.get_file_as_bytes(files[0])))
		return
	if OS.has_feature("mobile"):
		say("This phone has no file picker here: put the .hfr file in the game's replays folder.", false)
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	fd.filters = PackedStringArray(["*.hfr ; " + GameName.title() + " replay"])
	fd.file_selected.connect(func(f: String) -> void: import_bytes(FileAccess.get_file_as_bytes(f)))
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))


func import_bytes(bytes: PackedByteArray) -> void:
	var p := ReplayFile.import_bytes(bytes)
	if p == "":
		say("That file is not a replay of this game.", false)
	else:
		say("Replay imported.")
	refresh()


## (web) The browser's file picker: the file comes back as base64 (JavaScriptBridge passes strings).
func _web_pick() -> void:
	_js_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		if args.is_empty() or String(args[0]) == "":
			return
		import_bytes(Marshalls.base64_to_raw(String(args[0]))))
	var w = JavaScriptBridge.get_interface("window")
	w.hfReplayPicked = _js_cb
	JavaScriptBridge.eval("""
		(function(){
			var inp = document.createElement('input');
			inp.type = 'file';
			inp.accept = '.hfr';
			inp.onchange = function() {
				var f = inp.files && inp.files[0];
				if (!f) return;
				var rd = new FileReader();
				rd.onload = function() {
					var s = rd.result;
					window.hfReplayPicked(s.substring(s.indexOf(',') + 1));
				};
				rd.readAsDataURL(f);
			};
			inp.click();
		})();
	""", true)


## A player's name as the replay stored it ("P1 Crown (you)", "P2 Brood (easy AI)": English) in
## the language in use (it showed in English in Portuguese and Spanish).
static func _local_name(nm: String) -> String:
	for f in ["Crown", "Brood", "Clockwork"]:
		nm = nm.replace(" %s" % f, " %s" % Loc.t(f))
	if Loc.t("YOU") != "YOU":
		nm = nm.replace("(you)", "(%s)" % Loc.t("YOU").to_lower())
	for w in ["easy", "normal", "hard", "brutal"]:
		var k := "%s AI" % w.to_upper()
		if Loc.t(k) != k:
			nm = nm.replace("(%s AI)" % w, "(%s)" % Loc.t(k).to_lower().replace("ia ", "IA "))
	return nm
