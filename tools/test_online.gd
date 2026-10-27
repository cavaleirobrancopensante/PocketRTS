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
var limit := 420.0
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
var shots := ""                  # shots:<dir>: screenshots along the way (needs a window: xvfb-run, no --headless)
var _shot_q: Array = []          # names waiting for their frame
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
var lag_speed := PackedFloat32Array()     # guest: a probed unit's speed on screen, frame by frame, once it walks
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
var _saw_taken := false
var nolead := false
var nosame := false
var rate10 := false
var clocksnap := false
var noterp := false
var nopredict := false           # nopredict: the click shows nothing beyond the ring, the voice and the walk lead (as 0.14.47)
var react_rows: Array = []       # guest: [order, ms from the click to its first visible reaction (-1: none in 2.5 s), unit jumps, queue flickers, resources given back]
var _drained := false            # host: the guest's gold is held at 0 (its refused orders: the guest asked in the chat)
var _gold_was := 0
var lag_own_train := PackedFloat32Array()   # host: ms from its own TRAIN (held) to the queue showing it / to the real queue
var lag_own_train_real := PackedFloat32Array()
var _htrain := {}
var hostsurrender := false
var quick := false               # quick: only the first checks (no chat, orders, pause, surrender)
var _orders: Array = []          # guest: the order types still to send (_guest_extras)
var _ord: Dictionary = {}        # guest: the one being checked
var _host_chat_done := false
var _host_saw_pause := false


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
		elif a.begins_with("shots:"):
			shots = a.substr(6)
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
		elif a == "nolead":
			nolead = true             # the guest's units wait for the host's picture (as before 0.14.37)
		elif a == "nosame":
			nosame = true             # the lobby's "Same delay for both players" off
		elif a == "hostsurrender":
			hostsurrender = true      # at the end the HOST surrenders (the guest asks in the chat), not the guest
		elif a == "quick":
			quick = true
		elif a == "nopredict":
			nopredict = true
		elif a == "noterp":
			noterp = true             # the guest's units glide toward the newest picture (0.14.32), no buffer
		elif a == "clocksnap":
			clocksnap = true          # pictures by the clock, every 0.05 s (0.14.32), not every 2 game ticks
		elif a == "rate10":
			rate10 = true             # ten snapshots a second, fixed (as before the adaptive rate)
		elif a.begins_with("freeze_at:"):
			freeze_at = float(a.substr(10))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


## A screenshot a few frames from now (the HUD draws on its next frames).
func snap(name: String) -> void:
	if shots != "":
		_shot_q.append([name, 12])


func _snap_tick() -> void:
	for q in _shot_q.duplicate():
		q[1] -= 1
		if q[1] <= 0:
			_shot_q.erase(q)
			var img := root.get_viewport().get_texture().get_image()
			if img:
				img.save_png("%s/%s_%s.png" % [shots, role, q[0]])
				print("SHOT %s_%s" % [role, q[0]])


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
	_snap_tick()
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
		lobby.same_delay = not nosame
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
		# (walking on the host's word: how even its steps look here, per game tick: units move on the 30 Hz ticks, the
		# screen smooths between them)
		var pf := Engine.get_physics_frames()
		var dpf := pf - int(_probe.get("pf", pf))
		if dpf > 0:
			if _probe.has("host") and ms > float(_probe["host"]) + 300.0 and ms < 2300.0:
				var spd := (u.position - (_probe["tick_pos"] as Vector2)).length() * float(Engine.physics_ticks_per_second) / dpf
				lag_speed.append(spd)
				if OS.get_environment("PROBE_DEBUG") != "":
					_probe["spd"] = str(_probe.get("spd", "")) + " %d" % int(spd)
			_probe["tick_pos"] = u.position
		_probe["pf"] = pf
		if not _probe.has("tick_pos"):
			_probe["tick_pos"] = u.position
		_probe["last"] = u.position
		if ms > 2500.0:
			if _probe.has("walk"):
				lag_walk.append(float(_probe["walk"]))
			if _probe.has("moved"):
				lag_moved.append(float(_probe["moved"]))
			if _probe.has("host"):
				lag_hostmove.append(float(_probe["host"]))
			if OS.get_environment("PROBE_DEBUG") != "":
				print("PROBE %s walk %s moved %s ack %s host %s speeds%s" % [u.kind, _probe.get("walk", "-"), _probe.get("moved", "-"), _probe.get("ack", "-"), _probe.get("host", "-"), _probe.get("spd", "")])
			_probe = {}
		return
	if _probe_t < 2.0 or step < 2 or (g.hud and g.hud.countdown > 0.0) or (step >= 20 and not _ord.is_empty()):      # (not in the 3-2-1: nothing moves yet; not while an order's reaction is timed)
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
			if OS.get_environment("PROBE_DEBUG") != "":
				print("PROBE start %s id %d lead %s order %s work %s off_field %s aboard %s tesla %s braced %s net_t %s owl_t %s mo %s" % [u.kind, u.net_id,
					s.leads.has(u.net_id), u.order, u.work, u.off_field, u.aboard, u.tesla_mode, u.braced, u.net_t, u.owl_t, s.motion.get(u.net_id)])
			return


## Host: every 3 s one of its own idle soldiers is told to walk 200 px, given as at the screen (Game.input_cmd: with the
## same delay for both players it is held like a guest's order), and timed until it walks.
func _host_probe_tick(real: float) -> void:
	_host_train_probe()
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
	if _hprobe_t < 3.0 or step < 2 or autoplay or (g.hud and g.hud.countdown > 0.0):
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


