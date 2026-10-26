extends SceneTree
## Online play, end to end on one computer: a HOST and a GUEST process through a relay.
##   node tools/relay/local_relay.mjs 8799 &
##   godot --headless --script res://tools/test_online.gd -- role:host  relay:ws://127.0.0.1:8799 code:TEST
##   godot --headless --script res://tools/test_online.gd -- role:guest relay:ws://127.0.0.1:8799 code:TEST
## (tools/test_online.sh runs all three and checks the CHECK lines.) The guest joins by code, the host
## starts, and then the guest plays: it moves a worker, trains a unit, places a building and tries to
## order one of the host's units (refused). Snapshots must show every effect on the guest.
## Extra args: coop (two humans vs a computer), fac_host:<faction>, fac_guest:<faction>, map:<id>, secs:<n>.
## The window going away (docs/online_lag_study.md): freeze_host:<s> / freeze_guest:<s> stop that game for s seconds
## (as a browser stops a hidden tab, without telling anyone), hide_host:<s> the same with the hidden-page notice,
## freeze_at:<s> when (seconds after the first snapshots, default 20).
var main: Node
var role := "host"
var relay := "ws://127.0.0.1:8799"
var code := "TEST"
var coop := false
var fac_host := "crown"
var fac_guest := "crown"
var map := "hollowfen"
var limit := 150.0
var t := 0.0
var lobby: NetLobby
var g: Game
var step := 0
var step_t := 0.0
var base := {}
var results := {}
var done_t := -1.0
var _last_print := -1
var autoplay := false
var speed := 1.0
var watch := 50.0
var stay := 0.0
var shot_path := ""
var left_t := -1.0
var cstep := 0                 # guest: the colour picks in the room (0 wait, 1 duplicate sent, 2 own colour sent, 3 done)
var cstep_t := 0.0
const HOST_COL := 0
const GUEST_COL := 4
# ---- lag: measured once the match runs (the LAG lines at the end): real frame times, the time each frame spent on
# snapshots (Prof "net/snapshot" on the host, "net/apply" on the guest), their sizes, the gaps between them, and how
# long a guest's order takes to show
var lag_frames := PackedFloat32Array()
var lag_work := PackedFloat32Array()      # ms spent on snapshots in each frame that had any
var lag_gaps := PackedFloat32Array()      # guest: ms between frames that applied a snapshot
var lag_sizes := PackedFloat32Array()     # host: bytes sent in each frame that sent a snapshot
var lag_seen := PackedFloat32Array()      # guest: ms from an order to the host's ack in a snapshot
var lag_moved := PackedFloat32Array()     # guest: ms from a move order to the unit 3 px on its way on this screen
var lag_walk := PackedFloat32Array()      # guest: ms from a move order to the unit walking that way (its walk shown)
var lag_hostmove := PackedFloat32Array()  # guest: ms from a move order to a snapshot showing the host's unit on its way
var lag_jumps := 0                        # guest: frames where a probed unit jumped (moved much further than it walks)
var lag_jump_max := 0.0                   # guest: the biggest such jump (px beyond its walk)
var lag_own := PackedFloat32Array()       # host: ms from its own move order (given as at the screen) to the unit walking
var lag_hold := PackedFloat32Array()      # host: how long its own orders were held then (the same delay for both)
var _hprobe := {}                         # host: its own move order being timed
var _hprobe_t := 0.0
var _lag_us := 0
var _lag_prof := 0
var _lag_bytes := 0
var _lag_snap_us := 0
var _lag_ack := 0
var _probe := {}                          # guest: the move order being timed {u, from, to, t0}
var _probe_t := 0.0
var freeze_host := 0.0
var freeze_guest := 0.0
var hide_host := 0.0
var freeze_at := 20.0
var _frozen_at := -1.0                    # t when the freeze ended (-1: not yet)
var _after_freeze := PackedFloat32Array() # frame times in the 2 s after it
var _saw_wait := false
var _saw_away := false


