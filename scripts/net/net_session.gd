class_name NetSession
extends Node
## An online match in progress, attached to the Game (game.net).
## HOST: the real game and the computer players run here. Every 0.1 s the whole picture goes to the
## guests (NetSnapshot.build); their orders come back as commands (NetCommands.apply).
## GUEST: the game is a puppet (game.puppet): it applies snapshots and sends its orders as commands.
## The players are the game's teams: `peer_team` maps a guest's relay id to the team it plays (a
## second guest on the same side is a 2v1 co-op, a team vs a computer side, nothing more to build).
## Around the match: a ping each way about once a second (the counter left of the clock and the match log), the
## chat both ways, pauses (either player pauses, the host's game stops and both screens say who; PAUSES each, at most
## PAUSE_MAX seconds), a guest that hears nothing from the host for a second says so ("Waiting for the host..."), and
## a host whose browser tab or app goes to the background pauses the match for everyone until it is back.

signal lost(why: String)
signal replay_got(path: String)   # guest: the host's whole replay has arrived (saved there)

const SNAP_EVERY := 0.1
const SNAP_PAUSED := 0.5          # while paused nothing moves: a picture every half second is plenty
const UPLINK_MAX := 48 * 1024     # host: while this much is still waiting to leave the device, the next picture waits
const PING_EVERY := 1.0
const STALL_AFTER := 1000         # guest: msec without a picture = waiting for the host
const QUIET_AFTER := 2500         # host: msec without a word from a guest = it is not answering
const PAUSES := 3                 # online pauses for each player in a match
const PAUSE_MAX := 120.0          # a pause lasts at most this long (seconds), then the match goes on by itself
const RESUME_COUNT := 3.0         # the 3, 2, 1 before the match goes on again

var game: Game
var link: NetLink
var is_host := true
var my_team := 0                  # the team this machine plays
var peer_team := {}               # host: relay id -> team
var by_id := {}                   # net id -> Entity (as of the last snapshot)
var known := {}                   # host: the ids the last snapshot listed
var sent_slow := {}               # host: id -> hash of the values last sent whole (unchanged: a short row or none)
var sent_fast := {}               # host: id -> where it was / its health when last sent (unchanged too: no row)
var was_seen := {}                # host: ids a guest could see at the last snapshot (NetSnapshot._seen_by)
## Host: seconds between snapshots, from SNAP_FAST (15 a second, every 2 game ticks) to SNAP_EVERY (10, every 3), by what
## they cost to make here and their size (SNAP_BYTES a second at most):
## they may take SNAP_BUDGET of the time (a big battle on a phone: fewer, a small game on a computer: more).
const SNAP_FAST := 0.0667        # (two game ticks)
const SNAP_BUDGET := 0.05
var snap_every := SNAP_FAST
const SNAP_BYTES := 40.0 * 1024.0
var _build_ms := 1.0              # host: a snapshot's cost here (ms), smoothed
var _snap_pf := 0                 # host: the physics frame of the last picture
var _bytes_avg := 0.0             # host: a snapshot's size (bytes), smoothed
var _eyes: Array = []             # host: the sides the guests play (guest_sides), worked out when the guests change
var _eyes_n := -1
var next_id := 1
var snap_n := 0                   # host: snapshots sent / guest: the last one applied
var interval := SNAP_EVERY        # guest: seconds between snapshots, smoothed
var jitter := 0.0                 # guest: how far the time between them strays from that (smoothed), seconds
var motion := {}                  # guest: id -> [from, to, seconds since]
var rowhash := {}                 # guest: id -> hash of the last row applied
var acks := {}                    # host: relay id -> the last command number run for it
var cmd_seq := 0                  # guest: commands sent
var last_ack := 0                 # guest: the host has run commands up to this one
var sent_at := {}                 # guest: command number -> msec it was sent
var cmd_rtt_ms := 0.0             # guest: sent -> seen in a snapshot
var cmds_applied := 0
var cmds_rejected := 0
var snaps_got := 0
var last_reject := ""
var last_msg := ""                # guest: the last reason the host gave for an order it refused
var refusals := 0                 # guest: orders the host refused (each one said why)
var _told := {}                   # host: "team:text" -> msec it was last told (tell)
var trace := false
var _t := 0.0
var over_sent := 0
var fx: Array = []                # host: effects and shots since the last snapshot
var lost_peers := {}              # host: relay ids of guests who left
var count_diff_max := 0           # guest (tests): the most entities a snapshot left different from the host's list
var count_diff_snaps := 0
var line_fp := -1                 # host: fingerprint of the Line in the last snapshot that carried it
var pit_fp := -1                  # host: fingerprint of the Brood's old pit ground (Game.pit_spots) last sent
var _last_snap_ms := 0
# The start: both sides hold the 3-2-1 countdown until every guest's match has loaded (a phone loads slower
# than the host), then the host says GO and both count down together. READY_WAIT: start anyway after that.
const READY_WAIT := 20.0
var ready_peers := {}             # host: relay ids whose match has loaded
var go_given := false
var _wait_t := 0.0

# ---- pings (both ways): the counter left of the clock, and the match log
var ping_ms := -1.0               # the last round trip in msec (host: the slowest guest's); -1: none yet
var ping_of := {}                 # host: relay id -> its last round trip
var _ping_k := 0                  # pings sent
var _ping_out := {}               # ping number -> msec it left
var _answered := {}               # relay id (guest: 0, the host) -> the last ping number it answered
var _ping_t := 0.0
var _heard := {}                  # host: relay id -> msec of its last message
var _quiet := {}                  # host: relay id -> msec it went quiet (no word for QUIET_AFTER)
var waiting := false              # guest: no picture from the host for over STALL_AFTER
var _frame_ms := 0                # msec of the last frame (a long gap: this game itself stood still)

# ---- pause
var pause_by := -1                # the team whose PAUSE holds the match (-1: none)
var away := false                 # the host's game is in the background (a hidden browser tab, the app put away)
var pause_t := 0.0                # seconds this pause has lasted
var pauses_left := {}             # team -> pauses it still has (the host counts; the guests hear it)
var hidden := false               # this machine's window / app is in the background
var _hidden_ms := 0
var _vis_cb = null                # (web) the page's visibilitychange listener: kept, or the browser drops it