## Host: every 7 s its own Town Hall (or Hive, Clocktower) is told to train a worker, given as at the screen (held, with the
## same delay for both), and timed until the HUD's queue shows it (NetPredict.shown_queue) and until the real queue has it.
func _host_train_probe() -> void:
	if not _htrain.is_empty():
		var hb: Building = _htrain["b"]
		var ms := (Time.get_ticks_usec() - int(_htrain["t0"])) / 1000.0
		if not is_instance_valid(hb) or ms > 3000.0:
			_htrain = {}
			return
		if not _htrain.has("shown") and NetPredict.shown_queue(g, hb)[0].size() > int(_htrain["n"]):
			_htrain["shown"] = ms
			lag_own_train.append(ms)
		if hb.queue.size() > int(_htrain["n"]):
			lag_own_train_real.append(ms)
			if _htrain.has("shown") or true:
				g.set("input_cmd", true)
				g.cancel_train(hb)        # (and back out: the host's economy stays as it was)
				g.set("input_cmd", false)
			_htrain = {}
		return
	if step < 2 or autoplay or (g.hud and g.hud.countdown > 0.0) or Engine.get_physics_frames() % 210 != 0:
		return
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0) and b.built and not b.dead and b.queue.is_empty():
			var wk: String = Defs.FACTIONS[g.faction_of(0)]["worker"]
			if g.can_train(b, wk) != "":
				return
			_htrain = {"b": b, "n": b.queue.size(), "t0": Time.get_ticks_usec()}
			g.set("input_cmd", true)
			g.train_any([b], wk)
			g.set("input_cmd", false)
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
			float(g.net.snap_every), g.net.buffer_s() if g.net.interp_on else g.net.glide_span(), g.net.ping_shown(), g.net.jitter * 1000.0, g.net.hold_ms()])
	if role == "host":
		print("LAG HOST snapshot build+send ms per frame: %s | bytes per snapshot: %s | units %d buildings %d" % [_stats(lag_work), _stats(lag_sizes), g.units.size(), g.buildings.size()])
		print("LAG HOST own move order -> unit walking ms: %s | held for the same delay ms: %s" % [_stats(lag_own), _stats(lag_hold)])
		print("LAG HOST own train -> shown in the queue ms: %s | -> in the real queue ms: %s" % [_stats(lag_own_train), _stats(lag_own_train_real)])
	else:
		print("LAG GUEST snapshot apply ms per frame: %s | ms between snapshot frames: %s" % [_stats(lag_work), _stats(lag_gaps)])
		print("LAG GUEST order -> ack in a snapshot ms: %s | move order -> unit walking ms: %s | -> 3 px on its way ms: %s" % [_stats(lag_seen), _stats(lag_walk), _stats(lag_moved)])
		print("LAG GUEST move order -> a snapshot shows the host's unit on its way ms: %s | jumps while watched: %d (biggest %.1f px)" % [_stats(lag_hostmove), lag_jumps, lag_jump_max])
		var sm := 0.0
		var sv := 0.0
		for v in lag_speed:
			sm += v
		sm /= maxf(lag_speed.size(), 1.0)
		for v in lag_speed:
			sv += (v - sm) * (v - sm)
		sv = sqrt(sv / maxf(lag_speed.size(), 1.0))
		var jerk := 0.0
		for i in range(1, lag_speed.size()):
			jerk += absf(lag_speed[i] - lag_speed[i - 1])
		jerk /= maxf(lag_speed.size() - 1, 1.0)
		print("LAG GUEST walking unit's speed on screen px/s: mean %.1f, spread %.1f (%.0f%% of it), change from one game tick to the next %.1f (%.0f%%; 0 = perfectly even) (n %d)" % [sm, sv, 100.0 * sv / maxf(sm, 0.001), jerk, 100.0 * jerk / maxf(sm, 0.001), lag_speed.size()])


# ------------------------------------------------------------------ host