func _initialize() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("role:"):
			role = a.substr(5)
		elif a.begins_with("relay:"):
			relay = a.substr(6)
		elif a.begins_with("code:"):
			code = a.substr(5)
		elif a.begins_with("fac_host:"):
			fac_host = a.substr(9)
		elif a.begins_with("fac_guest:"):
			fac_guest = a.substr(10)
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("secs:"):
			limit = float(a.substr(5))
		elif a == "coop":
			coop = true
		elif a == "ai":
			autoplay = true           # the host runs a computer for each human side too: a real fight to watch
		elif a.begins_with("shot:"):
			shot_path = a.substr(5)
		elif a.begins_with("stay:"):
			stay = float(a.substr(5))
		elif a.begins_with("watch:"):
			watch = float(a.substr(6))
		elif a.begins_with("speed:"):
			speed = float(a.substr(6))
		elif a.begins_with("freeze_host:"):
			freeze_host = float(a.substr(12))
		elif a.begins_with("freeze_guest:"):
			freeze_guest = float(a.substr(13))
		elif a.begins_with("hide_host:"):
			hide_host = float(a.substr(10))
		elif a.begins_with("freeze_at:"):
			freeze_at = float(a.substr(10))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(name: String, ok: bool, extra := "") -> void:
	results[name] = ok
	print("CHECK %s %s %s %s" % [role.to_upper(), name, "OK" if ok else "FAIL", extra])


func _terrain_hash() -> int:
	return hash([g.height, g.water, g.cliff, g.ramp, g.W, g.H])


func _mine(kind_filter := "") -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == g.human and not u.dead)


func _process(delta: float) -> bool:
	var real := delta / maxf(Engine.time_scale, 0.01)
	t += real
	step_t += real
	_lag_sample(real)
	if t < 0.5 or main.game == null and lobby == null:
		if t >= 0.5 and lobby == null:
			_begin()
		return false
	if t > limit:
		print("TIMEOUT in step %d" % step)
		_finish()
		return false
	if role == "host":
		_host_tick()
	else:
		_guest_tick()
	return false


func _begin() -> void:
	lobby = NetLobby.new()
	main.add_child(lobby)
	main.net_lobby = lobby
	lobby.failed.connect(func(why: String) -> void: print("LOBBY FAILED: ", why))
	if role == "host":
		lobby.host(relay, code)
		if coop:
			lobby.set_mode("coop")
		lobby.map = map
		lobby.slots[0]["faction"] = fac_host
		check("host_colour_pick_accepted", lobby.set_colour(0, HOST_COL))
		check("host_duplicate_colour_refused", not lobby.set_colour(1, HOST_COL) and int(lobby.slots[1]["colour"]) != HOST_COL)
		if coop:
			lobby.set_strategy(2, "rush")
		lobby.slots[1]["faction"] = fac_guest
		if coop:
			lobby.slots[2]["faction"] = "brood"
	else:
		lobby.start_now.connect(func(cfg: Dictionary) -> void:
			print("GUEST got start: map=%s slots=%d" % [cfg["map"], cfg["slots"].size()])
			main.start(cfg))
		lobby.join(relay, code)


# ------------------------------------------------------------------ lag

func _lag_sample(real: float) -> void:
	var now := Time.get_ticks_usec()
	var running: bool = g != null and g.net != null and g.net.go_given and not g.over and step >= 1
	if not running:
		_lag_us = now
		return
	if _lag_us > 0:
		lag_frames.append((now - _lag_us) / 1000.0)
		if _frozen_at >= 0.0 and t - _frozen_at < 2.0 and t - _frozen_at > 0.0:
			_after_freeze.append((now - _lag_us) / 1000.0)
	_lag_us = now
	_freeze_tick()
	var key := "net/snapshot" if role == "host" else "net/apply"
	var v := int(Prof.us.get(key, 0))
	var d := v - _lag_prof if v >= _lag_prof else v       # (the match log empties Prof each minute)
	_lag_prof = v
	if d > 0:
		lag_work.append(d / 1000.0)
		if role == "guest":
			if _lag_snap_us > 0:
				lag_gaps.append((now - _lag_snap_us) / 1000.0)
			_lag_snap_us = now
	if role == "host":
		var b := int(g.net.link.sent_bytes)
		if d > 0 and _lag_bytes > 0:
			lag_sizes.append(float(b - _lag_bytes))
		_lag_bytes = b
		_host_probe_tick(real)
	else:
		var s: NetSession = g.net
		if s.last_ack > _lag_ack:
			_lag_ack = s.last_ack
			lag_seen.append(s.cmd_rtt_ms)
		_probe_tick(real)


