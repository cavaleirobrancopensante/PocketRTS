extends SceneTree
## THE ARMOURY STUDY AND THE MARCHING BAND'S FIGHTS (the owner, 2026-10-30; docs/armoury_study.md, docs/marching_band.md).
## A study: no game number is changed. Controlled fights on open ground (dune_sea's middle), the computers switched off:
## a Crown line of Musketeers in two ranks on HOLD against an enemy wave that attack-moves in (as study_raptor_spitter.gd),
## at about 1200 resources a side.
##
##   godot --headless --fixed-fps 30 --script res://tools/study_armoury_band.gd -- group:<g> enemy:<raptor|clock|musk> [seeds:4] [seed0:0] [out:/abs/runs.jsonl]
##   (tools/study_armoury_band.sh runs every group against every enemy, each in its own process)
##
## Groups:
##   AR  the Armoury's musket kit, one line per research: none, Matchlock, Flintlock, Caplock, Socket Bayonet, Armour,
##       Shot Pouch, mid (Matchlock + Bayonet), late (Caplock + Bayonet + Armour + Pouch). "same": 15 men whatever the kit
##       (the kit's raw worth); "eq": as many men as 1200 buys with the kit's refit fees (the cost trade).
##   AG  the guns' drills: 10 Musketeers (mid kit) + 2 Field Cannons, without and with Prepared Charges, and + Quadrant
##   AC  the Cavalry Charge: 8 Horsemen attack-moving into the enemy, without and with the drill
##   MB  the Marching Band (Defs.marching_band on): the mid kit's 15 men, without a band, with the band playing only its
##       secondaries, with a FIFE SOLO at the first shot, a PIPE SOLO when the enemy reaches the line, both (fife first,
##       the pipes when the fife ends), the Caplock line with and without the fife solo (stacking), and "eq": the band
##       paid out of the 1200 (fewer men) with both solos. The band stands 60 px behind the second rank on HOLD.
##   MD  the DRUMS: the Crown attacks (attack-moves 15 mid-kit men from 520 px away) into enemy Musketeers that hold;
##       without a band, with the band's secondaries, with a DRUM SOLO at the start, drums then the fife's solo.
## The enemy is worth 1200 (AR, AG, AC) or, in MB and MD, a size that makes the fight without a band close (foe_budget).
## One JSON line a fight to out: and a short line to the console.

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var group := "AR"
var enemy := "raptor"
var only := ""
var n_seeds := 4
var seed0 := 0                  # (seed0:N runs seeds N.. : a second process adds seeds to the same configs)
var out_path := ""
var _out: FileAccess = null
var map := "dune_sea"