func _host_tick() -> void:
	if g == null:
		if shots != "" and lobby.all_seated() and lobby.ping_ms >= 0 and not base.has("lobby_shot"):
			base["lobby_shot"] = true
			main.show_online()
			snap("lobby")
			step_t = 0.0
		if lobby.all_seated() and step_t > (3.0 if shots != "" else 1.0) and (int(lobby.slots[1]["colour"]) == GUEST_COL or step_t > 25.0):
			check("host_refused_guest_duplicate_colour", lobby.denied >= 2, "denied=%d" % lobby.denied)
			check("host_has_guest_colour", int(lobby.slots[1]["colour"]) == GUEST_COL)
			print("HOST: guest seated, starting")
			main.start(lobby.make_cfg())
			g = main.game
			g.net.trace = true
			if rate10:
				g.net.snap_fixed = 0.1
			if clocksnap:
				g.net.snap_by_clock = true
				if not rate10:
					g.net.snap_fixed = 0.05
			if g.net.predict:
				g.net.predict.on = not nopredict
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
		# (the snapshot's direct readers and writers must follow UNIT_PROPS / BLD_PROPS: a value added to a list only
		# shifts every later one on the guest)
		var why := NetSnapshot.check_lists(g.units[0] if not g.units.is_empty() else null, g.buildings[0] if not g.buildings.is_empty() else null)
		check("host_snapshot_lists_match", why == "", why)
		# a body near the guest's hall, for the guest's ATTACK GROUND (Defs.GROUND) and its health bar (Game.hit_body, fx "h")
		for hb in g.buildings:
			if hb.team == gt and hb.kind == Defs.FACTIONS[g.faction_of(gt)]["hall"]:
				var at: Vector2 = g.cell_center(g.nearest_free(g.cell_of(hb.center() + BODY_OFF), 6))
				base["host_body"] = g._add_unit("musketeer", 0, at)      # (killed in a moment, once the guest has it)
				break
		step = 2
	if step == 2 and step_t > 3.0 and base.has("host_body"):
		var bm: Unit = base["host_body"]
		base.erase("host_body")
		if is_instance_valid(bm) and not bm.dead:
			bm.take_damage(99999.0, null)
	if step_t > 3.0 and int(step_t * 10) % 50 == 0:
		pass
	if int(step_t * 30) % 150 == 0 and int(step_t * 30) != _last_print:
		_last_print = int(step_t * 30)
		print("HOST t=%.0f clock=%.1f units=%d bld=%d snaps=%d applied=%d rejected=%d sent=%dKB" % [step_t, g.clock, g.units.size(), g.buildings.size(), s.snap_n, s.cmds_applied, s.cmds_rejected, s.link.sent_bytes / 1024])
	_host_extras(s)
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
		check("host_guest_trained_unit", maxi(units, int(base.get("max_u", 0))) > int(base.get("units", 99)))
		check("host_guest_placed_building", maxi(bld, int(base.get("max_b", 0))) > int(base.get("bld", 99)))
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
			if lobby.status.contains("taken"):
				_saw_taken = true          # (a lobby sent again later puts the room's line back: the refusal was said)
			if cstep_t > 1.5:
				var back_ok: bool = int(lobby.slots[my]["colour"]) != HOST_COL
				check("guest_duplicate_colour_refused", back_ok and _saw_taken, "colour=%s status=%s" % [str(lobby.slots[my]["colour"]), lobby.status])
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
		if shots != "" and main.game == null and lobby._got_lobby and lobby.ping_ms >= 0 and cstep >= 3 and not base.has("lobby_shot"):
			base["lobby_shot"] = true
			main.show_online()          # (the room page, as the player sees it, with the ping line)
			snap("lobby")
		if main.game != null:
			check("guest_game_colours", int(g_colour(0)) == HOST_COL and int(g_colour(lobby.my_slot)) == GUEST_COL, str(main.game.colours))
			g = main.game
			g.net.lead_on = not nolead
			g.net.interp_on = not noterp
			if g.net.predict:
				g.net.predict.on = not nopredict
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
				_start_ground(s)
			elif step_t > 12.0:
				check("guest_place_building_command", false)
				_start_ground(s)
		7:
			# ATTACK GROUND online: the guest's order reaches the host, its worker strikes the body, and the guest's copy
			# of the body takes the health the host sends (and rots by itself meanwhile)
			var b = base.get("body")
			if b == null or step_t > 45.0:
				check("guest_ground_attack_hits_body", false, "no body seen" if b == null else "body health %.0f of %.0f" % [b.body_left() if is_instance_valid(b) else -1.0, b.body_size() if is_instance_valid(b) else -1.0])
				_start_foreign(s)
			elif not is_instance_valid(b) or b.torn or b.body_dmg > 0.0:
				check("guest_ground_attack_hits_body", true, "after %.1fs (%s)" % [step_t, "torn" if not is_instance_valid(b) or b.torn else "%.0f of %.0f left" % [b.body_left(), b.body_size()]])
				_start_foreign(s)
		5:
			if step_t > 2.5:
				check("guest_entity_counts_match_host", s.count_diff_max == 0, "worst difference %d, snapshots off by any: %d of %d" % [s.count_diff_max, s.count_diff_snaps, s.snaps_got])
				if not autoplay and not quick:
					step = 20             # the rest: chat, a refused order's reason, every order type, pause, surrender
					step_t = 0.0
					return
				step = 30
		20, 21, 22, 23, 24, 25, 26, 27:
			_guest_extras(s)
	if step == 30:
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


## Host: answers the guest's chat line, sees its pause and its surrender.
func _host_extras(s: NetSession) -> void:
	if step >= 2 and not g.over:
		# (the most the guest's side had: its surrender at the end pulls its buildings down)
		base["max_u"] = maxi(int(base.get("max_u", 0)), g.units.filter(func(u: Unit) -> bool: return u.team == 1).size())
		base["max_b"] = maxi(int(base.get("max_b", 0)), g.buildings.filter(func(b: Building) -> bool: return b.team == 1 and not b.dead).size())
	if g.chat and not _host_chat_done:
		for ln in g.chat.lines:
			if int(ln["team"]) == 1 and String(ln["text"]).contains("hello from the guest"):
				_host_chat_done = true
				check("host_got_guest_chat", true)
				g.chat.post(0, "hello from the host")
	if g.chat and not g.over:
		# (the guest's test asks for its setups in the chat: a target near its hall, its gold held at 0, given back)
		for ln in g.chat.lines:
			if int(ln["team"]) != 1:
				continue
			var tx := String(ln["text"])
			if tx.contains("test: dummy") and not base.has("dummy"):
				var gh: Building = null
				for b in g.buildings:
					if b.team == 1 and b.kind == g.faction_hall(1):
						gh = b
				if gh:
					var c := g.nearest_free(g.cell_of(gh.center() + Vector2(220, 0).rotated(0.6)), 8)
					var du := g._add_unit("musketeer", 0, g.cell_center(c))
					du.hold_fire = true
					base["dummy"] = du
					print("HOST: a target for the guest at %s" % str(du.position))
			if tx.contains("test: extras") and not base.has("extras"):
				base["extras"] = true
				var eh: Building = null
				for b in g.buildings:
					if b.team == 1 and b.kind == g.faction_hall(1):
						eh = b
				var ek: Array = {"brood": ["spore_mother", "mist_toad"], "clockwork": ["tesla_cart"]}.get(g.faction_of(1), [])
				for j in ek.size():
					if eh and Defs.UNITS.has(ek[j]) and ArtData.UNITS.has(ek[j]):
						var ec := g.nearest_free(g.cell_of(eh.center() + Vector2(-120 + j * 60, 120 if eh.center().y < Game.H * Game.T * 0.5 else -120)), 8)
						g._add_unit(ek[j], 1, g.cell_center(ec))
			if tx.contains("test: drain") and not base.has("drained"):
				base["drained"] = true
				_drained = true
				_gold_was = int(g.players[1]["gold"])
			if tx.contains("test: refill") and not base.has("refilled"):
				base["refilled"] = true
				_drained = false
				g.players[1]["gold"] = _gold_was + 500
		if _drained:
			g.players[1]["gold"] = 0
	if s.pause_by == 1 and not _host_saw_pause:
		_host_saw_pause = true
		snap("paused_by_guest")
		check("host_saw_guest_pause", paused and int(s.pauses_left.get(1, 0)) == NetSession.PAUSES - 1, "pauses left %s" % str(s.pauses_left))
	if hostsurrender and g.chat and not g.over and not base.has("surrendered"):
		for ln in g.chat.lines:
			if int(ln["team"]) == 1 and String(ln["text"]).contains("surrender now"):
				base["surrendered"] = true
				g.player_surrender()
	if g.over and not results.has("host_saw_guest_surrender") and g.end_note == "player_surrender" and not hostsurrender:
		check("host_saw_guest_surrender", g.end_quitter == 1 and not g.eliminated[0], "quitter %d" % g.end_quitter)


