extends SceneTree
## The owner's online notes of 2026-10-31 (a Brood guest in Ireland v a Clockwork host in Brazil, 300-400 ms): the
## guest's ANIMATIONS that only ran in the host's simulation, and the ROOTMAWS' GROUND. A host game and a guest's puppet
## fed with its snapshots, in one process (as tools/test_online_fix.gd); with delay:MS the snapshots reach the guest that
## late, in bursts (every BURST frames, merged as NetSession merges a backlog), as over a slow line.
##   godot --headless --fixed-fps 30 --script res://tools/test_online_anim.gd [-- delay:350]
## On the guest: a matured Raptor becomes a Tyrant Challenger (its art, no shell, visible) within a second of the host; a
## Mist Toad hops; a Springer jumps (its strip and arc); a cocoon opens; an egg hatches; a Swift becomes an Owl; a turtle
## roots with its rooting frames. The ground: the overlap rule, the guest's ghost value = the host's, a fresh circle
## beside a spent one keeps its food, the computer's spot check.
var main: Node
var t := 0.0
var g: Game
var pg: Game
var hs: NetSession
var gs: NetSession
var frames := 0
var fails := 0
var delay_ms := 0.0
var queue: Array = []          # [frame made, snapshot]
const BURST := 9
var stage := 0
var t0 := 0.0
var u_rap: Unit
var u_toad: Unit
var u_spr: Unit
var u_coc: Unit
var u_egg: Unit
var u_swift: Unit
var u_turt: Unit
var seen := {}                 # what the guest showed: name -> value
var host_mat_at := -1.0
var guest_mat_at := -1.0
var host_owl_at := -1.0
var guest_owl_at := -1.0
var host_open_at := -1.0
var guest_open_at := -1.0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("delay:"):
			delay_ms = float(a.substr(6))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if stage == 0:
		if t > 0.2 and main.game == null:
			main.start({"map": "twin_fords", "seed": 2053137776, "slots": [
				{"who": "easy", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": "you", "faction": "brood", "colour": 1, "side": 1}]})
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
		_deliver()
		if g.clock > 2.0 and u_rap == null:
			_spawn()
		if u_rap != null:
			_watch()
		if u_rap != null and g.clock - t0 > 34.0:
			_report()
			stage = 1
		return false
	return stage == 9


func _setup() -> void:
	hs = NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.go_given = true
	hs.link = NetLink.new()
	hs._m_reset()
	hs.peer_team = {99: 1}
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
	queue.append([frames, NetCodec.unpack(NetCodec.pack(NetSnapshot.build(hs)))])


func _deliver() -> void:
	if delay_ms <= 0.0:
		for q in queue:
			gs.pending.append(q[1])
		queue.clear()
		gs._apply_pending()             # (as the session does: its clock, the buffer the units glide through)
		return
	if frames % BURST != 0:
		return
	var late := int(delay_ms / 1000.0 * 30.0)
	var ready: Array = []
	while not queue.is_empty() and frames - int(queue[0][0]) >= late:
		ready.append(queue.pop_front()[1])
	if ready.is_empty():
		return
	gs.pending.append_array(ready)
	gs._apply_pending()                 # (a backlog: merged, NetSnapshot.merge)


func _guest(u) -> Unit:
	if u == null or not is_instance_valid(u) or u.net_id == 0:
		return null
	var p = gs.by_id.get(u.net_id)
	return p if is_instance_valid(p) else null


func _spawn() -> void:
	t0 = g.clock
	var q := BroodNew.queen(g, 1)
	var base: Vector2 = q.position + Vector2(0, 230)
	for cam in [g.camera, pg.camera]:
		cam.position = base
		cam.zoom = Vector2(0.35, 0.35)
	u_rap = g._add_unit("raptor", 1, base + Vector2(-120, 0))
	g.players[1]["gold"] += 2000
	BroodMature.start(u_rap)
	u_toad = g._add_unit("mist_toad", 1, base + Vector2(-160, 60))
	u_toad.cmd_move(u_toad.position + Vector2(260, 0))
	u_spr = g._add_unit(Defs.SPRINGER, 1, base + Vector2(80, -60))
	u_egg = g._add_unit(BroodNew.EGG, 1, base + Vector2(40, 70))
	u_egg.nb["k"] = "grub"
	u_egg.nb["t"] = BroodNew.egg_time("grub") - 4.0
	u_swift = g._add_unit("cuckoo", 1, base + Vector2(150, 40))
	u_swift.owl_t = float(Defs.OWL_MORPH["time"]) - 12.0      # (12 s left of its morph)
	u_coc = BroodRoot.cocoon(g, 1, BroodNew.TURTLE, base + Vector2(-40, 170))
	u_coc.nb["coc"] = BroodRoot.cocoon_time(u_coc) - 14.0       # (14 s left in its cocoon)
	u_turt = g._add_unit(BroodNew.TURTLE, 1, base + Vector2(240, -40))
	print("spawned at %.1f s (delay %d ms)" % [g.clock, int(delay_ms)])


func _seen_add(k: String, v) -> void:
	if not seen.has(k):
		seen[k] = {}
	seen[k][v] = true


func _watch() -> void:
	var el := g.clock - t0
	if el > 1.0 and u_spr.jump.is_empty() and not seen.has("spr_host_jumped"):
		seen["spr_host_jumped"] = true
		Springer.start(u_spr, u_spr.position + Vector2(130, 30))
	if el > 3.0 and u_turt.tesla_mode == "packed" and not seen.has("turt_cmd"):
		seen["turt_cmd"] = true
		u_turt.cmd_deploy()
		print("turtle root: %s %s" % [u_turt.tesla_mode, BroodNew.root_problem(g, u_turt)])
	# the moult
	if host_mat_at < 0.0 and u_rap.kind == "tyrant_challenger":
		host_mat_at = g.clock
	var gr := _guest(u_rap)
	if gr:
		if gr.get_node_or_null(MoultLook.SHELL) != null:
			seen["rap_shell"] = true
		if gr.moult_t >= 0.0:
			_seen_add("rap_moult_f", int(BroodMature.frac(gr) * 20.0))
		if guest_mat_at < 0.0 and gr.kind == "tyrant_challenger" and gr.get_node_or_null(MoultLook.SHELL) == null \
				and gr.sprite.self_modulate.a > 0.99 and gr._anim_art == gr.art:
			guest_mat_at = g.clock
	# the toad
	var gt := _guest(u_toad)
	if gt and gt.anim == "walk":
		_seen_add("toad_frames", gt.sprite.frame)
		seen["toad_hop_d"] = gt._hop_d
	# the Springer
	var gsp := _guest(u_spr)
	if gsp and not gsp.jump.is_empty():
		if gsp.anim == "jump":
			_seen_add("spr_frames", gsp.sprite.frame)
		seen["spr_lift"] = maxf(float(seen.get("spr_lift", 0.0)), -gsp.sprite.position.y)
	# the egg
	var ge := _guest(u_egg)
	if ge and ge.anim == "hatch":
		_seen_add("egg_hatch_frames", ge.sprite.frame)
	# the Swift
	if host_owl_at < 0.0 and u_swift.kind == Defs.OWL:
		host_owl_at = g.clock
	var gw := _guest(u_swift)
	if gw and guest_owl_at < 0.0 and gw.kind == Defs.OWL and gw.owl_t < 0.0 and gw._anim_art == gw.art:
		guest_owl_at = g.clock
	if gw and gw.owl_t >= 0.0:
		_seen_add("swift_morph_f", int(CwAir.morph_frac(gw) * 20.0))
	# the cocoon
	if host_open_at < 0.0 and not BroodRoot.in_cocoon(u_coc):
		host_open_at = g.clock
	var gc := _guest(u_coc)
	if gc:
		if BroodRoot.in_cocoon(gc):
			seen["coc_in"] = true
			_seen_add("coc_f", int(float(gc.nb["coc"]) * 4.0))
		elif guest_open_at < 0.0:
			guest_open_at = g.clock
	# rooting
	var gtu := _guest(u_turt)
	if gtu and gtu.anim == "root":
		_seen_add("turt_root_frames", gtu.sprite.frame)


func _lag(h: float, gv: float) -> String:
	if h < 0.0:
		return "host never did"
	if gv < 0.0:
		return "guest never showed it"
	return "%.2f s after the host" % (gv - h)


func _report() -> void:
	var tag := " (delay %d ms)" % int(delay_ms)
	var lim := 1.0 + delay_ms / 1000.0 + float(BURST) / 30.0
	check("moult: the guest drew the shell" + tag, seen.has("rap_shell"))
	check("moult: the shell's progress moved on the guest", seen.get("rap_moult_f", {}).size() >= 8, "%d steps" % seen.get("rap_moult_f", {}).size())
	check("moult: a Tyrant Challenger on the guest, its art, no shell" + tag, guest_mat_at >= 0.0 and guest_mat_at - host_mat_at <= lim, _lag(host_mat_at, guest_mat_at))
	check("toad: it hops on the guest (hop frames, ground counted)", seen.get("toad_frames", {}).size() >= 4 and float(seen.get("toad_hop_d", 0.0)) > 64.0,
		"%d frames, %.0f px" % [seen.get("toad_frames", {}).size(), float(seen.get("toad_hop_d", 0.0))])
	check("Springer: its jump strip plays on the guest" + tag, seen.get("spr_frames", {}).size() >= 4, "%d frames %s" % [seen.get("spr_frames", {}).size(), str(seen.get("spr_frames", {}).keys())])
	check("Springer: it rises on its arc on the guest", float(seen.get("spr_lift", 0.0)) > 5.0, "%.1f px" % float(seen.get("spr_lift", 0.0)))
	check("egg: it hatches on the guest (hatch frames)", seen.get("egg_hatch_frames", {}).size() >= 3, str(seen.get("egg_hatch_frames", {}).keys()))
	check("Swift: its morph runs and it becomes an Owl on the guest" + tag, seen.get("swift_morph_f", {}).size() >= 6 and guest_owl_at >= 0.0 and guest_owl_at - host_owl_at <= lim, _lag(host_owl_at, guest_owl_at))
	check("cocoon: it grows and opens on the guest" + tag, seen.has("coc_in") and seen.get("coc_f", {}).size() >= 20 and guest_open_at >= 0.0 and guest_open_at - host_open_at <= lim, _lag(host_open_at, guest_open_at))
	if seen.has("turt_cmd") and u_turt.tesla_mode != "packed":
		check("rooting: the turtle's rooting frames play on the guest", seen.get("turt_root_frames", {}).size() >= 3, str(seen.get("turt_root_frames", {}).keys()))
	else:
		print("(the turtle could not root there: rooting frames not checked)")
	check("the snapshot's lists match its readers", NetSnapshot.check_lists(u_spr, g.buildings[0]) == "", NetSnapshot.check_lists(u_spr, g.buildings[0]))
	_ground()
	print("RESULT %s (%d failed)" % ["ok" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


## THE ROOTMAWS' GROUND: a spent spot and fresh ground beside it, on the host and on the guest.
func _ground() -> void:
	var tl := float(Defs.TILE)
	var full := float(Defs.PIT_GROUND)
	check("overlap: 1 on the spot, 0 apart, ~0.39 a radius off", absf(BroodNew.overlap(0.0) - 1.0) < 0.001 and BroodNew.overlap(20.0 * tl) == 0.0 and absf(BroodNew.overlap(10.0 * tl) - 0.391) < 0.01)
	var q := BroodNew.queen(g, 1)
	var p: Vector2 = q.position + Vector2(0, -900)
	g.nb_spot_next += 1
	var sid := g.nb_spot_next
	g.nb_spots[sid] = {"p": p, "left": 0.0, "maw": 0}
	for i in 4:
		hs.snap_n += 1
		NetSnapshot.apply(gs, NetCodec.unpack(NetCodec.pack(NetSnapshot.build(hs))))
	check("ground: on a spent spot the host and the guest's ghost read 0", BroodNew.ground_at(g, p) < 1.0 and BroodNew.ground_at(pg, p) < 1.0,
		"host %.0f guest %.0f" % [BroodNew.ground_at(g, p), BroodNew.ground_at(pg, p)])
	var mid := p + Vector2(10.0 * tl, 0)
	check("ground: the guest's ghost reads the host's value beside it", absf(BroodNew.ground_at(g, mid) - BroodNew.ground_at(pg, mid)) < 2.0,
		"host %.0f guest %.0f" % [BroodNew.ground_at(g, mid), BroodNew.ground_at(pg, mid)])
	var edge := p + Vector2(19.0 * tl, 0)
	check("ground: a fresh circle a tile into a spent one keeps nearly all", BroodNew.ground_at(g, edge) > full * 0.97, "%.0f" % BroodNew.ground_at(g, edge))
	check("ground: half on a spent one: about 60%", absf(BroodNew.ground_at(g, mid) - full * 0.609) < 30.0, "%.0f" % BroodNew.ground_at(g, mid))
	check("ground: two tiles off a spent spot: little", BroodNew.ground_at(g, p + Vector2(2.0 * tl, 0)) < full * 0.15, "%.0f" % BroodNew.ground_at(g, p + Vector2(2.0 * tl, 0)))
	var m: Unit = g._add_unit(BroodNew.MAW, 1, edge)
	BroodNew._claim(g, m)
	check("ground: a Rootmaw rooted there gets it, the spent spot stays", BroodNew.ground_left(g, m) > full * 0.97 and g.nb_spots.has(sid),
		"%.0f, spent spot kept: %s" % [BroodNew.ground_left(g, m), str(g.nb_spots.has(sid))])
	var m2: Unit = g._add_unit(BroodNew.MAW, 1, p + Vector2(tl, 0))
	BroodNew._claim(g, m2)
	check("ground: one rooted on the spent spot gets ~0, the old spot merged", BroodNew.ground_left(g, m2) < full * 0.08 and not g.nb_spots.has(sid),
		"%.0f" % BroodNew.ground_left(g, m2))
	check("ground: spot ids are never reused", int(m.nb["spot"]) != int(m2.nb["spot"]) and int(m2.nb["spot"]) != sid)
	BroodNew._release(g, m)
	BroodNew._release(g, m2)
	g.nb_spots[sid] = {"p": p, "left": 0.0, "maw": 0}
	var ai := AIBroodNew.new()
	ai.game = g
	ai.team = 1
	check("ground: the computer won't root on the spent spot, will on fresh", not ai._nb_spot_ok(p + Vector2(tl, 0)) and ai._nb_spot_ok(p + Vector2(60.0 * tl, 0)))
	ai.free()
