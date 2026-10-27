class_name ReplayPlayer
extends NetSession
## Watching a replay (docs/replays.md): the game is an online guest's puppet (game.puppet: drawn and animated, nothing
## simulated) and this session feeds it the recorded pictures instead of a host's. game.net and game.replay are this.
## The clock it shows (play_t) moves with the game's ticks (Engine.time_scale is the speed); pictures are put on the
## puppets one ahead of it, so every unit glides between the two around play_t (NetSession.shown_at, rclk = play_t).
## A seek clears the world and starts again from the keyframe before the time asked, then runs the deltas forward
## silently (Sfx.hush): nothing from another time stays behind.

signal changed                    # playing, speed, the end reached: the bar redraws

const SPEEDS := [0.5, 1.0, 2.0, 4.0, 8.0]
const PLACEHOLDER := "horse"      # a unit kind this version no longer has is drawn as this, greyed

var data := {}
var header := {}
var footer := {}
var chunks: Array = []
var events: Array = []
var length := 0.0
var start_t := 0.0
var play_t := 0.0
var playing := true
var speed := 1.0
var at_end := false
var view_only := false
var me := -1                      # the team that recorded (-1: computers only)
var version_note := ""            # "recorded on v0.14.40: some things may look different" (another version)
var cam_follow := false           # the camera follows the recording player's
var _ci := -1                     # the chunk whose frames are decoded
var _frames: Array = []
var _fi := 0
var _ev := 0
var _seeking := false
var _cam_cur = null               # the recorded camera (Vector3: x, y, zoom) as of the last picture
var _cam_a: Array = []            # [clock, camera] before the newest change, and [clock, camera] of it
var _cam_b: Array = []
var _remap := {}                  # another version's field lists: how to read its rows (remap)
var _ph := {}                     # ids drawn as a placeholder
var _skip := {}                   # building ids of a kind this version no longer has (left out)
var _udef := {}                   # this version's default value of each unit / building field (remap)
var _bdef := {}
var _income := {}                 # team -> [[clock, gold so far], ...] (income per minute on the observer bar)
var end_winner := -1


## Read a replay file: the parsed data (ReplayFile.parse) with "error" set when it can't be watched.
static func load_file(path: String) -> Dictionary:
	var d := ReplayFile.read(path)
	if not d.get("ok", false):
		d["error"] = "This replay file is damaged or empty."
		return d
	var cfg: Dictionary = (d["header"] as Dictionary).get("cfg", {})
	var mid := String(cfg.get("map", ""))
	var cm = (d["header"] as Dictionary).get("custom_map")
	if mid.begins_with("custom:") and not map_exists(mid) and cm is Dictionary and not cm.is_empty():
		MapGen.save_custom(cm)          # (a map of the player who recorded it: it comes with the replay)
	if not map_exists(mid):
		d["error"] = Loc.t("Its map (%s) is not in this version of the game.") % mid
	for f in cfg.get("slots", []):
		if not Defs.FACTIONS.has(String(f.get("faction", ""))):
			d["error"] = "A faction in it is not in this version of the game."
	return d


static func map_exists(id: String) -> bool:
	if MapGen.MAPS.has(id) or MapData.NAMED.has(id) or id.begins_with("blank:"):
		return true
	if id.begins_with("custom:"):
		return not MapGen.load_custom(id.substr(7)).is_empty()
	return false


## Make `g` (a puppet in the tree) play `d` (load_file).
static func play(g: Game, d: Dictionary) -> ReplayPlayer:
	var p := ReplayPlayer.new()
	p.game = g
	p.is_host = false
	p.go_given = true
	p.lead_on = false
	p._m_reset()
	p.name = "ReplayPlayer"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.data = d
	p.header = d["header"]
	p.footer = d.get("footer", {})
	p.chunks = d["chunks"]
	p.events = d.get("events", [])
	p.me = int(p.header.get("me", -1))
	p.view_only = bool(p.header.get("view_only", false))
	p.start_t = float(p.chunks[0]["t0"])
	p.length = float(p.footer.get("len", 0.0)) if not p.footer.is_empty() else float(p.chunks.back()["t1"])
	p.length = maxf(p.length, float(p.chunks.back()["t1"]))
	var ver := String(p.header.get("game_version", "?"))
	if ver != String(ProjectSettings.get_setting("application/config/version", "dev")):
		p.version_note = Loc.t("Recorded on v%s: some things may look different.") % ver
	p._set_remap(p.header.get("lists", {}))
	g.net = p
	g.replay = p
	g.add_child(p)
	p.seek(p.start_t)
	return p


