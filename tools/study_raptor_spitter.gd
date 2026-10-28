extends SceneTree
## THE RAPTOR + SPITTER STUDY (the owner, 2026-10-28; docs/raptor_spitter_study.md). A study: no game number is changed.
## Controlled fights at equal cost: a Crown line standing on HOLD (Musketeers in two ranks, guns 70 px behind) against
## a Brood wave that attack-moves in (Raptors in front, Spitters behind, as a player sends them).
##
##   godot --headless --fixed-fps 30 --script res://tools/study_raptor_spitter.gd -- group:<g> [seeds:3] [out:/abs/runs.jsonl]
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/study_raptor_spitter.gd \
##       -- only:<config name> seeds:1 film:/abs/dir          (a frame every 0.5 s and a few stills, for a GIF)
##
## Groups (each a list of configs, all run on `seeds` jittered seeds):
##   A    Raptors only vs Musketeers, at 600, 1200 and 2000 resources a side
##   B    Raptors + Spitters (3:1, 2:1, 1:1 by cost) vs Musketeers, same sizes
##   C    Musketeers + 1 or 2 Field Cannons vs Raptors + Spitters (3:1 and 1:1), same sizes
##   D    Musketeers + 1 Field Cannon vs Raptors only, same sizes
##   V    variants at 1200: Spitters leading, spread out, a Mortar, the late kit (Armour, Flintlock, Pouch)
##   R    the ramp: A, B and C at 1200 against the Crown's own wall and gate (Greenhold, the AI's Cottage wall plan)
##   E    the new Brood (slot faction brood_new): Raptors only, as A (it has no Spitters yet)
##   S    break-even scan: the 1200 Brood mixes against 8 to 22 Musketeers
## One line of JSON a fight goes to out: (and a short line to the console).
##
## Prices (Defs.UNITS; Game.unit_price for the Musketeer's kit): a Raptor egg 75 biomass for 3 (25 each), a Spitter egg
## 90 biomass + 5 essence for 2 (45 + 2.5 each), a Musketeer 60 gold + 10 powder plus the kit's refit fees (mid kit:
## Matchlock 8 + Bayonet 3 = 71 gold + 10 powder), a Field Cannon 170 gold + its horse 40, a Mortar 145 + 20 powder + 40.
## The research itself (the Armoury's price) is not counted: it is paid once for the whole army.

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var group := "A"
var only := ""
var n_seeds := 3
var out_path := ""
var film := ""
var _out: FileAccess = null
var map := "dune_sea"
var ramp := false
var nb := false