## Guest, after the first checks: chat both ways, the reason for the refused order, every order type the HUD can give
## (each must be run by the host, none refused), a pause and its resume, and last a surrender that ends the match.
func _guest_extras(s: NetSession) -> void:
	match step:
		20:
			g.chat.post(g.human, "hello from the guest")
			step = 21
			step_t = 0.0
		21:
			var got := g.chat.lines.any(func(ln: Dictionary) -> bool: return int(ln["team"]) == 0 and String(ln["text"]).contains("hello from the host"))
			if got or step_t > 10.0:
				check("guest_chat_both_ways", got, "after %.1fs" % step_t)
				check("guest_refusal_says_why", s.refusals >= 1 and s.last_msg.contains("not yours"), "refusals %d, last '%s'" % [s.refusals, s.last_msg])
				_orders = _order_list()
				snap("chat")
				step = 22
				step_t = 0.0
		22:
			if _ord.is_empty():
				if _orders.is_empty():
					var bad: Array = results.keys().filter(func(k: String) -> bool: return k.begins_with("order_") and not results[k])
					if not results.has("guest_every_order_type"):
						check("guest_every_order_type", bad.is_empty(), "%d types, failed: %s" % [results.keys().filter(func(k: String) -> bool: return k.begins_with("order_")).size(), str(bad)])
					if shots != "" and not base.has("menu_shot"):
						base["menu_shot"] = true
						g.hud.toggle_menu(true)
						snap("menu")
						step_t = 0.0
						return
					if shots != "" and (step_t < 2.5 or not _shot_q.is_empty()):
						return
					g.hud.toggle_menu(true)
					var labels: Array = g.hud._menu_buttons().map(func(b: Dictionary) -> String: return String(b["label"]))
					check("guest_menu_has_pause_and_surrender", g.hud._pause_item().get("enabled", true) and labels.has("SURRENDER") and g.hud._layer_sig("pause").size() > 0,
						str(labels))
					g.hud.toggle_menu(false)
					s.request_pause(true)
					step = 23
					step_t = 0.0
					return
				_ord = _orders.pop_front()
				if _ord.has("ready") and not (_ord["ready"] as Callable).call():
					# (waits for its setup: the host draining the gold, a site to abandon...) up to 8 s
					if float(_ord.get("waited", 0.0)) < 8.0:
						_ord["waited"] = float(_ord.get("waited", 0.0)) + 1.0 / 60.0
						_orders.push_front(_ord)
						_ord = {}
						return
					var du = base.get("du")
					check("order_" + String(_ord["name"]), false, "its setup never came" + (" (%s: %s, order %s, %.1f s)" % [du.kind, du.tesla_mode, du.order, du.tesla_t] if is_instance_valid(du) else ""))
					_ord = {}
					return
				if _ord.has("warm") and not _ord.has("warm_t"):
					(_ord["warm"] as Callable).call()      # (units set walking first, so a stop has something to stop)
					_ord["warm_t"] = Time.get_ticks_msec()
				if _ord.has("warm_t") and Time.get_ticks_msec() - int(_ord["warm_t"]) < 1200:
					_orders.push_front(_ord)
					_ord = {}
					return
				if _ord.has("pre"):
					(_ord["pre"] as Callable).call()
				_ord["ref"] = s.refusals
				_ord["seq0"] = s.cmd_seq
				_watch_begin()
				(_ord["do"] as Callable).call()
				_ord["seq"] = s.cmd_seq
				step_t = 0.0
				return
			_watch_order()
			var acked: bool = s.last_ack >= int(_ord["seq"])
			if (acked and step_t > (2.5 if _ord.has("react") else 0.8)) or step_t > 6.0:
				_watch_end()
				var sent: bool = int(_ord["seq"]) > int(_ord["seq0"])
				var ok: bool = sent and acked and s.refusals == int(_ord["ref"])
				if String(_ord.get("expect", "")) != "":
					# (refused on purpose: the host must say the game's own reason, the one this screen works out too)
					ok = sent and acked and s.refusals == int(_ord["ref"]) + 1 and s.last_msg == String(_ord["expect"])
				if ok and _ord.has("then"):
					ok = (_ord["then"] as Callable).call()
				if g.net.predict and g.net.predict.pending() > 0:
					ok = false                 # (what the click showed must be gone once the host has answered)
					print("GUEST: order %s left %d predictions behind" % [String(_ord["name"]), g.net.predict.pending()])
				check("order_" + String(_ord["name"]), ok, "sent %s acked %s refused %d%s" % [sent, acked, s.refusals - int(_ord["ref"]), (" (" + s.last_msg + ")") if s.refusals > int(_ord["ref"]) else ""])
				_ord = {}
		23:
			if s.pause_by == g.human and shots != "" and not base.has("pause_shot"):
				base["pause_shot"] = true
				snap("paused")
				step_t = 0.0
			elif s.pause_by == g.human and (shots == "" or (step_t > 1.0 and _shot_q.is_empty())):
				check("guest_pause_holds_both", g.hud.paused and s.my_pauses() == NetSession.PAUSES - 1, "pauses left %d" % s.my_pauses())
				s.request_pause(false)
				step = 24
				step_t = 0.0
			elif step_t > 6.0:
				check("guest_pause_holds_both", false, "no pause came back")
				step = 24
				step_t = 0.0
		24:
			if not s.paused() and g.hud.countdown <= 0.0 and step_t > 0.5:
				check("guest_resume", true, "after %.1fs" % step_t)
				if hostsurrender:
					g.chat.post(g.human, "host, surrender now")
				else:
					g.player_surrender()
				step = 25
				step_t = 0.0
			elif step_t > 10.0:
				check("guest_resume", false)
				g.player_surrender()
				step = 25
				step_t = 0.0
		25:
			if coop and not hostsurrender:
				# (co-op: the friend plays on, so the guest's side is out and the match goes on for the host)
				if g.eliminated[g.human] or step_t > 10.0:
					check("guest_surrender_coop_side_out", g.eliminated[g.human] and not g.over, "out %s over %s after %.1fs" % [g.eliminated[g.human], g.over, step_t])
					step = 30
					step_t = 0.0
				return
			if g.over or step_t > 10.0:
				snap("over")
				if hostsurrender:
					check("guest_sees_host_surrender", g.over and g.end_note == "player_surrender" and g.end_quitter == 0 and g.winner >= 0, "over %s note %s quitter %d winner %d after %.1fs" % [g.over, g.end_note, g.end_quitter, g.winner, step_t])
				else:
					check("guest_surrender_ends_match", g.over and g.end_note == "player_surrender", "over %s note %s after %.1fs" % [g.over, g.end_note, step_t])
				step = 30
				step_t = 0.0


