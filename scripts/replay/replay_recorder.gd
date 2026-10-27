class_name ReplayRecorder
extends NetSession
## Records the match as it is played (docs/replays.md): the machine that runs it (a skirmish, the online host) takes
## the online mode's snapshots (NetSnapshot.build) of EVERY side, a few times a second, and writes them to a replay
## file (ReplayFile) in chunks: a keyframe (every entity whole) every KEY_SECS, then only what changed. An online guest
## records what it was sent (its own view only), as a fallback for the host's full replay.
## It is a NetSession so NetSnapshot.build can use it as is: its own "what was sent" bookkeeping, and no guest sides
## (guest_sides() is empty), so nothing is left out for fog. Never in the tree's net role: game.rec, not game.net.
## It records first in each physics frame (process_physics_priority): the state as the last game tick left it, every
## shot and blow of that tick landed.

signal recorded                  # a picture was taken (the tests compare the match with the replay right then)

const RATE := 5.0                # pictures a second, normally (the viewer glides between them)
const RATE_MIN := 3.0            # ...and in a big battle on a slow device, at least this many
const RATE_MAX := 8.0
## The share of real time recording may take (building and packing the pictures, writing the chunks): 3% of a
## phone's frame. Measured on the device itself, so a phone records less often than a computer in the same battle.
const BUDGET := 0.03
const KEY_SECS := 10.0           # a keyframe (a new chunk) this often: how far back a seek may have to start

var path := ""
var header := {}
var view_only := false           # an online guest: what it was sent (its side's view)
var rec_every := 1.0 / RATE
var frames: Array = []           # this chunk's frames (each var_to_bytes of a snapshot)
var chunk_t0 := 0.0
var last_clk := -999.0
var last_key := -999.0
var events: Array = []           # since the last chunk was written: [time, kind, ...]
var done := false
var written := false
var _cam_was := Vector3(INF, INF, INF)
var _id_next := 1 << 28          # (a guest's own entities with no id from the host: a range of their own)
# measurements (the test prints them; the doc's table)
var cost_us := 0                 # building and packing pictures, in all
var build_us := 0                # ...of which NetSnapshot.build
var compact_us := 0              # ...and compact (patches, columns)
var write_us := 0                # packing and writing the chunks, in all
var n_frames := 0
var n_keys := 0
var bytes_raw := 0
var bytes_file := 0
var _cost_avg := 0.0
var _out: Array = []             # who was out at the last picture


## Start recording `g` (in the tree, its setup known). `cfg`: the resolved setup (Main.last_cfg), `me`: the team
## that records (-1: watching computers).
static func start(g: Game, cfg: Dictionary, me: int, guest := false) -> ReplayRecorder:
	var r := ReplayRecorder.new()
	r.game = g
	r.is_host = true
	r.my_team = me
	r.view_only = guest
	r.go_given = true
	r.snap_every = 1.0 / RATE      # (never the "half rows" mode: pictures are far enough apart)
	r._m_reset()
	r.name = "ReplayRecorder"
	r.path = ReplayFile.new_path("_view" if guest else "")
	var c := cfg.duplicate(true)
	c.erase("net")
	c.erase("resume")
	var names: Array = []
	for t in g.n_players():
		var nm := "P%d %s" % [t + 1, g.faction_of(t).capitalize()]
		var who := String((c.get("slots", []) as Array)[t].get("who", "")) if t < (c.get("slots", []) as Array).size() else ""
		if t == me:
			nm += " (you)"
		elif who in ["easy", "normal", "hard", "brutal"]:
			nm += " (%s AI)" % who
		names.append(nm)
	r.header = {"format": ReplayFile.FORMAT, "game_version": String(ProjectSettings.get_setting("application/config/version", "dev")),
		"cfg": c, "me": me, "names": names, "date": int(Time.get_unix_time_from_system()), "map_name": g.map_name,
		"online": ("guest" if guest else "host") if g.net != null else "", "view_only": guest,
		"sandbox": g.sandbox, "cw_roster": Defs.cw_roster, "lists": lists(), "rate": RATE, "key_secs": KEY_SECS, "t0": snappedf(g.clock, 0.01)}
	if String(c.get("map", "")).begins_with("custom:"):
		r.header["custom_map"] = MapGen.load_custom(String(c["map"]).substr(7))     # (so it plays where the map isn't)
	r.written = ReplayFile.begin(r.path, r.header)
	if r.written:
		ReplayFile.write_meta(r.path, ReplayFile.meta_from(r.header, {}, r.path))
	r.process_physics_priority = -1000
	g.rec = r
	g.add_child(r)
	return r


