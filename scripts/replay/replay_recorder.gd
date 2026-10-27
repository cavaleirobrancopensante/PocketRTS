class_name ReplayRecorder
extends NetSession
## Records the match as it is played (docs/replays.md): the machine that runs it (a skirmish, the online host) takes
## the online mode's snapshots (NetSnapshot.build) of EVERY side, a few times a second, and writes them to a replay
## file (ReplayFile) in chunks: a keyframe (every entity whole) every KEY_SECS, then only what changed. An online guest
## records what it was sent (its own view only), as a fallback for the host's full replay.
## It is a NetSession so NetSnapshot.build can use it as is: its own "what was sent" bookkeeping, and no guest sides
## (guest_sides() is empty), so nothing is left out for fog. Never in the tree's net role: game.rec, not game.net.

const RATE := 6.0                # pictures a second, normally (the viewer glides between them)
const RATE_MIN := 3.0            # ...and in a big battle on a slow device, at least this many
const RATE_MAX := 8.0
## The share of real time recording may take (building and packing the pictures, writing the chunks): 3% of a
## phone's frame. Measured on the device itself, so a phone records less often than a computer in the same battle.
const BUDGET := 0.03
const KEY_SECS := 6.0            # a keyframe (a new chunk) this often: how far back a seek may have to start

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
var write_us := 0                # packing and writing the chunks, in all
var n_frames := 0
var n_keys := 0
var bytes_raw := 0
var bytes_file := 0
var _cost_avg := 0.0


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


## Ids: the online host's own (so the replay and the guests agree), else our own counter.
func assign(e: Entity) -> void:
	if e.net_id != 0:
		return
	if game.net != null and game.net != self and game.net.is_host:
		game.net.assign(e)
		return
	if view_only:
		e.net_id = _id_next
		_id_next += 1
		return
	e.net_id = next_id
	next_id += 1


## An online guest's record leaves out the enemies it can't see now (it would otherwise keep them standing where they
## were last seen): they come back when seen again, as on its screen.
func rec_skip(e: Entity) -> bool:
	if not view_only or e.team < 0 or game.allied(e.team, my_team):
		return false
	return not e.visible


# ------------------------------------------------------------------ what happens besides the pictures

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
	var m := NetSnapshot.build(self)
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
	var sg: Array = []
	for t in game.n_players():
		sg.append([int(game.stats[t]["gold"]), int(float(game.stats[t].get("res2_in", 0.0)))])
	m["sg"] = sg                   # (each side's income so far: the viewer's income per minute)
	var cam := Vector3(snappedf(game.camera.position.x, 1.0), snappedf(game.camera.position.y, 1.0), snappedf(game.camera.zoom.x, 0.01))
	if key or cam != _cam_was:
		_cam_was = cam
		m["cam"] = cam             # (the recording player's camera: "follow my camera")
	var b := var_to_bytes(m)
	frames.append(b)
	bytes_raw += b.size()
	n_frames += 1
	last_clk = clk
	var us := Time.get_ticks_usec() - t0
	cost_us += us
	Prof.add("replay/record", t0)
	# as often as the budget allows (a big battle: fewer, never under RATE_MIN a second)
	_cost_avg = lerpf(_cost_avg, float(us), 0.15) if n_frames > 1 else float(us)
	var every := clampf(_cost_avg / 1e6 / BUDGET, 1.0 / RATE, 1.0 / RATE_MIN)
	rec_every = maxf(every, 1.0 / RATE_MAX)


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
	return "frames %d (%.1f/s), keyframes %d, recording %.2f ms per match second (writing %.2f), raw %.0f KB, file %.0f KB (%.0f KB a minute)" % [
		n_frames, n_frames / secs, n_keys, cost_us / 1000.0 / secs, write_us / 1000.0 / secs, bytes_raw / 1024.0,
		bytes_file / 1024.0, bytes_file / 1024.0 / secs * 60.0]
