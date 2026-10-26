extends SceneTree
## Online snapshots, before and after (docs/online_lag_study.md). Two Hard computers play; from each checkpoint
## (game seconds) for `window` seconds, every 0.1 s of game time a snapshot is built the new way (NetSnapshot: direct
## reads, only what changed, zstd) and, with old:<path to the 0.14.27 net_snapshot.gd>, the old way too (every row read
## by name, deflate); each is packed, unpacked and applied to a puppet game of its own, as a guest would, and timed.
## The new puppet is then compared with the host, entity by entity (the delta snapshots must leave it the same).
## spawn:N adds N Musketeers and N Raptors at the first checkpoint, half of them sent across the map every 4 s (a big
## battle's worth of rows: the cost as the unit count grows).
##   godot --headless --fixed-fps 30 --script res://tools/bench_net_snapshot.gd -- at:180,420,720 window:10 [old:/abs/old.gd] [spawn:100]
var main: Node
var t := 0.0
var g: Game
var map := "hollowfen"
var at: Array = [180.0, 420.0, 720.0]
var window := 10.0
var old_path := ""
var old_s = null                 # the old snapshot code (a script), or null
var hs_new: NetSession           # host sessions (they read the host game)
var hs_old: NetSession
var gs_new: NetSession           # guest sessions (on the puppets)
var gs_old: NetSession
var pg_new: Game
var pg_old: Game
var stage := 0                   # checkpoint being measured
var t0 := 0.0
var frames := 0
var acc := {}
var spawn := 0
var spawned: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("at:"):
			at = Array(a.substr(3).split(",")).map(func(x: String) -> float: return float(x))
		elif a.begins_with("window:"):
			window = float(a.substr(7))
		elif a.begins_with("old:"):
			old_path = a.substr(4)
		elif a.begins_with("spawn:"):
			spawn = int(a.substr(6))
	if old_path != "":
		old_s = load(old_path)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if stage >= at.size() or g.over:
		_report_all()
		quit(0)
		return false
	if g.clock < float(at[stage]):
		return false
	if pg_new == null:
		_setup()
		_spawn()
	frames += 1
	if spawn > 0 and frames % 120 == 0:
		_march()
	if frames % 3 == 0:              # (a snapshot every 0.1 s of game time, as online)
		_one()
	if g.clock >= float(at[stage]) + window:
		_report()
		stage += 1
		acc = {}
	return false


func _puppet() -> Game:
	var p := Game.new()
	p.puppet = true
	p.human = 1
	p.factions = g.factions.duplicate()
	p.colours = g.colours.duplicate()
	p.sides = g.sides.duplicate()
	p.income_mult = g.income_mult.duplicate()
	p.map_id = g.map_id
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.rng.seed = 4242
	root.add_child(p)
	return p


func _session(game: Game, host: bool) -> NetSession:
	var s := NetSession.new()
	s.game = game
	s.is_host = host
	s.go_given = true
	s._m_reset()
	return s


func _setup() -> void:
	hs_new = _session(g, true)
	pg_new = _puppet()
	gs_new = _session(pg_new, false)
	pg_new.net = gs_new
	if old_s:
		hs_old = _session(g, true)
		pg_old = _puppet()
		gs_old = _session(pg_old, false)
		pg_old.net = gs_old


func _spawn() -> void:
	if spawn <= 0:
		return
	for tm in 2:
		var hall: Building = null
		for b in g.buildings:
			if b.team == tm and b.kind == g.faction_hall(tm):
				hall = b
		var c: Vector2 = hall.center() if hall else Vector2(Game.W, Game.H) * Game.T * 0.5
		for i in spawn:
			var k := "musketeer" if g.faction_of(tm) == "crown" else ("raptor" if g.faction_of(tm) == "brood" else "windup_soldier")
			var cell := g.nearest_free(g.cell_of(c + Vector2.from_angle(randf() * TAU) * randf_range(80, 400)), 12)
			spawned.append(g._add_unit(k, tm, g.cell_center(cell)))


## Half the added soldiers walk somewhere else (the rest stand or fight where they are).
func _march() -> void:
	for u in spawned:
		if is_instance_valid(u) and not u.dead and randf() < 0.5:
			var to := g.cell_center(g.nearest_free(g.cell_of(u.position + Vector2.from_angle(randf() * TAU) * 300.0), 10))
			u.give({"o": "move", "p": to})


func _add(k: String, v: float) -> void:
	if not acc.has(k):
		acc[k] = [0.0, 0.0, 0]
	acc[k][0] += v
	acc[k][1] = maxf(acc[k][1], v)
	acc[k][2] += 1


func _us(since: int) -> float:
	return (Time.get_ticks_usec() - since) / 1000.0


func _one() -> void:
	# new
	if old_s:
		hs_new.next_id = maxi(hs_new.next_id, hs_old.next_id)      # (both number the same entities)
	hs_new.snap_n += 1
	var a := Time.get_ticks_usec()
	var m := NetSnapshot.build(hs_new)
	_add("new build", _us(a))
	a = Time.get_ticks_usec()
	var pk := NetCodec.pack(m)
	_add("new pack", _us(a))
	_add("new bytes", pk.size())
	a = Time.get_ticks_usec()
	var m2 := NetCodec.unpack(pk)
	_add("new unpack", _us(a))
	a = Time.get_ticks_usec()
	NetSnapshot.apply(gs_new, m2)
	_add("new apply", _us(a))
	_add("rows sent", (m.get("u", []) as Array).size() + (m.get("b", []) as Array).size())
	if not old_s:
		return
	hs_old.next_id = maxi(hs_old.next_id, hs_new.next_id)
	hs_old.snap_n += 1
	a = Time.get_ticks_usec()
	var mo: Dictionary = old_s.build(hs_old)
	_add("old build", _us(a))
	a = Time.get_ticks_usec()
	var raw := var_to_bytes(mo)
	var z := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	_add("old pack", _us(a))
	_add("old bytes", z.size() + 5)
	a = Time.get_ticks_usec()
	var mo2: Dictionary = bytes_to_var(z.decompress(raw.size(), FileAccess.COMPRESSION_DEFLATE))
	_add("old unpack", _us(a))
	a = Time.get_ticks_usec()
	old_s.apply(gs_old, mo2)
	_add("old apply", _us(a))