const RAPTOR := [25.0, 0.0]
const SPITTER := [45.0, 2.5]
const GUN := {"cannon": [210.0, 0.0], "mortar": [185.0, 20.0]}
const KITS := {
	"mid": {"lock": "matchlock", "bayonet": true},
	"late": {"lock": "flintlock", "bayonet": true, "armour": true, "pouch": true},
}
const TECH := {"mid": ["matchlock", "bayonet"], "late": ["matchlock", "flintlock", "bayonet", "armour", "pouch"]}


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("group:"):
			group = a.substr(6)
		elif a.begins_with("only:"):
			only = a.substr(5)
		elif a.begins_with("seeds:"):
			n_seeds = int(a.substr(6))
		elif a.begins_with("out:"):
			out_path = a.substr(4)
		elif a.begins_with("film:"):
			film = a.substr(5)
	if only != "":
		group = only.substr(0, 1)
	ramp = group == "R"
	nb = group == "E"
	if ramp:
		map = "greenhold"
	if out_path != "":
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not begun:
		if t > 0.2:
			begun = true
			if film == "":
				root.add_child(SilentSfx.new())
			main.start({"map": map, "seed": 4242, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": Defs.BROOD_NEW if nb else "brood", "colour": 1, "side": 1}]})
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

## A Brood mix worth `budget` with `share` of it in Raptors (by cost), in whole eggs: [raptors, spitters].
func brood_mix(budget: float, share: float) -> Array:
	var eggs_r := int(round(budget * share / 75.0))
	var rest := budget - eggs_r * 75.0
	var eggs_s := int(round(rest / 95.0))
	return [eggs_r * 3, eggs_s * 2]


## Musketeers (and guns) worth about `budget` at face value (gold + powder): [musketeers, guns].
func crown_mix(budget: float, guns: int, gun := "cannon", kit := "mid") -> Array:
	var gp: Array = GUN[gun]
	var left: float = budget - guns * (float(gp[0]) + float(gp[1]))
	var mp := musk_price(kit)
	return [maxi(1, int(round(left / (float(mp[0]) + float(mp[1]))))), guns]


func musk_price(kit: String) -> Array:
	var f := Game.kit_fee(KITS[kit], "musketeer")
	return [60.0 + f[0], 10.0 + f[1]]


func cfg(name: String, musk: int, guns: int, raptors: int, spitters: int, extra := {}) -> Dictionary:
	var c := {"name": name, "musk": musk, "guns": guns, "gun": "cannon", "raptors": raptors, "spitters": spitters,
		"form": "front", "sp": 18.0, "kit": "mid"}
	c.merge(extra, true)
	return c


func configs() -> Array:
	var out: Array = []
	var sizes := [600.0, 1200.0, 2000.0]
	match group:
		"A", "E":
			for s in sizes:
				var m: Array = crown_mix(s, 0)
				out.append(cfg("%s_%d" % [group, s], m[0], 0, int(round(s / 75.0)) * 3, 0))
		"B":
			for s in sizes:
				var m: Array = crown_mix(s, 0)
				for r in [[3, 0.75], [2, 0.667], [1, 0.5]]:
					var b: Array = brood_mix(s, r[1])
					out.append(cfg("B_%d_%d1" % [s, r[0]], m[0], 0, b[0], b[1]))
		"C":
			for s in sizes:
				for guns in [1, 2]:
					if s < 1000.0 and guns == 2:
						continue
					var m: Array = crown_mix(s, guns)
					for r in [[3, 0.75], [1, 0.5]]:
						var b: Array = brood_mix(s, r[1])
						out.append(cfg("C_%d_g%d_%d1" % [s, guns, r[0]], m[0], guns, b[0], b[1]))
		"D":
			for s in sizes:
				var m: Array = crown_mix(s, 1)
				out.append(cfg("D_%d_g1" % s, m[0], 1, int(round(s / 75.0)) * 3, 0))
		"V":
			var s := 1200.0
			var m0: Array = crown_mix(s, 0)
			for r in [[3, 0.75], [1, 0.5]]:
				var b: Array = brood_mix(s, r[1])
				out.append(cfg("V_lead_%d1" % r[0], m0[0], 0, b[0], b[1], {"form": "lead"}))
				out.append(cfg("V_spread_%d1" % r[0], m0[0], 0, b[0], b[1], {"sp": 34.0}))
				var mm: Array = crown_mix(s, 1, "mortar")
				out.append(cfg("V_mortar_%d1" % r[0], mm[0], 1, b[0], b[1], {"gun": "mortar"}))
				var ml: Array = crown_mix(s, 0, "cannon", "late")
				out.append(cfg("V_late_%d1" % r[0], ml[0], 0, b[0], b[1], {"kit": "late"}))
				var mlc: Array = crown_mix(s, 1, "cannon", "late")
				out.append(cfg("V_latecan_%d1" % r[0], mlc[0], 1, b[0], b[1], {"kit": "late"}))
			out.append(cfg("V_late_raptors", m0[0], 0, int(round(s / 75.0)) * 3, 0, {"kit": "late"}))
			out[-1]["musk"] = crown_mix(s, 0, "cannon", "late")[0]
		"R":
			var s := 1200.0
			var m: Array = crown_mix(s, 0)
			var m1: Array = crown_mix(s, 1)
			out.append(cfg("R_raptors", m[0], 0, int(round(s / 75.0)) * 3, 0))
			for r in [[3, 0.75], [2, 0.667], [1, 0.5]]:
				var b: Array = brood_mix(s, r[1])
				out.append(cfg("R_%d1" % r[0], m[0], 0, b[0], b[1]))
				out.append(cfg("R_g1_%d1" % r[0], m1[0], 1, b[0], b[1]))
		"S":
			var s := 1200.0
			for r in [[99, 1.0], [3, 0.75], [1, 0.5]]:
				var b: Array = brood_mix(s, r[1])
				for nm in [8, 11, 14, 17, 20, 23]:
					out.append(cfg("S_%d1_m%d" % [r[0], nm], nm, 0, b[0], b[1]))
	if only != "":
		out = out.filter(func(c) -> bool: return c["name"] == only)
	return out


# ------------------------------------------------------------------ the field

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


## A free spot on p's level near p (spiral out a few px at a time).
func _free_near(p: Vector2, lv: int) -> Vector2:
	for r in 12:
		for i in maxi(1, r * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, r * 6.0)) * r * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, 8.0, 0):
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