## The window going away for a while (freeze_* / hide_host), once, freeze_at seconds into the match.
func _freeze_tick() -> void:
	var s = g.net
	if s.get("waiting") == true:
		_saw_wait = true
	if s.get("away") == true:
		_saw_away = true
	var secs := freeze_host + hide_host if role == "host" else freeze_guest
	if secs <= 0.0 or _frozen_at >= 0.0 or step_t < freeze_at or step < 1:
		return
	print("%s: the window goes away for %.0f s%s" % [role.to_upper(), secs, " (with the hidden-page notice)" if hide_host > 0.0 and role == "host" else ""])
	if role == "host" and hide_host > 0.0:
		s.set_hidden(true)
	OS.delay_msec(int(secs * 1000.0))
	if role == "host" and hide_host > 0.0:
		s.set_hidden(false)
	_frozen_at = t + 0.001


## Guest: every 2 s or so an idle soldier of ours is told to walk 200 px (group_move, as a click would), and timed until
## it shows walking here (its walk animation: "walk"), until it is 3 px on its way on this screen ("moved"), until a
## snapshot carries the host's ack ("ack") and until a snapshot shows the host's own unit on its way ("host"). Every
## frame of the 2.5 s it is watched, a step much longer than its walk would take is counted as a jump (a snap).
func _probe_tick(real: float) -> void:
	_probe_t += real
	var s = g.net
	if not _probe.is_empty():
		var u: Unit = _probe["u"]
		var ms := (Time.get_ticks_usec() - int(_probe["t0"])) / 1000.0
		if not is_instance_valid(u) or u.dead:
			_probe = {}
			return
		var dir: Vector2 = _probe["dir"]
		var from: Vector2 = _probe["from"]
		if not _probe.has("walk") and u.velocity.dot(dir) > 10.0:
			_probe["walk"] = ms
		if not _probe.has("moved") and (u.position - from).dot(dir) > 3.0:
			_probe["moved"] = ms
		if not _probe.has("ack") and int(s.last_ack) >= int(_probe["seq"]):
			_probe["ack"] = ms
		var mo = s.motion.get(u.net_id)
		if not _probe.has("host") and mo != null and ((mo[1] as Vector2) - from).dot(dir) > 3.0:
			_probe["host"] = ms
		var step_px := (u.position - (_probe["last"] as Vector2)).length()
		var allowed := u.speed * maxf(real, 1.0 / 30.0) * 2.0 + 2.0
		if step_px > allowed:
			lag_jumps += 1
			lag_jump_max = maxf(lag_jump_max, step_px - allowed)
		_probe["last"] = u.position
		if ms > 2500.0:
			if _probe.has("walk"):
				lag_walk.append(float(_probe["walk"]))
			if _probe.has("moved"):
				lag_moved.append(float(_probe["moved"]))
			if _probe.has("host"):
				lag_hostmove.append(float(_probe["host"]))
			if OS.get_environment("PROBE_DEBUG") != "":
				print("PROBE %s walk %s moved %s ack %s host %s" % [u.kind, _probe.get("walk", "-"), _probe.get("moved", "-"), _probe.get("ack", "-"), _probe.get("host", "-")])
			_probe = {}
		return
	if _probe_t < 2.0 or step < 2:
		return
	_probe_t = 0.0
	for u in _mine():
		if u.velocity.length() < 1.0 and not u.off_field and u.kind != "horse" and not u.is_worker() and u.kind != "cannon" \
				and not ["build", "move", "amove", "patrol"].has(u.order):
			var to: Vector2 = u.position + Vector2(200, 0).rotated(randf() * TAU)
			if not g.in_map(g.cell_of(to)) or not g.is_free(g.cell_of(to)) or not g.line_clear(u.position, to):
				continue
			_probe = {"u": u, "from": u.position, "to": to, "dir": (to - u.position).normalized(), "last": u.position, "t0": Time.get_ticks_usec()}
			g.group_move([u], to, false)
			_probe["seq"] = int(s.cmd_seq)
			return


