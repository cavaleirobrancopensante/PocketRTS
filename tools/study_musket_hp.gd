extends SceneTree
## THE MUSKETEER HEALTH TEST (the owner, 2026-10-30; docs/musket_hp_test.md). A study: no game number is changed. The
## variant's health is put on the spawned men only, by tools/musket_hp.gd (a test-only override).
## Small fixed fights: a Crown line on HOLD (8 Musketeers, mid kit: Matchlock + Socket Bayonet; or 8 Guardsmen: the same
## kit + Armour) against one kind of enemy at about equal cost (face value: gold + powder, food + spoils, cogs + Tension),
## each fight at today's health (hp "now": 70 / 90) and the variant (hp "55/65": 55 / 65), on `seeds` jittered seeds.
##
##   godot --headless --fixed-fps 30 --script res://tools/study_musket_hp.gd -- group:<g> [seeds:6] [out:/abs/runs.jsonl]
##   ... -- only:<config name> seeds:6 out:...      ... -- group:<g> list   (the config names, one a line)
##   [hpv:55/65]   the variant (default 55/65; several: hpv:55/65,60/80)       [n:8]  the Crown's men
##
## Groups (config names start with the group and "_"):
##   BO  Brood, the open field (Dune Sea's flat middle): Raptors, Tyrant Challengers, Brutes, Spitters;
##       "range": the enemy starts 16 tiles off and attack-moves in (the line gets its volleys first);
##       "close": the enemy starts 70 px off (caught at close range: the line's guns are loaded, nothing more)
##   BR  Brood, the ramp: the Crown's own Cottage wall and gate at Greenhold's main ramp (AI.plan_cottage_wall), the line
##       on the high ground behind it, the enemy from the ramp's foot
##   CO / CR  the Clockwork: Clock Soldiers, Springers (open field, ramp)
##   HO / HR  Horsemen (a Crown army on side 1: the Horseman with his horse, 155)
##   T   the Mist Toad's TONGUE on a Musketeer of the line: the Toad 200 px out (beyond musket range, within its 224),
##       with 0, 3, 6, 9 or 12 Raptors at its feet (the rest of the line holds its fire: it is busy); when the man lands they go for him; 0.5 s after he can move he is ordered
##       back to the line (a player's reaction). Does he die?
## One JSON line a fight to out:, and a short line to the console.

const MH := preload("res://tools/musket_hp.gd")

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var group := "BO"
var only := ""
var n_seeds := 6
var out_path := ""
var hpv := "55/65"
var n_men := 8
var _out: FileAccess = null
var map := "dune_sea"
var ramp := false
var listing := false
var foe_fac := "brood"
var _hp := [0.0, 0.0]          # the override on now (MH.apply each frame); [0, 0] = today's game

## per-unit price at face value split [first, second] (an egg's share; the Horseman with his horse)
const PRICE := {"raptor": [25.0, 0.0], "spitter": [45.0, 2.5], "tyrant_challenger": [100.0, 10.0], "brute": [150.0, 20.0],
	"mist_toad": [100.0, 25.0], "clock_soldier": [70.0, 0.0], "springer": [100.0, 25.0], "cuirassier": [155.0, 0.0]}