# ---- guest: units told to walk start out at once, before the host's picture shows the order (lead)
const LEAD_PACE := 1.0            # ...at their own speed
const LEAD_BACK := 0.12           # once the host's snapshot shows the order, the lead is taken back at this share of their speed
const LEAD_BACK_TURN := 0.6       # ...or this, when the host's path turns away from it (NetPuppet._lead)
const LEAD_MAX := 0.5             # seconds of walking at most ahead of the snapshots (a very late answer: they wait)
const LEAD_GIVE_UP := 1500        # msec: no word of the order by then, the lead is taken back
var lead_on := true               # (tools/test_online.gd nolead: off, to measure without it)
var snap_by_clock := false
var snap_fixed := 0.0              # (tests: rate10 = every 0.1 s, as before the adaptive rate; 0: adaptive)
var leads := {}                   # unit id -> {"to": spot, "seq": the order's number, "off": how far ahead it is shown, "t": msec}
# ---- host: the same delay for both players (the lobby's choice, on by default): the host's own orders wait as long
# as a guest's take to reach it, half the measured round trip (smoothed), HOLD_MAX at most
const HOLD_MAX := 250.0
var same_delay := false
var ping_avg := -1.0              # the round trip, steady (host: the slowest guest's): the middle of the last 7 since GO
var _recent: Array = []
var held: Array = []              # host: its own orders waiting: {"at": msec, "who", "fn", "args"}
var _hold_logged := -1000
# ---- guest: the pictures that came this frame (only the newest is applied: _apply_pending)
var pending: Array = []
var _cmd_tick := -1               # host: the physics frame a guest's order was run on (-1: none waiting for a picture)
var applied_by := {}              # host: relay id -> [orders run, orders refused] (the guest hears it once a second)
var _acc := [0, 0]                # guest: [run, refused] as the host last said
var _acc_was := [0, 0]            # guest: the same at the last minute line
var _seq_was := 0                 # guest: commands sent at the last minute line
var mstat := {}                   # this minute's numbers for the match log (minute_line)


## Create the session on a Game (after it is in the tree).
static func attach(g: Game, lnk: NetLink, host: bool, team: int, peers: Dictionary, same := false) -> NetSession:
	var s := NetSession.new()
	s.game = g
	s.link = lnk
	s.is_host = host
	s.my_team = team
	s.peer_team = peers
	s.same_delay = same
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	g.net = s
	g.add_child(s)
	lnk.message.connect(s._on_message)
	lnk.notice.connect(s._on_notice)
	lnk.closed.connect(s._on_closed)
	lnk.polled.connect(s._apply_pending)
	if host:
		s.pauses_left[team] = PAUSES
		for pr in peers:
			s.pauses_left[int(peers[pr])] = PAUSES
			s._heard[int(pr)] = Time.get_ticks_msec()
	else:
		lnk.send({"t": "ready"})            # my match has loaded: the host can start the countdown
		for t in g.n_players():
			s.pauses_left[t] = PAUSES        # (the host counts; until its first word, everyone has them all)
	s._m_reset()
	s._watch_visibility()
	s._log("%s; same delay for both players %s" % ["host" if host else "guest", "on (the host's orders wait as long as the guest's take to arrive)" if same else "off"])
	return s


func _exit_tree() -> void:
	if _vis_cb != null and OS.has_feature("web"):
		var doc = JavaScriptBridge.get_interface("document")
		if doc:
			doc.removeEventListener("visibilitychange", _vis_cb)
	_vis_cb = null


## Release the held countdown on this machine (the 3-2-1 then runs as usual).
func _go() -> void:
	go_given = true
	if game and is_instance_valid(game) and game.hud:
		game.hud.count_hold = false


## The host gives GO once every guest has loaded (or after READY_WAIT); a guest stops waiting by itself a
## little later if the GO never comes.
func _start_wait(delta: float) -> void:
	_wait_t += delta
	if is_host:
		var all_in := true
		for pr in peer_team:
			if not ready_peers.has(int(pr)) and not lost_peers.has(int(pr)):
				all_in = false
		if all_in or _wait_t >= READY_WAIT:
			link.send({"t": "go"})
			_go()
	elif _wait_t >= READY_WAIT + 5.0:
		_go()


## A replay recorder leaves some out (ReplayRecorder.rec_skip: an online guest's record, enemies out of its sight).
func rec_skip(_e: Entity) -> bool:
	return false


## A new id: one counter per game (Game.net_next), so the online session and the replay recorder never hand out the same.
func assign(e: Entity) -> void:
	if e.net_id == 0:
		next_id = maxi(next_id, game.net_next)
		e.net_id = next_id
		next_id += 1
		game.net_next = next_id


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _frame_ms > 0 and now - _frame_ms > 1500 and not hidden:
		_stood_still(now - _frame_ms)
	_frame_ms = now
	if not go_given:
		_start_wait(delta)
	_tick_ping(delta, now)
	if paused():
		pause_t += minf(delta, 0.5)          # (a long frame is a hidden window, not pause time)
		if is_host and pause_by >= 0 and pause_t >= PAUSE_MAX:
			_host_pause(-1, false, -1)       # the pause ran out
	if not is_host:
		_tick_waiting(now)
		_tick_camera(delta)
		return
	_tick_quiet(now)
	if rp_pos < rp_out.size():
		_send_replay_part()
	if not held.is_empty():
		_run_held(now)
	_t += delta
	# A picture goes out every few game ticks (the game moves 30 times a second): each then carries the same amount of
	# game time, so the guest's units glide at an even speed (by the clock, at 20 a second on a 60 Hz screen, they
	# alternated one and two ticks of movement: a stutter). Paused (no ticks): by the clock.
	var pf := Engine.get_physics_frames()
	var due: bool
	if paused():
		due = _t >= SNAP_PAUSED
	else:
		var ticks := maxi(1, roundi(snap_every * float(Engine.physics_ticks_per_second)))
		due = pf - _snap_pf >= ticks
		if snap_by_clock:
			due = _t >= snap_every     # (tests: the 0.14.32 way, by the clock, to compare)
		if _cmd_tick >= 0 and pf > _cmd_tick:
			due = true               # (a guest's order has had its first game tick: show it now)
	if not due:
		return
	if game.over:
		over_sent += 1
		if over_sent > 20:
			return                  # (the end has been told; stop)
	if link.buffered() > UPLINK_MAX:
		mstat["held"] += 1          # the last pictures are still on their way out (a slow uplink): this one waits
		return
	_t = 0.0
	_snap_pf = pf
	_cmd_tick = -1
	snap_n += 1
	var t0 := Time.get_ticks_usec()
	var snap := NetSnapshot.build(self)
	var bytes := link.send(snap, 0)
	var us := Time.get_ticks_usec() - t0
	mstat["snaps"] += 1
	mstat["bytes"] += bytes
	mstat["big"] = maxi(mstat["big"], bytes)
	mstat["work_us"] += us
	mstat["work_max"] = maxi(mstat["work_max"], us)
	Prof.add("net/snapshot", t0)
	# the next ones: as often as their cost allows (SNAP_BUDGET of the time), 10 to 20 a second
	_build_ms = lerpf(_build_ms, us / 1000.0, 0.1)
	_bytes_avg = lerpf(_bytes_avg, float(bytes), 0.1)
	# ...and as their size allows: SNAP_BYTES a second at most (a big battle on a phone's mobile uplink: fewer, smaller
	# bursts that don't queue up behind each other)
	snap_every = clampf(maxf(_build_ms / 1000.0 / SNAP_BUDGET, _bytes_avg / SNAP_BYTES), SNAP_FAST, SNAP_EVERY)
	if snap_fixed > 0.0:
		snap_every = snap_fixed