## The snapshot's field lists (a replay from another version is read by name: ReplayPlayer.remap).
static func lists() -> Dictionary:
	return {"up": NetSnapshot.UNIT_PROPS, "ur": NetSnapshot.UNIT_REFS, "bp": NetSnapshot.BLD_PROPS, "br": NetSnapshot.BLD_REFS,
		"uf": NetSnapshot.U_FIXED, "bf": NetSnapshot.B_FIXED}


func _process(_delta: float) -> void:
	pass                         # (NetSession's: the link, pings; a recorder has none)


func _exit_tree() -> void:
	pass


## Ids: the game's one counter (shared with the online host's session: the replay and the guests agree). An online
## guest's own entities with no id from the host get one from a range of their own.
func assign(e: Entity) -> void:
	if e.net_id != 0:
		return
	if view_only:
		e.net_id = _id_next
		_id_next += 1
		return
	super.assign(e)


## An online guest's record leaves out the enemies it can't see now (it would otherwise keep them standing where they
## were last seen): they come back when seen again, as on its screen.
func rec_skip(e: Entity) -> bool:
	if not view_only or e.team < 0 or game.allied(e.team, my_team):
		return false
	return not e.visible


# ------------------------------------------------------------------ what happens besides the pictures

## Online host: a guest's camera (it says where it looks twice a second, NetSession), for the replay's CAMERA.
var _cams_new := {}
var _cams_last := {}


func note_cam(team: int, v: Vector3) -> void:
	if done or team == my_team:
		return
	_cams_new[team] = v
	_cams_last[team] = v


func note_chat(team: int, text: String) -> void:
	if not done:
		events.append([snappedf(game.clock, 0.01), "chat", team, text])


func note_event(kind: String, data: Array) -> void:
	if not done:
		events.append([snappedf(game.clock, 0.01), kind] + data)


## An online guest: the host's effects as they came (NetSession.play_fx), into its own record.
func note_fx(list: Array) -> void:
	for f in list:
		if fx.size() < FX_MAX:
			fx.append(f)


# ------------------------------------------------------------------ the pictures

func _physics_process(_delta: float) -> void:
	if done or not written:
		return
	if game.clock - last_clk < rec_every - 0.0005:
		return
	record()