const KITS := {
	"M": {"lock": "matchlock", "bayonet": true},
	"G": {"lock": "matchlock", "bayonet": true, "armour": true},
}
const TECH := ["matchlock", "bayonet", "armour"]
const FOES := {"B": ["raptor", "tyrant_challenger", "brute", "spitter"], "C": ["clock_soldier", "springer"], "H": ["cuirassier"]}


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		match kv[0]:
			"group": group = kv[1]
			"only": only = kv[1]
			"seeds": n_seeds = int(kv[1])
			"out": out_path = kv[1]
			"hpv": hpv = kv[1]
			"n": n_men = int(kv[1])
			"list": listing = true
	if only != "":
		group = only.get_slice("_", 0)
	ramp = group.ends_with("R")
	foe_fac = {"B": "brood", "C": "clockwork", "H": "crown", "T": "brood"}[group.substr(0, 1)]
	if listing:
		for c in configs():
			print("CFG " + String(c["name"]))
		quit(0)
		return
	if ramp:
		map = "greenhold"
	if out_path != "":
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	if listing:
		return true
	t += delta
	if not begun:
		if t > 0.2:
			begun = true
			root.add_child(SilentSfx.new())
			main.start({"map": map, "seed": 4242, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": foe_fac, "colour": 1, "side": 1}]})
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
	MH.apply(g, _hp[0], _hp[1])
	if not started and t > 1.0:
		started = true
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


# ------------------------------------------------------------------ the configs

func musk_price(who: String) -> Array:
	var f := Game.kit_fee(KITS[who], "musketeer")
	return [60.0 + f[0], 10.0 + f[1]]


func configs() -> Array:
	var out: Array = []
	var hps := ["now"]
	hps.append_array(hpv.split(","))        # (hpv:55/65,60/80 tests more than one variant)
	if group == "T":
		for who in ["M", "G"]:
			for nr in [0, 3, 6, 9, 12]:
				for hp in hps:
					out.append({"name": "T_%s_r%d_%s" % [who, nr, hp.replace("/", "-")], "who": who, "raptors": nr, "hp": hp,
						"foe": "tongue", "n_foe": nr, "scen": "tongue"})
	else:
		var scens := ["ramp"] if ramp else ["range", "close"]
		for foe in FOES[group.substr(0, 1)]:
			for scen in scens:
				for who in ["M", "G"]:
					var mp := musk_price(who)
					var budget: float = n_men * (mp[0] + mp[1])
					var fp: Array = PRICE[foe]
					var nf := maxi(1, int(round(budget / (float(fp[0]) + float(fp[1])))))
					for hp in hps:
						out.append({"name": "%s_%s_%s_%s_%s" % [group, foe, scen, who, hp.replace("/", "-")], "who": who, "foe": foe,
							"n_foe": nf, "scen": scen, "hp": hp})
	if only != "":
		out = out.filter(func(c) -> bool: return c["name"] == only)
	return out


# ------------------------------------------------------------------ the field (as tools/study_raptor_spitter.gd)

func _hall(team: int) -> Building:
	for b in g.buildings:
		if b.team == team and not b.dead and b.kind in ["hive", "town_hall", "clocktower"]:
			return b
	return null


func _home(team: int) -> Vector2:
	var h := _hall(team)
	if h:
		return h.center()
	return g.cell_center(g.starts[team]) if g.starts.size() > team else Vector2.ZERO


func _free_near(p: Vector2, lv: int, r0 := 8.0) -> Vector2:
	for r in 14:
		for i in maxi(1, r * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, r * 6.0)) * r * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, r0, 0):
				return q
	return p


func _open(c: Vector2i, r: int) -> bool:
	if not g.in_map(c):
		return false
	var lv := int(g.height[g.idx(c)])
	for yy in range(-r, r + 1):
		for xx in range(-r, r + 1):
			var cc := c + Vector2i(xx, yy)
			if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or int(g.height[g.idx(cc)]) != lv or g.solid[g.idx(cc)] != 0:
				return false
	return true


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


var wall_pieces: Array = []
var wall_plan: Array = []


func _ramp_setup() -> Array:
	var ai: AI = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	var plan: Dictionary = ai.plan_cottage_wall()
	var bands: Array = ai._ramp_bands()
	var band: Array = bands[0]["band"]
	var rampc: Array = bands[0]["ramp"]
	var bc := Vector2.ZERO
	for c in band:
		bc += g.cell_center(c)
	bc /= band.size()
	var rc := Vector2.ZERO
	for c in rampc:
		rc += g.cell_center(c)
	rc /= rampc.size()
	var dir: Vector2 = (rc - bc).normalized()
	wall_plan = [["cottage", plan["cottage"]]]
	for e in plan["pieces"]:
		wall_plan.append([e[0], e[1]])
	for e in wall_plan:
		wall_pieces.append(g._add_building(e[0], 0, e[1], true))
	var kept_p: Array = []
	var kept_b: Array = []
	for i in wall_pieces.size():
		if is_instance_valid(wall_pieces[i]) and not wall_pieces[i].dead:
			kept_p.append(wall_plan[i])
			kept_b.append(wall_pieces[i])
	wall_plan = kept_p
	wall_pieces = kept_b
	print("wall: %s" % str(wall_plan))
	var lv := int(g.height[g.idx(band[0])])
	var line_mid := _free_near(bc - dir * 90.0, lv)
	var foot := rc
	for i in 40:
		var q: Vector2 = rc + dir * (i * 16.0)
		var c: Vector2i = g.cell_of(q)
		if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < lv and _open(c, 3):
			foot = q + dir * 200.0
			break
	var flv := int(g.height[g.idx(g.cell_of(foot))])
	foot = _free_near(foot, flv)
	return [line_mid, dir, foot]


# ------------------------------------------------------------------ one fight