## Host: the sides the guests (still here) play: a snapshot leaves out the enemy units none of them can see.
func guest_sides() -> Array:
	var n := peer_team.size() * 8 + lost_peers.size()
	if n != _eyes_n:
		_eyes_n = n
		_eyes = []
		for pr in _live_peers():
			var sd := int(game.sides[int(peer_team[pr])])
			if not _eyes.has(sd):
				_eyes.append(sd)
	return _eyes


## All the players of this machine's side are out (a friend still playing keeps the match going).
func humans_out() -> bool:
	if not game.eliminated[game.human]:
		return false
	for pr in peer_team:
		if not game.eliminated[int(peer_team[pr])] and not lost_peers.has(pr):
			return false
	return true


func _live_peers() -> Array:
	return peer_team.keys().filter(func(pr) -> bool: return not lost_peers.has(int(pr)))


## "P2 Crown" for the log (the host's own side is "YOU").
func _who(team: int) -> String:
	return game.mlog.who(team) if game.mlog else "P%d" % (team + 1)


## A timeline line in the match log: "[02:15] (online) ...".
func _log(text: String) -> void:
	if game.mlog:
		game.mlog.add("(online) " + text)


# ------------------------------------------------------------------ host: sights and shots for the guests

const FX_SENT := ["hit", "smoke", "smoke_big", "dust", "explosion", "burst", "flame", "blast", "blaze", "acid_splash",
	"zap_strike", "zap_spark_y", "zap_burst", "zap_burst_y", "arc_impact", "bloat_cloud"]
const FX_MAX := 60


func note_effect(name: String, p: Vector2, speed: float, looping: bool) -> void:
	if looping or fx.size() >= FX_MAX or not FX_SENT.has(name):
		return
	fx.append(["e", name, p, speed])


func note_shot(s: Shot, kind: String, a: Vector2, b: Vector2, spd: float) -> void:
	if fx.size() < FX_MAX:
		fx.append(["s", kind, a, b, spd, s.face_offset, s.scale.x, s.impact, s.impact_scale, s.arc])


## A Ticking Owl let its weight go (CwAir.drop_bomb): the guest sees it fall and burst (the host's bomb does the damage).
func note_bomb(b: OwlBomb) -> void:
	if fx.size() < FX_MAX:
		fx.append(["b", "", b.from, b.to, b.ground_from, b.duration])


## A Netter's net left the muzzle (Netter.fire): the guest sees it fly at its copy of the target (the host's net catches).
func note_net(cn: ChainNet) -> void:
	if fx.size() < FX_MAX and cn.target != null and is_instance_valid(cn.target):
		assign(cn.target)
		fx.append(["n", "", cn.from, cn.target.net_id, cn.speed])


## Guest: play what the host saw happen since the last snapshot.
func play_fx(list: Array) -> void:
	if game.rec != null:
		game.rec.note_fx(list)         # (the guest's own record of the match: the effects as they came)
	for f in list:
		var p: Vector2 = f[2]
		if f[0] == "c":
			game.torn_at(p)          # a body the host's shell tore up (Game.tear_body): gone here too, seen or not
			continue
		if f[0] == "h":
			game.body_health_at(p, float(f[3]))     # a body the host's men hit (Game.hit_body): its health here too
			continue
		if not game.view_rect.has_point(p):
			continue
		if f[0] == "e":
			game.spawn_effect(String(f[1]), p, float(f[3]))
		elif f[0] == "b":
			var ob := OwlBomb.new()       # (the falling weight, as a picture: it bursts where it lands)
			ob.game = game
			ob.view = true
			ob.from = p
			ob.to = f[3]
			ob.ground_from = f[4]
			ob.duration = float(f[5])
			game.add_child(ob)
		elif f[0] == "n":
			var tg = by_id.get(int(f[3]))
			if not is_instance_valid(tg) or not (tg is Unit):
				continue
			var cn := ChainNet.new()      # (the net in flight, as a picture: the host's catches)
			cn.game = game
			cn.view = true
			cn.from = p
			cn.target = tg
			cn.speed = float(f[4])
			game.add_child(cn)
		else:
			var s := Shot.new()
			s.face_offset = float(f[5])
			s.scale = Vector2(float(f[6]), float(f[6]))
			s.impact = String(f[7])
			s.impact_scale = float(f[8])
			s.arc = float(f[9])
			s.launch(game, String(f[1]), p, f[3], float(f[4]))


# ------------------------------------------------------------------ host: its own orders, held (same delay)

## How long the host's own orders wait now (msec): half the round trip to the guests, smoothed (0: off, or not
## measured yet).
func hold_ms() -> int:
	if not is_host or not same_delay or ping_avg < 0.0:
		return 0
	return int(clampf(ping_avg * 0.5, 0.0, HOLD_MAX))


func hold(who: Object, fn: String, args: Array) -> void:
	var at := Time.get_ticks_msec() + hold_ms()
	if not held.is_empty():
		at = maxi(at, int(held[held.size() - 1]["at"]))       # (in the order given)
	held.append({"at": at, "who": who, "fn": fn, "args": args})


func _run_held(now: int) -> void:
	while not held.is_empty() and int(held[0]["at"]) <= now:
		var h: Dictionary = held.pop_front()
		var who = h["who"]
		if game.over or who == null or not is_instance_valid(who) or (who is Entity and who.dead):
			continue
		game.net_quiet = true        # (its ring and voice came at the click)
		(who as Object).callv(String(h["fn"]), _alive(h["args"]))
		game.net_quiet = false


## The arguments with anything freed meanwhile taken out of their lists (a unit that died while the order waited).
static func _alive(args: Array) -> Array:
	var out: Array = []
	for a in args:
		if a is Array:
			out.append(a.filter(func(x) -> bool: return not (x is Object) or is_instance_valid(x)))
		elif a is Object and not is_instance_valid(a):
			out.append(null)
		else:
			out.append(a)
	return out


