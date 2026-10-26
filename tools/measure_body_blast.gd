extends SceneTree
## How often ORDINARY combat splash (round shot, canister, Mortar shells, Owl bombs fired at enemies, not BOMBARD) tears up
## the bodies the Brood could harvest (Defs.BODY_BLAST), in a Crown (Hard) vs Brood (Hard) AI match:
##   godot --headless --fixed-fps 30 --script res://tools/measure_body_blast.gd -- [map] [minutes:16] [share:1.0]
##       [shell:off|on] [crown:balanced] [brood:balanced] [cd:hard] [bd:hard]
## share: Defs.BODY_BLAST.combat for this run; shell: the Crown AI's own body shelling (off: ordinary splash alone).
## Every body that lies down for the Brood (Game.corpses) is followed to its end: harvested by a grub, torn up by a blast,
## raised by a Missionary, rotted away, or still lying at the end. Prints "BODYBLAST ..." lines (values in essence).
## lab [waves:6]: no match, a worst case instead: a Crown line (4 Field Cannons, 2 Mortars, 12 Musketeers, holding; the
## guns pick canister or round shot as the computer does) holds against Brood waves (9 Raptors, 4 Spitters, a Brute,
## every 35 s, at the same spot), so later waves die on the bodies of the earlier ones in front of the guns.
var main: Node
var t := 0.0
var stop_at := 960.0
var share := 1.0
var shell := false
var map := "ashford_crossing"
var strat := {"crown": "balanced", "brood": "balanced"}
var diff := {"crown": "hard", "brood": "hard"}       # (cd:/bd: the computers' levels: easy, normal, hard, brutal)
var next_report := 120.0
var track := {}          # body instance id -> {"b": body, "v": essence value, "died": clock, "kind": String, "team": int}
var fates := {"harvested": [0, 0.0], "torn": [0, 0.0], "revived": [0, 0.0], "rotted": [0, 0.0], "other": [0, 0.0]}
var fallen_seen := {}    # Crown bodies a Missionary could raise: id -> body
var fallen_torn := 0
var fallen_raised := 0
var made := [0, 0.0]
var pen0 := 0.0
var done := false
var lab := false
var waves := 6
var _wave_n := 0
var _next_wave := 3.0
var _line: Array = []
var _line_at := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("minutes:"):
			stop_at = float(a.substr(8)) * 60.0
		elif a.begins_with("share:"):
			share = float(a.substr(6))
		elif a.begins_with("shell:"):
			shell = a.substr(6) == "on"
		elif a.begins_with("crown:"):
			strat["crown"] = a.substr(6)
		elif a.begins_with("brood:"):
			strat["brood"] = a.substr(6)
		elif a.begins_with("cd:"):
			diff["crown"] = a.substr(3)
		elif a.begins_with("bd:"):
			diff["brood"] = a.substr(3)
		elif a == "lab":
			lab = true
		elif a.begins_with("waves:"):
			waves = int(a.substr(6))
		elif MapGen.all_ids().has(a):
			map = a
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and lab:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if t > 0.2 and main.game == null:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": diff["crown"], "faction": "crown", "colour": 0, "side": 0, "strategy": strat["crown"]},
			{"who": diff["brood"], "faction": "brood", "colour": 1, "side": 1, "strategy": strat["brood"]}]})
		return false
	var g: Game = main.game
	if g == null or done:
		return false
	g.body_combat = share             # (this run's share of the blast for ordinary fire)
	for ai in g.ais:
		ai.shell_bodies_on = shell
	if lab:
		_lab(g)
		_follow(g)
		return false
	_follow(g)
	if g.clock >= next_report:
		next_report += 120.0
		_report(g, "t=%d" % int(g.clock))
	if g.clock >= stop_at or g.over:
		_report(g, "END%s" % (" (over)" if g.over else ""))
		done = true
		quit(0)
	return false


