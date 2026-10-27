extends "res://tools/study/study_game.gd"
## Balance study v2 (docs/study_v2.md): ONE study game, headless, with tools/study/study_game.gd's full recording, where
## either side may OPEN WITH A SCRIPTED BUILD ORDER (tools/study/bo_ai_v2.gd over bo_ai.gd) and then play on as the
## Hard computer with the build's "then" plan. Measurement only: it changes nothing in the game.
##
##   godot --headless --fixed-fps 30 --script res://tools/study/study_game_v2.gd -- \
##       a:crown b:brood oa:crown_musket_wall ob:brood_economy map:greenhold seed:1 swap:0 out:/abs/dir id:g0001 \
##       [end:1800] [gg:1] [builds:/abs/extra_builds.json] [step_timeout:180] [script_timeout:720]
##
##   oa / ob     a build name (from tools/study/build_orders.json, or from the `builds:` file, which wins on a clash);
##               leave it out (or "ai") for the plain Hard computer on plan pa / pb. A build's own faction wins over a / b.
##   builds      an extra file of builds in the same format ({"builds": [...]}) : the exploratory runner writes its
##               candidates there.
## Everything study_game.gd writes, plus in games/<id>.json: "opening_a", "opening_b", and per team "opening" and "bo"
## (the scripted player's record: each step's first try, issue time, built time and status, when the script ended and
## why, its attacks and drops) and "snaps" (army, workers, bank and income at 3, 5, 7, 10, 15 and 20 minutes).

const BOAI2 := preload("res://tools/study/bo_ai_v2.gd")
const SNAP_AT := [180.0, 300.0, 420.0, 600.0, 900.0, 1200.0]

var oa := ""
var ob := ""
var extra_builds := ""
var step_timeout := 180.0
var script_timeout := 720.0
var builds: Dictionary = {}
var swapped := false
var bo2: Array = [null, null]
var snaps: Array = [{}, {}]
var snap_k := 0


func _initialize() -> void:
	super._initialize()
	for a in OS.get_cmdline_user_args():
		var p := a.split(":", true, 1)
		if p.size() < 2:
			continue
		match p[0]:
			"oa": oa = p[1]
			"ob": ob = p[1]
			"builds": extra_builds = p[1]
			"step_timeout": step_timeout = float(p[1])
			"script_timeout": script_timeout = float(p[1])
	if oa == "ai":
		oa = ""
	if ob == "ai":
		ob = ""
	_load_builds("res://tools/study/build_orders.json")
	if extra_builds != "":
		_load_builds(extra_builds)
	for nm in [oa, ob]:
		if nm != "" and not builds.has(nm):
			push_error("study_game_v2: unknown build " + nm)
			quit(2)
			return
	if oa != "":
		fa = String(builds[oa]["faction"])
		pa = String(builds[oa].get("then", "balanced"))
	if ob != "":
		fb = String(builds[ob]["faction"])
		pb = String(builds[ob].get("then", "balanced"))


func _load_builds(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("study_game_v2: cannot read " + path)
		return
	var j = JSON.parse_string(f.get_as_text())
	if j == null:
		push_error("study_game_v2: bad JSON in " + path)
		return
	for b in (j["builds"] as Array):
		builds[String(b["name"])] = b


func _process(delta: float) -> bool:
	var r: bool = super._process(delta)
	if not swapped and main.game != null and main.game.ais.size() >= 2:
		_swap()
	return r


func _init_state() -> void:
	if not swapped:
		_swap()
	super._init_state()


## Put the scripted players in place of the ordinary computers, in the frame they were made (none has thought yet).
func _swap() -> void:
	swapped = true
	var gm = main.game
	var a_team := 1 if swap else 0
	for old in gm.ais.duplicate():
		var nm: String = oa if old.team == a_team else ob
		if nm == "":
			continue
		var nai = BOAI2.new()
		nai.game = gm
		nai.team = old.team
		nai.difficulty = old.difficulty
		nai.strategy = "balanced"
		nai.bo = builds[nm]
		nai.bo_name = nm
		nai.step_timeout = step_timeout
		nai.script_timeout = script_timeout
		old.process_mode = Node.PROCESS_MODE_DISABLED
		gm.ais.erase(old)
		old.queue_free()
		gm.add_child(nai)
		gm.ais.append(nai)
		bo2[nai.team] = nai


func _step() -> void:
	super._step()
	if done or g == null:
		return
	while snap_k < SNAP_AT.size() and g.clock >= SNAP_AT[snap_k]:
		_snap(SNAP_AT[snap_k])
		snap_k += 1


func _snap(at: float) -> void:
	for i in 2:
		var comp := {}
		for u in g.army(i):
			comp[u.kind] = int(comp.get(u.kind, 0)) + 1
		snaps[i][str(int(at))] = {"army": comp, "value": g.army_value(i), "supply": _supply_of_army(i), "workers": g.workers(i).size(),
			"bank": int(g.players[i]["gold"]), "earned": int(g.stats[i]["gold"]), "res2": snappedf(float(g.players[i]["res2"]), 0.1),
			"tension": snappedf(float(g.players[i].get("tension", 0.0)), 0.1), "buildings": g.building_count(i),
			"halls": g.halls_of(i).size()}


func _write(row: Dictionary) -> void:
	var a_team := 1 if swap else 0
	row["opening_a"] = oa if oa != "" else "ai:" + pa
	row["opening_b"] = ob if ob != "" else "ai:" + pb
	row["study"] = "v2"
	if extra_builds != "":
		var found: Array = []
		for nm in [oa, ob]:
			if nm != "" and builds.has(nm):
				found.append(builds[nm])
		row["builds_used"] = found          # (the exploratory candidates' full scripts travel with the game)
	for td in (row["teams"] as Array):
		var i := int(td["team"])
		td["opening"] = row["opening_a"] if i == a_team else row["opening_b"]
		td["bo"] = bo2[i].report_v2() if bo2[i] != null else null
		td["snaps"] = snaps[i]
	super._write(row)