# ------------------------------------------------------------------ guest: orders out

func send_cmd(c: Dictionary) -> void:
	cmd_seq += 1
	c["t"] = "cmd"
	c["s"] = cmd_seq
	sent_at[cmd_seq] = Time.get_ticks_msec()
	link.send(c)
	if trace:
		print("[net] guest sent #%d %s" % [cmd_seq, c.get("f")])


## Host: a line for the player of `team` (a guest's order refused, a guest's unit that can't do what it was told).
func tell(team: int, text: String, quiet := false) -> void:
	var key := "%d:%s" % [team, text]
	var now := Time.get_ticks_msec()
	if now - int(_told.get(key, -99999)) < 3000:
		return              # (the same words again within 3 s: the guest's screen would not show them anyway)
	_told[key] = now
	if _told.size() > 64:
		_told.clear()
	for pr in _live_peers():
		if int(peer_team[pr]) == team:
			link.send({"t": "msg", "m": text, "q": quiet}, int(pr))


# ------------------------------------------------------------------ guest: units answer at once

# ------------------------------------------------------------------ guest: the units' positions, from a buffer

## Each unit's last few places with the host's clock (hist), and the screen shows them at a host clock a little behind
## the newest picture (rclk, buffer_s behind): its place there is worked out between the two pictures around it, so it
## walks at an even speed however unevenly the pictures arrive (the internet's jitter), as long as the next one comes
## within the buffer. The buffer is sized to the measured jitter (buffer_s). The clock is steered gently (up to 15%
## faster or slower) to stay that far behind on average; a big gap (a stall, a hidden window) jumps it.
const BUF_MIN := 0.05
const BUF_MAX := 0.3
const HIST_N := 8
var interp_on := true              # (tests: noterp = the older glide toward the newest picture)
var hist := {}                     # guest: id -> [[host clock, where], ...] oldest first
var rclk := -1.0                   # guest: the host clock the screen shows
var snap_clk := 0.0                # guest: the newest picture's host clock
var prev_clk := 0.0                # guest: the one before it
var _rc_err := 0.0


## Seconds the screen stays behind the newest picture: the time between pictures and twice their measured unevenness.
func buffer_s() -> float:
	return clampf(interval + 2.0 * jitter + 0.01, BUF_MIN, BUF_MAX)


## Guest, each game tick (NetPuppet.tick_game): the shown clock moves on.
func tick_rclk(delta: float) -> void:
	if snap_clk <= 0.0:
		return
	var target := snap_clk - buffer_s()
	if rclk < 0.0 or absf(target - rclk) > 0.5:
		rclk = target
		_rc_err = 0.0
	else:
		# (steered by the error smoothed over a couple of seconds: the target itself saws up by a picture's worth at
		# every arrival, and following that tooth made the walk pulse faster and slower)
		_rc_err = lerpf(_rc_err, target - rclk, 0.03)
		rclk += delta * (1.0 + clampf(_rc_err * 1.5, -0.15, 0.15))
	rclk = minf(rclk, snap_clk)


## Guest (NetSnapshot): a picture puts unit `id` at p. `jump`: start its buffer over (new, or a jump across the map).
func push_pos(id: int, p: Vector2, jump: bool) -> void:
	var h: Array = hist.get(id, [])
	if jump or h.is_empty():
		hist[id] = [[snap_clk, p]]
		return
	var last: Array = h[h.size() - 1]
	if float(last[0]) < prev_clk - 0.001:
		h.append([prev_clk, last[1]])      # (it stood still until the last picture: no row meanwhile)
	if float(last[0]) >= snap_clk:
		h[h.size() - 1] = [snap_clk, p]
	else:
		h.append([snap_clk, p])
	while h.size() > HIST_N:
		h.pop_front()
	hist[id] = h


## Guest: where unit `id` is shown now, and its speed there ([place, velocity]); [] if no buffer.
func shown_at(id: int) -> Array:
	var h = hist.get(id)
	if h == null or (h as Array).is_empty():
		return []
	var arr: Array = h
	var rc := rclk
	if rc <= float(arr[0][0]) or arr.size() == 1:
		return [arr[0][1], Vector2.ZERO]
	for i in range(1, arr.size()):
		var b: Array = arr[i]
		if rc <= float(b[0]):
			var a: Array = arr[i - 1]
			var span := maxf(float(b[0]) - float(a[0]), 0.001)
			var f := clampf((rc - float(a[0])) / span, 0.0, 1.0)
			return [(a[1] as Vector2).lerp(b[1], f), ((b[1] as Vector2) - (a[1] as Vector2)) / span]
	return [arr[arr.size() - 1][1], Vector2.ZERO]      # (past the newest: it waits there)


## How long a unit glides to where the newest snapshot has it: the time between snapshots plus room for one coming
## late (twice the measured jitter), so a late one finds it still walking; at most twice the interval.
func glide_span() -> float:
	return clampf(interval + 2.0 * jitter, interval, interval * 2.0)


## Guest: these units were just told to walk to p (the order goes out right after): they start out here at once,
## turned that way and walking, a little ahead of the pictures (NetPuppet.tick_unit); once a picture with the order
## comes, the lead is taken back gently while the host's own walk carries on. Units that can't simply walk off
## (aboard, set up, braced, caught, changing) are left alone; for an attack-move, only those with no enemy near.
func lead(us: Array, p: Vector2, attack_move: bool) -> void:
	if is_host or not lead_on:
		return
	var spots := game.group_points(us, p)
	var now := Time.get_ticks_msec()
	for u in us:
		if not (u is Unit) or not is_instance_valid(u) or u.dead or u.net_id == 0 or u.off_field or u.aboard != null \
				or u.speed <= 0.0 or u.tesla_mode != "packed" or u.braced or u.net_t > 0.0 or u.owl_t >= 0.0 \
				or u.work == "mounting" or u.work == "dismounting":
			continue
		if attack_move and _foe_near(u, 300.0):
			continue
		if trace:
			print("[net] lead #%d %s" % [u.net_id, u.kind])
		var was: Dictionary = leads.get(u.net_id, {})
		var off: Vector2 = was.get("off", Vector2.ZERO)
		leads[u.net_id] = {"to": spots.get(u, p), "seq": cmd_seq + 1, "off": off, "t": now, "from": u.position - off}


func _foe_near(u: Unit, r: float) -> bool:
	for o in game.units:
		if not o.dead and o.visible and game.hostile(o.team, u.team) and o.position.distance_squared_to(u.position) < r * r:
			return true
	return false