## Every order type the guest's HUD can give, with the guest's own units and buildings: [name, what to call, (a check
## that it took)]. Each goes through the real game function, as a click or a key would. "react": what the player sees
## on its screen first (timed from the click: the LAG REACT lines); "us": units watched for jumps; "qb": a building
## whose queue is watched for flickers; "cost": what it spends (the resources must not come back while it waits).
func _order_list() -> Array:
	var out: Array = []
	var special := ["cannon", "spore_mother", "mist_toad", "tesla_cart"]
	var soldiers: Array = _mine().filter(func(u: Unit) -> bool: return not u.is_worker() and not special.has(u.kind) and u.kind != "horse")
	var workers: Array = _mine().filter(func(u: Unit) -> bool: return u.is_worker())
	var guns: Array = _mine().filter(func(u: Unit) -> bool: return u.kind == "cannon")
	var hall: Building = base["hall"]
	var here: Vector2 = hall.center()
	var away := here + (Vector2(0, 260) if here.y < Game.H * Game.T * 0.5 else Vector2(0, -260))
	var wk: String = Defs.FACTIONS[g.faction_of(g.human)]["worker"]
	var p := g.net.predict
	if not soldiers.is_empty():
		var sq := soldiers.slice(0, 2)
		out.append({"name": "move", "do": func() -> void: g.group_move(sq, away, false), "us": sq, "react": func() -> bool: return _walking(sq)})
		out.append({"name": "attack_move", "do": func() -> void: g.group_move(sq, away + Vector2(60, 0), true), "us": sq, "react": func() -> bool: return _walking(sq)})
		out.append({"name": "smart_move", "do": func() -> void: g.smart_command(sq, away + Vector2(-60, 0)), "us": sq, "react": func() -> bool: return _walking(sq)})
		out.append({"name": "line_move", "do": func() -> void: g.line_move(sq, PackedVector2Array([away + Vector2(-80, 40), away + Vector2(80, 40)]), false),
			"us": sq, "react": func() -> bool: return _walking(sq)})
		out.append({"name": "hold", "do": func() -> void: g.command_all(sq, "hold"), "warm": func() -> void: _walk_first(sq, away + Vector2(0, 120)),
			"us": sq, "react": func() -> bool: return _standing(sq)})
		out.append({"name": "stop_all", "do": func() -> void: g.command_all(sq, "stop"), "warm": func() -> void: _walk_first(sq, away + Vector2(-120, 0)),
			"us": sq, "react": func() -> bool: return _standing(sq)})
		var one: Unit = sq[0]
		out.append({"name": "unit_stop", "do": func() -> void: one.cmd_stop(), "warm": func() -> void: _walk_first([one], away + Vector2(120, 60)),
			"us": [one], "react": func() -> bool: return _standing([one])})
		# (the host's own hall, across the map: they turn to it and start out; the next order stops them)
		var foe_hall: Building = null
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.kind == g.faction_hall(0):
				foe_hall = b
		if foe_hall:
			out.append({"name": "attack_building", "do": func() -> void: g.smart_command(sq, foe_hall.center()), "us": sq,
				"react": func() -> bool: return _turned(sq, foe_hall.center()) and _walking(sq)})
			out.append({"name": "stop_after_attack", "do": func() -> void: g.command_all(sq, "stop"), "us": sq, "react": func() -> bool: return _standing(sq)})
		out.append({"name": "attack_unit", "ready": func() -> bool: return _dummy() != null, "pre": func() -> void: base["dummy_u"] = _dummy(),
			"do": func() -> void: g.smart_command(sq, (base["dummy_u"] as Unit).position), "us": sq,
			"react": func() -> bool: return is_instance_valid(base["dummy_u"]) and _turned(sq, (base["dummy_u"] as Unit).position)})
		out.append({"name": "hold_fire", "do": func() -> void: one.set_hold_fire(true),
			"then": func() -> bool: return one.hold_fire or not one.has_gun(), "react": func() -> bool: return one.hold_fire or not one.has_gun()})     # (only a unit with a firearm holds it)
		out.append({"name": "hold_fire_off", "do": func() -> void: one.set_hold_fire(false), "react": func() -> bool: return not one.hold_fire})
	if not guns.is_empty():
		var gp: Vector2 = away + Vector2(0, 120)
		out.append({"name": "bombard", "do": func() -> void: g.bombard_order(guns, gp), "us": guns,
			"react": func() -> bool: return g._pings.any(func(pg: Array) -> bool: return (pg[0] as Vector2).distance_to(g.on_map(gp)) < 4.0)})
		out.append({"name": "gun_stop", "do": func() -> void: g.command_all(guns, "stop"), "us": guns, "react": func() -> bool: return _standing(guns)})
		var gun: Unit = guns[0]
		out.append({"name": "deploy", "do": func() -> void: gun.cmd_deploy(), "react": func() -> bool: return gun.tesla_mode != "packed",
			"then": func() -> bool: return gun.tesla_mode != "packed"})
		out.append({"name": "pack", "ready": func() -> bool: return gun.tesla_mode == "deployed", "do": func() -> void: gun.cmd_pack(),
			"react": func() -> bool: return gun.tesla_mode != "deployed"})
	# the others that set up (the Spore Mother roots, the Tesla Cart deploys) and a spell (the Mist Toad's FOG): the host
	# puts them by this side's hall when asked (after the entity count check: some of them count apart)
	var extra: Array = {"brood": ["spore_mother", "mist_toad"], "clockwork": ["tesla_cart"]}.get(g.faction_of(g.human), [])
	for k in extra:
		if not ["spore_mother", "tesla_cart"].has(k):
			continue
		out.append({"name": "deploy_" + k, "ready": func() -> bool: return _extra_unit(k) != null, "pre": func() -> void: base["du"] = _extra_unit(k),
			"do": func() -> void: (base["du"] as Unit).cmd_deploy(), "react": func() -> bool: return (base["du"] as Unit).tesla_mode != "packed",
			"then": func() -> bool: return (base["du"] as Unit).tesla_mode != "packed"})
		out.append({"name": "pack_" + k, "ready": func() -> bool: return (base["du"] as Unit).tesla_mode == "deployed", "do": func() -> void: (base["du"] as Unit).cmd_pack(),
			"react": func() -> bool: return (base["du"] as Unit).tesla_mode != "deployed"})
	if extra.has("mist_toad"):
		out.append({"name": "cast_fog", "ready": func() -> bool: return _extra_unit("mist_toad") != null, "pre": func() -> void:
				var td: Unit = _extra_unit("mist_toad")
				base["td"] = td
				base["fp"] = td.position + Vector2(380, 0)
				if g.spell_problem(td, "fog") != "":
					_ord["cant"] = true,           # (no energy yet: the host only says so; nothing to show)
			"do": func() -> void: g.cast_order([base["td"]], "fog", base["fp"]),
			"react": func() -> bool:
				var td: Unit = base["td"]
				return _ord.has("cant") or (_turned([td], base["fp"]) and (td.velocity.length() > 10.0 or td.order == "cast"))})
	if hall:
		var rp: Vector2 = away + Vector2(30, 30)
		out.append({"name": "rally", "do": func() -> void: g.set_rally(hall, rp),
			"then": func() -> bool: return hall.rally != Vector2.INF, "react": func() -> bool: return hall.rally.distance_to(g.on_map(rp)) < 2.0})
		if hall.dual_rally():
			var wp: Vector2 = here + Vector2(-90, 60)
			out.append({"name": "worker_rally", "do": func() -> void: g.set_rally(hall, wp, "worker"),
				"react": func() -> bool: return hall.worker_rally.distance_to(g.on_map(wp)) < 2.0})
		var wcost := int(g.unit_price(g.human, wk)[0])
		out.append({"name": "train", "do": func() -> void: g.train_any([hall], wk), "qb": hall, "cost": wcost, "react": _queue_grew(hall)})
		out.append({"name": "cancel_train", "do": func() -> void: g.cancel_train(hall), "qb": hall, "react": _queue_shrank(hall), "refund": true})
		out.append({"name": "train_two", "do": func() -> void:
			g.train_any([hall], wk)
			g.train_any([hall], wk), "qb": hall, "cost": wcost, "react": _queue_grew(hall)})
		out.append({"name": "cancel_train_at", "ready": func() -> bool: return hall.queue.size() >= 2, "do": func() -> void: g.cancel_train_at(hall, 1),
			"qb": hall, "react": _queue_shrank(hall), "refund": true})
		out.append({"name": "auto_train", "do": func() -> void: g.net_set(hall, "auto_train", wk), "react": func() -> bool: return String(hall.auto_train) == wk})
		out.append({"name": "auto_train_off", "do": func() -> void: g.net_set(hall, "auto_train", ""), "react": func() -> bool: return String(hall.auto_train) == ""})
		# research, where this side has something to research now
		for b in g.buildings:
			if b.team != g.human or b.dead or not b.built:
				continue
			var rk := ""
			for k in Defs.RESEARCH:
				if g.research_problem(b, k) == "":
					rk = k
					break
			if rk != "":
				var rb: Building = b
				out.append({"name": "research", "do": func() -> void: g.start_research(rb, rk), "qb": rb, "cost": int(Defs.RESEARCH[rk]["cost"]), "react": _queue_grew(rb)})
				out.append({"name": "cancel_research", "do": func() -> void: g.cancel_train(rb), "qb": rb, "react": _queue_shrank(rb), "refund": true})
				break
	if hall:
		# (refused or not by what this side holds when it is given: the orders before spend)
		out.append({"name": "hall_upgrade", "pre": func() -> void:
				var why := g.hall_upgrade_problem(hall)
				if why != "":
					_ord["expect"] = why,
			"do": func() -> void: g.start_hall_upgrade(hall)})
	if not workers.is_empty():
		var mine: Entity = null
		for b in g.buildings:
			if b.team == g.human and not b.dead and b.built and b.crew_max() > 0:
				if mine == null or b.position.distance_to(here) < mine.position.distance_to(here):
					mine = b
		if mine:
			# (the worker is picked when the order is given: the list is made seconds before, and the worker sent to
			# attack the ground at the body may be gone by then)
			out.append({"name": "gather", "do": func() -> void:
				var ws: Array = _mine().filter(func(u: Unit) -> bool: return u.is_worker() and is_instance_valid(u) and u.order != "build")
				if not ws.is_empty():
					base["gather_w"] = ws[0]
					(ws[0] as Unit).cmd_gather(mine), "us": [], "react": func() -> bool:
						var w = base.get("gather_w")
						if not is_instance_valid(w):
							return false
						var near: Vector2 = (w as Unit).position.clamp((mine as Building).rect().position, (mine as Building).rect().end)      # (it heads for the nearest edge)
						if near.distance_to((w as Unit).position) < 2.0:
							return true
						return _turned([w], near) and ((w as Unit).velocity.length() > 10.0 or mine.edge_distance((w as Unit).position) < 24.0)})
		# a building site: it shows at once (pending), the worker heads for it; then it is abandoned (cost back)
		var sk: String = Defs.supply_kind(g.faction_of(g.human))
		out.append({"name": "place", "ready": func() -> bool: return _free_spot(sk).x >= 0 and int(g.players[g.human]["gold"]) >= int(Defs.BUILDINGS[sk]["cost"]),
			"pre": func() -> void: base["site_at"] = _free_spot(sk),
			"do": func() -> void: g.place_building(g.human, sk, base["site_at"], _mine().filter(func(u: Unit) -> bool: return u.is_worker()).slice(0, 2), false),
			"cost": int(Defs.BUILDINGS[sk]["cost"]), "react": func() -> bool:
				if _site_at(sk, base["site_at"]) != null:
					base["site_seen"] = true      # (the host's site: a grub that turns into it may swap it for a moment)
				return not p.sites().is_empty() or _site_at(sk, base["site_at"]) != null,
			"then": func() -> bool: return (_site_at(sk, base["site_at"]) != null or base.get("site_seen", false)) and p.sites().is_empty()})
		out.append({"name": "abandon", "ready": func() -> bool: return _site_at(sk, base.get("site_at", Vector2i(-1, -1))) != null,
			"pre": func() -> void: base["site_b"] = _site_at(sk, base["site_at"]),
			"do": func() -> void: g.abandon(base["site_b"]), "refund": true,
			"react": func() -> bool: return not is_instance_valid(base["site_b"]) or (base["site_b"] as Building).dead or (base["site_b"] as Building).modulate.a < 0.3})
		# refused on purpose (the host has drained this side's gold; this screen is told it has plenty): the click shows the
		# site / the queue item at once, then the host's refusal takes it back with its reason, and nothing is left over
		var res_word := "Not enough %s." % String(Defs.FACTIONS[g.faction_of(g.human)]["res"][0]).to_lower()
		out.append({"name": "place_refused", "expect": res_word, "ready": func() -> bool: return _drain_ready(), "pre": func() -> void:
				base["site_at2"] = _free_spot(sk)
				_cheat_gold(),
			"do": func() -> void: g.place_building(g.human, sk, base["site_at2"], _mine().filter(func(u: Unit) -> bool: return u.is_worker()).slice(0, 1), false),
			"react": func() -> bool: return not p.sites().is_empty(),
			"then": func() -> bool: return p.sites().is_empty() and p.pending() == 0 and _site_at(sk, base["site_at2"]) == null})
		out.append({"name": "train_refused", "expect": res_word, "ready": func() -> bool: return _drain_ready(), "pre": func() -> void:
				base["q_was"] = hall.queue.size()
				_cheat_gold(),
			"do": func() -> void: g.train_any([hall], wk), "qb": hall, "react": _queue_grew(hall),
			"then": func() -> bool:
				g.chat.post(g.human, "test: refill")
				return p.pending() == 0 and hall.queue.size() == int(base["q_was"])})
	# last: pull down one of its own buildings (not the hall)
	for b in g.buildings:
		if b.team == g.human and not b.dead and b != hall and b.kind != "mine" and b.built:
			var bb: Building = b
			out.append({"name": "demolish", "do": func() -> void: g.demolish(bb), "then": func() -> bool: return true,
				"react": func() -> bool: return bb.dead or not is_instance_valid(bb) or bb.modulate.a < 0.9})
			break
	return out


