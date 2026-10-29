extends SceneTree
## THE CROWN TURTLE STUDY (the owner, 2026-10-29; docs/crown_turtle_study.md). A study: no game number is changed; the
## variants are set on the spawned units inside this tool only.
## A dug-in Crown at its main ramp (the Crown computer's own Cottage wall plan, Musketeers in two ranks on HOLD behind
## it, Field Cannons (or a cannon and a Mortar), two Horsemen behind the gate, a Powder Wagon with haulers, Labourers
## mending the wall and the guns), against a coached siege army at 1.0, 1.5 and 2.0 times its cost (x10, x15, x20).
## The army gathers out of sight at the ramp's foot (300 px down from the gate), then goes in together (_muster_tick).
##   CW   the Clockwork: Clock Soldiers (SHIELD WALL, raised by the computer's own rule), Springers and a Netter on the
##        menders (the Clockwork computer's own siege prey, AI._siege_prey; HIGH LEAP by AI._springer_leaps), a Spring
##        Ballista bombarding the gate, a Pendulum, a Great Winder and two Winders mending the army. "bsiege": four
##        Ballistas (eight at x15) bombard the Musketeer line from 290 px for up to 120 s first. "norepair": no menders.
##   OB   the old Brood: Raptors, Brutes, Spitters, two Mist Toads (full energy: FOG on the line, TONGUE); three Spitters
##        escort each Toad and shoot a Horseman riding at it ("noesc": no escort).
##   NB   the new Brood (slot faction brood_new): the same creatures (the Tyrannosaur is kept at home: sent with the wave,
##        he never reached the gate).
## Brood TONGUE rules: pull (as the game is now: a Field Cannon or Mortar is pulled whole), stagger (the guns are tagged
## "massive" on the spawned units: only staggered; the Toads then tongue a mender, a Horseman or a Musketeer instead),
## none (no Toads: their cost goes to Raptors). Crown play: "p" holds (HOLD, repair, nothing else); "r" a good player:
## the guns fire at any Toad in reach, and on a tongue warning every Musketeer in reach shoots the marked Toad and the
## Horsemen (Cavalry Charge) ride at it; "rwarn" only the warning's answer (the guns don't hunt Toads first); "rcav"
## only the Horsemen answer.
##
##   tools/study_crown_turtle.sh OUT_DIR 8 G M H                    (every config in its own process; resumes)
##   godot --headless --fixed-fps 30 --script res://tools/study_crown_turtle.gd -- only:<config> [seeds:8] [out:/abs/runs.jsonl]
##   ... -- only:<config> seeds:1 film:/abs/dir [zoom:1.35] [cap:90] [from:N]   (xvfb-run, opengl3: a frame every 0.5 s)
##   ... -- only:G_OB_list list                                      (a group's config names for one attacker)
## Groups: G Greenhold (two cannons), M Greenhold (a cannon and a Mortar), H Highmoor (two cannons; every map's main is
## the same template), L the limber test (can a deployed gun get 336 px away within the 3 s windup?).

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var group := "G"
var only := ""
var n_seeds := 8
var out_path := ""
var film := ""
var film_zoom := 1.0
var _out: FileAccess = null
var map := "greenhold"
var map_seed := 4242
var seed_from := 0          # (from:N: the first seed, to film one fight of a run)
var listing := false
var att := "OB"                 # the attacker of this process's configs (one faction a process: the slot is set at start)
var cap_t := 300.0
var verbose := false
var _rt0 := 0

const KIT := {"lock": "matchlock", "bayonet": true, "pouch": true}
const PRICE := {
	"raptor": [25.0, 0.0], "spitter": [45.0, 2.5], "brute": [150.0, 20.0], "mist_toad": [100.0, 25.0], "tyrannosaur": [200.0, 0.0],
	"clock_soldier": [70.0, 0.0], "springer": [100.0, 25.0], "netter": [125.0, 50.0], "pendulum": [200.0, 75.0],
	"ballista": [150.0, 50.0], "great_winder": [175.0, 75.0], "winder": [50.0, 0.0],
	"cannon": [210.0, 0.0], "mortar": [185.0, 20.0], "powder_wagon": [110.0, 30.0], "cuirassier": [155.0, 0.0],
	"labourer": [50.0, 0.0],
}


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
		elif a.begins_with("zoom:"):
			film_zoom = float(a.substr(5))
		elif a.begins_with("cap:"):
			cap_t = float(a.substr(4))
		elif a == "list":
			listing = true
		elif a == "verbose":
			verbose = true
	if only != "":
		group = only.get_slice("_", 0)
		att = only.get_slice("_", 1)
	if listing:
		if only.ends_with("_list"):
			only = ""          # (only:G_CW_list list: the group's configs for that attacker)
		for c in configs():
			print("CFG " + String(c["name"]))
		quit(0)
		return
	if group == "H":
		map = "highmoor"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("from:"):
			seed_from = int(a.substr(5))
		if a.begins_with("mseed:"):
			map_seed = int(a.substr(6))
		if a.begins_with("map:"):
			map = a.substr(4)
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
			if film == "":
				root.add_child(SilentSfx.new())
			var f1 := "brood"
			if att == "CW":
				f1 = "clockwork"
			elif att == "NB":
				f1 = Defs.BROOD_NEW
			main.start({"map": map, "seed": map_seed, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
				{"who": "hard", "faction": f1, "colour": 1, "side": 1}]})
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

func cfg(name: String, extra := {}) -> Dictionary:
	var c := {"name": name, "att": "OB", "mult": 1.0, "rule": "none", "react": false, "guns": ["cannon", "cannon"], "repair": true,
		"escort": true}
	c.merge(extra, true)
	return c


