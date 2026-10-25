class_name MultiplayerMenu
extends Control
## The ONLINE page of the main menu: host a game (you get a short room code), or join a friend's by
## code. Then the waiting room: slots, map and mode (host), your faction (guest), START (host).
## The logic is NetLobby; this only shows it. Needs the relay address (SETTINGS, tools/relay/README.md).

const FACS := ["random", "crown", "brood", "clockwork"]

var main: Node                 # Main (its _button / _page helpers and start())
var code_edit: LineEdit
var _box: VBoxContainer


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	add_child(m)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	m.add_child(_box)
	_draw()


func _lobby() -> NetLobby:
	return main.net_lobby


func _draw() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UiStyle.heading("ONLINE", 42, UiStyle.TRIM))
	if _lobby() == null:
		_draw_entry()
	else:
		_draw_room()


func _relay_set() -> bool:
	return not Settings.relay_url.contains("YOURNAME") and Settings.relay_url.strip_edges() != ""


func _draw_entry() -> void:
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(cc)
	var pn := PanelContainer.new()
	pn.custom_minimum_size.x = 700
	cc.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pn.add_child(v)
	var note := UiStyle.text("Play a friend over the internet: web and Android can play together. One of you hosts and tells the other the room code. The host's device runs the match, so the host has no delay; the guest feels the internet's delay.", 17, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	var rl := UiStyle.text("RELAY ADDRESS", 18, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	rrow.add_child(rl)
	var re := LineEdit.new()
	re.text = Settings.relay_url
	re.placeholder_text = "wss://pocketrts-relay.salgarellius-rts.workers.dev"
	re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	re.custom_minimum_size = Vector2(0, 52)
	re.text_changed.connect(func(t: String) -> void:
		Settings.relay_url = t.strip_edges()
		Settings.save_all())
	rrow.add_child(re)
	v.add_child(rrow)
	if not _relay_set():
		var w := UiStyle.text("Set the relay address first (the one `wrangler deploy` printed, see tools/relay/README.md).", 16, UiStyle.BAD, HORIZONTAL_ALIGNMENT_LEFT)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(w)
	var host: Button = main._button("HOST A GAME", func() -> void:
		var l := NetLobby.new()
		main.add_child(l)
		main.net_lobby = l
		l.changed.connect(_on_changed)
		l.failed.connect(_on_failed)
		l.host(Settings.relay_url, NetLink.new_code())
		_draw())
	UiStyle.primary(host)
	host.custom_minimum_size = Vector2(0, 64)
	host.disabled = not _relay_set()
	v.add_child(host)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "ROOM CODE"
	code_edit.max_length = 12
	code_edit.custom_minimum_size = Vector2(240, 64)
	code_edit.add_theme_font_size_override("font_size", 30)
	code_edit.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			code_edit.text = up
			code_edit.caret_column = up.length())
	jrow.add_child(code_edit)
	var join: Button = main._button("JOIN", func() -> void:
		var c := code_edit.text.strip_edges()
		if c.length() < 3:
			return
		var l := NetLobby.new()
		main.add_child(l)
		main.net_lobby = l
		l.changed.connect(_on_changed)
		l.failed.connect(_on_failed)
		l.start_now.connect(func(cfg: Dictionary) -> void:
			main.start(cfg))
		l.join(Settings.relay_url, c)
		_draw())
	join.custom_minimum_size = Vector2(200, 64)
	join.disabled = not _relay_set()
	jrow.add_child(join)
	v.add_child(jrow)
	var back: Button = main._button("BACK", func() -> void: main.show_menu())
	back.custom_minimum_size = Vector2(240, 58)
	_box.add_child(back)


func _on_changed() -> void:
	if is_inside_tree():
		_draw()


func _on_failed(_why: String) -> void:
	if is_inside_tree():
		_draw()


func _draw_room() -> void:
	var l := _lobby()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var code := UiStyle.heading("ROOM  " + l.code, 38, Color(1, 0.9, 0.55))
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(code)
	if l.is_host:
		var cp: Button
		cp = main._button("COPY", func() -> void:
			DisplayServer.clipboard_set(l.code)
			cp.text = Loc.t("COPIED"))
		cp.custom_minimum_size = Vector2(150, 54)
		top.add_child(cp)
		top.move_child(cp, 0)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(150, 0)
		top.add_child(pad)
	_box.add_child(top)
	var st := UiStyle.text(l.status, 18, UiStyle.BAD if l.refused != "" or not l.online else UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(st)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(body)
	var pp := PanelContainer.new()
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pp.add_child(pv)
	for i in l.slots.size():
		pv.add_child(_slot_row(l, i))
	# map and mode
	var mp := PanelContainer.new()
	mp.custom_minimum_size.x = 340
	body.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mp.add_child(mv)
	mv.add_child(UiStyle.text("MODE", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	if l.is_host:
		var mb: Button = main._button(String(NetLobby.MODE_LABEL[l.mode]), func() -> void:
			l.set_mode("coop" if l.mode == "1v1" else "1v1"))
		mv.add_child(mb)
	else:
		mv.add_child(UiStyle.text(String(NetLobby.MODE_LABEL.get(l.mode, l.mode)), 20, UiStyle.TEXT))
	mv.add_child(UiStyle.text("MAP", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	var ids: Array = []
	for p in MapGen.POOLS:
		ids.append(p[0])
	ids += MapGen.all_ids()
	ids = ids.filter(func(id) -> bool: return l.map_fits(id))
	var mrow := HBoxContainer.new()
	mv.add_child(mrow)
	var cur: int = ids.find(l.map)
	if l.is_host:
		var prev: Button = main._button("<", func() -> void: l.set_map(ids[(cur - 1 + ids.size()) % ids.size()]))
		prev.custom_minimum_size = Vector2(46, 46)
		mrow.add_child(prev)
	var nm := UiStyle.text(MapGen.label(l.map) if MapGen.is_pool(l.map) else MapGen.display_name(l.map), 18, UiStyle.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mrow.add_child(nm)
	if l.is_host:
		var nx: Button = main._button(">", func() -> void: l.set_map(ids[(cur + 1) % ids.size()]))
		nx.custom_minimum_size = Vector2(46, 46)
		mrow.add_child(nx)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(sp)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_box.add_child(row)
	var back: Button = main._button("LEAVE", func() -> void:
		l.dispose()
		main.net_lobby = null
		_draw())
	back.custom_minimum_size = Vector2(200, 60)
	row.add_child(back)
	if l.is_host:
		var go: Button = main._button("START", func() -> void:
			Sfx.play_any(["ui/start_match"])
			main.start(l.make_cfg()))
		go.custom_minimum_size = Vector2(300, 60)
		go.add_theme_font_size_override("font_size", 28)
		UiStyle.primary(go)
		go.disabled = not l.all_seated()
		row.add_child(go)
		if not l.all_seated():
			row.add_child(UiStyle.text("Waiting for your friend to join.", 16, UiStyle.MUTED))


func _slot_row(l: NetLobby, i: int) -> Control:
	var s: Dictionary = l.slots[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var who := String(s["who"])
	var mine := (l.is_host and who == "you") or (not l.is_host and i == l.my_slot)
	var name_txt := ""
	if who == "you":
		name_txt = "YOU (HOST)" if l.is_host else "HOST"
	elif who == "remote":
		var here: bool = (int(s.get("peer", -1)) >= 0) if l.is_host else bool(s.get("here", false))
		name_txt = ("YOU" if mine else "FRIEND") if here else "waiting..."
	else:
		name_txt = "%s COMPUTER" % who.to_upper()
	var nl := UiStyle.text(name_txt, 20, Color(1, 0.9, 0.55) if mine else UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nl.custom_minimum_size.x = 200
	h.add_child(nl)
	var f := String(s["faction"])
	var fb: Button = main._button("RANDOM" if f == "random" else String(Defs.FACTIONS[f]["name"]).to_upper(), func() -> void:
		var nf: String = FACS[(FACS.find(f) + 1) % FACS.size()]
		if l.is_host:
			l.set_faction(i, nf)
		else:
			l.choose_faction(nf))
	fb.custom_minimum_size = Vector2(200, 52)
	# the host sets his own and the computers'; a friend sets only his own
	fb.disabled = not (l.is_host or mine)
	h.add_child(fb)
	var tl := UiStyle.text("TEAM %d" % (int(s["side"]) + 1), 16, UiStyle.MUTED)
	h.add_child(tl)
	return h