## Host: every 3 s one of its own idle soldiers is told to walk 200 px, given as at the screen (Game.input_cmd: with the
## same delay for both players it is held like a guest's order), and timed until it walks.
func _host_probe_tick(real: float) -> void:
	_hprobe_t += real
	if not _hprobe.is_empty():
		var u: Unit = _hprobe["u"]
		var ms := (Time.get_ticks_usec() - int(_hprobe["t0"])) / 1000.0
		if not is_instance_valid(u) or u.dead or ms > 2000.0:
			_hprobe = {}
			return
		if u.velocity.dot(_hprobe["dir"]) > 10.0:
			lag_own.append(ms)
			_hprobe = {}
		return
	if _hprobe_t < 3.0 or step < 2 or autoplay:
		return
	_hprobe_t = 0.0
	for u in g.units:
		if u.team == 0 and not u.dead and u.velocity.length() < 1.0 and not u.is_worker() and u.kind != "horse" and u.kind != "cannon" \
				and not ["build", "move", "amove", "patrol"].has(u.order):
			var to: Vector2 = u.position + Vector2(200, 0).rotated(randf() * TAU)
			if not g.in_map(g.cell_of(to)) or not g.is_free(g.cell_of(to)) or not g.line_clear(u.position, to):
				continue
			_hprobe = {"u": u, "dir": (to - u.position).normalized(), "t0": Time.get_ticks_usec()}
			g.set("input_cmd", true)
			g.group_move([u], to, false)
			g.set("input_cmd", false)
			lag_hold.append(float(g.net.hold_ms()) if g.net.has_method("hold_ms") else 0.0)
			return


static func _stats(a: PackedFloat32Array) -> String:
	if a.is_empty():
		return "-"
	var tot := 0.0
	var mx := 0.0
	for x in a:
		tot += x
		mx = maxf(mx, x)
	var sorted := a.duplicate()
	sorted.sort()
	return "avg %.1f, p95 %.1f, max %.1f (n %d)" % [tot / a.size(), sorted[int(a.size() * 0.95)], mx, a.size()]


func _lag_report() -> void:
	var over50 := 0
	for f in lag_frames:
		if f > 50.0:
			over50 += 1
	print("LAG %s frames ms: %s, over 50 ms: %d" % [role.to_upper(), _stats(lag_frames), over50])
	if _frozen_at >= 0.0 or freeze_host + hide_host > 0.0:
		print("LAG %s after the window came back, frames ms: %s | saw 'waiting for the host': %s, saw 'host away': %s" % [role.to_upper(), _stats(_after_freeze), _saw_wait, _saw_away])
	if g.net.get("snap_every") != null:
		print("LAG %s snapshot every %.3f s (adaptive), guest glide %.3f s, ping %d ms, jitter %.0f ms, own orders held %d ms" % [role.to_upper(),
			float(g.net.snap_every), g.net.glide_span(), g.net.ping_shown(), g.net.jitter * 1000.0, g.net.hold_ms()])
	if role == "host":
		print("LAG HOST snapshot build+send ms per frame: %s | bytes per snapshot: %s | units %d buildings %d" % [_stats(lag_work), _stats(lag_sizes), g.units.size(), g.buildings.size()])
		print("LAG HOST own move order -> unit walking ms: %s | held for the same delay ms: %s" % [_stats(lag_own), _stats(lag_hold)])
	else:
		print("LAG GUEST snapshot apply ms per frame: %s | ms between snapshot frames: %s" % [_stats(lag_work), _stats(lag_gaps)])
		print("LAG GUEST order -> ack in a snapshot ms: %s | move order -> unit walking ms: %s | -> 3 px on its way ms: %s" % [_stats(lag_seen), _stats(lag_walk), _stats(lag_moved)])
		print("LAG GUEST move order -> a snapshot shows the host's unit on its way ms: %s | jumps while watched: %d (biggest %.1f px)" % [_stats(lag_hostmove), lag_jumps, lag_jump_max])


# ------------------------------------------------------------------ host