## The lab: the Crown line is set up once; a Brood wave comes every 35 s; after the last, 25 s more, then the report.
func _lab(g: Game) -> void:
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if _line.is_empty():
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		if g.hud:
			g.hud.countdown = 0.0
		g.explored.fill(1)
		_line_at = g.cell_center(g.nearest_free(Vector2i(g.W / 2, g.H / 2), 10))
		var spots := [["cannon", Vector2(-90, 0)], ["cannon", Vector2(-30, 0)], ["cannon", Vector2(30, 0)], ["cannon", Vector2(90, 0)],
			["mortar", Vector2(-60, 70)], ["mortar", Vector2(60, 70)]]
		for i in 12:
			spots.append(["musketeer", Vector2(-110 + (i % 6) * 44, -40 - (i / 6) * 26)])
		for sp in spots:
			var u: Unit = g._add_unit(sp[0], 0, _line_at + sp[1])
			if u.deploys():
				u.tesla_mode = "deployed"
			u.cmd_hold()
			_line.append(u)
		return
	# the guns keep their powder (a wagon would) and pick canister when a crowd is close, as the computer does
	for u in _line:
		if is_instance_valid(u) and not u.dead:
			u.powder = u._pmax
			if u.kind == "cannon":
				var crowd := 0
				for o in g.units_near(u.position, float(Defs.CANISTER["range"]) + 20.0):
					if g.hostile(o.team, 0) and not o.dead:
						crowd += 1
				u.set_canister(crowd >= 3)
	_next_wave -= 1.0 / 30.0
	if _wave_n < waves and _next_wave <= 0.0:
		_next_wave = 35.0
		_wave_n += 1
		var from := _line_at + Vector2(0, -650)
		var kinds := []
		for i in 9:
			kinds.append("raptor")
		for i in 4:
			kinds.append("spitter")
		kinds.append("brute")
		for i in kinds.size():
			var at: Vector2 = g.cell_center(g.nearest_free(g.cell_of(from + Vector2(-120 + (i % 7) * 40, (i / 7) * 30)), 6))
			var u: Unit = g._add_unit(kinds[i], 1, at)
			u.cmd_move(_line_at + Vector2(randf_range(-60, 60), 0), true)
		print("  wave %d out at %.0f s (%d bodies so far)" % [_wave_n, g.clock, made[0]])
	if _wave_n >= waves and _next_wave <= 10.0:
		_report(g, "LAB %d waves" % waves)
		done = true
		quit(0)


func _follow(g: Game) -> void:
	for b in g.corpses:
		if not is_instance_valid(b):
			continue
		var id: int = b.get_instance_id()
		if not track.has(id):
			track[id] = {"b": b, "v": g.corpse_value(b), "died": g.clock, "kind": String(b.kind), "team": int(b.team)}
			made[0] += 1
			made[1] += g.corpse_value(b)
	for b in g.fallen:
		if is_instance_valid(b) and not fallen_seen.has(b.get_instance_id()):
			fallen_seen[b.get_instance_id()] = b
	var here := {}
	for b in g.corpses:
		if is_instance_valid(b):
			here[b.get_instance_id()] = true
	for id in track.keys():
		if here.has(id):
			continue
		var e: Dictionary = track[id]
		var b = e["b"]
		var fate := "other"
		if is_instance_valid(b) and b.torn:
			fate = "torn"
		elif is_instance_valid(b) and not b.dead:
			fate = "revived"
		elif is_instance_valid(b) and b.harvester != null and is_instance_valid(b.harvester) and b.harvester.cocoon > 0.0:
			fate = "harvested"
		elif g.clock - float(e["died"]) >= float(Defs.HARVEST["time"]) - 2.0:
			fate = "rotted"
		elif not is_instance_valid(b):
			fate = "other"
		fates[fate][0] += 1
		fates[fate][1] += float(e["v"])
		track.erase(id)
	var fall_here := {}
	for b in g.fallen:
		if is_instance_valid(b):
			fall_here[b.get_instance_id()] = true
	for id in fallen_seen.keys():
		if fall_here.has(id):
			continue
		var b = fallen_seen[id]
		if is_instance_valid(b) and b.torn:
			fallen_torn += 1
		elif is_instance_valid(b) and not b.dead:
			fallen_raised += 1
		fallen_seen.erase(id)


func _report(g: Game, tag: String) -> void:
	var lying := [track.size(), 0.0]
	for id in track:
		lying[1] += float(track[id]["v"])
	var line := "BODYBLAST %s map=%s %s/%s share=%.2f shell=%s | bodies %d (%.0f ess) | harvested %d (%.0f) | torn %d (%.0f) | rotted %d (%.0f) | raised %d | other %d | lying %d (%.0f)" % [
		tag, map, diff["crown"], diff["brood"], share, "on" if shell else "off", made[0], made[1], fates["harvested"][0], fates["harvested"][1],
		fates["torn"][0], fates["torn"][1], fates["rotted"][0], fates["rotted"][1], fates["revived"][0], fates["other"][0], lying[0], lying[1]]
	var ended: int = fates["harvested"][0] + fates["torn"][0]
	if ended > 0:
		line += " | torn/(harvested+torn) %.0f%%" % (100.0 * fates["torn"][0] / ended)
	line += " | blasts: combat %d aimed %d | Crown raisable torn %d raised %d" % [int(g.bodies_blasted["combat"]), int(g.bodies_blasted["aimed"]), fallen_torn, fallen_raised]
	var guns := 0
	for u in g.units:
		if u.team == 0 and not u.dead and (u.kind == "cannon" or u.kind == "mortar"):
			guns += 1
	var jobs := 0
	for ai in g.ais:
		jobs += ai.shell_log.size()
	line += " | crown guns now %d | computer shelling jobs %d | essence in: brood %.0f" % [guns, jobs, float(g.stats[1].get("res2_in", 0.0))]
	print(line)