## How far ahead of the pictures this unit is shown (Vector2.ZERO: not leading).
func lead_off(id: int) -> Vector2:
	return leads[id]["off"] if leads.has(id) else Vector2.ZERO


## Still waiting for the host to show its order (its facing is ours meanwhile): until a picture after the order shows
## the unit itself on its way (the order is run a tick or two before the unit takes its first step: taking the lead
## back at the ack alone pulled the unit back for a moment on a fast connection), or LEAD_GIVE_UP.
func leading(id: int) -> bool:
	if not leads.has(id):
		return false
	var ld: Dictionary = leads[id]
	var going: bool = ld.get("go", false) and (not interp_on or rclk >= float(ld.get("go_clk", 0.0)))   # (shown from the buffer: once the shown clock gets there too)
	return (last_ack < int(ld["seq"]) or not going) and Time.get_ticks_msec() - int(ld["t"]) < LEAD_GIVE_UP


## Guest (NetSnapshot): a picture put this unit from `was` to `now`: once its order has been run, a step toward its spot
## means the host's own walk has begun (leading ends; the lead is taken back from here).
func lead_seen(id: int, was: Vector2, now: Vector2) -> void:
	var ld = leads.get(id)
	if ld == null or ld.get("go", false) or last_ack < int(ld["seq"]):
		return
	var to: Vector2 = ld["to"]
	var from: Vector2 = ld.get("from", was)       # (where the pictures had it at the order: a standing unit's jostle is not a walk)
	if (now - from).dot((to - from).normalized()) > 3.0 or now.distance_to(to) < 6.0:
		ld["go"] = true
		ld["go_clk"] = prev_clk         # (the picture before this one still had it standing)


# ------------------------------------------------------------------ the replay, after the match (docs/replays.md)
## The host recorded every side; when the match is over it sends the finished file to each guest in parts (a relay
## message is at most about 1 MB: RP_PART each), one part whenever the last has left the device. Never before the end:
## the replay shows what the fog hid. A guest keeps its own record (its view only) until the whole one has come.

const RP_PART := 192 * 1024
const RP_BUFFER := 256 * 1024
var rp_out := PackedByteArray()   # host: the replay being sent
var rp_pos := 0                   # host: bytes of it sent so far
var rp_in := PackedByteArray()    # guest: the parts that came
var rp_total := 0                 # guest: its whole size (0: nothing coming yet)
var rp_path := ""                 # guest: where the whole replay was saved, once it came


## Host: send the finished replay at `path` to every guest still here (`now`: all of it at once, the host is leaving).
func send_replay(path: String, now := false) -> void:
	if not is_host or _live_peers().is_empty():
		return
	rp_out = FileAccess.get_file_as_bytes(path)
	rp_pos = 0
	_log("sending the replay to the guests (%d KB)" % (rp_out.size() / 1024))
	if now:
		while rp_pos < rp_out.size():
			var n := mini(RP_PART, rp_out.size() - rp_pos)
			link.send({"t": "rp", "i": rp_pos, "n": rp_out.size(), "d": rp_out.slice(rp_pos, rp_pos + n)}, 0)
			rp_pos += n
		link.flush()


func _send_replay_part() -> void:
	if link.buffered() > RP_BUFFER:
		return
	var n := mini(RP_PART, rp_out.size() - rp_pos)
	link.send({"t": "rp", "i": rp_pos, "n": rp_out.size(), "d": rp_out.slice(rp_pos, rp_pos + n)}, 0)
	rp_pos += n
	if rp_pos >= rp_out.size():
		link.flush()


## 0..1 of the replay sent (host) or received (guest); -1: none under way.
func replay_progress() -> float:
	if is_host:
		return -1.0 if rp_out.is_empty() else float(rp_pos) / float(rp_out.size())
	if rp_path != "":
		return 1.0
	return -1.0 if rp_total <= 0 else float(rp_in.size()) / float(rp_total)


## Guest: a part of the host's replay. The whole one is saved as this player's (its result theirs), and the guest's own
## record (its view only) goes.
func _replay_part(m: Dictionary) -> void:
	var at := int(m.get("i", -1))
	if at == 0:
		rp_in = PackedByteArray()
		rp_total = int(m.get("n", 0))
	if at != rp_in.size() or rp_total <= 0:
		return
	rp_in.append_array(m.get("d", PackedByteArray()))
	if rp_in.size() < rp_total:
		return
	var path := ReplayFile.import_bytes(rp_in, "", my_team, "")
	rp_in = PackedByteArray()
	if path == "":
		_log("the host's replay came damaged: the guest keeps its own view")
		return
	rp_path = path
	if game.rec != null and game.rec.done and game.rec.path != "" and game.rec.path != path:
		ReplayFile.delete(game.rec.path)        # (the whole replay replaces this player's own view of the match)
	_log("the host's replay came (%d KB)" % (rp_total / 1024))
	replay_got.emit(path)


## Guest: where its camera looks, twice a second when it moved (the host's replay keeps it: CAMERA in the viewer).
var _cam_t := 0.0
var _cam_sent := Vector3.INF


func _tick_camera(delta: float) -> void:
	_cam_t -= delta
	if _cam_t > 0.0 or not go_given or game.over or game.camera == null:
		return
	_cam_t = 0.5
	var v := Vector3(snappedf(game.camera.position.x, 1.0), snappedf(game.camera.position.y, 1.0), snappedf(game.camera.zoom.x, 0.01))
	if v != _cam_sent:
		_cam_sent = v
		link.send({"t": "cam", "c": v})


# ------------------------------------------------------------------ chat

## Every chat line goes through here (Chat.post): a guest's own lines go to the host; the host passes every line on
## (its own, the computers', a guest's) to the guests, but not back to the guest who wrote it. `from_peer`: the relay id
## it came from (-1: said on this machine).
func chat_out(team: int, text: String, from_peer: int) -> void:
	if is_host:
		for pr in _live_peers():
			if int(pr) != from_peer:
				link.send({"t": "chat", "tm": team, "x": text}, int(pr))
	elif from_peer < 0 and team == my_team:
		link.send({"t": "chat", "x": text})


# ------------------------------------------------------------------ ping

func _tick_ping(delta: float, now: int) -> void:
	_ping_t -= delta
	if _ping_t > 0.0:
		return
	_ping_t = PING_EVERY
	_ping_k += 1
	_ping_out[_ping_k] = now
	link.send({"t": "ping", "k": _ping_k}, 0)       # (host: to every guest)
	for k in _ping_out.keys():
		if now - int(_ping_out[k]) > 60000:
			_ping_out.erase(k)