## The new puppet against the host: every live entity there, with the same kind, team, health, order, building
## progress and (where its glide is heading) position.
func _compare() -> Dictionary:
	var out := {"entities": 0, "missing": 0, "extra": 0, "kind/team": 0, "hp": 0, "order": 0, "pos": 0, "built": 0}
	var live := {}
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.net_id != 0:
			live[u.net_id] = u
	for b in g.buildings:
		if is_instance_valid(b) and b.net_id != 0:
			live[b.net_id] = b
	out["entities"] = live.size()
	for id in live:
		var e = live[id]
		var p = gs_new.by_id.get(id)
		if not is_instance_valid(p):
			out["missing"] += 1
			continue
		if p.kind != e.kind or p.team != e.team:
			out["kind/team"] += 1
		if absf(p.hp - snappedf(e.hp, 0.1)) > 0.11:
			out["hp"] += 1
		if e is Unit:
			if p.order != e.order:
				out["order"] += 1
			var mo = gs_new.motion.get(id)
			var to: Vector2 = mo[1] if mo != null else p.position
			if to.distance_to(e.position) > 0.5:
				out["pos"] += 1
		elif p.built != e.built or absf(p.progress - snappedf(e.progress, 0.01)) > 0.011:
			out["built"] += 1
	for id in gs_new.by_id:
		if not live.has(id):
			out["extra"] += 1
	return out


func _report() -> void:
	print("BENCH --- %.0f s: %d units, %d buildings (%d snapshots)" % [g.clock, g.units.size(), g.buildings.size(), int(acc.get("new build", [0, 0, 0])[2])])
	var keys := acc.keys()
	keys.sort()
	for k in keys:
		var v: Array = acc[k]
		print("BENCH %-12s avg %8.2f  max %8.2f" % [k, v[0] / maxi(v[2], 1), v[1]])
	# (compared right after a snapshot: the last one applied is the host as it is now)
	hs_new.next_id = maxi(hs_new.next_id, hs_old.next_id if old_s else 0)
	hs_new.snap_n += 1
	NetSnapshot.apply(gs_new, NetCodec.unpack(NetCodec.pack(NetSnapshot.build(hs_new))))
	print("BENCH new puppet vs host: %s" % str(_compare()))
	var u: Unit = null
	var b: Building = null
	for x in g.units:
		if is_instance_valid(x) and not x.dead:
			u = x
			break
	for x in g.buildings:
		if is_instance_valid(x):
			b = x
			break
	var lists := NetSnapshot.check_lists(u, b)
	print("BENCH direct readers vs the lists: %s" % ("same" if lists == "" else lists))
	_parts()


func _report_all() -> void:
	print("BENCH done")


## Where a unit's row goes (the host's build, part by part), over every unit, 20 times.
func _parts() -> void:
	var us: Array = g.units.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead)
	var parts := {}
	var reps := 20
	for r in reps:
		var a := Time.get_ticks_usec()
		for u in us:
			NetSnapshot.unit_vals(u)
		parts["unit_vals"] = parts.get("unit_vals", 0.0) + _us(a)
		a = Time.get_ticks_usec()
		for u in us:
			NetSnapshot.ref(hs_new, u.target)
			NetSnapshot.ref(hs_new, u.home_mine)
			NetSnapshot.ref(hs_new, u.leader)
			NetSnapshot.ref(hs_new, u.aboard)
			NetSnapshot.ref(hs_new, u.order_target)
		parts["5 refs"] = parts.get("5 refs", 0.0) + _us(a)
		a = Time.get_ticks_usec()
		for u in us:
			var sl := NetSnapshot.unit_vals(u)
			hash(sl)
		parts["vals+hash"] = parts.get("vals+hash", 0.0) + _us(a)
		a = Time.get_ticks_usec()
		for u in us:
			var fast: Array = [u.position.snapped(Vector2(0.25, 0.25)), snappedf(u.hp, 0.1), snappedf(u.facing.angle(), 0.02)]
			var same: bool = hs_new.sent_fast.get(u.net_id) == fast
		parts["fast+compare"] = parts.get("fast+compare", 0.0) + _us(a)
		a = Time.get_ticks_usec()
		for u in us:
			u.cooldown > 0.0
			u.passengers.size()
			is_instance_valid(u)
			u.is_queued_for_deletion()
		parts["misc"] = parts.get("misc", 0.0) + _us(a)
		a = Time.get_ticks_usec()
		hs_new.snap_n += 1
		NetSnapshot.build(hs_new)
		parts["whole build"] = parts.get("whole build", 0.0) + _us(a)
	for k in parts:
		print("BENCH part %-14s %.2f ms for %d units (%.1f us each)" % [k, parts[k] / reps, us.size(), parts[k] / reps * 1000.0 / maxi(us.size(), 1)])
