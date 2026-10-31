extends SceneTree
## The online match of 2026-10-31 (docs/playtests/online_2026-10-31_brood_v_clockwork.txt, 0.24.34: a Brood guest v a
## Clockwork host), its four problems, checked in one process: a host game (two Hard computers, Clockwork v Brood on
## Twin Fords) and a guest's puppet game fed with its snapshots (as tools/bench_net_snapshot.gd), the guest playing the
## Brood. Then single player: a Clockwork human placing several buildings with Shift.
##   godot --headless --fixed-fps 30 --script res://tools/test_online_fix.gd [-- secs:300]
## 1. the guest's copy must never drop the host's sites (it used to run the "nobody is coming" sweep on its puppets,
##    where an enemy's Winder out of sight and every worker's Shift queue are unknown: 108 "dropped" lines);
##    a host site a worker is ordered to (now or Shift-queued) is kept, and a fresh one has a grace period.
## 2. the guest's overlay: its cost per second on the puppet (it was 160-390 ms/s).
## 3. the Rootmaws' ground (Game.nb_spots) reaches the guest.
## 4. every order the game forwards online has a path on the host (NetCommands.GAME / ENTITY / PROPS).
var main: Node
var t := 0.0
var g: Game
var pg: Game
var hs: NetSession
var gs: NetSession
var secs := 300.0
var frames := 0
var fails := 0
var lost_sites := 0          # host ghosts alive on the host but dropped on the guest
var checked_sites := 0
var spots_seen := 0
var spots_off := 0
var ov_us := 0
var ov_n := 0
var ov_secs := 0.0
var stage := 0
var _ov_hooked := false
var _ov_a := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs:"):
			secs = float(a.substr(5))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if stage == 0:
		if t > 0.2 and main.game == null:
			main.start({"map": "twin_fords", "seed": 2053137776, "slots": [
				{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
			return false
		if main.game == null:
			return false
		g = main.game
		paused = false
		if pg == null:
			_setup()
		frames += 1
		if frames % 2 == 0:
			_snap()
		if frames % 30 == 0:
			_compare()
		if g.clock >= secs or g.over:
			_online_report()
			stage = 1
			_single_player.call_deferred()
		return false
	return stage == 9


func _setup() -> void:
	hs = NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.go_given = true
	hs.link = NetLink.new()
	hs._m_reset()
	hs.peer_team = {99: 1}                # (the guest plays team 1: enemies it can't see are left out, as online)
	pg = Game.new()
	pg.puppet = true
	pg.human = 1
	pg.factions = g.factions.duplicate()
	pg.colours = g.colours.duplicate()
	pg.sides = g.sides.duplicate()
	pg.income_mult = g.income_mult.duplicate()
	pg.map_id = g.map_id
	pg.rng.seed = 2053137776
	root.add_child(pg)
	gs = NetSession.new()
	gs.game = pg
	gs.is_host = false
	gs.go_given = true
	gs.link = NetLink.new()
	gs._m_reset()
	pg.net = gs


func _snap() -> void:
	hs.snap_n += 1
	var m := NetSnapshot.build(hs)
	NetSnapshot.apply(gs, NetCodec.unpack(NetCodec.pack(m)))
	# the guest's overlay, drawn as its screen would (the puppet's own tick asks for it), with the Mother selected
	if g.clock > 30.0 and pg.selection.is_empty():
		var q := BroodNew.queen(pg, 1)
		if q:
			pg.selection = [q]
			pg.camera.position = q.position          # (the guest looks at its base, as a player does)
			pg.camera.zoom = Vector2(0.8, 0.8)
	if not _ov_hooked and pg.overlay:
		_ov_hooked = true
		pg.overlay.draw.disconnect(pg._draw_overlay)
		pg.overlay.draw.connect(func() -> void: _ov_a = Time.get_ticks_usec())
		pg.overlay.draw.connect(pg._draw_overlay)
		pg.overlay.draw.connect(func() -> void:
			if g.clock > 30.0:
				ov_us += Time.get_ticks_usec() - _ov_a
				ov_n += 1)


func _compare() -> void:
	for b in g.buildings:
		if b.dead or not b.ghost or b.net_id == 0 or b.team != 0:
			continue
		if g.clock - b.placed_clk < 2.0:
			continue                                # (just placed: the next snapshot brings it)
		checked_sites += 1
		var p = gs.by_id.get(b.net_id)
		if not is_instance_valid(p) or p.dead or not pg.buildings.has(p):
			lost_sites += 1
	for id in g.nb_spots:
		spots_seen += 1
		var s: Dictionary = g.nb_spots[id]
		var ps = pg.nb_spots.get(id)
		if ps == null or absf(float(ps["left"]) - float(s["left"])) > 2.0:
			spots_off += 1


func _online_report() -> void:
	print("INFO host %.0f s: %d units, %d buildings; host ghosts looked at %d" % [g.clock, g.units.size(), g.buildings.size(), checked_sites])
	check("1 the guest never drops the host's sites", lost_sites == 0 and checked_sites > 0, "(%d of %d lost)" % [lost_sites, checked_sites])
	var per := ov_us / 1000.0 / maxi(ov_n, 1)
	var per_s := ov_us / 1000.0 / maxf(g.clock - 30.0, 1.0)
	var rate := ov_n / maxf(g.clock - 30.0, 1.0)
	# (the Mother selected all along: her father's ring used to redraw the overlay every tick, 30 a second)
	check("2 the guest's overlay is redrawn on change, not every tick", rate < 10.0, "(%.1f draws/s, %.2f ms a draw, %.1f ms/s here)" % [rate, per, per_s])
	check("3 the Rootmaws' ground reaches the guest", spots_seen > 0 and spots_off <= spots_seen / 20, "(%d off of %d)" % [spots_off, spots_seen])
	var ml := 0
	for u in pg.units:
		if u.kind == BroodNew.MAW and BroodNew.rooted(u) and u.team == 1:
			ml += 1
			if BroodNew.ground_left(pg, u) <= 0.0 and BroodNew.ground_left(g, gs_host(u)) > 0.0:
				check("3 a rooted Rootmaw's ground on the guest", false, "(0 there)")
	print("INFO rooted Rootmaws on the guest: %d" % ml)
	_orders_check()


func gs_host(u: Unit) -> Unit:
	for x in g.units:
		if x.net_id == u.net_id:
			return x
	return u


## Every order forwarded online (Game.net_forward(..., "fn", ...) and net_set props in scripts/) has a path on the host.
func _orders_check() -> void:
	var missing: Array = []
	var re := RegEx.create_from_string("net_forward\\([a-zA-Z_.]+, *\"([a-z_]+)\"")
	var re2 := RegEx.create_from_string("net_set\\([^,]+, *\"([a-z_]+)\"")
	for f in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			var fn := m.get_string(1)
			if not NetCommands.GAME.has(fn) and not NetCommands.ENTITY.has(fn):
				missing.append(fn)
		for m in re2.search_all(src):
			if not NetCommands.PROPS.has(m.get_string(1)):
				missing.append("@" + m.get_string(1))
	check("4 every forwarded order has an online path", missing.is_empty(), str(missing))


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out


# ------------------------------------------------------------------ single player: a Clockwork human, Shift

func _single_player() -> void:
	pg.process_mode = Node.PROCESS_MODE_DISABLED
	main.game.process_mode = Node.PROCESS_MODE_DISABLED      # (left in place: the cursor code reads main.game)
	await process_frame
	var s := Game.new()
	s.map_id = "twin_fords"
	s.factions = ["clockwork", "brood"]
	s.sides = [0, 1]
	s.human = 0
	root.add_child(s)
	await process_frame
	await process_frame
	s.players[0]["gold"] = 99999
	s.add_tension(0, 9999.0)
	var winders: Array = s.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.is_worker())
	var hall: Building = null
	for b in s.buildings:
		if b.team == 0 and b.kind == s.faction_hall(0):
			hall = b
	var w: Unit = winders[0]
	var placed: Array = []
	var kinds := ["regulator", "regulator", Defs.GEAR_PRESS, "regulator", "regulator"]
	var c0 := s.cell_of(hall.center())
	for k in kinds:
		var c := _spot(s, k, c0)
		if c.x < 0:
			continue
		var b := s.place_building(0, k, c, [w], true)
		if b:
			placed.append(b)
	print("INFO single player: %d sites Shift-queued on one Winder (queue %d)" % [placed.size(), w.queue.size()])
	for i in 60:
		s._physics_process(1.0 / 30.0)
		for u in s.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		if i % 8 == 0:
			await process_frame
	var gone := placed.filter(func(b: Building) -> bool: return b.dead)
	check("1 single player: Shift-queued sites of one Winder all kept", placed.size() >= 4 and gone.is_empty(), "(%d of %d gone)" % [gone.size(), placed.size()])
	# a fresh site nobody is ordered to yet (a delayed order on its way): kept for its grace period, then dropped
	var c2 := _spot(s, "regulator", c0 + Vector2i(6, 6))
	var lone := s.place_building(0, "regulator", c2, [])
	var kept := true
	for i in 6:
		s._physics_process(1.0 / 30.0)
		if lone == null or lone.dead:
			kept = false
	check("1 a fresh site waits a moment for its builder (0.25 s)", lone != null and kept)
	if lone and not lone.dead:
		w.give({"o": "build", "e": lone}, true)
		for i in 150:
			s._physics_process(1.0 / 30.0)
		check("1 ... and is kept once its order comes", not lone.dead)
	var lone2 := s.place_building(0, "regulator", _spot(s, "regulator", c0 + Vector2i(-6, 6)), [])
	for i in 200:
		s._physics_process(1.0 / 30.0)
	check("1 a site nobody ever comes to still goes", lone2 == null or lone2.dead)
	print("RESULT %s" % ("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails))
	stage = 9
	quit(1 if fails > 0 else 0)


func _spot(s: Game, k: String, c0: Vector2i) -> Vector2i:
	for r in range(4, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if s.placement_problem(0, k, c) == "":
					var taken := false
					for b in s.buildings:
						if not b.dead and b.rect().grow(Game.T * 1.0).intersects(Rect2(Vector2(c) * Game.T, Vector2(Defs.BUILDINGS[k]["size"]) * Game.T)):
							taken = true
							break
					if not taken:
						return c
	return Vector2i(-1, -1)