const BUDGET := 1200.0
const RAPTOR := [25.0, 0.0]
const CLOCK_SOLDIER := [70.0, 0.0]
const MUSK := [60.0, 10.0]
const GUN := [210.0, 0.0]               # (a Field Cannon and its horse)
const HORSEMAN := [155.0, 0.0]          # (115 and his horse)
const KITS := {
	"none": {}, "matchlock": {"lock": "matchlock"}, "flintlock": {"lock": "flintlock"}, "caplock": {"lock": "caplock"},
	"bayonet": {"bayonet": true}, "armour": {"armour": true}, "pouch": {"pouch": true},
	"mid": {"lock": "matchlock", "bayonet": true}, "late": {"lock": "caplock", "bayonet": true, "armour": true, "pouch": true},
	"capmid": {"lock": "caplock", "bayonet": true},
}
const TECH := {"none": [], "matchlock": ["matchlock"], "flintlock": ["matchlock", "flintlock"], "caplock": ["matchlock", "flintlock", "caplock"],
	"bayonet": ["bayonet"], "armour": ["armour"], "pouch": ["pouch"], "mid": ["matchlock", "bayonet"],
	"late": ["matchlock", "flintlock", "caplock", "bayonet", "armour", "pouch"], "capmid": ["matchlock", "flintlock", "caplock", "bayonet"]}


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("group:"):
			group = a.substr(6)
		elif a.begins_with("enemy:"):
			enemy = a.substr(6)
		elif a.begins_with("only:"):
			only = a.substr(5)
		elif a.begins_with("seeds:"):
			n_seeds = int(a.substr(6))
		elif a.begins_with("seed0:"):
			seed0 = int(a.substr(6))
		elif a.begins_with("out:"):
			out_path = a.substr(4)
	if out_path != "":
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not begun:
		if t > 0.2:
			begun = true
			root.add_child(SilentSfx.new())
			var fac: String = {"raptor": "brood", "clock": "clockwork", "musk": "crown"}[enemy]
			main.start({"map": map, "seed": 4242, "marching_band": true, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": fac, "colour": 1, "side": 1}]})
			if main.game:
				for ai in main.game.ais:
					ai.process_mode = Node.PROCESS_MODE_DISABLED
				main.game.path_budget_us = 1 << 40
				if Music.me:
					Music.me._faction = ""
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


# ------------------------------------------------------------------ the configs

## The enemy's budget: 1200 in the Armoury groups; in the band's groups (MB, MD) the size that makes the fight without a
## band close (a lopsided fight hides a 10-30% buff: 15 mid-kit Musketeers on HOLD crush 1200 of Clock Soldiers and lose
## to 1200 of attacking Musketeers): Raptors 1200, Clock Soldiers 2000, Musketeers 900.
func foe_budget() -> float:
	if group in ["MB", "MD"]:
		return {"raptor": 1200.0, "clock": 2000.0, "musk": 900.0}[enemy]
	return BUDGET


func musk_price(kit: String) -> Array:
	var f := Game.kit_fee(KITS[kit], "musketeer")
	var p := [MUSK[0] + f[0], MUSK[1] + f[1]]
	if KITS[kit].get("pouch", false):
		p[0] += float(Defs.RESEARCH["pouch"]["fee"])
	return p


func band_price(ins: Array) -> Array:
	var p := [float(Defs.UNITS["band"]["cost"]), 0.0]
	for k in ins:
		p[0] += float(Defs.MARCHING_BAND[k]["cost"])
		p[1] += float(Defs.MARCHING_BAND[k]["cost2"])
	return p


func cfg(name: String, extra := {}) -> Dictionary:
	var c := {"name": name, "musk": 15, "kit": "mid", "guns": 0, "tech": [], "horse": 0, "band": [], "solo": "", "attack": false}
	c.merge(extra, true)
	return c


func configs() -> Array:
	var out: Array = []
	match group:
		"AR":
			for k in ["none", "matchlock", "flintlock", "caplock", "bayonet", "armour", "pouch", "mid", "late"]:
				out.append(cfg("AR_same_%s" % k, {"kit": k, "musk": 15}))
				var p := musk_price(k)
				out.append(cfg("AR_eq_%s" % k, {"kit": k, "musk": int(round(BUDGET / (p[0] + p[1])))}))
		"AG":
			var mp := musk_price("mid")
			var n := int(round((BUDGET - 2 * GUN[0]) / (mp[0] + mp[1])))
			out.append(cfg("AG_guns", {"musk": n, "guns": 2}))
			out.append(cfg("AG_charges", {"musk": n, "guns": 2, "tech": ["charges"]}))
			out.append(cfg("AG_quadrant", {"musk": n, "guns": 2, "tech": ["charges", "quadrant"]}))
		"AC":
			out.append(cfg("AC_horse", {"musk": 0, "horse": 8}))
			out.append(cfg("AC_charge", {"musk": 0, "horse": 8, "tech": ["charge"]}))
		"MB":
			var all3 := ["drums", "pipes", "fife"]
			out.append(cfg("MB_none"))
			out.append(cfg("MB_sec", {"band": all3}))
			out.append(cfg("MB_fife", {"band": all3, "solo": "fife"}))
			out.append(cfg("MB_pipes", {"band": all3, "solo": "pipes"}))
			out.append(cfg("MB_both", {"band": all3, "solo": "both"}))
			out.append(cfg("MB_cap_none", {"kit": "capmid"}))
			out.append(cfg("MB_cap_fife", {"kit": "capmid", "band": all3, "solo": "fife"}))
			var bp := band_price(all3)
			var mp2 := musk_price("mid")
			out.append(cfg("MB_eq_both", {"band": all3, "solo": "both", "musk": int(round((BUDGET - bp[0] - bp[1]) / (mp2[0] + mp2[1])))}))
			out.append(cfg("MB_eq_none", {"musk": int(round(BUDGET / (mp2[0] + mp2[1])))}))
		"MD":
			if enemy != "musk":
				return []          # (the drums are measured walking in under fire: a line of Musketeers that holds)
			var all3b := ["drums", "pipes", "fife"]
			out.append(cfg("MD_none", {"attack": true}))
			out.append(cfg("MD_sec", {"attack": true, "band": all3b}))
			out.append(cfg("MD_drums", {"attack": true, "band": all3b, "solo": "drums"}))
			out.append(cfg("MD_drums_fife", {"attack": true, "band": all3b, "solo": "drums_fife"}))
	if only != "":
		out = out.filter(func(c) -> bool: return c["name"] == only)
	return out


# ------------------------------------------------------------------ the field

func _free_near(p: Vector2, lv: int) -> Vector2:
	for r in 12:
		for i in maxi(1, r * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, r * 6.0)) * r * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, 8.0, 0):
				return q
	return p