# ------------------------------------------------------------------ guest: the click's reaction, timed

## Walking on screen (the walk shown: its speed), any of them.
func _walking(us: Array) -> bool:
	return us.any(func(u) -> bool: return is_instance_valid(u) and (u as Unit).velocity.length() > 10.0)


## Standing on screen, all of them.
func _standing(us: Array) -> bool:
	return us.all(func(u) -> bool: return not is_instance_valid(u) or (u as Unit).velocity.length() < 1.0)


## Turned toward p (within 30 degrees), all of them.
func _turned(us: Array, p: Vector2) -> bool:
	return us.all(func(u) -> bool: return not is_instance_valid(u) or (u as Unit).facing.dot((p - (u as Unit).position).normalized()) > 0.86)


func _queue_grew(b: Building) -> Callable:
	return func() -> bool: return is_instance_valid(b) and NetPredict.shown_queue(g, b)[0].size() > int(_ord.get("qn0", 99))


func _queue_shrank(b: Building) -> Callable:
	return func() -> bool: return is_instance_valid(b) and NetPredict.shown_queue(g, b)[0].size() < int(_ord.get("qn0", 0))


## Before the order: units walking somewhere (so a stop or hold has something to stop).
func _walk_first(us: Array, to: Vector2) -> void:
	g.group_move(us, to, false)


