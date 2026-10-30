extends "res://tools/test_ai_wall_vs_rush.gd"
## THE MUSKETEER HEALTH TEST, the early yardstick (docs/musket_hp_test.md): tools/test_ai_wall_vs_rush.gd (a Hard Crown
## that walls its ramp against the Brood's Extreme rush, scripted as the owner played it) with the variant's health on
## every Crown Musketeer (tools/musket_hp.gd, a test-only override). Measurement only.
##   godot --headless --fixed-fps 30 --script res://tools/study_musket_hp_rush.gd -- [hpv:now|55/65] [map:..] [seed:..] [until:300]
## On top of the base test's lines it prints one OUTCOME line (JSON): Musketeers made and lost, labourers lost, the
## Brood's fighters made / killed / alive, the Crown's buildings lost, the wall's damage, at 2:30, 3:30 and the end.
const MH := preload("res://tools/musket_hp.gd")

var hpv := "now"
var _hp := [0.0, 0.0]
var _seen := {}
var _out := {"musk_made": 0, "musk_lost": 0, "lab_lost": 0, "brood_made": 0, "brood_killed": 0, "brood_killed_value": 0.0,
	"crown_bld_lost": 0, "snap": {}}
var _bseen := {}
var _snap_at := [150.0, 210.0, 270.0]
var _printed := false


func _initialize() -> void:
	super._initialize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hpv:"):
			hpv = a.substr(4)
	_hp = MH.parse(hpv)


func _process(delta: float) -> bool:
	var r := super._process(delta)
	if main.game != null:
		MH.apply(main.game, _hp[0], _hp[1])
		if Engine.get_process_frames() % 3 == 0:
			_tally()
	return r


func _tally() -> void:
	var gg = main.game
	for u in gg.units:
		if not is_instance_valid(u):
			continue
		var id: int = u.get_instance_id()
		if not _seen.has(id) and not u.dead:
			_seen[id] = [u.team, u.kind, u]
			if u.team == 0 and u.kind == "musketeer":
				_out["musk_made"] += 1
			if u.team == 1 and u.has_attack() and not u.is_worker() and not BroodNew.is_nb(u.kind):
				_out["brood_made"] += 1
	for id in _seen.keys():
		var e: Array = _seen[id]
		var u = e[2]
		if u == null:
			continue
		if not is_instance_valid(u) or u.dead:
			if e[0] == 0 and e[1] == "musketeer":
				_out["musk_lost"] += 1
			elif e[0] == 0 and e[1] == "labourer":
				_out["lab_lost"] += 1
			elif e[0] == 1 and e[1] in ["raptor", "tyrant_challenger", "spitter", "brute"]:
				_out["brood_killed"] += 1
				_out["brood_killed_value"] += float(Defs.UNITS[e[1]]["cost"]) / maxf(1.0, float(Defs.UNITS[e[1]].get("spawn", 1)))
			e[2] = null
		else:
			e[1] = u.kind
	for b in gg.buildings:
		var bid: int = b.get_instance_id()
		if b.team == 0 and b.built and not _bseen.has(bid):
			_bseen[bid] = b
	if not _snap_at.is_empty() and gg.clock >= float(_snap_at[0]):
		_snap(str(int(_snap_at.pop_front())))


func _snap(key: String) -> void:
	var gg = main.game
	var bl := 0
	for bid in _bseen:
		var b = _bseen[bid]
		if not is_instance_valid(b) or b.dead:
			bl += 1
	_out["crown_bld_lost"] = bl
	var s := {"musk_alive": gg.army(0).filter(func(u) -> bool: return u.kind == "musketeer").size(),
		"brood_alive": gg.army(1).filter(func(u) -> bool: return u.kind in ["raptor", "tyrant_challenger", "spitter", "brute"]).size(),
		"musk_made": _out["musk_made"], "musk_lost": _out["musk_lost"], "lab_lost": _out["lab_lost"],
		"brood_made": _out["brood_made"], "brood_killed": _out["brood_killed"], "crown_bld_lost": bl,
		"wall_dmg": int(wall_dmg), "labs": gg.workers(0).size()}
	_out["snap"][key] = s


## (the base test's last step is its checks: the outcome is printed before the first)
func check(ok: bool, what: String) -> void:
	if not _printed:
		_printed = true
		_tally()
		_snap("end")
		_out["hpv"] = hpv
		_out["map"] = map
		_out["seed"] = seed_
		_out["over"] = main.game.over
		_out["winner"] = main.game.winner
		_out["clock"] = int(main.game.clock)
		print("OUTCOME " + JSON.stringify(_out))
	super.check(ok, what)