func _pong(from: int, k: int) -> void:
	if not _ping_out.has(k) or k <= int(_answered.get(from, 0)):
		return
	_answered[from] = k
	var rtt := float(Time.get_ticks_msec() - int(_ping_out[k]))
	if is_host:
		ping_of[from] = rtt
		ping_ms = 0.0
		for pr in _live_peers():
			ping_ms = maxf(ping_ms, float(ping_of.get(pr, 0.0)))
	else:
		ping_ms = rtt
	# the round trip for the same delay: the middle of the last few (a single slow one doesn't move it), counted only
	# from GO (the first answers come while the match is still loading and can take seconds)
	if go_given:
		_recent.append(ping_ms)
		if _recent.size() > 7:
			_recent.pop_front()
		var srt := _recent.duplicate()
		srt.sort()
		ping_avg = float(srt[srt.size() / 2])
	if is_host and same_delay and absi(hold_ms() - _hold_logged) >= 20:
		_hold_logged = hold_ms()
		_log("same delay for both: the host's orders wait %d ms (half the %d ms round trip)" % [hold_ms(), int(ping_avg)])
	mstat["ping_sum"] += rtt
	mstat["ping_n"] += 1
	mstat["ping_max"] = maxf(mstat["ping_max"], rtt)


## What the counter left of the clock shows (msec): the last round trip, or, while an answer is late, how long it has
## been out (so a stall shows climbing). -1: nothing measured yet.
func ping_shown() -> int:
	var now := Time.get_ticks_msec()
	var p := ping_ms
	var froms: Array = _live_peers() if is_host else [0]
	for fr in froms:
		var k := int(_answered.get(fr, 0)) + 1
		if _ping_out.has(k):
			p = maxf(p, float(now - int(_ping_out[k])) - PING_EVERY * 1000.0 if k < _ping_k else float(now - int(_ping_out[k])))
	if not is_host and waiting and _last_snap_ms > 0:
		p = maxf(p, float(now - _last_snap_ms))
	return int(p)


## 0 green (good), 1 yellow (slow), 2 red (bad, or waiting for the host / paused for a hidden host).
func ping_grade() -> int:
	var p := ping_shown()
	if (not is_host and waiting) or away or p >= 250:
		return 2
	return 1 if p >= 120 else 0


# ------------------------------------------------------------------ stalls and hidden windows

## Guest: no picture for over STALL_AFTER: "Waiting for the host..." (the HUD) until the next one comes.
func _tick_waiting(now: int) -> void:
	if not go_given or game.over or _last_snap_ms == 0 or away:
		return
	if not waiting and now - _last_snap_ms > STALL_AFTER:
		waiting = true


func _end_wait(now: int) -> void:
	if not waiting:
		return
	waiting = false
	var secs := (now - _last_snap_ms) / 1000.0
	mstat["stalls"] += 1
	mstat["stall_max"] = maxf(mstat["stall_max"], secs)
	_log("waited for the host %.1f s" % secs)


## Host: a guest that has said nothing (not even its ping) for QUIET_AFTER: stalled, or its window hidden.
func _tick_quiet(now: int) -> void:
	for pr in _live_peers():
		if not _quiet.has(pr) and now - int(_heard.get(pr, now)) > QUIET_AFTER:
			_quiet[pr] = int(_heard.get(pr, now))


func _heard_from(pr: int, now: int) -> void:
	_heard[pr] = now
	if _quiet.has(pr):
		var secs := (now - int(_quiet[pr])) / 1000.0
		_quiet.erase(pr)
		mstat["stalls"] += 1
		mstat["stall_max"] = maxf(mstat["stall_max"], secs)
		_log("no word from %s for %.1f s" % [_who(int(peer_team.get(pr, -1))), secs])


## This game stood still for a while without knowing why (no visibility notice: a frame that took seconds, the phone
## busy or asleep): the log says so. A guest's wait for the host starts over (the gap was its own).
func _stood_still(ms: int) -> void:
	mstat["stalls"] += 1
	mstat["stall_max"] = maxf(mstat["stall_max"], ms / 1000.0)
	_log("this game stood still %.1f s" % (ms / 1000.0))
	if not is_host:
		_last_snap_ms = Time.get_ticks_msec()


## (web) Hear when the page is hidden (another tab in front, the browser minimised) and shown again.
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	var doc = JavaScriptBridge.get_interface("document")
	if doc == null:
		return
	_vis_cb = JavaScriptBridge.create_callback(_on_visibility)
	doc.addEventListener("visibilitychange", _vis_cb)


func _on_visibility(_args: Array) -> void:
	var doc = JavaScriptBridge.get_interface("document")
	if doc:
		set_hidden(String(doc.visibilityState) == "hidden")


## This machine's window (a browser tab) or app went to the background (on) or came back (Main calls it on Android;
## the page's visibility on the web). Nothing runs here while it is away (the browser stops the game), so the host
## pauses the match for everyone until it is back; a guest just lets the host know (its side stands still meanwhile).
func set_hidden(on: bool) -> void:
	if on == hidden or game == null or not is_instance_valid(game):
		return
	hidden = on
	var now := Time.get_ticks_msec()
	if on:
		_hidden_ms = now
	var secs := (now - _hidden_ms) / 1000.0
	if is_host:
		_host_away(on, secs)
	else:
		link.send({"t": "away", "on": on, "secs": secs})
		if not on:
			_log("this window was hidden %.0f s" % secs)
			_last_snap_ms = now           # (the gap was ours, not the host's)
	link.flush()                          # (out now: the app may stop running right after this)
	_frame_ms = 0


# ------------------------------------------------------------------ pause

func paused() -> bool:
	return pause_by >= 0 or away


## The HUD's PAUSE / RESUME. The host decides (its game is the one that stops) and tells the guests.
func request_pause(on: bool) -> void:
	if is_host:
		_host_pause(my_team, on, -1)
	else:
		link.send({"t": "pause", "on": on})


## Host: `team` asks to pause (on) or resume. -1 with on false: the pause ran out. `peer`: the guest who asked (-1 here).
func _host_pause(team: int, on: bool, peer: int) -> void:
	if game.over:
		return
	if on:
		if paused():
			return
		var left := int(pauses_left.get(team, 0))
		if left <= 0:
			_say_to(peer, "No pauses left.")
			return
		pauses_left[team] = left - 1
		_state(team, away, "pause", team, 0.0)
	else:
		if pause_by < 0:
			return
		_state(-1, away, "resume" if team >= 0 else "timeout", team, pause_t)