func configs() -> Array:
	var out: Array = []
	match group:
		"G", "H", "M":
			var guns: Array = ["cannon", "mortar"] if group == "M" else ["cannon", "cannon"]
			var mults: Array = [1.0, 1.5, 2.0] if group == "G" else [1.0]
			for m in mults:
				var ms := "x%d" % int(round(m * 10.0))
				out.append(cfg("%s_CW_%s" % [group, ms], {"att": "CW", "mult": m, "guns": guns}))
				for a in ["OB", "NB"]:
					if a == "NB" and m > 1.7:
						continue
					for rule in ["pull", "stagger", "none"]:
						var reacts: Array = [false, true] if (group == "G" and a == "OB" and rule != "none" and m < 1.7) else [false]
						for r in reacts:
							out.append(cfg("%s_%s_%s_%s_%s" % [group, a, ms, rule, "r" if r else "p"],
								{"att": a, "mult": m, "rule": rule, "react": r, "guns": guns}))
							if r and m < 1.2:
								# (the Brood's answer to the charge is Spitters escorting the Toads: here WITHOUT that escort)
								out.append(cfg("%s_%s_%s_%s_rnoesc" % [group, a, ms, rule],
									{"att": a, "mult": m, "rule": rule, "react": true, "guns": guns, "escort": false}))
								# (the answer to the WARNING only: the guns do not hunt Toads before a mark; with and without the escort)
								out.append(cfg("%s_%s_%s_%s_rwarn" % [group, a, ms, rule],
									{"att": a, "mult": m, "rule": rule, "react": true, "guns": guns, "gunprio": false}))
								out.append(cfg("%s_%s_%s_%s_rwarnnoesc" % [group, a, ms, rule],
									{"att": a, "mult": m, "rule": rule, "react": true, "guns": guns, "gunprio": false, "escort": false}))
			if group == "G":
				# (the warning's answer where the pull matters, and the charge alone against the Spitter escort)
				for m in [1.5, 2.0]:
					var ms := "x%d" % int(round(m * 10.0))
					for rule in ["pull", "stagger"]:
						out.append(cfg("G_OB_%s_%s_rwarn" % [ms, rule], {"att": "OB", "mult": m, "rule": rule, "react": true, "gunprio": false}))
					if m > 1.7:
						out.append(cfg("G_OB_%s_pull_r" % ms, {"att": "OB", "mult": m, "rule": "pull", "react": true}))
				for e in [true, false]:
					out.append(cfg("G_OB_x10_pull_rcav%s" % ("" if e else "noesc"), {"att": "OB", "rule": "pull", "react": true,
						"gunprio": false, "focus": false, "escort": e}))
				out.append(cfg("G_CW_x10_norepair", {"att": "CW", "repair": false}))
				out.append(cfg("G_CW_x10_bsiege", {"att": "CW", "bsiege": true}))
				out.append(cfg("G_CW_x15_bsiege", {"att": "CW", "mult": 1.5, "bsiege": true}))
		"L":
			out.append(cfg("L_OB_limber", {"att": "OB"}))
	if only != "":
		out = out.filter(func(c) -> bool: return c["name"] == only)
	else:
		out = out.filter(func(c) -> bool: return c["att"] == att)
	return out


# ------------------------------------------------------------------ the field (as tools/study_raptor_spitter.gd)

func _hall(team: int) -> Building:
	for b in g.buildings:
		if b.team == team and not b.dead and b.kind in ["hive", "town_hall", "clocktower"]:
			return b
	return null


func _free_near(p: Vector2, lv: int, r := 8.0) -> Vector2:
	for k in 14:
		for i in maxi(1, k * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, k * 6.0)) * k * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, r, 0):
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


var crown_ai: AI = null
var att_ai: AI = null
var wall_pieces: Array = []
var wall_plan: Array = []
var setup := {}


## The Crown computer's own wall at its main ramp; the line, the guns, the wagon and the attackers' muster.
func _ramp_setup() -> Dictionary:
	for a in g.ais:
		if a.team == 0:
			crown_ai = a
		else:
			att_ai = a
	var plan: Dictionary = crown_ai.plan_cottage_wall()
	var bands: Array = crown_ai._ramp_bands()
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
	var lv := int(g.height[g.idx(band[0])])
	var line_mid := _free_near(bc - dir * 90.0, lv)
	var foot := rc
	for i in 40:
		var q: Vector2 = rc + dir * (i * 16.0)
		var c: Vector2i = g.cell_of(q)
		if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < lv and _open(c, 3):
			foot = q
			break
	var flv := int(g.height[g.idx(g.cell_of(foot))])
	# the Crown base behind: a Powder Mill and a Barracks by the hall (the wagon's kegs, the haulers' trips)
	var hall := _hall(0)
	for k in ["powder_mill", "barracks"]:
		var sp: Vector2i = g.find_spot(0, k, hall, 3, 26, "near", true)
		if sp.x >= 0:
			g._add_building(k, 0, sp, true)
	var wall_cost := 0.0
	for e in wall_plan:
		wall_cost += float(Defs.BUILDINGS[e[0]]["cost"])
	var s := {"band_c": bc, "dir": dir, "line": line_mid, "lv": lv, "foot": foot, "flv": flv, "ramp_c": rc,
		"muster": _free_near(foot + dir * 260.0, flv, 10.0), "wall_cost": wall_cost}
	print("wall: %s (cost %d), line %s, foot %s, dir %s" % [str(wall_plan), int(wall_cost), str(line_mid), str(foot), str(dir)])
	return s


func _gate() -> Building:
	for b in wall_pieces:
		if is_instance_valid(b) and not b.dead and b.kind == "gate":
			return b
	return null


## The piece the attackers break: the gate, else the standing piece nearest the ramp.
func _piece() -> Building:
	var gt := _gate()
	if gt:
		return gt
	var best: Building = null
	var bd := INF
	for b in wall_pieces:
		if is_instance_valid(b) and not b.dead and b.kind != "cottage":
			var dd: float = b.center().distance_to(setup["ramp_c"])
			if dd < bd:
				bd = dd
				best = b
	return best


func _breached() -> bool:
	for b in wall_pieces:
		if not is_instance_valid(b) or b.dead:
			return true
	return false


# ------------------------------------------------------------------ spawning

func _add(k: String, team: int, p: Vector2, lv: int, list: Array) -> Unit:
	var u: Unit = g._add_unit(k, team, _free_near(p, lv, 10.0 if k != "great_winder" else 26.0))
	u.auto_work = false
	u._sep_n = list.size() % 3
	u.scan_t = float(list.size() % 10) / 30.0
	list.append(u)
	roster.append({"u": u, "kind": k, "team": team, "price": _price(u)})
	return u


var roster: Array = []      # every unit of this fight: its kind and price kept (a dead unit is freed later)

func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _price(u: Unit) -> Array:
	if u.kind == "musketeer":
		var f := Game.kit_fee(KIT, "musketeer")
		return [60.0 + f[0], 10.0 + f[1]]
	return PRICE.get(u.kind, [float(u.d.get("cost", 0)), float(u.d.get("cost2", 0))])