func record(force_key := false) -> void:
	var t0 := Time.get_ticks_usec()
	var clk := game.clock
	var key := force_key or frames.is_empty() or clk - last_key >= KEY_SECS
	if key and not frames.is_empty():
		flush()
	# NetSnapshot.build makes a keyframe when snap_n % KEY_EVERY == 1
	snap_n += 1
	if key:
		snap_n = (snap_n / NetSnapshot.KEY_EVERY + 1) * NetSnapshot.KEY_EVERY + 1
		line_fp = -1               # (the Line and the old pit ground in every keyframe: a seek starts from one)
		pit_fp = -1
		last_key = clk
		chunk_t0 = clk
		n_keys += 1
	elif snap_n % NetSnapshot.KEY_EVERY == 1:
		snap_n += 1
	var tb := Time.get_ticks_usec()
	var m := NetSnapshot.build(self)
	build_us += Time.get_ticks_usec() - tb
	m.erase("ack")
	m.erase("acc")
	m.erase("pz")
	if key:
		m["tr"] = game.line_net.rails.view_rows()
		if Defs.cw_roster:
			m["cpl"] = CwConsist.net_rows(self, game)
		m["stats"] = game.stats.duplicate(true)
	else:
		m.erase("stats")          # (the battle report's numbers grow all match: only in keyframes and at the end)
		if game.over:
			m["stats"] = game.stats.duplicate(true)
	for t in game.n_players():
		if t < _out.size() and game.eliminated[t] and not _out[t]:
			note_event("out", [t])        # (a player is out: the viewer says so at its time)
	_out = game.eliminated.duplicate()
	var sg: Array = []
	for t in game.n_players():
		sg.append([int(game.stats[t]["gold"]), int(float(game.stats[t].get("res2_in", 0.0)))])
	m["sg"] = sg                   # (each side's income so far: the viewer's income per minute)
	var cam := Vector3(snappedf(game.camera.position.x, 1.0), snappedf(game.camera.position.y, 1.0), snappedf(game.camera.zoom.x, 0.01))
	if key or cam != _cam_was:
		_cam_was = cam
		m["cam"] = cam             # (the recording player's camera: "follow my camera")
	if key and not _cams_last.is_empty():
		m["cams"] = _cams_last.duplicate()
	elif not _cams_new.is_empty():
		m["cams"] = _cams_new
	_cams_new = {}
	var tc := Time.get_ticks_usec()
	compact(m, key)
	compact_us += Time.get_ticks_usec() - tc
	var b := var_to_bytes(m)
	frames.append(b)
	bytes_raw += b.size()
	n_frames += 1
	last_clk = clk
	var us := Time.get_ticks_usec() - t0
	cost_us += us
	Prof.add("replay/record", t0)
	recorded.emit()
	# as often as the budget allows (a big battle: fewer, never under RATE_MIN a second)
	_cost_avg = lerpf(_cost_avg, float(us), 0.15) if n_frames > 1 else float(us)
	var every := clampf(_cost_avg / 1e6 / BUDGET, 1.0 / RATE, 1.0 / RATE_MIN)
	rec_every = maxf(every, 1.0 / RATE_MAX)


## Smaller pictures for the file (ReplayPlayer.expand undoes it): between keyframes a whole row that changed only a few
## values goes as a patch ([fixed fields..., [index, value, index, value...]]), and the lists sent with every picture
## (players, power, the income) only when they changed. A keyframe is left whole: a seek starts from it.
const SAME_KEYS := ["pl", "en", "ore", "asm", "wind", "elim", "cnt", "sg", "win"]
var _last_rows := {}             # id -> its last whole row as written
var _last_vals := {}             # SAME_KEYS -> the last value written
var _last_fast := {}             # unit id -> [kind, team, x, y, hp, facing] as last written (in tenths, fiftieths)


## The short unit rows (a unit that only moved, turned or was hurt) as columns of small whole numbers, each the change
## since that unit's last row: "uf" = [ids..., dx..., dy..., d health..., d facing...] (tenths of a px, tenths of
## health, fiftieths of a radian). Most are 0 or a few dozen: zstd packs them several times smaller than the rows.
## A row whose unit changed kind or side, or is new here, stays a row.
static func fast_ints(row: Array) -> Array:
	var p: Vector2 = row[3]
	return [String(row[1]), int(row[2]), roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(float(row[4]) * 10.0), roundi(float(row[5]) * 50.0)]


func _columns(m: Dictionary, key: bool) -> void:
	var fx := NetSnapshot.U_FIXED
	var keep: Array = []
	var ids := PackedInt32Array()
	var dx := PackedInt32Array()        # (four plain arrays: a packed array taken out of an Array is a copy)
	var dy := PackedInt32Array()
	var dh := PackedInt32Array()
	var df := PackedInt32Array()
	for row in m["u"]:
		var r: Array = row
		var id := int(r[0])
		var now := fast_ints(r)
		var was = _last_fast.get(id)
		_last_fast[id] = now
		if key or r.size() > fx or was == null or was[0] != now[0] or was[1] != now[1]:
			keep.append(r)
			continue
		ids.append(id)
		dx.append(int(now[2]) - int(was[2]))
		dy.append(int(now[3]) - int(was[3]))
		dh.append(int(now[4]) - int(was[4]))
		df.append(int(now[5]) - int(was[5]))
	m["u"] = keep
	if not ids.is_empty():
		ids.append_array(dx)
		ids.append_array(dy)
		ids.append_array(dh)
		ids.append_array(df)
		m["uf"] = ids