func _price(u: Unit, who: String) -> Array:
	if u.kind == "musketeer":
		return musk_price(who)
	if PRICE.has(u.kind):
		return PRICE[u.kind]
	return [float(u.d.get("cost", 0)), float(u.d.get("cost2", 0))]


func _add(k: String, team: int, p: Vector2, lv: int, list: Array) -> Unit:
	var u: Unit = g._add_unit(k, team, _free_near(p, lv, float(Defs.UNITS[k]["radius"])))
	u.auto_work = false
	u._sep_n = list.size() % 3
	u.scan_t = float(list.size() % 10) / 30.0
	list.append(u)
	return u


func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _musk_shots(crown: Array) -> int:
	var n := 0.0
	for u in crown:
		if is_instance_valid(u) and u.kind == "musketeer":
			n += u._pmax - u.powder
	return int(round(n))


## Is any enemy within melee reach (its radius + the man's + 14 px) of a man of the line?
func _contact(crown: Array, foes: Array) -> bool:
	for u in _alive(crown):
		for o in _alive(foes):
			if o.position.distance_to(u.position) < u.radius + o.radius + 14.0:
				return true
	return false


func _line(crown: Array, who: String, mid: Vector2, dir: Vector2, lv0: int, rng: RandomNumberGenerator) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var per_rank := int(ceil(n_men / 2.0))
	for i in n_men:
		var rank := i / per_rank
		var j := i % per_rank
		var along := (j - (per_rank - 1) / 2.0) * 24.0 + rank * 12.0
		var p: Vector2 = mid + perp * along - dir * rank * 26.0 + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		var u := _add("musketeer", 0, p, lv0, crown)
		u.set_kit(KITS[who])
		u.powder = u._pmax
		u.cmd_hold()


func fight(c: Dictionary, s: int) -> Dictionary:
	seed(1000 + s * 7919)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s * 131
	for k in TECH:
		g.players[0]["tech"][k] = true
	_hp = MH.parse(String(c["hp"]))
	var mid: Vector2
	var dir: Vector2
	var bspot: Vector2
	if ramp:
		if _ramp_cache.is_empty():
			_ramp_cache = _ramp_setup()
		mid = _ramp_cache[0]
		dir = _ramp_cache[1]
		bspot = _ramp_cache[2]
		for b in wall_pieces:
			if is_instance_valid(b) and not b.dead:
				b.hp = b.max_hp
	else:
		if _field_cache.is_empty():
			_field_cache = _field()
			print("field at %s, facing %s" % [str(_field_cache[0]), str(_field_cache[1])])
		mid = _field_cache[0]
		dir = _field_cache[1]
		bspot = mid + dir * (70.0 if c["scen"] == "close" else 480.0)
	var lv0 := int(g.height[g.idx(g.cell_of(mid))])
	var lv1 := int(g.height[g.idx(g.cell_of(bspot))])
	var perp := Vector2(-dir.y, dir.x)
	var crown: Array = []
	var foes: Array = []
	_line(crown, c["who"], mid, dir, lv0, rng)
	var fk: String = c["foe"]
	var nf: int = c["n_foe"]
	var sp: float = maxf(18.0, float(Defs.UNITS[fk]["radius"]) * 2.0 + 4.0)
	var cols := maxi(1, int(ceil(sqrt(nf * 1.6))))
	if c["scen"] == "close":
		cols = maxi(cols, mini(nf, n_men / 2 + 1))     # (caught along the line's front, not in a deep column)
	for i in nf:
		var row := i / cols
		var col := i % cols
		var p: Vector2 = bspot + dir * (row * sp) + perp * ((col - (cols - 1) / 2.0) * sp)
		p += Vector2(rng.randf_range(-sp * 0.25, sp * 0.25), rng.randf_range(-sp * 0.25, sp * 0.25))
		_add(fk, 1, p, lv1, foes)
	await physics_frame
	MH.apply(g, _hp[0], _hp[1])
	var hp0: float = crown[0].max_hp
	var goal: Vector2 = _home(0) if ramp else mid
	for u in foes:
		u.cmd_move(goal, true)
	var t0: float = g.clock
	var contact_t := -1.0
	var shots_at_contact := -1
	var foe_lost_at_contact := 0
	var first_man_t := -1.0
	var half_line_t := -1.0
	while g.clock - t0 < 180.0:
		await wait(0.25)
		var a0 := _alive(crown)
		var a1 := _alive(foes)
		if contact_t < 0.0 and _contact(crown, foes):
			contact_t = snapped(g.clock - t0, 0.25)
			shots_at_contact = _musk_shots(crown)
			foe_lost_at_contact = nf - a1.size()
		if first_man_t < 0.0 and a0.size() < n_men:
			first_man_t = snapped(g.clock - t0, 0.25)
		if half_line_t < 0.0 and a0.size() <= n_men / 2:
			half_line_t = snapped(g.clock - t0, 0.25)
		if a0.is_empty() or a1.is_empty():
			break
		var at := Vector2.ZERO
		for u in a0:
			at += u.position
		at /= a0.size()
		for u in a1:
			if u.order == "idle" and u.target == null:
				u.cmd_move(at, true)
	var dur: float = g.clock - t0
	var r := {"name": c["name"], "seed": s, "who": c["who"], "foe": fk, "n_foe": nf, "n": n_men, "scen": c["scen"], "hp": c["hp"],
		"max_hp": hp0, "time": snapped(dur, 0.25), "contact_t": contact_t, "shots_at_contact": shots_at_contact,
		"foe_lost_at_contact": foe_lost_at_contact, "first_man_t": first_man_t, "half_line_t": half_line_t,
		"shots": _musk_shots(crown)}
	for side in [["crown", crown], ["foe", foes]]:
		var cost := 0.0
		var lost := 0.0
		var left_hp := 0.0
		var nalive := 0
		for u in side[1]:
			var pr := _price(u, c["who"])
			var v: float = pr[0] + pr[1]
			cost += v
			if not is_instance_valid(u) or u.dead:
				lost += v
			else:
				nalive += 1
				left_hp += u.hp
		r[side[0] + "_cost"] = snapped(cost, 0.1)
		r[side[0] + "_lost"] = snapped(lost, 0.1)
		r[side[0] + "_alive"] = nalive
		r[side[0] + "_left_hp"] = snapped(left_hp, 1.0)
	var w := "draw"
	if _alive(foes).is_empty() and not _alive(crown).is_empty():
		w = "crown"
	elif _alive(crown).is_empty() and not _alive(foes).is_empty():
		w = "foe"
	r["winner"] = w
	if ramp:
		var broken := 0
		var wl := 0.0
		for b in wall_pieces:
			if not is_instance_valid(b) or b.dead:
				broken += 1
			else:
				wl += b.max_hp - b.hp
		r["wall_broken"] = broken
		r["wall_dmg"] = snapped(wl, 1.0)
	await _clear()
	return r