func _host_tick() -> void:
	if g == null:
		if lobby.all_seated() and step_t > 1.0 and (int(lobby.slots[1]["colour"]) == GUEST_COL or step_t > 25.0):
			check("host_refused_guest_duplicate_colour", lobby.denied >= 2, "denied=%d" % lobby.denied)
			check("host_has_guest_colour", int(lobby.slots[1]["colour"]) == GUEST_COL)
			print("HOST: guest seated, starting")
			main.start(lobby.make_cfg())
			g = main.game
			g.net.trace = true
			check("host_game_colours", int(g.colours[0]) == HOST_COL and int(g.colours[1]) == GUEST_COL, str(g.colours))
			_give_guest_soldiers()
			if coop:
				check("host_computer_plan_in_config", String(main.last_cfg["slots"][2].get("strategy", "")) == "rush")
			if autoplay:
				for tm in [0, 1]:
					var ai := AI.new()
					ai.game = g
					ai.team = tm
					ai.difficulty = 2
					ai.strategy = "balanced"
					g.add_child(ai)
					g.ais.append(ai)
				Engine.time_scale = speed
			step = 1
			step_t = 0.0
			print("HOST terrain hash %d" % _terrain_hash())
		return
	var s := g.net
	if step == 1 and step_t > 1.0:
		var gt := 1
		base["units"] = g.units.filter(func(u: Unit) -> bool: return u.team == gt).size()
		base["bld"] = g.buildings.filter(func(b: Building) -> bool: return b.team == gt).size()
		step = 2
	if step_t > 3.0 and int(step_t * 10) % 50 == 0:
		pass
	if int(step_t * 30) % 150 == 0 and int(step_t * 30) != _last_print:
		_last_print = int(step_t * 30)
		print("HOST t=%.0f clock=%.1f units=%d bld=%d snaps=%d applied=%d rejected=%d sent=%dKB" % [step_t, g.clock, g.units.size(), g.buildings.size(), s.snap_n, s.cmds_applied, s.cmds_rejected, s.link.sent_bytes / 1024])
	# the guest has left: a computer takes the seat; with stay:<secs> the host plays on a while to show it
	if not s.link.connected or (lobby.link and not lobby.all_seated()):
		if stay > 0.0:
			if left_t < 0.0:
				left_t = t
				print("HOST: guest left, staying %.0fs" % stay)
			elif t - left_t > stay:
				check("host_computer_took_the_seat", g.ais.any(func(a) -> bool: return a.team == 1), "ais=%d" % g.ais.size())
				_finish()
		else:
			_finish()


## The guest's side gets 4 soldiers and (Crown) a Cannon by its hall at the start: units free to walk (the lag
## probe times their first steps) and for the orders only soldiers take (attack, patrol, hold, BOMBARD).
func _give_guest_soldiers() -> void:
	if autoplay:
		return
	var hall: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == g.faction_hall(1):
			hall = b
		elif b.team == 0 and b.kind == g.faction_hall(0):
			# the host gets two soldiers of its own (its own orders are timed too: the same delay for both)
			var hk: String = {"crown": "musketeer", "brood": "raptor", "clockwork": "clock_soldier"}[g.faction_of(0)]
			for j in 2:
				var hc := g.nearest_free(g.cell_of(b.center() + Vector2(-40 + j * 80, 130 if b.center().y < Game.H * Game.T * 0.5 else -130)), 8)
				g._add_unit(hk, 0, g.cell_center(hc))
	if hall == null:
		return
	var f := g.faction_of(1)
	var kinds: Array = {"crown": ["musketeer", "musketeer", "musketeer", "musketeer", "cannon"], "brood": ["raptor", "raptor", "raptor", "raptor"],
		"clockwork": ["clock_soldier", "clock_soldier", "clock_soldier", "clock_soldier"]}[f]
	var i := 0
	for k in kinds:
		var c := g.nearest_free(g.cell_of(hall.center() + Vector2(-90 + i * 45, 130 if hall.center().y < Game.H * Game.T * 0.5 else -130)), 8)
		g._add_unit(k, 1, g.cell_center(c))
		i += 1
	# and a supply building for them (else the guest's first TRAIN is refused: "Need more supply")
	var sk := Defs.supply_kind(f)
	for r in range(6, 16):
		for a in 24:
			var sc := hall.cell + Vector2i(Vector2.from_angle(TAU * a / 24.0 + 0.3) * r)
			if g.in_map(sc) and g.placement_problem(1, sk, sc) == "":
				g._add_building(sk, 1, sc, true)
				return