func _process(_delta: float) -> void:
	pass                         # (NetSession's: the link, pings, the countdown; a replay has none)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.hush = false


# ------------------------------------------------------------------ the online parts a replay has none of

func send_cmd(_c: Dictionary) -> void:
	pass


func chat_out(_team: int, _text: String, _from_peer: int) -> void:
	pass


func set_hidden(_on: bool) -> void:
	pass


func request_pause(on: bool) -> void:
	set_playing(not on)


func ping_shown() -> int:
	return -1


func ping_grade() -> int:
	return 0


func pause_text() -> String:
	return ""


func minute_line() -> String:
	return ""


# ------------------------------------------------------------------ controls

func set_playing(on: bool) -> void:
	if on and at_end:
		seek(start_t)
	playing = on
	_freeze(not on)
	changed.emit()


func set_speed(x: float) -> void:
	speed = x
	Engine.time_scale = x
	changed.emit()


## The next speed up (or down), 0.5x to 8x.
func step_speed(dir: int) -> void:
	var i := SPEEDS.find(speed)
	set_speed(SPEEDS[clampi((i if i >= 0 else 1) + dir, 0, SPEEDS.size() - 1)])


## While paused the pictures stand still (the units, their animations, buildings); the camera and the selection work.
func _freeze(on: bool) -> void:
	if game and game.world:
		game.world.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func follow_camera(on: bool) -> void:
	cam_follow = on and me >= 0
	if cam_follow and game.spectator and game.spectator.mode == "follow":
		game.spectator.set_mode("free" if game.view_team >= 0 else "all", maxi(game.view_team, 0), true)
	changed.emit()


# ------------------------------------------------------------------ playing

## Each game tick (NetPuppet.tick_game): the shown clock moves on and the pictures up to it go on the puppets.
func tick_rclk(delta: float) -> void:
	if playing:
		play_t = minf(play_t + delta, length)
		_feed(play_t)
		if play_t >= length - 0.001 and not at_end:
			at_end = true
			playing = false
			_freeze(true)
			changed.emit()
	rclk = play_t
	game.clock = play_t
	_post_events(play_t)
	if cam_follow:
		_camera()


## Put the pictures on until the newest one is past `t` (one ahead: the units glide between the two around t).
func _feed(t: float) -> void:
	var guard := 0
	while snap_clk <= t or _ci < 0:
		var m = _next_frame()
		if m == null:
			break
		_apply(m)
		guard += 1
		if guard > 100000:
			break


func _next_frame():
	while true:
		if _ci < 0 or _fi >= _frames.size():
			if _ci + 1 >= chunks.size():
				return null
			_load_chunk(_ci + 1)
			continue
		var b: PackedByteArray = _frames[_fi]
		_fi += 1
		var m = bytes_to_var(b)
		if m is Dictionary:
			return m
	return null


func _load_chunk(i: int) -> void:
	_ci = i
	_fi = 0
	_frames = ReplayFile.unpack_frames(chunks[i]["data"])


func _apply(m: Dictionary) -> void:
	var clk := float(m.get("clk", snap_clk))
	if m.has("over"):
		if bool(m["over"]):
			end_winner = int(m.get("win", -1))
		m.erase("over")            # (the match never ends here: seeking back must still work)
	if m.has("cam"):
		_cam_a = [snap_clk, _cam_cur if _cam_cur != null else m["cam"]]
		_cam_b = [clk, m["cam"]]
		_cam_cur = m["cam"]
	if not _remap.is_empty():
		_remap_rows(m)
	_sanitize(m)
	if m.has("fx"):
		var keep: Array = []
		for f in m["fx"]:
			if _seeking and f[0] != "c" and f[0] != "h":
				continue           # (a jump: only the bodies torn or hit, no sights or sounds from the times between)
			if f[0] == "e" and not ArtData.EFFECTS.has(String(f[1])):
				continue
			keep.append(f)
		m["fx"] = keep
	prev_clk = snap_clk
	snap_clk = clk
	if prev_clk > 0.0:
		interval = clampf(snap_clk - prev_clk, 0.03, 0.5)
	NetSnapshot.apply(self, m)
	for id in _ph:
		var u = by_id.get(id)
		if is_instance_valid(u):
			u.modulate = Color(0.55, 0.55, 0.55, 0.75)
	var sg: Array = m.get("sg", [])
	for t in sg.size():
		var h: Array = _income.get(t, [])
		h.append([clk, int(sg[t][0]), int(sg[t][1])])
		while h.size() > 2 and float(h[1][0]) < clk - 60.0:
			h.pop_front()
		_income[t] = h