## The open-field battlefield: the flat, clear stretch of the map nearest its middle, 34 tiles long (from 10 behind the
## Crown line to 24 past it, along `dir`) and 19 wide, all on one level with no ramp or cliff. [middle, dir]
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


## The ramp: the Crown's Cottage wall (AI.plan_cottage_wall) built at its main ramp, its men on the high ground
## behind it, the Brood at the ramp's foot. Returns [crown line middle, line direction (towards the enemy), brood spot].
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
	var dir: Vector2 = (rc - bc).normalized()       # (down the ramp: towards the enemy)
	wall_plan = [["cottage", plan["cottage"]]]
	for e in plan["pieces"]:
		wall_plan.append([e[0], e[1]])
	for e in wall_plan:
		wall_pieces.append(g._add_building(e[0], 0, e[1], true))
	# (a gate laid on a palisade piece takes its place: keep only what stands)
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
	# the ramp's foot: walk down from the ramp's middle until we are off it, on the low ground
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

func _price(u: Unit, kit: String) -> Array:
	match u.kind:
		"raptor":
			return RAPTOR
		"spitter":
			return SPITTER
		"musketeer":
			return musk_price(kit)
		"cannon", "mortar":
			return GUN[u.kind]
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


func fight(c: Dictionary, s: int) -> Dictionary:
	seed(1000 + s * 7919)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s * 131
	for k in TECH[c["kit"]]:
		g.players[0]["tech"][k] = true
	var mid: Vector2
	var dir: Vector2
	var bspot: Vector2
	if ramp:
		if _ramp_cache.is_empty():
			_ramp_cache = _ramp_setup()
		var rs := _ramp_cache
		mid = rs[0]
		dir = rs[1]
		bspot = rs[2]
		for b in wall_pieces:
			if is_instance_valid(b) and not b.dead:
				b.hp = b.max_hp
	else:
		if _field_cache.is_empty():
			_field_cache = _field()
			print("field at %s, facing %s" % [str(_field_cache[0]), str(_field_cache[1])])
		mid = _field_cache[0]
		dir = _field_cache[1]
		bspot = mid + dir * 480.0
	var lv0 := int(g.height[g.idx(g.cell_of(mid))])
	var lv1 := int(g.height[g.idx(g.cell_of(bspot))])
	var perp := Vector2(-dir.y, dir.x)
	var crown: Array = []
	var brood: Array = []
	# the Crown line: two ranks, 24 px apart along the line, the second rank 26 px back and staggered
	var nm: int = c["musk"]
	var per_rank := int(ceil(nm / 2.0))
	for i in nm:
		var rank := i / per_rank
		var j := i % per_rank
		var along := (j - (per_rank - 1) / 2.0) * 24.0 + rank * 12.0
		var p: Vector2 = mid + perp * along - dir * rank * 26.0 + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		var u := _add("musketeer", 0, p, lv0, crown)
		u.set_kit(KITS[c["kit"]])
		u.powder = u._pmax        # (the pouch refit keeps what he had: a player's army has filled it since)
	for i in int(c["guns"]):
		var gp: Vector2 = mid - dir * 75.0 + perp * ((i - (c["guns"] - 1) / 2.0) * 70.0)
		_add(c["gun"], 0, gp, lv0, crown)
	for u in crown:
		if u.deploys():
			u.cmd_deploy()
		else:
			u.cmd_hold()
	# the Brood wave: Raptors in front (towards the Crown), Spitters 110 px behind; "lead" swaps them
	var sp: float = c["sp"]
	var front_k := "spitter" if c["form"] == "lead" else "raptor"
	var back_k := "raptor" if c["form"] == "lead" else "spitter"
	var nf: int = c["spitters"] if c["form"] == "lead" else c["raptors"]
	var nb_: int = c["raptors"] if c["form"] == "lead" else c["spitters"]
	for pair in [[front_k, nf, 0.0], [back_k, nb_, 110.0 + sqrt(float(nf)) * sp * 0.5]]:
		var k: String = pair[0]
		var n: int = pair[1]
		var cols := maxi(1, int(ceil(sqrt(n * 1.6))))
		for i in n:
			var row := i / cols
			var col := i % cols
			var p: Vector2 = bspot + dir * (float(pair[2]) + row * sp) + perp * ((col - (cols - 1) / 2.0) * sp)
			p += Vector2(rng.randf_range(-sp * 0.3, sp * 0.3), rng.randf_range(-sp * 0.3, sp * 0.3))
			_add(k, 1, p, lv1, brood)
	await wait(3.0)        # (the guns unlimber: 2.5 s)
	for u in crown:
		if u.deploys():
			u.cmd_hold()
	var goal: Vector2 = _home(0) if ramp else mid
	var held: Array = []
	for u in brood:
		if c["form"] == "lead" and u.kind == "raptor":
			held.append(u)
			continue
		u.cmd_move(goal, true)
	var supply0 := 0
	var supply1 := 0
	for u in crown:
		supply0 += int(u.d["supply"])
	for u in brood:
		supply1 += int(u.d["supply"])
	var t0: float = g.clock
	var shots := 0
	var released := held.is_empty()
	var frame := 0
	while g.clock - t0 < 180.0:
		if film != "":
			await _film_frame(crown, brood, frame, c["name"])
			frame += 1
		await wait(0.5)
		var a0 := _alive(crown)
		var a1 := _alive(brood)
		if a0.is_empty() or a1.is_empty():
			break
		if not released:
			var go := g.clock - t0 > 30.0
			for u in brood:
				if u.kind == "spitter" and is_instance_valid(u) and not u.dead and u.target != null:
					go = true
			for u in crown:
				if is_instance_valid(u) and (u.dead or u.hp < u.max_hp):
					go = true
			if go:
				released = true
				for u in held:
					if is_instance_valid(u) and not u.dead:
						u.cmd_move(goal, true)
		# (a player keeps his wave at it: idle creatures are sent on again)
		var at: Vector2 = Vector2.ZERO
		for u in a0:
			at += u.position
		at /= a0.size()
		for u in a1:
			if (released or not held.has(u)) and u.order == "idle" and u.target == null:
				u.cmd_move(at, true)
	var dur: float = g.clock - t0
	var r := {"name": c["name"], "seed": s, "musk": c["musk"], "guns": c["guns"], "gun": c["gun"], "raptors": c["raptors"],
		"spitters": c["spitters"], "form": c["form"], "sp": c["sp"], "kit": c["kit"], "ramp": ramp, "nb": nb, "time": snapped(dur, 0.5),
		"supply_crown": supply0, "supply_brood": supply1}
	for side in [["crown", crown], ["brood", brood]]:
		var cost := [0.0, 0.0]
		var lost := [0.0, 0.0]
		var left := [0.0, 0.0]
		var left_hp := 0.0
		var alive := {}
		for u in side[1]:
			var pr := _price(u, c["kit"])
			cost[0] += pr[0]
			cost[1] += pr[1]
			if not is_instance_valid(u) or u.dead:
				lost[0] += pr[0]
				lost[1] += pr[1]
			else:
				left[0] += pr[0]
				left[1] += pr[1]
				left_hp += (pr[0] + pr[1]) * u.hp / maxf(1.0, u.max_hp)
				alive[u.kind] = int(alive.get(u.kind, 0)) + 1
		r[side[0] + "_cost"] = cost
		r[side[0] + "_lost"] = lost
		r[side[0] + "_left"] = left
		r[side[0] + "_left_hp"] = snapped(left_hp, 1.0)
		r[side[0] + "_alive"] = alive
	var w := "draw"
	if _alive(brood).is_empty() and not _alive(crown).is_empty():
		w = "crown"
	elif _alive(crown).is_empty() and not _alive(brood).is_empty():
		w = "brood"
	r["winner"] = w
	if ramp:
		var wl := 0.0
		var broken := 0
		var pieces: Array = []
		for i in wall_pieces.size():
			var b = wall_pieces[i]
			if not is_instance_valid(b) or b.dead:
				broken += 1
				pieces.append("%s gone" % wall_plan[i][0])
			else:
				wl += b.max_hp - b.hp
				pieces.append("%s %d" % [wall_plan[i][0], int(b.hp)])
		r["wall"] = pieces
		r["wall_broken"] = broken
		r["wall_dmg"] = snapped(wl, 1.0)
	if film != "":
		await _film_frame(crown, brood, frame, c["name"], true)
	# clear the field (bodies too) for the next fight
	for u in crown + brood:
		if is_instance_valid(u):
			g.consume_unit(u)
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.dead:
			g.consume_unit(u)
	if ramp:
		# (rebuild what fell, where it stood)
		for i in wall_pieces.size():
			var b = wall_pieces[i]
			if not is_instance_valid(b) or b.dead:
				wall_pieces[i] = g._add_building(wall_plan[i][0], 0, wall_plan[i][1], true)
	await wait(1.0)
	return r