## The turtle: 16 Musketeers in two ranks on HOLD, the guns 80 px behind, two Horsemen behind the gate, a Powder Wagon
## behind the guns, 4 Labourers by the wall (menders) and 2 haulers at the hall. Returns [army, labourers, wagon].
func _turtle(c: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var mid: Vector2 = setup["line"]
	var dir: Vector2 = setup["dir"]
	var lv: int = setup["lv"]
	var perp := Vector2(-dir.y, dir.x)
	var army: Array = []
	var nm := 16
	var per_rank := 8
	for i in nm:
		var rank := i / per_rank
		var j := i % per_rank
		var along := (j - (per_rank - 1) / 2.0) * 22.0 + rank * 11.0
		var p: Vector2 = mid + perp * along - dir * rank * 24.0 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		var u := _add("musketeer", 0, p, lv, army)
		u.set_kit(KIT)
		u.powder = u._pmax
	var guns: Array = c["guns"]
	for i in guns.size():
		var gp: Vector2 = mid - dir * 85.0 + perp * ((i - (guns.size() - 1) / 2.0) * 80.0)
		var u := _add(guns[i], 0, gp, lv, army)
		if c["rule"] == "stagger":
			# (the variant: the guns are tagged massive on this unit's own copy of its numbers: TONGUE only staggers them)
			var tags: Array = (u.d.get("tags", []) as Array).duplicate()
			tags.append("massive")
			u.d = u.d.duplicate()
			u.d["tags"] = tags
	for i in 2:
		var hp: Vector2 = mid - dir * 40.0 + perp * ((i - 0.5) * 150.0)
		_add("cuirassier", 0, hp, lv, army)
	var wagon := _add("powder_wagon", 0, mid - dir * 140.0, lv, army)
	var labs: Array = []
	for i in 4:
		_add("labourer", 0, mid - dir * 110.0 + perp * ((i - 1.5) * 30.0), lv, labs)
	for u in labs:
		u.auto_repair = true
	var haulers: Array = []
	var hall := _hall(0)
	for i in 2:
		var h := _add("labourer", 0, hall.center() + Vector2(0, 60), int(g.height[g.idx(g.cell_of(hall.center()))]), haulers)
		h.cmd_gather(hall)
	for u in army:
		if u.deploys():
			u.cmd_deploy()
		else:
			u.cmd_hold()
	return {"army": army, "labs": labs, "haulers": haulers, "wagon": wagon}


## The attacker's army worth `budget` (gold-like units: the second resource at face value).
func _attack_army(c: Dictionary, budget: float, rng: RandomNumberGenerator) -> Array:
	var list: Array = []
	var m: float = c["mult"]
	var n := {}
	var big := 2 if m > 1.2 else 1
	match c["att"]:
		"CW":
			n = {"ballista": big, "great_winder": 1, "pendulum": big, "netter": 1, "springer": 4 * big, "winder": 2}
			if c.get("bsiege", false):
				# (the patient siege: Ballistas shoot the line from beyond its sight, the rest waits)
				n = {"ballista": 4 * big, "great_winder": 1, "springer": 4, "winder": 2}
		"OB":
			n = {"brute": 2 * big, "spitter": 10 * big}
			if c["rule"] != "none":
				n["mist_toad"] = 2
		"NB":
			# (the new Brood has Spitters too: the Tyrannosaur fathers them until a Spitter father exists; the owner, 11:03)
			# (no Tyrannosaur: sent with the wave in the first runs it stood 370 px from the gate on its attack order and never
			# reached it; and a player keeps him at the Mother, where he fathers the warriors)
			n = {"brute": 2 * big, "spitter": 10 * big}
			if c["rule"] != "none":
				n["mist_toad"] = 2
	var spent := 0.0
	for k in n:
		spent += (PRICE[k][0] + PRICE[k][1]) * int(n[k])
	var filler := "clock_soldier" if c["att"] == "CW" else "raptor"
	var fp: Array = PRICE[filler]
	n[filler] = maxi(0, int(round((budget - spent) / (fp[0] + fp[1]))))
	var muster: Vector2 = setup["muster"]
	var dir: Vector2 = setup["dir"]
	var perp := Vector2(-dir.y, dir.x)
	var flv: int = setup["flv"]
	var order := ["clock_soldier", "raptor", "brute", "tyrannosaur", "pendulum", "springer", "netter", "spitter", "mist_toad", "ballista", "great_winder", "winder"]
	var row := 0.0
	for k in order:
		if not n.has(k):
			continue
		var cnt: int = n[k]
		var sp := 22.0 if k in ["raptor"] else (30.0 if k in ["clock_soldier", "spitter", "springer"] else 56.0)
		var cols := maxi(1, int(ceil(sqrt(cnt * 1.6))))
		for i in cnt:
			var p: Vector2 = muster + dir * (row + (i / cols) * sp) + perp * (((i % cols) - (cols - 1) / 2.0) * sp)
			p += Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			var u := _add(k, 1, p, flv, list)
			if k == "mist_toad":
				u.charge = float(Defs.TOAD["max"])     # (a Toad brought to a planned siege has waited: full energy)
		row += ceil(float(cnt) / cols) * sp + 10.0
	return list


# ------------------------------------------------------------------ one fight

var ev: Array = []          # [time, text]
var t0 := 0.0
var rec := {}


func _log(s: String) -> void:
	var tt := snappedf(g.clock - t0, 0.5)
	ev.append([tt, s])
	print("  %5.1f %s" % [tt, s])


func fight(c: Dictionary, s: int) -> Dictionary:
	seed(1000 + s * 7919)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + s * 131
	for k in ["matchlock", "bayonet", "pouch", "charge"]:
		g.players[0]["tech"][k] = true
	if c["att"] == "CW":
		g.players[1]["tech"]["shield_wall"] = true
		g.players[1]["tech"]["high_leap"] = true
	g.players[0]["gold"] = 3000
	g.players[0]["res2"] = 600
	for b in wall_pieces:
		if is_instance_valid(b) and not b.dead:
			b.hp = b.max_hp
	ev = []
	roster = []
	co = {}
	rec = {"tongues": [], "fogs": 0, "pulled": 0, "staggered": 0, "broken": 0, "toad_killed_windup": 0, "pulled_guns_killed": 0,
		"charge_stuns": 0, "menders_killed": 0, "leaps": 0}
	var tur := _turtle(c, rng)
	var crown: Array = tur["army"]
	var labs: Array = tur["labs"]
	labs_cache = labs
	crown_cache = crown
	cur_cfg = c
	var turtle_val := [0.0, 0.0]
	for u in crown:
		var pr := _price(u)
		turtle_val[0] += pr[0]
		turtle_val[1] += pr[1]
	var budget: float = (turtle_val[0] + turtle_val[1] + float(setup["wall_cost"])) * float(c["mult"])
	var foe := _attack_army(c, budget, rng)
	var foe_val := [0.0, 0.0]
	for u in foe:
		var pr := _price(u)
		foe_val[0] += pr[0]
		foe_val[1] += pr[1]
	var comp := {}
	for u in foe:
		comp[u.kind] = int(comp.get(u.kind, 0)) + 1
	await wait(3.0)
	for u in crown:
		if u.deploys():
			u.cmd_hold()
	var posts := {}
	for u in crown:
		posts[u] = u.position
	t0 = g.clock
	_rt0 = Time.get_ticks_msec()
	var repair0 := float(g.stats[0].get("repair", 0.0))
	var gold0 := float(g.players[0]["gold"])
	var phase := "go"
	var t_first_down := -1.0
	var t_gate_down := -1.0
	var t_inside := -1.0
	var frame := 0
	var watch := {"on": true}
	_watch(watch, crown, foe)
	var spent_out := false
	while g.clock - t0 < cap_t:
		if film != "":
			await _film_frame(crown, foe, frame, c["name"])
			frame += 1
		await wait(0.5)
		if verbose and int((g.clock - t0) * 2.0) % 20 == 0:
			print("    t %.0f real %d ms  crown %d foe %d  piece %s" % [g.clock - t0, Time.get_ticks_msec() - _rt0, _alive(crown).size(), _alive(foe).size(),
				str(int(_piece().hp)) if _piece() else "none"])
		var a0 := _alive(crown).filter(func(u) -> bool: return u.kind != "powder_wagon")
		var a1 := _alive(foe).filter(func(u) -> bool: return not u.kind in ["mist_toad", "winder", "great_winder"])
		if a0.is_empty() or a1.is_empty():
			break
		# (what is left of the attack is a tenth of it or less, and the wall stands: the turtle held; a lone Ballista
		# bombarding a gate the menders keep mending would only run the clock out)
		var left1 := 0.0
		for u in a1:
			var pr := _price(u)
			left1 += pr[0] + pr[1]
		if left1 < (foe_val[0] + foe_val[1]) * 0.1 and not _breached():
			spent_out = true
			break
		# (only the Ballistas are left, out of reach: the assault is spent; in the patient siege they are the point)
		if not c.get("bsiege", false) and a1.all(func(u) -> bool: return u.kind in ["ballista", "netter"]):
			spent_out = true
			break
		if t_first_down < 0.0 and _breached():
			t_first_down = snappedf(g.clock - t0, 0.5)
			for i in wall_pieces.size():
				if not is_instance_valid(wall_pieces[i]) or wall_pieces[i].dead:
					_log("%s down" % wall_plan[i][0])
		if t_gate_down < 0.0 and _gate() == null:
			t_gate_down = snappedf(g.clock - t0, 0.5)
			_log("the gate is down")
		if t_inside < 0.0:
			for u in a1:
				if g.level_of(u.position) == int(setup["lv"]) and g.ramp[g.idx(g.cell_of(u.position))] == 0 \
						and (u.position - Vector2(setup["band_c"])).dot(setup["dir"]) < -30.0:
					t_inside = snappedf(g.clock - t0, 0.5)
					_log("the first %s is inside the wall" % u.d["name"])
					break
		_crown_tick(c, crown, labs, foe, posts)
		if not _muster_tick(c, foe):
			continue
		if c["att"] == "CW":
			_cw_tick(foe)
		else:
			_brood_tick(c, foe, crown)
	watch["on"] = false
	var dur: float = g.clock - t0
	var r := {"name": c["name"], "seed": s, "map": map, "att": c["att"], "mult": c["mult"], "rule": c["rule"], "react": c["react"],
		"guns": c["guns"], "repair": c["repair"], "time": snappedf(dur, 0.5), "turtle_cost": turtle_val, "wall_cost": setup["wall_cost"],
		"foe_cost": foe_val, "foe_comp": comp, "t_first_down": t_first_down, "t_gate_down": t_gate_down, "t_inside": t_inside}
	for side in [["crown", crown + labs + tur["haulers"]], ["foe", foe]]:
		var lost := [0.0, 0.0]
		var left := [0.0, 0.0]
		var dead := {}
		var alive := {}
		for ro in roster:
			if int(ro["team"]) != (0 if side[0] == "crown" else 1):
				continue
			var u = ro["u"]
			var pr: Array = ro["price"]
			if not is_instance_valid(u) or u.dead:
				lost[0] += pr[0]
				lost[1] += pr[1]
				var k: String = ro["kind"]
				dead[k] = int(dead.get(k, 0)) + 1
			else:
				left[0] += pr[0] * u.hp / maxf(1.0, u.max_hp)
				left[1] += pr[1] * u.hp / maxf(1.0, u.max_hp)
				alive[u.kind] = int(alive.get(u.kind, 0)) + 1
		r[side[0] + "_lost"] = [snappedf(lost[0], 1.0), snappedf(lost[1], 1.0)]
		r[side[0] + "_left"] = [snappedf(left[0], 1.0), snappedf(left[1], 1.0)]
		r[side[0] + "_dead"] = dead
		r[side[0] + "_alive"] = alive
	var wl := 0.0
	var broken := 0
	for i in wall_pieces.size():
		var b = wall_pieces[i]
		if not is_instance_valid(b) or b.dead:
			broken += 1
			wl += float(Defs.BUILDINGS[wall_plan[i][0]]["cost"])
	r["wall_lost"] = wl
	r["wall_broken"] = broken
	r["repair_gold"] = snappedf(float(g.stats[0].get("repair", 0.0)) - repair0, 1.0)
	var fighters0 := _alive(crown).filter(func(u) -> bool: return u.kind in ["musketeer", "cannon", "mortar", "cuirassier"])
	var fighters1 := _alive(foe).filter(func(u) -> bool: return not u.kind in ["mist_toad", "winder", "great_winder"])
	var res := "held"
	if fighters0.is_empty():
		res = "broken"
	elif not fighters1.is_empty() and not spent_out:
		res = "timeout"
	r["result"] = res
	for k in rec:
		r[k] = rec[k]
	r["events"] = ev
	if film != "":
		await _film_frame(crown, foe, frame, c["name"], true)
		_write_events(c["name"])
	# clear the field for the next fight
	for z in g.zones:
		z["age"] = maxf(float(z["age"]), float(z["t"]))
	for u in crown + labs + tur["haulers"] + foe:
		if is_instance_valid(u):
			g.consume_unit(u)
	for u in g.units.duplicate():
		if is_instance_valid(u) and (u.dead or (u.team == 0 and u.kind == "horse")):
			g.consume_unit(u)
	for k in g.kegs.duplicate():
		if is_instance_valid(k):
			k.queue_free()
	g.kegs.clear()
	for i in wall_pieces.size():
		var b = wall_pieces[i]
		if not is_instance_valid(b) or b.dead:
			wall_pieces[i] = g._add_building(wall_plan[i][0], 0, wall_plan[i][1], true)
	await wait(1.0)
	return r


# ------------------------------------------------------------------ the Crown's hands

var _rep_t := 0.0


func _crown_tick(c: Dictionary, crown: Array, labs: Array, foe: Array, posts: Dictionary) -> void:
	# REPAIR (as the computer: AI._repair_wall's rule, but up to 3 hands and the guns too): a hurt piece (below 85%) or
	# a hurt gun (below 70%) gets the nearest free labourer, while the spot is safe (AI._repair_safe)
	if c["repair"]:
		var busy := 0
		for u in _alive(labs):
			if u.order == "repair":
				busy += 1
		var hurt: Array = []
		for b in wall_pieces:
			if is_instance_valid(b) and not b.dead and b.hp < b.max_hp * 0.85 and crown_ai._repair_safe(b):
				hurt.append(b)
		for u in _alive(crown):
			if u.kind in ["cannon", "mortar"] and u.hp < u.max_hp * 0.7 and g.level_of(u.position) == int(setup["lv"]):
				hurt.append(u)
		hurt.sort_custom(func(a, b) -> bool: return a.hp / a.max_hp < b.hp / b.max_hp)
		for h in hurt:
			if busy >= 3:
				break
			var already := false
			for u in _alive(labs):
				if u.order == "repair" and u.order_target == h:
					already = true
			if already:
				continue
			var best: Unit = null
			var bd := INF
			for u in _alive(labs):
				if u.order == "repair":
					continue
				var dd: float = u.position.distance_to(h.center())
				if dd < bd:
					bd = dd
					best = u
			if best:
				best.cmd_repair(h)
				busy += 1
	else:
		for u in _alive(labs):
			if u.order == "repair":
				u.cmd_stop()
			u.auto_repair = false
	# idle labourers back to their post behind the guns
	for u in _alive(labs):
		if u.order == "idle" and u.position.distance_to(Vector2(setup["line"]) - Vector2(setup["dir"]) * 110.0) > 60.0:
			u.cmd_move(Vector2(setup["line"]) - Vector2(setup["dir"]) * 110.0)
	if not c["react"]:
		return
	# THE GOOD PLAYER'S ANSWER TO THE TONGUE WARNING: every gun and Musketeer that reaches the marked Toad shoots it; the
	# Horsemen ride at it (Cavalry Charge: the blow stuns, the windup breaks); the guns fire at any Toad they reach
	var marked: Array = []
	var toads: Array = _alive(foe).filter(func(u) -> bool: return u.kind == "mist_toad")
	for tu in toads:
		if tu.tongue_stage == "windup" or (c.get("gunprio", true) and (tu.order == "tongue" or tu.order == "cast")):
			marked.append(tu)
	for u in _alive(crown):
		if u.kind == "powder_wagon":
			continue
		if not c.get("focus", true) and u.kind != "cuirassier":
			continue            # ("rcav": only the Horsemen answer the warning, to measure the charge against the escort)
		var tgt: Unit = null
		var bd := INF
		var pool: Array = marked if not u.kind in ["cannon", "mortar"] or not c.get("gunprio", true) else toads
		for tu in pool:
			if not g.is_visible_to(0, tu.position):
				continue
			var dd: float = tu.position.distance_to(u.position)
			var reach: float = u._range() + tu.radius
			if u.kind == "cuirassier":
				reach = 420.0
			if dd < reach and dd < bd and (u.kind != "mortar" or dd > 170.0) and (u.kind != "cannon" or dd > 85.0):
				bd = dd
				tgt = tu
		if tgt:
			if not (u.order == "attack" and u.order_target == tgt):
				u.cmd_attack(tgt)
		elif u.order == "attack" and is_instance_valid(u.order_target) and u.order_target is Unit and u.order_target.kind == "mist_toad":
			# the Toad is gone or out of sight: back to the post
			if u.kind == "cuirassier" or u.position.distance_to(posts[u]) > 20.0:
				u.cmd_move(posts[u])
			else:
				u.cmd_hold()
		elif u.kind == "cuirassier" and u.order == "idle" and u.position.distance_to(posts[u]) > 30.0:
			u.cmd_move(posts[u])
		elif u.order == "idle" and u.position.distance_to(posts[u]) <= 30.0:
			u.cmd_hold()


# ------------------------------------------------------------------ the Clockwork's siege (coached)

var _aimed := {}


## THE MUSTER (a good player does not walk in a column): the whole army gathers at P1, out of the Crown's sight (300 px
## down from the gate), then goes in together, the slow ones first so that all reach the gate at about the same time.
## The Clockwork's Ballistas BOMBARD the gate from P1 meanwhile (they fire into the fog), and the assault waits for
## the gate to drop under 75% or 25 s of bombardment. Returns true once the assault is on.
var co := {}


func _muster_tick(c: Dictionary, foe: Array) -> bool:
	var a := _alive(foe)
	var piece := _piece()
	if co.is_empty():
		var gp: Vector2 = piece.center() if piece else Vector2(setup["band_c"])
		co = {"phase": "gather", "t": g.clock, "p1": _free_near(gp + Vector2(setup["dir"]) * 300.0, int(setup["flv"]), 12.0), "ready_t": -1.0}
		for u in a:
			u.cmd_move(co["p1"])
	if co["phase"] == "go":
		return true
	var p1: Vector2 = co["p1"]
	var far := 0
	for u in a:
		if u.kind == "ballista":
			if c.get("bsiege", false):
				_bombard_line(u)
			elif piece and u.order != "bombard":
				u.cmd_bombard(piece.center())
			continue
		if u.position.distance_to(p1) > 150.0:
			far += 1 if float(u.d["speed"]) >= 60.0 else 1000      # (the slow ones, the Toads first, must be there)
			if u.order == "idle":
				u.cmd_move(p1)
	if co["ready_t"] < 0.0 and (far <= a.size() / 8 or g.clock - float(co["t"]) > 40.0):
		co["ready_t"] = g.clock
		_log("the army is gathered at the ramp's foot")
	if co["ready_t"] < 0.0:
		return false
	var hold := 0.0
	if c.get("bsiege", false):
		var musk := _alive(crown_cache).filter(func(u) -> bool: return u.kind == "musketeer").size()
		if musk > 9 and g.clock - float(co["ready_t"]) < 120.0:
			return false
	elif c["att"] == "CW" and piece:
		var bal := a.any(func(u) -> bool: return u.kind == "ballista")
		if bal and piece.hp > piece.max_hp * 0.75 and g.clock - float(co["ready_t"]) < 25.0:
			return false
		hold = 0.0
	co["phase"] = "go"
	var gp2: Vector2 = piece.center() if piece else Vector2(setup["band_c"])
	var slow := INF
	for u in a:
		if u.kind in ["winder", "great_winder", "ballista"]:
			continue
		slow = minf(slow, float(u.d["speed"]))
	for u in a:
		var d: float = u.position.distance_to(gp2)
		var sp := float(u.d["speed"])
		u.set_meta("go_t", g.clock + hold + maxf(0.0, d / maxf(1.0, slow) - d / maxf(1.0, sp)))
	_log("the assault goes in (gate at %d%%)" % int(100.0 * piece.hp / piece.max_hp) if piece else "the assault goes in")
	return true


var crown_cache: Array = []
var cur_cfg := {}


## The patient siege: a Ballista fires at the middle of the Musketeer line (BOMBARD: into the fog, from beyond the line's
## sight), its bolt through the ranks; it re-aims every 6 s as the line thins.
func _bombard_line(u: Unit) -> void:
	var at := Vector2.ZERO
	var n := 0
	for e in _alive(crown_cache):
		if e.kind == "musketeer" or e.kind == "cannon" or e.kind == "mortar":
			at += e.position
			n += 1
	if n == 0:
		return
	at /= n
	# (first to its own firing spot, 290 px out from the line: beyond the Musketeers' 8-tile sight, inside its own 300)
	if not u.has_meta("spot"):
		var k := int(rec.get("bal_n", 0))
		rec["bal_n"] = k + 1
		var side := Vector2(-Vector2(setup["dir"]).y, Vector2(setup["dir"]).x)
		u.set_meta("spot", _free_near(at + Vector2(setup["dir"]) * 290.0 + side * (k % 4 - 1.5) * 50.0, int(setup["flv"]), 26.0))
	var spot: Vector2 = u.get_meta("spot")
	if not u.has_meta("placed"):
		if u.position.distance_to(spot) > 24.0:
			if u.order != "move" or u.order_point.distance_to(spot) > 10.0:
				u.cmd_move(spot)
			return
		u.set_meta("placed", true)
	if u.order != "bombard" or u.order_point.distance_to(at) > 30.0 and g.clock - float(u.get_meta("aim_t", -99.0)) > 6.0:
		u.cmd_bombard(at)
		u.set_meta("aim_t", g.clock)


## A unit held back so the slow ones lead (its go time is still ahead): it waits at P1.
func _held(u: Unit) -> bool:
	return u.has_meta("go_t") and g.clock < float(u.get_meta("go_t"))


func _cw_tick(foe: Array) -> void:
	var piece := _piece()
	var a := _alive(foe)
	ShieldWall.think(g, 1)
	if att_ai.has_method("_springer_leaps"):
		var n0: int = att_ai._leapt.size()
		att_ai._springer_leaps(a)
		if att_ai._leapt.size() > n0:
			rec["leaps"] += att_ai._leapt.size() - n0
			_log("%d Springers leap up" % (att_ai._leapt.size() - n0))
	var aimed := {}
	var centre := Vector2.ZERO
	var nc := 0
	for u in a:
		if u.kind == "clock_soldier":
			centre += u.position
			nc += 1
	centre = centre / nc if nc > 0 else Vector2(setup["foot"])
	for u in a:
		match u.kind:
			"winder", "great_winder":
				# (behind the soldiers, out of musket reach; they mend on their own)
				var back: Vector2 = centre + Vector2(setup["dir"]) * 120.0
				if u.order == "idle" and u.position.distance_to(back) > 60.0:
					u.cmd_move(back)
				continue
			"ballista":
				if cur_cfg.get("bsiege", false) and not _alive(crown_cache).is_empty():
					_bombard_line(u)
				elif piece == null:
					if u.order == "idle":
						u.cmd_move(setup["line"], true)
				elif u.order != "bombard":
					u.cmd_bombard(piece.center())
				continue
		if _held(u):
			continue
		if att_ai._leapt.has(u):
			att_ai._leapt_fight(u)
			continue
		if piece == null:
			# the wall is open: everything in, after the line
			if u.order == "idle" or (u.order == "attack" and u.order_target is Building):
				u.cmd_move(setup["line"], true)
			continue
		if u.kind in ["springer", "netter"]:
			var prey: Unit = att_ai._siege_prey(u, piece, aimed)
			if prey != null:
				aimed[prey] = int(aimed.get(prey, 0)) + 1
				if not (u.order == "attack" and u.order_target == prey):
					u.cmd_attack(prey)
					if prey.is_worker():
						rec["mender_shots"] = int(rec.get("mender_shots", 0)) + 1
				continue
		if not (u.order == "attack" and u.order_target == piece) and not (u.order == "attack" and u.order_target is Unit and is_instance_valid(u.order_target) and not u.order_target.dead and u.order_target.position.distance_to(u.position) < 80.0):
			u.cmd_attack(piece)


# ------------------------------------------------------------------ the Brood's siege (coached)

func _brood_tick(c: Dictionary, foe: Array, crown: Array) -> void:
	var piece := _piece()
	var a := _alive(foe)
	var fighting := false
	for u in a:
		if u.kind in ["raptor", "brute", "tyrannosaur"] and piece and piece.edge_distance(u.position) < 60.0:
			fighting = true
	for u in _alive(crown):
		if u.kind == "musketeer" and u.hp < u.max_hp:
			fighting = true
	var line := Vector2.ZERO
	var nl := 0
	var guns: Array = []
	for u in _alive(crown):
		if u.kind == "musketeer":
			line += u.position
			nl += 1
		elif u.kind in ["cannon", "mortar"]:
			guns.append(u)
	line = line / nl if nl > 0 else Vector2(setup["line"])
	var toads: Array = a.filter(func(u) -> bool: return u.kind == "mist_toad")
	var fog_on := false
	for z in g.zones:
		if z["kind"] == "fog" and float(z["age"]) < float(z["t"]) - 2.0 and Vector2(z["pos"]).distance_to(line) < 110.0:
			fog_on = true
	for tu in toads:
		if tu.order == "cast":
			fog_on = true
	var taken := {}
	for tu in toads:
		if tu.tongue_victim:
			taken[tu.tongue_victim] = true
		if tu.order == "tongue" and tu.order_target:
			taken[tu.order_target] = true
	var stage: Vector2 = Vector2(setup["ramp_c"]) + Vector2(setup["dir"]) * 150.0
	for i in toads.size():
		var tu: Unit = toads[i]
		if tu.order in ["cast", "tongue"] or tu.tongue_stage != "":
			continue
		# (the first Toad fogs the line once the swarm is at the gate; the second goes up with the wave for the TONGUE)
		var tongue_first: bool = i == 1 and not tu.has_meta("tongued")
		if not fighting and not tongue_first:
			if tu.position.distance_to(stage) > 40.0 and (tu.order != "move" or tu.order_point.distance_to(stage) > 30.0):
				tu.cmd_move(stage)
			continue
		var want_fog: bool = (i == 0 or toads.size() == 1) and not fog_on and tu.charge >= float(Defs.FOG["cost"])
		if want_fog:
			tu.cmd_cast("fog", line)
			rec["fogs"] += 1
			_log("a Toad lays FOG on the line")
			continue
		if tu.charge >= float(Defs.TONGUE["cost"]):
			var best: Unit = null
			var bs := INF
			for e in _alive(crown):
				if taken.has(e) or not tu.can_tongue(e) or not g.is_visible_to(1, e.position) and not (e.kind in ["cannon", "mortar"]):
					continue
				if e.position.distance_to(tu.position) < 90.0:
					continue          # (already at its feet: pulled in)
				var sc: float = e.position.distance_to(tu.position)
				if e.kind in ["cannon", "mortar"]:
					if Unit.too_heavy(e):
						continue          # (only a stagger: a good player tongues a man instead)
					sc -= 400.0
				elif e.kind == "labourer" or e.kind == "cuirassier":
					sc -= 60.0
				elif e.kind != "musketeer":
					continue
				if sc < bs:
					bs = sc
					best = e
			for e in _alive(labs_cache):
				if taken.has(e) or not tu.can_tongue(e):
					continue
				var sc2: float = e.position.distance_to(tu.position) - 60.0
				if sc2 < bs:
					bs = sc2
					best = e
			if best and best.position.distance_to(tu.position) < 650.0:
				tu.cmd_tongue(best)
				tu.set_meta("tongued", true)
				taken[best] = true
			elif not fog_on and tu.charge >= float(Defs.FOG["cost"]):
				tu.cmd_cast("fog", line)
				rec["fogs"] += 1
				_log("a Toad lays FOG on the line")
	# THE ESCORT (the owner, 11:05): three Spitters keep by each Toad; a Horseman riding at a Toad is focused by them
	var escorting := {}
	if c["escort"] and c["rule"] != "none":
		var spit: Array = a.filter(func(u) -> bool: return u.kind == "spitter")
		for tu in toads:
			var own: Array = []
			for sp in spit:
				if (sp.get_meta("esc") if sp.has_meta("esc") else null) == tu:
					own.append(sp)
			for sp in spit:
				if own.size() >= 3:
					break
				var m = (sp.get_meta("esc") if sp.has_meta("esc") else null)
				if m == null or not is_instance_valid(m) or m.dead:
					sp.set_meta("esc", tu)
					own.append(sp)
			var rider: Unit = null
			var rd := INF
			for e in g.units_near(tu.position, 320.0):
				if e.team == 0 and not e.dead and e.kind == "cuirassier" and ((e.order == "attack" and e.order_target == tu) or e.position.distance_to(tu.position) < 170.0):
					var dd: float = e.position.distance_to(tu.position)
					if dd < rd:
						rd = dd
						rider = e
			var side := Vector2(-Vector2(setup["dir"]).y, Vector2(setup["dir"]).x)
			for j in own.size():
				var sp: Unit = own[j]
				escorting[sp] = true
				if rider:
					if not (sp.order == "attack" and sp.order_target == rider):
						sp.cmd_attack(rider)
						rec["escort_focus"] = int(rec.get("escort_focus", 0)) + 1
				else:
					var at: Vector2 = tu.position + Vector2(setup["dir"]) * 30.0 + side * (j - 1) * 26.0
					var busy: bool = sp.order == "attack" and is_instance_valid(sp.order_target) and sp.order_target is Unit and not sp.order_target.dead \
						and sp.order_target.position.distance_to(sp.position) < 170.0
					if not busy and sp.position.distance_to(at) > 40.0 and (sp.order != "move" or sp.order_point.distance_to(at) > 30.0):
						sp.cmd_move(at)
	# what was pulled in is eaten at once
	for tu in toads:
		if tu.tongue_stage == "pull" and is_instance_valid(tu.tongue_victim):
			var v: Unit = tu.tongue_victim
			var n := 0
			for u in a:
				if u.kind in ["raptor", "brute"] and n < 8 and u.position.distance_to(tu.position) < 260.0:
					u.cmd_attack(v)
					n += 1
	for u in a:
		if u.kind == "mist_toad" or escorting.has(u) or _held(u):
			continue
		if u.order == "attack" and is_instance_valid(u.order_target) and u.order_target is Unit and not u.order_target.dead:
			continue
		if piece == null:
			if u.order == "idle" or (u.order == "attack" and u.order_target is Building):
				u.cmd_move(setup["line"], true)
			continue
		match u.kind:
			"spitter":
				# (to the wall's foot: they spit over it at whatever they reach, acid on the gate otherwise)
				if u.order == "idle" or (u.order == "move" and not u.order_point.is_equal_approx(piece.center())):
					u.cmd_move(piece.center(), true)
			_:
				if not (u.order == "attack" and u.order_target == piece):
					u.cmd_attack(piece)


var labs_cache: Array = []


# ------------------------------------------------------------------ watching (every frame)

func _watch(w: Dictionary, crown: Array, foe: Array) -> void:
	var stages := {}
	var guns_pulled := {}
	var stuns := {}
	while w["on"]:
		await physics_frame
		if not w["on"] or g == null:
			return
		var fz := 0
		for z in g.zones:
			if z["kind"] == "fog" and float(z["age"]) < float(z["t"]):
				fz += 1
		if fz > int(w.get("nfog", 0)):
			rec["fogs_laid"] = int(rec.get("fogs_laid", 0)) + 1
			_log("the fog bank is down")
		w["nfog"] = fz
		for tu in foe:
			if not is_instance_valid(tu) or tu.kind != "mist_toad":
				continue
			var st: String = tu.tongue_stage if not tu.dead else ""
			var prev: String = stages.get(tu, "")
			if tu.stun_t > 0.0 and not stuns.get(tu, false):
				stuns[tu] = true
				if prev == "windup":
					rec["charge_stuns"] += 1
			elif tu.stun_t <= 0.0:
				stuns[tu] = false
			if st == prev:
				continue
			stages[tu] = st
			if st == "windup" and tu.tongue_victim:
				var v: Unit = tu.tongue_victim
				var e := {"victim": v.kind, "t": snappedf(g.clock - t0, 0.1), "dist": snappedf(v.position.distance_to(tu.position), 1.0), "result": "", "_v": v, "_toad": tu}
				rec["tongues"].append(e)
				_log("a Toad marks the %s (%d px)" % [v.d["name"], int(e["dist"])])
			elif not rec["tongues"].is_empty():
				var e: Dictionary = {}
				for x in rec["tongues"]:
					if x.get("_toad") == tu and x["result"] == "":
						e = x
				if e.is_empty():
					continue
				if st == "pull":
					e["result"] = "pulled"
					rec["pulled"] += 1
					var v = e["_v"]
					if is_instance_valid(v) and v.kind in ["cannon", "mortar"]:
						guns_pulled[v] = true
						_log("the %s is PULLED out to the Toad" % v.d["name"])
				elif st == "recoil":
					e["result"] = "staggered"
					rec["staggered"] += 1
					_log("the tongue only staggers the %s" % e["victim"])
				elif st == "" and prev == "windup":
					e["result"] = "toad killed in windup" if tu.dead else "broken"
					if tu.dead:
						rec["toad_killed_windup"] += 1
						_log("the Toad is killed in its windup")
					else:
						rec["broken"] += 1
						_log("the tongue is broken (the Toad stunned or moved)")
		for gu in guns_pulled.keys():
			if guns_pulled[gu] and (not is_instance_valid(gu) or gu.dead):
				guns_pulled[gu] = false
				rec["pulled_guns_killed"] += 1
				_log("the pulled gun is destroyed")
		for u in labs_cache:
			if is_instance_valid(u) and u.dead and not u.get_meta("counted", false):
				u.set_meta("counted", true)
				rec["menders_killed"] += 1
				_log("a Labourer by the wall is killed")


func _clean_tongues() -> void:
	for e in rec["tongues"]:
		e.erase("_v")
		e.erase("_toad")


# ------------------------------------------------------------------ film

func _film_frame(crown: Array, foe: Array, i: int, name: String, last := false) -> void:
	var piece := _piece()
	var c: Vector2 = piece.center() if piece else Vector2(setup["band_c"])
	c = c.lerp(Vector2(setup["line"]), 0.35)
	g.camera.position = c + Vector2(setup["dir"]) * 40.0
	g.camera.zoom = Vector2(film_zoom, film_zoom)
	if g.hud:
		g.hud.visible = false
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%04d.png" % [film, name, i])
	if last:
		img.save_png("%s/%s_end.png" % [film, name])


func _write_events(name: String) -> void:
	var f := FileAccess.open("%s/%s_events.txt" % [film, name], FileAccess.WRITE)
	for e in ev:
		f.store_line("%s %s" % [_mmss(e[0]), e[1]])
	f.close()


func _mmss(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


# ------------------------------------------------------------------ the run

func _clear_start() -> void:
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN:
			g.consume_unit(u)


## L: can a deployed Field Cannon limber and get 336 px from a Toad within the 3 s windup? (owner: it should not)
func _limber_test() -> void:
	var lv: int = setup["lv"]
	var list: Array = []
	var gun := _add("cannon", 0, setup["line"], lv, list)
	gun.cmd_deploy()
	await wait(3.5)
	var start: Vector2 = gun.position
	gun.cmd_pack()
	var t1 := g.clock
	var away: Vector2 = Vector2(setup["line"]) - Vector2(setup["dir"]) * 600.0
	var moved_at := -1.0
	while g.clock - t1 < 8.0:
		await wait(0.1)
		if gun.tesla_mode == "packed" and gun.order != "move":
			gun.cmd_move(away)
		if moved_at < 0.0 and gun.position.distance_to(start) > 2.0:
			moved_at = g.clock - t1
		if absf(fmod(g.clock - t1, 1.0)) < 0.05:
			print("  t %.1f mode %s moved %.0f px" % [g.clock - t1, gun.tesla_mode, gun.position.distance_to(start)])
	print("LIMBER: first moved at %.1f s; after 3 s it would need to be 112+ px further away (Toad at 224, break at 336)" % moved_at)


func _run() -> void:
	await wait(1.0)
	_clear_start()
	g.players[0]["cap"] = 400
	g.players[1]["cap"] = 400
	setup = _ramp_setup()
	if group == "L":
		await _limber_test()
		quit(0)
		return
	var list := configs()
	print("STUDY group %s (%s): %d configs x %d seeds, map %s" % [group, att, list.size(), n_seeds, map])
	for c in list:
		for s in range(seed_from, seed_from + n_seeds):
			var r: Dictionary = await fight(c, s)
			_clean_tongues()
			r["tongues"] = rec["tongues"]
			var line := JSON.stringify(r)
			if _out:
				_out.store_line(line)
				_out.flush()
			print("%-22s s%d %-7s %5.1fs gate %.0f in %.0f | crown lost %s dead %s | foe lost %s dead %s | pulled %d stag %d brk %d tk %d" % [
				r["name"], s, r["result"], r["time"], r["t_gate_down"], r["t_inside"], str(r["crown_lost"]), str(r["crown_dead"]),
				str(r["foe_lost"]), str(r["foe_dead"]), r["pulled"], r["staggered"], r["broken"], r["toad_killed_windup"]])
	if _out:
		_out.close()
	print("STUDY DONE")
	quit(0)
