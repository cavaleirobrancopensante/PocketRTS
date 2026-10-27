extends SceneTree
## Horse ledger audit (AI vs AI, a Crown rush), tracks every horse each tick:
##   godot --headless --fixed-fps 30 --script res://tools/audit_horses.gd -- <map> <minutes> [crown|brood|clockwork] [seed]
## Prints one line per horse that leaves the field, with how (died / consumed + what was next to it)
## and flags the ones with no legitimate event, with the last 5 s of state. Also flags a man leading
## horses (a Town Hall hauler or anyone else) who makes no headway for 8 s ("LEAD STUCK"), and a
## limbered gun or wagon jammed for 8 s on the move ("GUN STUCK"); the SUMMARY counts them.
var main: Node
var t := 0.0
var rec := {}          # instance id -> {u, hist, born, team}
var ended := 0.0
var stop_at := 420.0
var summary := {"made": 0, "died": 0, "mounted": 0, "building": 0, "harness": 0, "other": 0, "suspect": 0,
	"lead_stuck": 0, "gun_stuck": 0}
var _riders_seen := {}
var map := "glimmerdeep"
var enemy := "brood"
var seed_n := -1
var _moves := {}       # a leader's / gun's instance id -> [[clock, position], ...] (every 0.5 s)
var _stuck_on := {}    # instance id -> true while it is flagged stuck (one line per episode)
var _sample_t := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _state(u: Unit, g) -> Dictionary:
	var c: Vector2i = g.cell_of(u.position)
	return {"t": snappedf(g.clock, 0.1), "pos": Vector2i(u.position), "team": u.team, "leader": (u.leader.kind + "#" + str(u.leader.get_instance_id() % 10000) if u.leader != null and is_instance_valid(u.leader) else "-"),
		"lead_dead": (u.leader != null and is_instance_valid(u.leader) and u.leader.dead), "order": u.order,
		"hphase": (str(u.leader.haul_job.get("k", "")) + "/" + str(u.leader.get("work")) if u.leader != null and is_instance_valid(u.leader) else "-"),
		"into": (u.into.name if u.into != null and is_instance_valid(u.into) else "-"), "into_t": snappedf(u._into_t, 0.1), "rid": u.horse_rid,
		"claimed": u.claimed != null, "off": u.off_field, "solid": (g.solid[g.idx(c)] if g.in_map(c) else -9), "hp": int(u.hp)}


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		var args := OS.get_cmdline_user_args()
		if args.size() > 0: map = args[0]
		if args.size() > 1: stop_at = float(args[1]) * 60.0
		if args.size() > 2: enemy = args[2]
		if args.size() > 3: seed_n = int(args[3])
		var cfg := {"map": map, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": enemy, "colour": 1, "side": 1, "strategy": "balanced"}]}
		if seed_n >= 0:
			cfg["seed"] = seed_n
		main.start(cfg)
	var g = main.game
	if g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var live := {}
	for u in g.units:
		if u.kind == "horse" and is_instance_valid(u):
			var id: int = u.get_instance_id()
			live[id] = true
			if not rec.has(id):
				rec[id] = {"u": u, "hist": [], "born": g.clock, "team": u.team}
				summary["made"] += 1
			var r: Dictionary = rec[id]
			r["hist"].append(_state(u, g))
			if r["hist"].size() > 150: r["hist"].pop_front()
			r["last_seen_pos"] = u.position
			r["rid"] = u.horse_rid
			if u.get("hitch_p") != null and u.hitch_p != Vector2.INF:
				r["hitched"] = true
			r["into"] = u.into
			r["coat"] = u.coat
			# standing impossible: off_field or in a solid cell
			if (u.off_field and not r.has("flag_off")) :
				r["flag_off"] = true
				print("FLAG off_field horse ", id % 10000, " at ", snappedf(g.clock, 0.1), " ", r["hist"][-1])
			var st: Dictionary = r["hist"][-1]
			if st["solid"] in [1, 2, 4] and not r.has("flag_solid") and u.into == null:
				r["flag_solid"] = true
				print("FLAG horse in solid cell(", st["solid"], ") ", id % 10000, " ", st)
	_watch_movers(g, delta)
	for id in rec.keys():
		var r: Dictionary = rec[id]
		if live.has(id) or r.get("gone", false):
			continue
		r["gone"] = true
		var u = r["u"]
		var how := "?"
		var valid := is_instance_valid(u)
		var next := ""
		var lp: Vector2 = r["last_seen_pos"]
		if valid and u.dead and u.hp <= 0.0:
			how = "died"
			summary["died"] += 1
		else:
			# consumed: what is next to it?
			for o in g.units:
				if o.kind != "horse" and not o.dead and o.is_mounted() and o.position.distance_to(lp) < 60.0:
					next = "rider %s" % o.kind
					break
			if next == "":
				for o in g.units:
					if o.team == r["team"] and not o.dead and o.kind != "horse" and o.position.distance_to(lp) < 60.0 and (Defs.HARNESSED.has(o.kind)):
						next = "gun %s" % o.kind
						break
			var inb = r["into"] if r["into"] != null and is_instance_valid(r["into"]) and r["into"] is Building else null
			if next != "":
				how = "mounted/harness"
				summary["mounted" if next.begins_with("rider") else "harness"] += 1
			elif inb != null and r.get("hitched", false):
				how = "hitched, consumed at " + inb.kind + " when its recruit came out"
				summary["hitch_used"] = summary.get("hitch_used", 0) + 1
			elif inb != null:
				how = "VANISHED into " + inb.kind + " unhitched rid=" + str(r["rid"])
				summary["building"] += 1
			else:
				how = "SUSPECT"
				summary["suspect"] += 1
		print("GONE horse ", id % 10000, " t=", snappedf(g.clock, 0.1), " ", how, " ", next, " last=", r["hist"][-1] if r["hist"].size() > 0 else "")
		if how == "SUSPECT" or how.begins_with("VANISHED"):
			var h: Array = r["hist"]
			for i in range(maxi(0, h.size() - 150), h.size(), 15):
				print("    ", h[i])
	if g.over or g.clock > stop_at:
		var alive := 0
		alive = live.size()
		var riders := {}
		for u in g.units:
			if u.team == 0 and not u.dead and (u.is_mounted()): riders[u.kind] = riders.get(u.kind, 0) + 1
		print("SUMMARY map=", map, " seed=", seed_n, " clock=", int(g.clock), " ", summary, " alive_now=", alive, " mounted_alive=", riders, " ", "")
		quit(0)
		return true
	return false


## Every 0.5 s: men leading horses (or sent for them as haulers) and limbered guns / wagons on the
## move; one that has covered under 12 px in the last 8 s is flagged once, until it moves again.
func _watch_movers(g, delta: float) -> void:
	_sample_t -= delta
	if _sample_t > 0.0:
		return
	_sample_t = 0.5
	var seen := {}
	for u in g.units:
		if u.dead or u.off_field or u.team < 0:
			continue
		var what := ""
		if not u.led.is_empty() or (u.kind == "labourer" and String(u.haul_job.get("k", "")) in ["horse", "team"] and String(u.haul_job.get("ph", "")) != "home"):
			what = "LEAD"
		elif Defs.HARNESSED.has(u.kind) and u.harnessed and u.tesla_mode == "packed" and u.order in ["move", "amove"]:
			what = "GUN"
		if what == "":
			continue
		var id: int = u.get_instance_id()
		seen[id] = true
		var hist: Array = _moves.get(id, [])
		hist.append([g.clock, u.position])
		while hist.size() > 0 and g.clock - float(hist[0][0]) > 8.0:
			hist.pop_front()
		_moves[id] = hist
		if hist.size() < 15:
			continue
		var moved := 0.0
		for p in hist:
			moved = maxf(moved, (p[1] as Vector2).distance_to(u.position))
		if moved < 12.0:
			if not _stuck_on.has(id):
				_stuck_on[id] = true
				summary["lead_stuck" if what == "LEAD" else "gun_stuck"] += 1
				var c: Vector2i = g.cell_of(u.position)
				print("%s STUCK %s#%d t=%.1f pos=%s cell=%s solid=%d order=%s job=%s led=%d path_i=%d/%d goal=%s" % [what, u.kind, id % 10000,
					g.clock, Vector2i(u.position), c, int(g.solid[g.idx(c)]), u.order, str(u.haul_job.get("k", "")) + "/" + str(u.haul_job.get("ph", "")),
					u.led.size(), u.path_i, u.path.size(), Vector2i(u.path_goal) if u.path_goal != Vector2.INF else Vector2i(-1, -1)])
		else:
			_stuck_on.erase(id)
	for id in _moves.keys():
		if not seen.has(id):
			_moves.erase(id)
			_stuck_on.erase(id)