var _ramp_cache: Array = []
var _field_cache: Array = []


func _film_frame(crown: Array, brood: Array, i: int, name: String, last := false) -> void:
	var a0 := _alive(crown)
	var a1 := _alive(brood)
	if a0.is_empty() and a1.is_empty():
		return
	var c := Vector2.ZERO
	for side in [a0, a1]:
		if side.is_empty():
			continue
		var m := Vector2.ZERO
		for u in side:
			m += u.position
		c += m / side.size() * (0.5 if not a0.is_empty() and not a1.is_empty() else 1.0)
	g.camera.position = c
	g.camera.zoom = Vector2(0.8, 0.8)
	if g.hud:
		g.hud.visible = false
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%03d.png" % [film, name, i])
	if last:
		img.save_png("%s/%s_end.png" % [film, name])


# ------------------------------------------------------------------ the run

func _clear_start() -> void:
	# the starting workers (and the new Brood's grubs) go: only the fight's own units on the map
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN:
			g.consume_unit(u)


func _run() -> void:
	await wait(1.0)
	_clear_start()
	g.players[0]["cap"] = 400
	g.players[1]["cap"] = 400
	var list := configs()
	print("STUDY group %s: %d configs x %d seeds, map %s" % [group, list.size(), n_seeds, map])
	for c in list:
		for s in n_seeds:
			var r: Dictionary = await fight(c, s)
			var line := JSON.stringify(r)
			if _out:
				_out.store_line(line)
				_out.flush()
			print("%-18s s%d  %-5s %5.1fs  crown %d musk+%d %s lost %s left %s | brood %dR+%dS lost %s left %s" % [
				r["name"], s, r["winner"], r["time"], r["musk"], r["guns"], r["gun"], str(r["crown_lost"]), str(r["crown_alive"]),
				r["raptors"], r["spitters"], str(r["brood_lost"]), str(r["brood_alive"])])
	if _out:
		_out.close()
	print("STUDY DONE")
	quit(0)