func _free_spot(k: String) -> Vector2i:
	var hall: Building = base["hall"]
	for r in range(5, 16):
		for a in 24:
			var c := hall.cell + Vector2i(Vector2.from_angle(TAU * a / 24.0 + 0.13) * r)
			if g.in_map(c) and g.placement_problem(g.human, k, c) == "":
				return c
	return Vector2i(-1, -1)


func _site_at(k: String, c: Vector2i) -> Building:
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == k and b.cell == c:
			return b
	return null


## A unit of kind k of this side, asked of the host in the chat the first time (it puts one by the hall).
func _extra_unit(k: String) -> Unit:
	if not base.has("extra_asked"):
		base["extra_asked"] = true
		g.chat.post(g.human, "test: extras")
	for u in _mine():
		if u.kind == k:
			return u
	return null


## The host's hold-fire Musketeer near this side's hall (it puts it there when asked in the chat).
func _dummy() -> Unit:
	if not base.has("dummy_asked"):
		base["dummy_asked"] = true
		g.chat.post(g.human, "test: dummy")
	for u in g.units:
		if u.team == 0 and not u.dead and u.visible and u.position.distance_to((base["hall"] as Building).center()) < 600.0:
			return u
	return null


## The host holds this side's gold at 0 (asked in the chat): true once the pictures show it.
func _drain_ready() -> bool:
	if not base.has("drain_asked"):
		base["drain_asked"] = true
		g.chat.post(g.human, "test: drain")
	return int(g.players[g.human]["gold"]) == 0


