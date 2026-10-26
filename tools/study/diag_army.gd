extends SceneTree
## Diagnostic for the study's "army sits at the supply cap and never attacks" games (measurement only: it reads the AI's
## state, never changes the game, the AI or a balance number). One headless game, Hard AI on both sides, and every 5 game
## seconds one line per side with what holds the army back in AI._army():
##   threat     an enemy unit within 330 px of one of the AI's buildings (AI._threat(): _army() defends and returns before
##              its wave logic); with the unit's kind, whether it is armed, the building and the distance
##   attack_at  the army supply the next wave waits for; army_sup = the supply of the AI's army now
##   regroup    seconds left of a regroup (no wave while it runs and the army is under 60 supply)
##   walled     enemy halls the AI leaves be after a pull-back at their gate (count), siege = a siege plan is active
##   godot --headless --fixed-fps 30 --path . --script res://tools/study/diag_army.gd -- \
##       a:crown b:clockwork pa:balanced pb:balanced map:saltmarsh_isles seed:108784 swap:1 out:/abs/dir id:diag1 [end:1800]
## Writes <out>/<id>.csv (the 5 s lines) and <out>/<id>.log (the match log).
const STEP := 5.0

var main: Node
var t := 0.0
var g
var fa := "crown"
var fb := "clockwork"
var pa := "balanced"
var pb := "balanced"
var map := "saltmarsh_isles"
var seed_ := 1
var swap := false
var out_dir := ""
var gid := "diag"
var end_t := 1800.0
var inited := false
var ais: Array = [null, null]
var next_t := STEP
var lines := PackedStringArray()


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"a": fa = kv[1]
			"b": fb = kv[1]
			"pa": pa = kv[1]
			"pb": pb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"swap": swap = kv[1] == "1"
			"out": out_dir = kv[1]
			"id": gid = kv[1]
			"end": end_t = float(kv[1])
	lines.append("t,team,faction,supply,cap,workers,gold,army_sup,army_units,army_idle,attack_at,attacking,regroup,siege,walled,det,threat,threat_kind,threat_team,threat_armed,threat_bld,threat_dist,strategy,verdict")


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var slots: Array = []
		var facs := [fb, fa] if swap else [fa, fb]
		var plans := [pb, pa] if swap else [pa, pb]
		for i in 2:
			slots.append({"who": "hard", "faction": facs[i], "colour": i, "side": i, "strategy": plans[i]})
		main.start({"map": map, "seed": seed_, "slots": slots})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if not inited:
		if g.ais.size() < 2:
			return false
		inited = true
		for a in g.ais:
			ais[a.team] = a
		if g.hud:
			g.hud.visible = false
			g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	if g.over or g.clock >= end_t:
		_sample()
		_write()
		return true
	if g.clock >= next_t:
		next_t += STEP
		_sample()
		if int(round(g.clock)) % 60 == 0:
			_flush()       # (partial lines survive if the game is killed)
	return false


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open("%s/%s.csv" % [out_dir, gid], FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()


func _sample() -> void:
	for i in 2:
		var ai = ais[i]
		var ar: Array = g.army(i)
		var sup := 0
		var idle := 0
		for u in ar:
			sup += int(u.d["supply"])
			if u.order == "idle":
				idle += 1
		# the same scan as AI._threat(), keeping the unit and the building it found
		var th_u = null
		var th_b = null
		for b in g.buildings:
			if b.team != i or b.dead:
				continue
			for u in g.units_near(b.center(), 330.0):
				if g.hostile(u.team, i) and not u.dead and not u.off_field:
					th_u = u
					th_b = b
					break
			if th_u != null:
				break
		var row := [snappedf(g.clock, 0.1), i, g.faction_of(i), g.supply_used(i), int(g.players[i]["cap"]), g.workers(i).size(),
			int(g.players[i]["gold"]), sup, ar.size(), idle, int(ai._attack_at), 1 if bool(ai._attacking) else 0,
			snappedf(maxf(0.0, float(ai._regroup_until) - g.clock), 0.1), 0 if (ai._siege as Dictionary).is_empty() else 1,
			(ai._walled_halls as Dictionary).size(), (ai._det as Dictionary).size(), 1 if th_u != null else 0,
			String(th_u.kind) if th_u != null else "", th_u.team if th_u != null else -1,
			(1 if th_u.has_attack() else 0) if th_u != null else -1, String(th_b.kind) if th_b != null else "",
			int(th_u.position.distance_to(th_b.center())) if th_u != null else -1, String(ai.strategy),
			String(ai.scout.verdict) if ai.scout else ""]
		lines.append(",".join(PackedStringArray(row.map(func(x) -> String: return str(x)))))


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open("%s/%s.csv" % [out_dir, gid], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var ml := PackedStringArray()
	if g.mlog:
		ml = g.mlog.lines
	var f2 := FileAccess.open("%s/%s.log" % [out_dir, gid], FileAccess.WRITE)
	f2.store_string("\n".join(ml) + "\n")
	f2.close()
	quit(0)