func _clear() -> void:
	for z in g.zones:
		z["age"] = maxf(float(z["age"]), float(z["t"]))
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN and u.kind != "brood_mother":
			g.consume_unit(u)
	if ramp:
		for i in wall_pieces.size():
			var b = wall_pieces[i]
			if not is_instance_valid(b) or b.dead:
				wall_pieces[i] = g._add_building(wall_plan[i][0], 0, wall_plan[i][1], true)
	await wait(1.0)


# ------------------------------------------------------------------ the Toad's TONGUE (group T)

func tongue(c: Dictionary, s: int) -> Dictionary:
	seed(1000 + s * 7919)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s * 131
	for k in TECH:
		g.players[0]["tech"][k] = true
	_hp = MH.parse(String(c["hp"]))
	if _field_cache.is_empty():
		_field_cache = _field()
	var mid: Vector2 = _field_cache[0]
	var dir: Vector2 = _field_cache[1]
	var perp := Vector2(-dir.y, dir.x)
	var lv := int(g.height[g.idx(g.cell_of(mid))])
	var crown: Array = []
	var foes: Array = []
	_line(crown, c["who"], mid, dir, lv, rng)
	# the Toad 200 px in front of the line's front man nearest the middle (beyond 190, within the tongue's 224)
	var toad_at: Vector2 = mid + dir * 200.0 + perp * rng.randf_range(-20, 20)
	var toad := _add("mist_toad", 1, toad_at, lv, foes)
	toad.charge = float(Defs.TOAD["max"])
	var raps: Array = []
	for i in int(c["raptors"]):
		var p: Vector2 = toad_at + dir * 26.0 + perp * ((i - (c["raptors"] - 1) / 2.0) * 18.0)
		raps.append(_add("raptor", 1, p, lv, foes))
	for u in foes:
		u.cmd_hold()
	await physics_frame
	MH.apply(g, _hp[0], _hp[1])
	await wait(0.5)
	var victim: Unit = null
	var bd := INF
	for u in crown:
		if toad.can_tongue(u) and u.position.distance_to(toad.position) < bd:
			bd = u.position.distance_to(toad.position)
			victim = u
	var r := {"name": c["name"], "seed": s, "who": c["who"], "raptors": c["raptors"], "hp": c["hp"], "max_hp": crown[0].max_hp,
		"scen": "tongue", "foe": "tongue"}
	if victim == null:
		r["result"] = "no target"
		await _clear()
		return r
	# (the rest of the line is busy with the fight in front of it: it holds its fire, so only the pulled man and the
	# creatures at the Toad's feet decide it)
	for u in crown:
		if u != victim:
			u.hold_fire = true
	toad.cmd_tongue(victim)
	var t0: float = g.clock
	var min_hp: float = victim.hp
	var raps_at_land := -1
	var landed := -1.0
	var ordered := -1.0
	var stage_seen := ""
	var hp_landed := -1.0
	while g.clock - t0 < 25.0:
		await physics_frame
		if not is_instance_valid(victim) or victim.dead:
			break
		var st: String = toad.tongue_stage if is_instance_valid(toad) and not toad.dead else ""
		if st != "":
			stage_seen = st if st == "pull" or stage_seen != "pull" else stage_seen
		if landed < 0.0 and stage_seen == "pull" and st == "":
			landed = g.clock - t0
			hp_landed = victim.hp
			raps_at_land = _alive(raps).size()
			if OS.get_cmdline_user_args().has("dbg"):
				print("landed: victim %.0f px from the Toad (alive %s), %d Raptors alive, toad hp %.0f, victim stun %.2f" % [
					victim.position.distance_to(toad.position), str(not toad.dead), raps_at_land, toad.hp, victim.stun_t])
			for rp in _alive(raps):
				rp.cmd_attack(victim)
		if landed >= 0.0 and ordered < 0.0 and victim.stun_t <= 0.0 and g.clock - t0 > landed + 0.5:
			ordered = g.clock - t0
			victim.cmd_move(mid - dir * 30.0, false)       # (a player pulls him back to the line)
		min_hp = minf(min_hp, victim.hp)
		if landed < 0.0 and stage_seen == "" and g.clock - t0 > 6.0:
			break                                           # (the tongue broke)
		if landed >= 0.0 and victim.position.distance_to(mid) < 120.0:
			break                                           # (he is back at the line: safe)
	var dead: bool = not is_instance_valid(victim) or victim.dead
	r["result"] = "no pull" if landed < 0.0 else ("killed" if dead else "escaped")
	r["landed_t"] = snapped(landed, 0.05)
	r["hp_landed"] = snapped(hp_landed, 1.0)
	r["death_after_land"] = snapped(g.clock - t0 - landed, 0.05) if dead and landed >= 0.0 else -1.0
	r["hp_left"] = 0.0 if dead else snapped(victim.hp, 1.0)
	r["toad_dead"] = not is_instance_valid(toad) or toad.dead
	r["min_hp"] = 0.0 if dead else snapped(min_hp, 1.0)
	r["raps_at_land"] = raps_at_land
	await _clear()
	return r