## Host: its window or app went to the background (on) or came back after `secs`.
func _host_away(on: bool, secs: float) -> void:
	if game.over:
		return
	_state(pause_by, on, "away" if on else "back", my_team, secs)


## A message for one player (-1: this machine).
func _say_to(peer: int, text: String) -> void:
	if peer < 0:
		game.notify(text)
	else:
		link.send({"t": "msg", "m": text}, peer)


## Host: set the pause state and tell every guest.
func _state(by: int, aw: bool, ev: String, who: int, secs: float) -> void:
	link.send({"t": "pause", "by": by, "away": aw, "ev": ev, "who": who, "secs": secs, "left": pauses_left}, 0)
	_apply_state(by, aw, ev, who, secs)


## Both: the match is paused (by a player, or the host is away) or goes on again (after a 3-2-1).
func _apply_state(by: int, aw: bool, ev: String, who: int, secs: float) -> void:
	var was := paused()
	pause_by = by
	away = aw
	var now_p := paused()
	if now_p and not was:
		pause_t = 0.0
	if not is_host and aw:
		waiting = false
	var name := game.team_name(who).capitalize() if who >= 0 else ""
	match ev:
		"pause":
			_log("paused by %s (%d pauses left)" % [_who(who), int(pauses_left.get(who, 0))])
		"resume":
			_log("%s resumed after %.0f s" % [_who(who), secs])
			if who != game.human:
				game.notify("%s resumed the match." % name, true)
		"timeout":
			_log("the pause ran out after %.0f s" % secs)
			game.notify("The pause ran out: the match goes on.", true)
		"away":
			_log("host window hidden: the match waits")
			if not is_host:
				game.notify("The host's game is in the background: the match waits.", true)
		"back":
			_log("host window hidden %.0f s" % secs)
	if game.hud:
		game.hud.net_paused(now_p)


## The banner while paused: "Paused by Pink" or "The host's game is in the background".
func pause_text() -> String:
	if away:
		return "The host's game is in the background." if not is_host else "Your game was in the background."
	if pause_by >= 0:
		return "Paused by %s" % game.team_name(pause_by).capitalize()
	return ""


func my_pauses() -> int:
	return int(pauses_left.get(game.human, 0))


# ------------------------------------------------------------------ messages in