## This screen believes it has plenty (until the next picture): its click is shown, the host refuses it.
func _cheat_gold() -> void:
	g.players[g.human]["gold"] = 100000


func _watch_begin() -> void:
	_ord["t0"] = Time.get_ticks_usec()
	_ord["last"] = {}
	_ord["jumps"] = 0
	_ord["flick"] = 0
	_ord["back"] = 0
	_ord["gold0"] = int(NetPredict.shown_player(g, g.human)["gold"])
	for u in _ord.get("us", []):
		if is_instance_valid(u):
			_ord["last"][u] = (u as Unit).position
	if _ord.has("qb") and is_instance_valid(_ord["qb"]):
		_ord["qn0"] = NetPredict.shown_queue(g, _ord["qb"])[0].size()
		_ord["qn"] = _ord["qn0"]
		_ord["qdir"] = 0


func _watch_order() -> void:
	var ms := (Time.get_ticks_usec() - int(_ord["t0"])) / 1000.0
	if ms > 2500.0:
		return
	if _ord.has("react"):
		var r: bool = (_ord["react"] as Callable).call()
		if r and not _ord.has("rms"):
			_ord["rms"] = ms
		if _ord.has("rms") and not r and bool(_ord.get("rwas", false)) and not _ord.has("expect") and not _ord.has("us"):
			_ord["flick"] = int(_ord["flick"]) + 1          # (it showed, then went back: a flicker)
		_ord["rwas"] = r
	# (units move on the game's 30 ticks a second, the screen shows them between: a step is measured against the ticks)
	var pf := Engine.get_physics_frames()
	var dt := maxf(float(pf - int(_ord.get("wpf", pf - 1))), 1.0) / float(Engine.physics_ticks_per_second)
	_ord["wpf"] = pf
	for u in _ord["last"]:
		if not is_instance_valid(u) or (u as Unit).dead:
			continue
		var step_px := ((u as Unit).position - (_ord["last"][u] as Vector2)).length()
		if step_px > (u as Unit).speed * dt * 2.0 + 3.0:
			_ord["jumps"] = int(_ord["jumps"]) + 1
		if _ord.has("rms") and _ord.has("warm"):
			# (a stop: how far it is shown to move on after it stood still, the furthest of them)
			if not _ord.has("stood"):
				_ord["stood"] = {}
			if not (_ord["stood"] as Dictionary).has(u):
				_ord["stood"][u] = (u as Unit).position
			_ord["after"] = maxf(float(_ord.get("after", 0.0)), ((u as Unit).position - (_ord["stood"][u] as Vector2)).length())
		_ord["last"][u] = (u as Unit).position
	if _ord.has("qb") and is_instance_valid(_ord["qb"]):
		var n: int = NetPredict.shown_queue(g, _ord["qb"])[0].size()
		if n != int(_ord["qn"]):
			var d := signi(n - int(_ord["qn"]))
			if int(_ord["qdir"]) != 0 and d != int(_ord["qdir"]) and not _ord.has("expect"):
				_ord["flick"] = int(_ord["flick"]) + 1          # (it went one way, then back: a flicker)
			_ord["qdir"] = d
			_ord["qn"] = n
	var gold := int(NetPredict.shown_player(g, g.human)["gold"])
	if int(_ord.get("cost", 0)) > 0 and not _ord.get("refund", false) and not _ord.has("expect") \
			and gold - int(_ord.get("glast", _ord["gold0"])) >= int(_ord["cost"]) * 0.8:
		_ord["back"] = int(_ord["back"]) + 1                 # (what it cost came back, then went again: a jump)
	_ord["glast"] = gold


func _watch_end() -> void:
	if not _ord.has("react"):
		return
	var ms: float = float(_ord.get("rms", -1.0))
	react_rows.append([String(_ord["name"]), ms, int(_ord["jumps"]), int(_ord["flick"]), int(_ord["back"])])
	print("LAG GUEST REACT %s: %s | unit jumps %d, flickers %d, resources back %d%s" % [String(_ord["name"]), ("%.0f ms" % ms) if ms >= 0.0 else "none in 2.5 s",
		int(_ord["jumps"]), int(_ord["flick"]), int(_ord["back"]), (", closes up %.0f px after the stop" % float(_ord.get("after", 0.0))) if _ord.has("warm") else ""])


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


const BODY_OFF := Vector2(0, 110)


func _start_ground(s: NetSession) -> void:
	var hall: Building = base["hall"]
	var want: Vector2 = hall.center() + BODY_OFF
	var body: Unit = null
	for b in g.bodies:
		if Game.lying(b) and b.position.distance_to(want) < 90.0:
			body = b
	var w: Unit = null
	for u in _mine():
		if u.can_ground_attack() and u.order != "build" and (w == null or u.position.distance_to(want) < w.position.distance_to(want)):
			w = u
	if body and w:
		base["body"] = body
		print("GUEST orders worker %d to attack the ground at the body (%.0f health)" % [w.net_id, body.body_left()])
		g.ground_order([w], PackedVector2Array([body.position]))
	step = 7
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