func _field() -> Array:
	var best := [Vector2.ZERO, Vector2.RIGHT]
	var best_d := INF
	var mid := Vector2(g.W, g.H) * 0.5
	for y in range(10, g.H - 10, 2):
		for x in range(10, g.W - 10, 2):
			var c := Vector2i(x, y)
			var dd: float = Vector2(c).distance_to(mid)
			if dd >= best_d:
				continue
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _rect_ok(c, dv):
					best_d = dd
					best = [g.cell_center(c), Vector2(dv)]
					break
	return best


func _rect_ok(c: Vector2i, dv: Vector2i) -> bool:
	if not g.in_map(c):
		return false
	var lv := int(g.height[g.idx(c)])
	var pv := Vector2i(-dv.y, dv.x)
	for a in range(-10, 25):
		for b in range(-9, 10):
			var cc: Vector2i = c + dv * a + pv * b
			if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or int(g.height[g.idx(cc)]) != lv or g.solid[g.idx(cc)] != 0:
				return false
	return true


var _field_cache: Array = []


# ------------------------------------------------------------------ one fight

func _price(u: Unit, kit: String) -> Array:
	match u.kind:
		"raptor":
			return RAPTOR
		"clock_soldier":
			return CLOCK_SOLDIER
		"musketeer":
			return musk_price(kit) if u.team == 0 else MUSK
		"cannon":
			return GUN
		"cuirassier":
			return HORSEMAN
		"band":
			return band_price(u.band.get("m", []))
	return [float(u.d.get("cost", 0)), float(u.d.get("cost2", 0))]


func _add(k: String, team: int, p: Vector2, lv: int, list: Array) -> Unit:
	var u: Unit = g._add_unit(k, team, _free_near(p, lv))
	u.auto_work = false
	u._sep_n = list.size() % 3
	u.scan_t = float(list.size() % 10) / 30.0
	list.append(u)
	return u


func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _shots(list: Array) -> int:
	var n := 0.0
	for u in list:
		if is_instance_valid(u) and u.kind == "musketeer":
			n += u._pmax - u.powder
	return int(round(n))