func _on_message(from: int, m: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if is_host:
		_heard_from(from, now)
	match String(m.get("t", "")):
		"ready":
			if is_host:
				ready_peers[from] = true
		"go":
			if not is_host and not go_given:
				_go()
		"ping":
			link.send({"t": "pong", "k": int(m.get("k", 0))}, from)
		"pong":
			_pong(from, int(m.get("k", 0)))
		"cmd":
			if not is_host:
				return
			var why := NetCommands.apply(self, from, m)
			acks[from] = int(m.get("s", 0))
			var ab: Array = applied_by.get(from, [0, 0])
			if why == "":
				cmds_applied += 1
				ab[0] += 1
				mstat["applied"] += 1
				_cmd_tick = Engine.get_physics_frames()
				if trace:
					print("[net] host ran #%d %s from %d" % [int(m.get("s", 0)), m.get("f"), from])
			else:
				cmds_rejected += 1
				ab[1] += 1
				mstat["refused"] += 1
				last_reject = why
				if trace:
					print("[net] host refused #%d %s: %s" % [int(m.get("s", 0)), m.get("f"), why])
				link.send({"t": "msg", "m": refusal_text(why), "x": true}, from)     # (every refusal says why on the guest's screen)
			applied_by[from] = ab
			mstat["sent"] += 1
		"rp":
			if not is_host:
				_replay_part(m)
		"cam":
			if is_host and game.rec != null and m.get("c") is Vector3:
				game.rec.note_cam(int(peer_team.get(from, -1)), m["c"])
		"snap":
			if not is_host:
				pending.append(m)             # (applied once this frame's messages are all in: _apply_pending)
		"msg":
			last_msg = String(m.get("m", ""))
			if bool(m.get("x", false)):
				refusals += 1                      # (a refused order: always on screen, not held back like other notes)
				_log("the host refused an order: %s" % last_msg)
				if game.hud:
					game.hud.toast(last_msg, true)
			else:
				game.notify(last_msg, bool(m.get("q", false)))
		"chat":
			if game.chat == null:
				return
			if is_host:
				var team: int = peer_team.get(from, -1)
				var text := Chat.clean(String(m.get("x", "")))
				if team < 0 or text == "" or game.over:
					return
				game.chat.post(team, text, from)
				if Chat.is_gg(text):
					for ai in game.ais.duplicate():         # (a computer waiting for a gg takes a guest's as well)
						if is_instance_valid(ai) and ai.gg_pending() and game.hostile(ai.team, team):
							ai.gg_reply()
			else:
				game.chat.post(int(m.get("tm", 0)), String(m.get("x", "")), 0)
		"pause":
			if is_host:
				var team: int = peer_team.get(from, -1)
				if team >= 0:
					_host_pause(team, bool(m.get("on", false)), from)
			else:
				var lf = m.get("left", {})
				if lf is Dictionary:
					pauses_left = lf
				_apply_state(int(m.get("by", -1)), bool(m.get("away", false)), String(m.get("ev", "")), int(m.get("who", -1)), float(m.get("secs", 0.0)))
		"away":
			if is_host:
				var team: int = peer_team.get(from, -1)
				if team < 0:
					return
				if bool(m.get("on", false)):
					game.notify("%s's game went to the background." % game.team_name(team).capitalize(), true)
				else:
					_log("%s's window was hidden %.0f s" % [_who(team), float(m.get("secs", 0.0))])


## Host: the words a guest sees for an order it refused. A game's own reason ("Not enough gold.") as it is; the checks
## of the funnel (NetCommands._apply) in the player's words.
static func refusal_text(why: String) -> String:
	match why:
		"not yours":
			return "That order was refused: it is not yours (any more)."
		"target is gone":
			return "That order was refused: its target is gone."
		"no team", "bad args", "bad property", "no callables":
			return "That order was refused by the host."
	if why.begins_with("unknown"):
		return "That order can't be given online yet."
	if why.length() > 0 and why[0] == why[0].to_upper():
		return why
	return "That order was refused by the host."


## Guest: the pictures that came this frame. Each one is the whole match, so only the newest is applied; what
## happened in between (who is gone, the shots, the Line) is taken from the older ones (several come at once after
## a slow frame, and hundreds when a hidden window comes back: applying each would freeze the game for seconds).
func _apply_pending() -> void:
	if is_host or pending.is_empty():
		return
	var now := Time.get_ticks_msec()
	var m: Dictionary = pending[pending.size() - 1] if pending.size() == 1 else NetSnapshot.merge(pending)
	snaps_got += pending.size()
	mstat["snaps"] += pending.size()
	pending.clear()
	_end_wait(now)
	if _last_snap_ms > 0:
		var gap := float(now - _last_snap_ms) / 1000.0
		jitter = lerpf(jitter, minf(absf(gap - interval), 0.2), 0.1)
		interval = clampf(lerpf(interval, gap, 0.2), 0.03, 0.4)
	_last_snap_ms = now
	snap_n = int(m.get("n", snap_n))
	prev_clk = snap_clk
	snap_clk = float(m.get("clk", snap_clk))
	var ack := int(m.get("ack", {}).get(link.my_id, 0)) if m.get("ack") is Dictionary else 0
	if ack > last_ack:
		if sent_at.has(ack):
			cmd_rtt_ms = float(now - int(sent_at[ack]))
			mstat["seen_sum"] += cmd_rtt_ms
			mstat["seen_n"] += 1
			mstat["seen_max"] = maxf(mstat["seen_max"], cmd_rtt_ms)
		last_ack = ack
		for k in sent_at.keys():
			if int(k) <= ack:
				sent_at.erase(k)
	var acc = m.get("acc", {}).get(link.my_id) if m.get("acc") is Dictionary else null
	if acc is Array and acc.size() == 2:
		_acc = acc
	var pz = m.get("pz")
	if pz is Array and pz.size() == 2 and (int(pz[0]) != pause_by or bool(pz[1]) != away):
		_apply_state(int(pz[0]), bool(pz[1]), "", -1, 0.0)     # (the messages said it first; this is the net)
	var t0 := Time.get_ticks_usec()
	NetSnapshot.apply(self, m)
	var us := Time.get_ticks_usec() - t0
	mstat["work_us"] += us
	mstat["work_max"] = maxi(mstat["work_max"], us)
	Prof.add("net/apply", t0)


func _on_notice(d: Dictionary) -> void:
	if String(d.get("t", "")) == "leave" and is_host:
		var team: int = peer_team.get(int(d.get("id", -1)), -1)
		var who := game.team_name(team).capitalize() if team >= 0 else "A friend"
		game.notify("%s left the game. A computer plays on." % who)
		if game.mlog and team >= 0:
			game.mlog.add("(online) %s's player disconnected: a computer takes over" % game.mlog.who(team))
		if team >= 0 and not game.over and not lost_peers.has(int(d.get("id", -1))):
			lost_peers[int(d.get("id", -1))] = true
			if not game.eliminated[team]:
				var ai := AI.new()                  # (their side is not left standing still)
				ai.game = game
				ai.team = team
				ai.difficulty = 1
				ai.strategy = "balanced"
				game.add_child(ai)
				game.ais.append(ai)
			if pause_by == team:
				_host_pause(team, false, -1)        # (their pause goes with them)


func _on_closed(why: String) -> void:
	if game and is_instance_valid(game) and not game.over:
		game.notify(why)
	lost.emit(why)


# ------------------------------------------------------------------ the match log

func _m_reset() -> void:
	mstat = {"t0": Time.get_ticks_msec(), "ping_sum": 0.0, "ping_n": 0, "ping_max": 0.0, "snaps": 0, "bytes": 0, "big": 0,
		"work_us": 0, "work_max": 0, "sent": 0, "applied": 0, "refused": 0, "seen_sum": 0.0, "seen_n": 0, "seen_max": 0.0,
		"stalls": 0, "stall_max": 0.0, "held": 0}


## The online line of a minute block of the match log (MatchLog.snapshot), then the counts start over:
## "Online (guest): ping avg 85 ms, max 240 ms | snapshots 598 (10.0/s) ... | orders sent 41, applied 41, refused 0 | stalls 0"
func minute_line() -> String:
	var ms := mstat
	var secs := maxf((Time.get_ticks_msec() - int(ms["t0"])) / 1000.0, 0.001)
	var n := maxi(int(ms["snaps"]), 1)
	var ping := "ping avg %d ms, max %d ms" % [int(ms["ping_sum"] / maxi(int(ms["ping_n"]), 1)), int(ms["ping_max"])] if int(ms["ping_n"]) > 0 else "ping -"
	var line := ""
	if is_host:
		line = "Online (host): %s | snapshots %d (%.1f/s), %.1f KB avg, %.1f KB max, %.1f KB/s, built in %.1f ms avg (%.1f max)" % [
			ping, int(ms["snaps"]), int(ms["snaps"]) / secs, int(ms["bytes"]) / 1024.0 / n, int(ms["big"]) / 1024.0,
			int(ms["bytes"]) / 1024.0 / secs, int(ms["work_us"]) / 1000.0 / n, int(ms["work_max"]) / 1000.0]
		if int(ms["held"]) > 0:
			line += ", %d held for a slow uplink" % int(ms["held"])
		line += " | orders from guests %d, applied %d, refused %d" % [int(ms["sent"]), int(ms["applied"]), int(ms["refused"])]
		if same_delay:
			line += " | own orders held %d ms" % hold_ms()
	else:
		var run := int(_acc[0]) - int(_acc_was[0])
		var refused := int(_acc[1]) - int(_acc_was[1])
		_acc_was = _acc.duplicate()
		var sent := cmd_seq - _seq_was
		_seq_was = cmd_seq
		line = "Online (guest): %s | snapshots %d (%.1f/s), applied in %.1f ms avg (%.1f max) | orders sent %d, applied %d, refused %d" % [
			ping, int(ms["snaps"]), int(ms["snaps"]) / secs, int(ms["work_us"]) / 1000.0 / n, int(ms["work_max"]) / 1000.0, sent, run, refused]
		if int(ms["seen_n"]) > 0:
			line += ", seen after %d ms avg (%d max)" % [int(ms["seen_sum"] / int(ms["seen_n"])), int(ms["seen_max"])]
	if link.relay_n > 0:
		# (this device's own leg: the relay answers its pings itself; the ping to the other player is both legs)
		line += " | to the relay %d ms avg, %d max" % [int(link.relay_sum / link.relay_n), int(link.relay_max)]
		link.relay_sum = 0.0
		link.relay_n = 0
		link.relay_max = 0.0
	line += " | stalls %d" % int(ms["stalls"])
	if int(ms["stalls"]) > 0:
		line += " (longest %.1f s)" % float(ms["stall_max"])
	_m_reset()
	return line