func compact(m: Dictionary, key: bool) -> void:
	if key:
		_last_rows.clear()
		_last_fast.clear()
	for gn in m.get("gone", []):
		_last_rows.erase(int(gn[0]))
		_last_fast.erase(int(gn[0]))
	if m.has("u"):
		_columns(m, key)
	for pr in [["u", NetSnapshot.U_FIXED], ["b", NetSnapshot.B_FIXED]]:
		var fixed: int = pr[1]
		for row in m.get(pr[0], []):
			var r: Array = row
			if r.size() <= fixed:
				continue
			var id := int(r[0])
			var prev = _last_rows.get(id)
			_last_rows[id] = r.duplicate()
			if key or prev == null or (prev as Array).size() != r.size():
				continue
			var patch: Array = []
			for i in range(fixed, r.size()):
				if typeof(r[i]) != typeof(prev[i]) or r[i] != prev[i]:
					patch.append(i)
					patch.append(r[i])
			r.resize(fixed)
			r.append(patch)
	for k in SAME_KEYS:
		if not m.has(k):
			continue
		if not key and _last_vals.has(k) and _last_vals[k] == m[k]:
			m.erase(k)
		else:
			_last_vals[k] = m[k].duplicate(true) if (m[k] is Array or m[k] is Dictionary) else m[k]


## Write this chunk (and the events since the last one) to the file.
func flush() -> void:
	if frames.is_empty() or not written:
		return
	var t0 := Time.get_ticks_usec()
	if not events.is_empty():
		ReplayFile.append(path, ReplayFile.T_EVENTS, float(events[0][0]), float(events.back()[0]), var_to_bytes(events))
		events = []
	var data := ReplayFile.pack_frames(frames)
	ReplayFile.append(path, ReplayFile.T_CHUNK, chunk_t0, last_clk, data)
	bytes_file += data.size() + ReplayFile.REC_HEAD
	frames = []
	var us := Time.get_ticks_usec() - t0
	write_us += us
	cost_us += us
	Prof.add("replay/write", t0)


## The match is over (winner -1: a draw, or left before the end: `left`): the last picture, the footer, the list entry.
## Returns the replay's path ("" if nothing was written).
func finish(winner: int, left := false) -> String:
	if done:
		return path if written else ""
	if written:
		record(false)
		note_event("end", [winner, game.end_note, int(game.end_quitter)])
		flush()
		var footer := {"winner": winner, "len": snappedf(game.clock, 0.01), "note": game.end_note, "quit": int(game.end_quitter),
			"left": left, "frames": n_frames}
		var fb := var_to_bytes(footer)
		ReplayFile.append(path, ReplayFile.T_FOOT, game.clock, game.clock, fb)
		bytes_file += fb.size() + ReplayFile.REC_HEAD
		ReplayFile.write_meta(path, ReplayFile.meta_from(header, footer, path))
		ReplayFile.prune(Settings.replays_keep)
	done = true
	return path if written else ""


## Measurements for the tests and the doc: ms of recording per second of match, KB a minute.
func cost_line() -> String:
	var secs := maxf(game.clock - float(header.get("t0", 0.0)), 1.0)
	return "frames %d (%.1f/s), keyframes %d, recording %.2f ms per match second (snapshots %.2f, compacting %.2f, writing %.2f), raw %.0f KB, file %.0f KB (%.0f KB a minute)" % [
		n_frames, n_frames / secs, n_keys, cost_us / 1000.0 / secs, build_us / 1000.0 / secs, compact_us / 1000.0 / secs, write_us / 1000.0 / secs, bytes_raw / 1024.0,
		bytes_file / 1024.0, bytes_file / 1024.0 / secs * 60.0]