## A unit kind this version doesn't have: drawn as PLACEHOLDER, greyed. A building kind: left out.
func _sanitize(m: Dictionary) -> void:
	if m.has("u"):
		for row in m["u"]:
			if not Defs.UNITS.has(String(row[1])):
				row[1] = PLACEHOLDER
				_ph[int(row[0])] = true
	if m.has("b"):
		var keep: Array = []
		for row in m["b"]:
			if Defs.BUILDINGS.has(String(row[1])) and not _skip.has(int(row[0])):
				keep.append(row)
			else:
				_skip[int(row[0])] = true
		m["b"] = keep


## The chat (and the end) as play_t passes their times.
func _post_events(t: float) -> void:
	while _ev < events.size() and float(events[_ev][0]) <= t:
		var e: Array = events[_ev]
		_ev += 1
		if String(e[1]) == "chat" and game.chat:
			game.chat.post(int(e[2]), String(e[3]))


func _camera() -> void:
	if _cam_b.is_empty():
		return
	var a: Vector3 = _cam_a[1]
	var b: Vector3 = _cam_b[1]
	var span := float(_cam_b[0]) - float(_cam_a[0])
	var f := 1.0 if span <= 0.001 else clampf((play_t - float(_cam_a[0])) / span, 0.0, 1.0)
	var c := a.lerp(b, f)
	game.camera.position = Vector2(c.x, c.y)
	game.camera.zoom = Vector2(c.z, c.z)


# ------------------------------------------------------------------ seeking

## Jump to match time `t`: everything goes, the keyframe before t is put on an empty map and the pictures after it
## run forward to t (no sounds, no effects).
func seek(t: float) -> void:
	t = clampf(t, start_t, length)
	var back := t < play_t
	_clear_world()
	var k := 0
	for i in chunks.size():
		if float(chunks[i]["t0"]) <= t + 0.001:
			k = i
	_ci = -1
	_frames = []
	_fi = 0
	if k > 0:
		_load_chunk(k)
	snap_clk = 0.0
	prev_clk = 0.0
	_cam_a = []
	_cam_b = []
	_cam_cur = null
	_income = {}
	_seeking = true
	Sfx.hush = true
	_feed(t)
	Sfx.hush = false
	_seeking = false
	play_t = t
	rclk = t
	game.clock = t
	at_end = t >= length - 0.001
	# the chat: the lines of the last few seconds, as they would still show
	_ev = 0
	if game.chat:
		game.chat.lines.clear()
	while _ev < events.size() and float(events[_ev][0]) <= t:
		var e: Array = events[_ev]
		_ev += 1
		if String(e[1]) == "chat" and game.chat and float(e[0]) > t - Chat.SHOW_SECS:
			Sfx.hush = true
			game.chat.post(int(e[2]), String(e[3]))
			Sfx.hush = false
	if back:
		for ex in game.explored_by:
			(ex as PackedByteArray).fill(0)     # (what each side had looked at by then: from here on)
	game.swamp_dirty = true
	game.fog_base_dirty = true
	game.refresh_fog()
	for u in game.units:
		var at := shown_at(u.net_id)          # (where the pictures have it now: NetPuppet.tick_unit would put it there next)
		if not at.is_empty():
			u.position = at[0]
			u.velocity = at[1]
		u.reset_physics_interpolation()
	if cam_follow:
		_camera()
	changed.emit()


