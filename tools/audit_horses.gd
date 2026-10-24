extends SceneTree
## Horse ledger audit (AI vs AI Crown rush), tracks every horse each tick:
##   godot --headless --fixed-fps 30 --script res://tools/audit_horses.gd -- <map> <minutes> [crown|brood]
## Prints one line per horse that leaves the field, with how (died / consumed + what was next to it)
## and flags the ones with no legitimate event, with the last 5 s of state.
var main: Node
var t := 0.0
var rec := {}          # instance id -> {u, hist, born, team}
var ended := 0.0
var stop_at := 420.0
var summary := {"made": 0, "died": 0, "mounted": 0, "building": 0, "harness": 0, "other": 0, "suspect": 0}
var _riders_seen := {}
var map := "glimmerdeep"
var enemy := "brood"
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
		main.start({"map": map, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": enemy, "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	if g == null:
		return false
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
		print("SUMMARY map=", map, " clock=", int(g.clock), " ", summary, " alive_now=", alive, " mounted_alive=", riders, " ", "")
		return true
	return false