func fight(c: Dictionary, s: int) -> Dictionary:
	seed(1000 + s * 7919)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s * 131
	g.players[0]["tech"] = {}
	for k in TECH[c["kit"]] + c["tech"]:
		g.players[0]["tech"][k] = true
	if _field_cache.is_empty():
		_field_cache = _field()
		print("field at %s, facing %s" % [str(_field_cache[0]), str(_field_cache[1])])
	var mid: Vector2 = _field_cache[0]
	var dir: Vector2 = _field_cache[1]
	var bspot: Vector2 = mid + dir * (520.0 if c["attack"] else 480.0)
	var lv0 := int(g.height[g.idx(g.cell_of(mid))])
	var lv1 := int(g.height[g.idx(g.cell_of(bspot))])
	var perp := Vector2(-dir.y, dir.x)
	var crown: Array = []
	var foes: Array = []
	var nm: int = c["musk"]
	var per_rank := int(ceil(nm / 2.0))
	for i in nm:
		var rank := i / per_rank
		var j := i % per_rank
		var along := (j - (per_rank - 1) / 2.0) * 24.0 + rank * 12.0
		var p: Vector2 = mid + perp * along - dir * rank * 26.0 + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		var u := _add("musketeer", 0, p, lv0, crown)
		u.set_kit(KITS[c["kit"]])
		u.powder = u._pmax
	for i in int(c["horse"]):
		var p2: Vector2 = mid + perp * ((i - (c["horse"] - 1) / 2.0) * 30.0)
		_add("cuirassier", 0, p2, lv0, crown)
	for i in int(c["guns"]):
		var gp: Vector2 = mid - dir * 75.0 + perp * ((i - (c["guns"] - 1) / 2.0) * 70.0)
		_add("cannon", 0, gp, lv0, crown)
	var band: Unit = null
	if not (c["band"] as Array).is_empty():
		band = _add("band", 0, mid - dir * 86.0, lv0, crown)
		band.band = MarchingBand.fresh()
		for k in c["band"]:
			(band.band["m"] as Array).append(k)
		band.max_hp = float(band.d["hp"]) + float(Defs.MARCHING_BAND["hp_per"]) * (c["band"] as Array).size()
		band.hp = band.max_hp
	for u in crown:
		if u.deploys():
			u.cmd_deploy()
		else:
			u.cmd_hold()
	# the enemy: a block, BUDGET worth
	var ek: String = {"raptor": "raptor", "clock": "clock_soldier", "musk": "musketeer"}[enemy]
	var ep: Array = {"raptor": RAPTOR, "clock": CLOCK_SOLDIER, "musk": MUSK}[enemy]
	var n_e := int(round(foe_budget() / (ep[0] + ep[1])))
	var sp := 18.0 if enemy == "raptor" else 24.0
	var cols := maxi(1, int(ceil(sqrt(n_e * 1.6))))
	if enemy == "musk" and c["attack"]:
		cols = int(ceil(n_e / 2.0))      # (a defending musket line: two ranks)
	for i in n_e:
		var row := i / cols
		var col := i % cols
		var p3: Vector2 = bspot + dir * (row * sp) + perp * ((col - (cols - 1) / 2.0) * sp)
		p3 += Vector2(rng.randf_range(-sp * 0.3, sp * 0.3), rng.randf_range(-sp * 0.3, sp * 0.3))
		var e := _add(ek, 1, p3, lv1, foes)
		if c["attack"]:
			e.cmd_hold()
	await wait(3.0)
	for u in crown:
		if u.deploys():
			u.cmd_hold()
	var goal: Vector2 = bspot if c["attack"] else mid
	if c["attack"]:
		for u in crown:
			if u != band:
				u.cmd_move(goal, true)
		if band:
			var lead_man: Unit = crown[int(crown.size() / 2)]
			band.cmd_follow(lead_man)
	else:
		for u in foes:
			u.cmd_move(goal, true)
	var t0: float = g.clock
	var first_shot := -1.0
	var contact := -1.0
	var solos: Array = []
	var band_died := -1.0
	var horse_charges := 0
	if band and (c["solo"] == "drums" or c["solo"] == "drums_fife"):
		band.band_solo("drums")
		solos.append(["drums", 0.0])
	while g.clock - t0 < 150.0:
		await wait(0.25)
		var a0 := _alive(crown).filter(func(u) -> bool: return u.kind != "band")
		var a1 := _alive(foes)
		if a0.is_empty() or a1.is_empty():
			break
		if first_shot < 0.0 and (_shots(crown) > 0 or _shots(foes) > 0):
			first_shot = snapped(g.clock - t0, 0.25)
		if contact < 0.0:
			for u in a0:
				for e in a1:
					if u.position.distance_to(e.position) < u.radius + e.radius + 30.0:
						contact = snapped(g.clock - t0, 0.25)
						break
				if contact >= 0.0:
					break
		if band and band.dead and band_died < 0.0:
			band_died = snapped(g.clock - t0, 0.25)
		if band and not band.dead and MarchingBand.lead(band) == "":
			var want := ""
			match String(c["solo"]):
				"fife", "drums_fife":
					if first_shot >= 0.0:
						want = "fife"
				"pipes":
					if contact >= 0.0:
						want = "pipes"
				"both":
					if first_shot >= 0.0:
						want = "fife"
					if contact >= 0.0 and MarchingBand.solo_problem(band, "fife") != "":
						want = "pipes"
			if want != "" and MarchingBand.solo_problem(band, want) == "":
				band.band_solo(want)
				solos.append([want, snapped(g.clock - t0, 0.25)])
		for u in a0:
			if u.kind == "cuirassier" and u.run_t >= float(Defs.CHARGE["run"]):
				horse_charges += 1
		# (an attacker keeps at it: idle men go on to the enemy's middle)
		var at: Vector2 = Vector2.ZERO
		var movers: Array = a0 if c["attack"] else a1
		var targets: Array = a1 if c["attack"] else a0
		for u in targets:
			at += u.position
		at /= targets.size()
		for u in movers:
			if u.order == "idle" and u.target == null:
				u.cmd_move(at, true)
	var dur: float = g.clock - t0
	var r := {"name": c["name"], "enemy": enemy, "seed": s, "musk": c["musk"], "kit": c["kit"], "guns": c["guns"], "horse": c["horse"],
		"band": c["band"], "solo": c["solo"], "time": snapped(dur, 0.25), "first_shot": first_shot, "contact": contact,
		"solos": solos, "band_died": band_died, "n_enemy": n_e}
	for side in [["crown", crown], ["foe", foes]]:
		var cost := 0.0
		var lost := 0.0
		var left_hp := 0.0
		var alive := 0
		for u in side[1]:
			var pr := _price(u, c["kit"])
			cost += pr[0] + pr[1]
			if not is_instance_valid(u) or u.dead:
				lost += pr[0] + pr[1]
			else:
				left_hp += (pr[0] + pr[1]) * u.hp / maxf(1.0, u.max_hp)
				alive += 1
		r[side[0] + "_cost"] = cost
		r[side[0] + "_lost"] = lost
		r[side[0] + "_left_hp"] = snapped(left_hp, 1.0)
		r[side[0] + "_alive"] = alive
	# the band's own share of the Crown's numbers (a band paid on top of the same men is not the soldiers' result)
	r["band_cost"] = 0.0
	r["band_left"] = 0.0
	if band:
		var bp2 := _price(band, c["kit"])
		r["band_cost"] = bp2[0] + bp2[1]
		if is_instance_valid(band) and not band.dead:
			r["band_left"] = snapped((bp2[0] + bp2[1]) * band.hp / maxf(1.0, band.max_hp), 1.0)
	var w := "draw"
	var a0b := _alive(crown).filter(func(u) -> bool: return u.kind != "band")
	if _alive(foes).is_empty() and not a0b.is_empty():
		w = "crown"
	elif a0b.is_empty() and not _alive(foes).is_empty():
		w = "foe"
	r["winner"] = w
	for u in crown + foes:
		if is_instance_valid(u):
			g.consume_unit(u)
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.dead:
			g.consume_unit(u)
	await wait(1.0)
	return r


func _clear_start() -> void:
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN:
			g.consume_unit(u)


func _run() -> void:
	await wait(1.0)
	_clear_start()
	g.players[0]["cap"] = 400
	g.players[1]["cap"] = 400
	g.players[0]["gold"] = 100000
	g.players[0]["res2"] = 10000
	var list := configs()
	print("STUDY group %s vs %s: %d configs x %d seeds" % [group, enemy, list.size(), n_seeds])
	for c in list:
		for s in range(seed0, seed0 + n_seeds):
			var r: Dictionary = await fight(c, s)
			if _out:
				_out.store_line(JSON.stringify(r))
				_out.flush()
			print("%-16s %-6s s%d %-5s %5.1fs crown %d lost %d left %d | foe %d lost %d left %d | band died %.1f solos %s" % [
				r["name"], enemy, s, r["winner"], r["time"], int(r["crown_cost"]), int(r["crown_lost"]), int(r["crown_left_hp"]),
				int(r["foe_cost"]), int(r["foe_lost"]), int(r["foe_left_hp"]), r["band_died"], str(r["solos"])])
	if _out:
		_out.close()
	print("STUDY DONE")
	quit(0)