func _host_report() -> void:
	var s := g.net
	var gt := 1
	var units := g.units.filter(func(u: Unit) -> bool: return u.team == gt).size()
	var bld := g.buildings.filter(func(b: Building) -> bool: return b.team == gt).size()
	print("HOST guest team: units %d -> %d, buildings %d -> %d" % [base.get("units", 0), units, base.get("bld", 0), bld])
	if not autoplay:
		check("host_applied_commands", s.cmds_applied >= 3, "applied=%d" % s.cmds_applied)
		check("host_refused_foreign_order", s.cmds_rejected >= 1, "rejected=%d (%s)" % [s.cmds_rejected, s.last_reject])
		check("host_guest_trained_unit", units > int(base.get("units", 99)))
		check("host_guest_placed_building", bld > int(base.get("bld", 99)))
	print("HOST_RESULT snapshots=%d bytes_sent=%d (%.1f KB/s)" % [s.snap_n, s.link.sent_bytes, s.link.sent_bytes / 1024.0 / maxf(step_t, 1.0)])
	_lag_report()


# ------------------------------------------------------------------ guest

func _guest_colour_picks() -> void:
	cstep_t += 1.0 / 60.0
	var my := lobby.my_slot
	match cstep:
		0:
			if lobby.slots.size() >= 2 and bool(lobby.slots[my].get("here", false)):
				lobby.choose_colour(HOST_COL)        # the host wears it: must be refused
				cstep = 1
				cstep_t = 0.0
		1:
			if cstep_t > 1.5:
				var back_ok: bool = int(lobby.slots[my]["colour"]) != HOST_COL
				check("guest_duplicate_colour_refused", back_ok and lobby.status.contains("taken"), "colour=%s status=%s" % [str(lobby.slots[my]["colour"]), lobby.status])
				lobby.choose_colour(GUEST_COL)
				cstep = 2
				cstep_t = 0.0
		2:
			if int(lobby.slots[my]["colour"]) == GUEST_COL:
				check("guest_colour_pick_confirmed", true, "after %.1fs" % cstep_t)
				cstep = 3
			elif cstep_t > 5.0:
				check("guest_colour_pick_confirmed", false)
				cstep = 3


