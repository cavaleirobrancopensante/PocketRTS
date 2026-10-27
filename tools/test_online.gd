extends SceneTree
## Online play, end to end on one computer: a HOST and a GUEST process through a relay.
##   node tools/relay/local_relay.mjs 8799 &
##   godot --headless --script res://tools/test_online.gd -- role:host  relay:ws://127.0.0.1:8799 code:TEST
##   godot --headless --script res://tools/test_online.gd -- role:guest relay:ws://127.0.0.1:8799 code:TEST
## (tools/test_online.sh runs all three and checks the CHECK lines.) The guest joins by code, the host
## starts, and then the guest plays: it moves a worker, trains a unit, places a building and tries to
## order one of the host's units (refused). Snapshots must show every effect on the guest.
## Extra args: coop (two humans vs a computer), fac_host:<faction>, fac_guest:<faction>, map:<id>, secs:<n>.
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
				print("GUEST_RESULT snaps=%d interval=%.3f cmds=%d cmd_rtt=%.0f ms ping=%.0f ms recv=%d bytes (%.1f KB/s)" % [s.snaps_got, s.interval, s.cmd_seq, s.cmd_rtt_ms, s.link.rtt_ms, s.link.recv_bytes, s.link.recv_bytes / 1024.0 / maxf(t, 1.0)])
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
	var k: String = Defs.FACTIONS[f]["supply"]
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