func _clear_world() -> void:
	var g := game
	for u in g.units.duplicate():
		NetSnapshot._unit_gone(g, u)
	for b in g.buildings.duplicate():
		if is_instance_valid(b):
			NetSnapshot._building_gone(g, b, false)
	for n in g.world.get_children():
		if (n is Unit or n is Building or n is Crate) and not n.is_queued_for_deletion():
			n.queue_free()       # (bodies and rubble too)
	for n in g.get_children():
		if n is Effect or n is Shot or n is OwlBomb or n is ChainNet:
			n.queue_free()
	g.units.clear()
	g.buildings.clear()
	g.crates.clear()
	g.selection.clear()
	g.bodies.clear()
	for grp in g.groups:
		grp.clear()
	g._floats.clear()
	by_id.clear()
	motion.clear()
	hist.clear()
	rowhash.clear()
	leads.clear()
	_ph.clear()
	_skip.clear()


# ------------------------------------------------------------------ the observer bar

## Income per minute of side t over the last minute ([main, second resource]).
func income_of(t: int) -> Vector2:
	var h: Array = _income.get(t, [])
	if h.size() < 2:
		return Vector2.ZERO
	var a: Array = h[0]
	var b: Array = h[h.size() - 1]
	var dt := maxf(float(b[0]) - float(a[0]), 1.0)
	return Vector2(float(b[1]) - float(a[1]), float(b[2]) - float(a[2])) * 60.0 / dt


## "income 640/min · army 1200 · 14 workers" for side t.
func obs_line(t: int) -> String:
	var inc := income_of(t)
	return Loc.t("income %d/min · army %d · %d workers") % [int(inc.x), game.army_value(t), game.worker_count(t)]


## The match time as "12:05".
static func clock_text(secs: float) -> String:
	var s := int(secs)
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ another version's replays

## The recorded field lists, if they differ from this version's: rows are read by name (remap).
func _set_remap(rec: Dictionary) -> void:
	_remap = {}
	if rec.is_empty():
		return
	var now := ReplayRecorder.lists()
	if str(rec) == str(now):
		return
	_remap = rec
	var tu := Unit.new()
	for p in NetSnapshot.UNIT_PROPS:
		_udef[p] = NetSnapshot.q(tu.get(p))
	tu.free()
	var tb := Building.new()
	for p in NetSnapshot.BLD_PROPS:
		_bdef[p] = NetSnapshot.q(tb.get(p))
	tb.free()


func _remap_rows(m: Dictionary) -> void:
	var up: Array = _remap.get("up", NetSnapshot.UNIT_PROPS)
	var ur: Array = _remap.get("ur", NetSnapshot.UNIT_REFS)
	var uf := int(_remap.get("uf", NetSnapshot.U_FIXED))
	var bp: Array = _remap.get("bp", NetSnapshot.BLD_PROPS)
	var br: Array = _remap.get("br", NetSnapshot.BLD_REFS)
	var bf := int(_remap.get("bf", NetSnapshot.B_FIXED))
	if m.has("u"):
		var out: Array = []
		for row in m["u"]:
			out.append(_row_by_name(row, uf, up, ur, true))
		m["u"] = out
	if m.has("b"):
		var outb: Array = []
		for row in m["b"]:
			outb.append(_row_by_name(row, bf, bp, br, false))
		m["b"] = outb


## One row from another version's layout into this one's: [fixed][props][(units: cooldown)][refs][list of ids].
func _row_by_name(row: Array, fixed: int, props: Array, refs: Array, unit: bool) -> Array:
	var nf := NetSnapshot.U_FIXED if unit else NetSnapshot.B_FIXED
	var out: Array = []
	for i in nf:
		out.append(row[i] if i < fixed and i < row.size() else 0)
	if row.size() <= fixed:
		return out                 # (a short row: the fixed fields only)
	var now_props: Array = NetSnapshot.UNIT_PROPS if unit else NetSnapshot.BLD_PROPS
	var now_refs: Array = NetSnapshot.UNIT_REFS if unit else NetSnapshot.BLD_REFS
	var defs: Dictionary = _udef if unit else _bdef
	for p in now_props:
		var j := props.find(p)
		var dv = defs.get(p)
		var v = row[fixed + j] if j >= 0 and fixed + j < row.size() else dv
		out.append(v if typeof(v) == typeof(dv) else type_convert(v, typeof(dv)) if dv != null else v)
	var base := fixed + props.size()
	if unit:
		out.append(bool(row[base]) if base < row.size() else false)
		base += 1
	for r in now_refs:
		var j2 := refs.find(r)
		out.append(int(row[base + j2]) if j2 >= 0 and base + j2 < row.size() else 0)
	var li := base + refs.size()
	out.append(row[li] if li < row.size() and row[li] is Array else [])
	return out