# ------------------------------------------------------------------ the run

var _ramp_cache: Array = []
var _field_cache: Array = []


func _run() -> void:
	await wait(1.0)
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN:
			g.consume_unit(u)
	g.players[0]["cap"] = 400
	g.players[1]["cap"] = 400
	var list := configs()
	print("STUDY group %s: %d configs x %d seeds, map %s" % [group, list.size(), n_seeds, map])
	for c in list:
		for s in n_seeds:
			var r: Dictionary
			if c["scen"] == "tongue":
				r = await tongue(c, s)
			else:
				r = await fight(c, s)
			if _out:
				_out.store_line(JSON.stringify(r))
				_out.flush()
			if c["scen"] == "tongue":
				print("%-22s s%d %s landed %.2f hp_landed %s death_after %s hp_left %s" % [r["name"], s, r["result"], r.get("landed_t", -1),
					str(r.get("hp_landed", -1)), str(r.get("death_after_land", -1)), str(r.get("hp_left", -1))])
			else:
				print("%-34s s%d %-5s %5.1fs hp%d contact %.1f shots@c %d foe lost@c %d | crown lost %.0f alive %d | foe %d lost %.0f alive %d" % [
					r["name"], s, r["winner"], r["time"], int(r["max_hp"]), r["contact_t"], r["shots_at_contact"], r["foe_lost_at_contact"],
					r["crown_lost"], r["crown_alive"], r["n_foe"], r["foe_lost"], r["foe_alive"]])
	if _out:
		_out.close()
	print("STUDY DONE")
	quit(0)