func _guest_tick() -> void:
	if g == null:
		if main.game == null and cstep < 3:
			_guest_colour_picks()
		if main.game != null:
			check("guest_game_colours", int(g_colour(0)) == HOST_COL and int(g_colour(lobby.my_slot)) == GUEST_COL, str(main.game.colours))
			g = main.game
			print("GUEST game up. puppet=%s human=%d terrain hash %d" % [g.puppet, g.human, _terrain_hash()])
			step = 1
			step_t = 0.0
		return
	var s := g.net
	if s == null:
		return
	match step:
		1:
			if s.snaps_got >= 10 and not _mine().is_empty():
				print("GUEST first snapshots: units=%d buildings=%d (own units %d)" % [g.units.size(), g.buildings.size(), _mine().size()])
				check("guest_got_snapshots", s.snaps_got >= 10 and g.units.size() >= 4 and g.buildings.size() >= 2)
				var hall: Building = null
				for b in g.buildings:
					if b.team == g.human and b.kind == Defs.FACTIONS[g.faction_of(g.human)]["hall"]:
						hall = b
				check("guest_has_own_hall", hall != null)
				base["hall"] = hall
				base["own_units"] = _mine().size()
				base["own_bld"] = g.buildings.filter(func(b: Building) -> bool: return b.team == g.human).size()
				var w: Unit = null
				for u in _mine():
					if u.is_worker():
						w = u
						break
				base["w"] = w
				base["w_from"] = w.position
				base["w_to"] = w.position + Vector2(260, 40)
				base["seq"] = s.cmd_seq
				if autoplay:
					step = 8
					step_t = 0.0
					return
				g.smart_command([w], base["w_to"])
				print("GUEST ordered worker %d to move" % w.net_id)
				step = 2
				step_t = 0.0
		2:
			var w: Unit = base["w"]
			if is_instance_valid(w) and w.position.distance_to(base["w_to"]) < 50.0:
				check("guest_move_command_round_trip", true, "took %.1fs, command rtt %.0f ms" % [step_t, s.cmd_rtt_ms])
				_start_train(s)
			elif step_t > 12.0:
				check("guest_move_command_round_trip", false, "worker at %s wanted %s" % [str(w.position), str(base["w_to"])])
				_start_train(s)
		3:
			if shot_path != "" and step_t > 6.0 and not base.has("shot"):
				base["shot"] = true
				var img := root.get_viewport().get_texture().get_image()
				if img:
					img.save_png(shot_path)
					print("GUEST screenshot saved ", shot_path, " ", img.get_size())
			if _mine().size() > int(base["own_units"]):
				check("guest_train_command", true, "new unit after %.1fs" % step_t)
				_start_build(s)
			elif step_t > 25.0:
				check("guest_train_command", false)
				_start_build(s)
		4:
			var n := g.buildings.filter(func(b: Building) -> bool: return b.team == g.human).size()
			if n > int(base["own_bld"]):
				check("guest_place_building_command", true, "after %.1fs" % step_t)
				_start_foreign(s)
			elif step_t > 12.0:
				check("guest_place_building_command", false)
				_start_foreign(s)
		5:
			if step_t > 2.5:
				check("guest_entity_counts_match_host", s.count_diff_max == 0, "worst difference %d, snapshots off by any: %d of %d" % [s.count_diff_max, s.count_diff_snaps, s.snaps_got])
				print("GUEST_RESULT snaps=%d interval=%.3f cmds=%d cmd_rtt=%.0f ms ping=%.0f ms recv=%d bytes (%.1f KB/s)" % [s.snaps_got, s.interval, s.cmd_seq, s.cmd_rtt_ms, s.link.rtt_ms, s.link.recv_bytes, s.link.recv_bytes / 1024.0 / maxf(t, 1.0)])
				_lag_report()
				var all_ok := true
				for k in results:
					all_ok = all_ok and results[k]
				print("GUEST %s" % ("ALL OK" if all_ok else "SOME FAILED"))
				step = 6
				done_t = t
	if step == 8 and step_t > watch:
		step = 5
		step_t = 10.0
	if step == 6 and t - done_t > 1.0:
		lobby.dispose()
		quit(0)


func g_colour(i: int) -> int:
	return int(main.game.colours[i])


func _start_train(s: NetSession) -> void:
	var hall: Building = base["hall"]
	var worker: String = Defs.FACTIONS[g.faction_of(g.human)]["worker"]
	base["own_units"] = _mine().size()
	var r := g.train_any([hall], worker)
	print("GUEST asked the hall to train a %s (local answer '%s')" % [worker, r])
	step = 3
	step_t = 0.0


func _start_build(s: NetSession) -> void:
	var f := g.faction_of(g.human)
	var k: String = Defs.supply_kind(f)
	var hall: Building = base["hall"]
	var spot := Vector2i(-1, -1)
	for r in range(5, 14):
		for a in 24:
			var c := hall.cell + Vector2i(Vector2.from_angle(TAU * a / 24.0) * r)
			if g.in_map(c) and g.placement_problem(g.human, k, c) == "":
				spot = c
				break
		if spot.x >= 0:
			break
	base["own_bld"] = g.buildings.filter(func(b: Building) -> bool: return b.team == g.human).size()
	var builders: Array = _mine().filter(func(u: Unit) -> bool: return u.is_worker()).slice(0, 2)
	print("GUEST places %s at %s" % [k, str(spot)])
	g.place_building(g.human, k, spot, builders, false)
	step = 4
	step_t = 0.0


func _start_foreign(s: NetSession) -> void:
	var foe: Unit = null
	for u in g.units:
		if u.team == 0 and not u.dead:
			foe = u
			break
	if foe:
		print("GUEST tries to stop the host's unit %d (must be refused)" % foe.net_id)
		foe.cmd_stop()
	step = 5
	step_t = 0.0


func _finish() -> void:
	if role == "host" and g != null:
		_host_report()
		var all_ok := true
		for k in results:
			all_ok = all_ok and results[k]
		print("HOST %s" % ("ALL OK" if all_ok else "SOME FAILED"))
	if lobby:
		lobby.dispose()
	quit(0)
